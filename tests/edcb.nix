{
  pkgs,
  self,
}:

let
  fakeEdcb = pkgs.runCommand "fake-edcb" { } ''
    mkdir -p "$out/bin" "$out/lib/edcb" "$out/share/edcb/initial-state/HttpPublic"
    cp ${pkgs.writeShellScript "EpgTimerSrv" "exec sleep infinity"} "$out/bin/EpgTimerSrv"
    chmod +x "$out/bin/EpgTimerSrv"
    touch "$out/lib/edcb/"{EpgDataCap3,RecName_Macro,SendTSTCP,Write_Default}.so
    touch "$out/share/edcb/initial-state/"{Bitrate.ini,BonCtrl.ini,ContentTypeText.txt}
    touch "$out/share/edcb/initial-state/HttpPublic/index.html"
  '';
  fakeWebUI = pkgs.runCommand "fake-edcb-material-webui" { } ''
    mkdir -p "$out/share/edcb-material-webui/HttpPublic/"{E3,api} "$out/share/edcb-material-webui/Setting"
    touch "$out/share/edcb-material-webui/HttpPublic/E3/index.html"
    touch "$out/share/edcb-material-webui/HttpPublic/api/util.lua"
    echo '[SET]' > "$out/share/edcb-material-webui/Setting/HttpPublic.ini"
    echo 'XCODE_OPTIONS={}' > "$out/share/edcb-material-webui/Setting/XCODE_OPTIONS.lua"
  '';
  fakeBonDriver = pkgs.runCommand "fake-bondriver" { } ''
    mkdir -p "$out/lib"
    touch "$out/lib/BonDriver_LinuxMirakc.so"
  '';
  fakeCustomBonDriver = pkgs.runCommand "fake-custom-bondriver" { } ''
    mkdir -p "$out/other"
    touch "$out/other/"{BonDriver_Custom,BonDriver_Unselected,BonDriver_FileOnly}.so
  '';
  customSettingsFile = pkgs.writeText "custom-driver.ini" ''
    ; Preserve the supplied file verbatim.
    [GLOBAL]
    PRIORITY=17
  '';
  coreSources = {
    "EpgTimerSrv.ini" =
      pkgs.writeText "supplied-EpgTimerSrv.ini" "; Keep comments and spacing\r\n[SET]\r\nTCPPort = 14510\r\nFileOnly = timer\r\n";
    "Common.ini" =
      pkgs.writeText "supplied-Common.ini" "; Keep comments and spacing\n[SET]\nRecFolderPath0 = /supplied/recordings\nFileOnly = common\n";
    "EpgDataCap_Bon.ini" =
      pkgs.writeText "supplied-EpgDataCap_Bon.ini" "; Keep comments and spacing\n[SET]\nTsBuffMaxCount = 7654\nFileOnly = capture\n";
  };
  fileNode = immutable: {
    imports = [ self.nixosModules.nix-dtv ];
    services.edcb = {
      enable = true;
      package = fakeEdcb;
      settingsFile = coreSources."EpgTimerSrv.ini";
      commonSettingsFile = coreSources."Common.ini";
      epgDataCapBonSettingsFile = coreSources."EpgDataCap_Bon.ini";
      settingsImmutable = immutable;
      commonSettingsImmutable = immutable;
      epgDataCapBonSettingsImmutable = immutable;
      settings.SET = {
        TCPPort = 9999;
        GeneratedOnly = "ignored";
      };
      commonSettings = if immutable then null else { SET.GeneratedOnly = "ignored"; };
      epgDataCapBonSettings = if immutable then { SET.TsBuffMaxCount = 9999; } else null;
      tcpPort = 4512;
      recordingDir = [ "/mnt/tv/recordings" ];
      bondriver = [
        {
          driverPath = "${fakeBonDriver}/lib/BonDriver_LinuxMirakc.so";
          tunerSettings.Count = 4;
        }
      ];
    };
  };
  fakePlugin = pkgs.runCommand "fake-edcb-plugin" { } ''
    mkdir -p "$out/lib"
    touch "$out/lib/Write_Custom.so"
  '';
in
pkgs.testers.runNixOSTest {
  node.pkgsReadOnly = false;
  name = "edcb-module";
  nodes.machine = {
    imports = [ self.nixosModules.nix-dtv ];
    security.polkit.enable = true;
    services.pcscd.enable = true;
    services.edcb = {
      enable = true;
      package = fakeEdcb;
      plugins = [
        {
          name = "RecName_Macro.so";
          settings.SET.Macro = "$ZtoH(Title)$.ts";
        }
        {
          pluginPath = "${fakePlugin}/lib/Write_Custom.so";
          settings.SET.Value = 42;
        }
        {
          pluginPath = "${fakePlugin}/lib/Write_Custom.so";
          name = "Write_File.so";
          settings.SET.Value = 99;
          settingsFile = customSettingsFile;
        }
        {
          pluginPath = "${fakePlugin}/lib/Write_Custom.so";
          name = "Write_Unmanaged.so";
        }
        {
          pluginPath = null;
          name = "Write_SettingsOnly.so";
          settings.SET.Value = 73;
        }
        {
          name = "Write_FileOnly.so";
          settingsFile = customSettingsFile;
        }
      ];
      materialWebUI = {
        enable = true;
        package = fakeWebUI;
        extraCertificateSubjectAltNames = [ "DNS:tv.example.com" ];
      };
      bondriver = [
        {
          driverPath = "${fakeBonDriver}/lib/BonDriver_LinuxMirakc.so";
          settings.GLOBAL.PRIORITY = 5;
          tunerSettings = {
            Count = 4;
            GetEpg = 1;
            EPGCount = 2;
          };
        }
        {
          driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
          settings.GLOBAL.PRIORITY = 7;
          settingsFile = customSettingsFile;
          tunerSettings.Count = 2;
        }
        {
          driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
          name = "BonDriver_Custom_2.so";
          settings.GLOBAL.PRIORITY = 8;
          tunerSettings.Count = 3;
        }
        {
          driverPath = "${fakeCustomBonDriver}/other/BonDriver_FileOnly.so";
          settingsFile = customSettingsFile;
        }
      ];
      recordingDir = [
        "/mnt/tv/recordings"
        "/srv/tv/archive"
      ];
      tcpPort = 4512;
      httpPorts = [
        5510
        5520
      ];
      httpsPorts = [
        5511
        5521
      ];
      settingsImmutable = false;
      settings.SET = {
        EnableHttpSrv = 1;
        HttpAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
        EnableTCPSrv = 1;
        TCPAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
        TCPPort = 9999;
        HttpPort = "9998,9999s";
        CompatFlags = 128;
        TimeSync = 0;
      };
      commonSettingsImmutable = false;
      commonSettings = { };
      epgDataCapBonSettingsImmutable = false;
      epgDataCapBonSettings.SET = {
        TsBuffMaxCount = 5000;
        WriteBuffMaxCount = -1;
      };
    };
  };
  nodes.immutable = {
    imports = [ self.nixosModules.nix-dtv ];
    services.edcb = {
      enable = true;
      package = fakeEdcb;
      settingsImmutable = true;
      commonSettingsImmutable = true;
      epgDataCapBonSettingsImmutable = true;
      epgDataCapBonSettings.SET.TsBuffMaxCount = 5000;
    };
  };
  nodes.fileImmutable = fileNode true;
  nodes.fileMutable = fileNode false;
  testScript = ''
    import shlex
    import configparser
    import json

    class EdcbIni(configparser.ConfigParser):
        def optionxform(self, optionstr: str) -> str:
            return optionstr

    core_sources = json.loads('${builtins.toJSON coreSources}')
    fileImmutable.wait_for_unit("edcb.service")
    file_pid = fileImmutable.succeed("systemctl show edcb.service -p MainPID --value").strip()
    for name, source in core_sources.items():
        path = "/var/lib/edcb/" + name
        prefix = f"${pkgs.util-linux}/bin/nsenter -t {file_pid} -m -- su -s /bin/sh edcb -c "
        fileImmutable.succeed(prefix + shlex.quote(f"cmp {source} {path}"))
        fileImmutable.fail(prefix + shlex.quote(f"echo changed > {path}"))

    fileMutable.wait_for_unit("edcb.service")
    expected = {
        "EpgTimerSrv.ini": {"TCPPort": "14510", "FileOnly": "timer"},
        "Common.ini": {"RecFolderPath0": "/supplied/recordings", "FileOnly": "common"},
        "EpgDataCap_Bon.ini": {"TsBuffMaxCount": "7654", "FileOnly": "capture"},
    }

    def read_file_ini(name):
        parser = EdcbIni(interpolation=None)
        parser.read_string(fileMutable.succeed(f"cat /var/lib/edcb/{name}"))
        return parser

    for name, values in expected.items():
        parser = read_file_ini(name)
        assert parser.sections() == ["SET"], (name, parser.sections())
        assert dict(parser["SET"]) == values, (name, dict(parser["SET"]))
        path = "/var/lib/edcb/" + name
        content = "[SET]\nFileOnly=runtime-conflict\nRuntimeKey=keep%value\n[RuntimeOnly]\nMixedCase=retained\n"
        fileMutable.succeed("su -s /bin/sh edcb -c " + shlex.quote(f"printf %s {shlex.quote(content)} > {path}"))
    before = fileMutable.succeed("sha256sum /var/lib/edcb/*.ini")
    fileMutable.succeed("systemctl restart edcb")
    assert fileMutable.succeed("sha256sum /var/lib/edcb/*.ini") == before
    fileMutable.succeed("systemctl stop edcb")
    for _ in range(2):
        fileMutable.succeed("/run/current-system/activate")
        for name, values in expected.items():
            parser = read_file_ini(name)
            assert parser.sections() == ["SET", "RuntimeOnly"]
            assert dict(parser["SET"]) == dict(values, RuntimeKey="keep%value")
            assert dict(parser["RuntimeOnly"]) == {"MixedCase": "retained"}
            fileMutable.succeed(f"test ! -L /var/lib/edcb/{name} && test $(stat -c %a /var/lib/edcb/{name}) = 640 && test $(stat -c %U /var/lib/edcb/{name}) = edcb")
    fileMutable.succeed("systemctl start edcb")

    def service_command(command):
        pid = machine.succeed("systemctl show edcb.service -p MainPID --value").strip()
        return f"${pkgs.util-linux}/bin/nsenter -t {pid} -m -- su -s /bin/sh edcb -c {shlex.quote(command)}"

    def service_succeed(command):
        return machine.succeed(service_command(command))

    def service_fail(command):
        return machine.fail(service_command(command))

    immutable.wait_for_unit("edcb.service")
    immutable.succeed("systemctl stop edcb")
    core_files = ["EpgTimerSrv.ini", "Common.ini", "EpgDataCap_Bon.ini"]
    for index, name in enumerate(core_files):
        source = "${customSettingsFile}" if index % 2 == 0 else "/nix/store/missing-ini"
        immutable.succeed(f"ln -sf {source} /var/lib/edcb/{name}")
    immutable.succeed("/run/current-system/activate")
    for name in core_files:
        immutable.succeed(f"test ! -L /var/lib/edcb/{name}")
    immutable.succeed("systemctl start edcb")
    immutable_pid = immutable.succeed("systemctl show edcb.service -p MainPID --value").strip()

    def immutable_command(command):
        return f"${pkgs.util-linux}/bin/nsenter -t {immutable_pid} -m -- su -s /bin/sh edcb -c {shlex.quote(command)}"

    for name in core_files:
        path = "/var/lib/edcb/" + name
        immutable.succeed(immutable_command(f"test -s {path} && test ! -L {path}"))
        before = immutable.succeed(immutable_command(f"sha256sum {path}"))
        for command in [f"echo changed > {path}", f"rm -f {path}", f"mv -f {path} {path}.moved"]:
            immutable.fail(immutable_command(command))
        immutable.succeed(immutable_command(f"echo replacement > {path}.replacement"))
        immutable.fail(immutable_command(f"mv -f {path}.replacement {path}"))
        immutable.succeed(immutable_command(f"rm {path}.replacement"))
        assert immutable.succeed(immutable_command(f"sha256sum {path}")) == before
    immutable.succeed(immutable_command("echo runtime > /var/lib/edcb/Reserve.txt"))

    machine.wait_for_unit("edcb.service")
    machine.wait_for_unit("polkit.service")
    machine.wait_for_unit("pcscd.socket")
    machine.succeed("test -f /run/current-system/sw/share/polkit-1/rules.d/10-edcb.rules")
    for action in ["access_pcsc", "access_card"]:
        machine.succeed(f"su -s /bin/sh edcb -c 'pkcheck --action-id org.debian.pcsc-lite.{action} --process $$'")
        machine.fail(f"su -s /bin/sh nobody -c 'pkcheck --action-id org.debian.pcsc-lite.{action} --process $$'")

    machine.succeed("test $(stat -c %U /var/lib/edcb) = edcb")
    machine.succeed("test $(stat -c %a /mnt/tv/recordings) = 2770")
    machine.succeed("test $(stat -c %a /srv/tv/archive) = 2770")
    machine.succeed("test -f /var/lib/edcb/Bitrate.ini")
    machine.succeed("test -f /var/lib/edcb/BonCtrl.ini")
    machine.succeed("test $(readlink -f /var/lib/edcb/HttpPublic/E3) = ${fakeWebUI}/share/edcb-material-webui/HttpPublic/E3")
    machine.succeed("test $(readlink -f /var/lib/edcb/HttpPublic/api) = ${fakeWebUI}/share/edcb-material-webui/HttpPublic/api")
    machine.succeed("test ! -L /var/lib/edcb/Setting/HttpPublic.ini")
    machine.succeed("test ! -L /var/lib/edcb/Setting/XCODE_OPTIONS.lua")
    machine.succeed("test $(stat -c %a /var/lib/edcb/Setting/HttpPublic.ini) = 640")
    machine.succeed("test $(stat -c %U /var/lib/edcb/Setting/XCODE_OPTIONS.lua) = edcb")
    machine.succeed("test $(stat -c %a /var/lib/edcb/ssl_cert.pem) = 600")
    machine.succeed("test $(stat -c %U /var/lib/edcb/ssl_cert.pem) = edcb")
    machine.succeed("${pkgs.openssl}/bin/openssl x509 -in /var/lib/edcb/ssl_cert.pem -noout -checkend 86400")
    machine.succeed("${pkgs.openssl}/bin/openssl x509 -in /var/lib/edcb/ssl_cert.pem -noout -ext subjectAltName | grep -F 'DNS:localhost'")
    machine.succeed("${pkgs.openssl}/bin/openssl x509 -in /var/lib/edcb/ssl_cert.pem -noout -ext subjectAltName | grep -F 'DNS:tv.example.com'")
    certificate_hash = machine.succeed("sha256sum /var/lib/edcb/ssl_cert.pem")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_LinuxMirakc.so")
    for name in ["Write_Custom.so", "Write_File.so", "Write_Unmanaged.so"]:
        machine.succeed(f"test $(readlink /var/lib/edcb/lib/{name}) = ${fakePlugin}/lib/Write_Custom.so")
        machine.fail(f"test -e /var/lib/edcb/lib/{name}.ini")
    service_succeed("grep -Fx 'Value=42' /var/lib/edcb/Write_Custom.so.ini")
    service_succeed("cmp /var/lib/edcb/Write_File.so.ini ${customSettingsFile}")
    service_fail("test -e /var/lib/edcb/Write_Unmanaged.so.ini")
    service_succeed("grep -Fx 'Value=73' /var/lib/edcb/Write_SettingsOnly.so.ini")
    service_succeed("cmp /var/lib/edcb/Write_FileOnly.so.ini ${customSettingsFile}")
    for name in ["Write_SettingsOnly.so", "Write_FileOnly.so"]:
        machine.fail(f"test -L /var/lib/edcb/lib/{name}")
        machine.fail(f"test -e /var/lib/edcb/lib/{name}")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_Custom.so")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_Custom_2.so")
    service_succeed("test -f /var/lib/edcb/lib/BonDriver_Custom_2.so.ini")
    machine.fail("test -e /var/lib/edcb/lib/BonDriver_Unselected.so")
    machine.fail("test -e /var/lib/edcb/lib/BonDriver_Unselected.so.ini")
    machine.succeed("test $(readlink -f /var/lib/edcb/lib/BonDriver_LinuxMirakc.so) = ${fakeBonDriver}/lib/BonDriver_LinuxMirakc.so")
    machine.succeed("test $(readlink -f /var/lib/edcb/lib/BonDriver_Custom.so) = ${fakeCustomBonDriver}/other/BonDriver_Custom.so")
    machine.succeed("test $(readlink -f /var/lib/edcb/lib/BonDriver_Custom_2.so) = ${fakeCustomBonDriver}/other/BonDriver_Custom.so")
    machine.succeed("grep -F 'RecFolderNum=2' /var/lib/edcb/Common.ini")
    machine.succeed("grep -F 'RecFolderPath0=/mnt/tv/recordings' /var/lib/edcb/Common.ini")
    machine.succeed("grep -F 'RecFolderPath1=/srv/tv/archive' /var/lib/edcb/Common.ini")
    machine.succeed("grep -F 'EnableTCPSrv=1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -Fx 'TCPPort=4512' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TCPAccessControlList=+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'CompatFlags=128' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TimeSync=0' /var/lib/edcb/EpgTimerSrv.ini")
    ini = EdcbIni()
    ini.read_string(machine.succeed("cat /var/lib/edcb/EpgTimerSrv.ini"))
    assert dict(ini["TVTEST"]) == {"Num": "4", "0": "BonDriver_LinuxMirakc.so", "1": "BonDriver_Custom.so", "2": "BonDriver_Custom_2.so", "3": "BonDriver_FileOnly.so"}
    assert dict(ini["BonDriver_LinuxMirakc.so"]) == {"Count": "4", "GetEpg": "1", "EPGCount": "2"}
    assert dict(ini["BonDriver_Custom.so"]) == {"Count": "2"}
    assert dict(ini["BonDriver_Custom_2.so"]) == {"Count": "3"}
    assert "BonDriver_FileOnly.so" not in ini
    assert "BonDriver_Unselected.so" not in ini
    machine.succeed("grep -F 'EnableHttpSrv=1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -Fx 'HttpPort=5510,5520,5511s,5521s' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F '[EPG_CAP]' /var/lib/edcb/EpgTimerSrv.ini")
    service_fail("grep -F 'SERVER_HOST=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    service_fail("grep -F 'SERVER_PORT=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    service_fail("grep -F 'SERVER_TYPE=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    service_succeed("grep -F 'PRIORITY=5' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    service_succeed("cmp /var/lib/edcb/lib/BonDriver_Custom.so.ini ${customSettingsFile}")
    service_succeed("grep -F 'PRIORITY=8' /var/lib/edcb/lib/BonDriver_Custom_2.so.ini")
    service_succeed("cmp /var/lib/edcb/lib/BonDriver_FileOnly.so.ini ${customSettingsFile}")
    service_fail("grep -F 'SERVER_HOST=' /var/lib/edcb/lib/BonDriver_Custom.so.ini")
    machine.succeed("grep -F 'TsBuffMaxCount=5000' /var/lib/edcb/EpgDataCap_Bon.ini")
    machine.succeed("grep -F 'WriteBuffMaxCount=-1' /var/lib/edcb/EpgDataCap_Bon.ini")
    service_succeed("grep -F 'Macro=$ZtoH(Title)$.ts' /var/lib/edcb/RecName_Macro.so.ini")
    immutable_files = [
        "RecName_Macro.so.ini", "Write_Custom.so.ini", "Write_File.so.ini",
        "Write_SettingsOnly.so.ini", "Write_FileOnly.so.ini",
        "lib/BonDriver_LinuxMirakc.so.ini", "lib/BonDriver_Custom.so.ini",
        "lib/BonDriver_Custom_2.so.ini", "lib/BonDriver_FileOnly.so.ini",
    ]
    for name in immutable_files:
        path = "/var/lib/edcb/" + name
        service_succeed(f"test -f {path} && test ! -L {path}")
        before = service_succeed(f"sha256sum {path}")
        service_fail(f"echo changed > {path}")
        service_fail(f"rm -f {path}")
        service_fail(f"mv -f {path} {path}.moved")
        service_succeed(f"echo replacement > {path}.replacement")
        service_fail(f"mv -f {path}.replacement {path}")
        service_succeed(f"rm {path}.replacement")
        assert service_succeed(f"sha256sum {path}") == before
    # The surrounding state and recording directories must remain writable.
    for path in ["/var/lib/edcb/Reserve.txt", "/var/lib/edcb/Setting/runtime.ini", "/mnt/tv/recordings/runtime.ts"]:
        service_succeed(f"echo runtime > {path} && mv {path} {path}.moved && rm {path}.moved")
    for name in ["EpgTimerSrv.ini", "Common.ini", "EpgDataCap_Bon.ini", "Setting/HttpPublic.ini"]:
        service_succeed(f"echo '; runtime update' >> /var/lib/edcb/{name}")
    import base64

    files = {
        "EpgTimerSrv.ini": ("EnableHttpSrv", "1"),
        "Common.ini": ("RecFolderPath0", "/mnt/tv/recordings"),
        "EpgDataCap_Bon.ini": ("TsBuffMaxCount", "5000"),
    }
    machine.succeed("systemctl stop edcb")
    for name, (key, value) in files.items():
        path = "/var/lib/edcb/" + name
        machine.succeed(f"test ! -L {path}; test $(stat -c %a {path}) = 640")
        port_settings = "TCPPort=1234\nHttpPort=1235,1236s\n" if name == "EpgTimerSrv.ini" else ""
        content = f"[SET]\n{key}=old\n{port_settings}Existing=keep%value\n[RuntimeOnly]\nMixedCase=保持\n"
        encoding = "utf-16" if name == "EpgTimerSrv.ini" else "utf-8-sig"
        encoded = base64.b64encode(content.encode(encoding)).decode()
        machine.succeed(f"echo {encoded} | base64 -d > {path}")
    # A service restart must not reapply Nix settings.
    before = machine.succeed("sha256sum /var/lib/edcb/*.ini")
    machine.succeed("systemctl restart edcb")
    assert machine.succeed("sha256sum /var/lib/edcb/*.ini") == before
    assert machine.succeed("sha256sum /var/lib/edcb/ssl_cert.pem") == certificate_hash
    machine.succeed("systemctl stop edcb")
    machine.succeed("echo custom >> /var/lib/edcb/Setting/HttpPublic.ini")
    # Simulate links left by a previous BonDriver selection, including dangling links.
    for suffix in [".so", ".so.ini"]:
        machine.succeed(f"ln -s ${customSettingsFile} /var/lib/edcb/lib/BonDriver_Removed{suffix}")
        machine.succeed(f"ln -s /nix/store/missing-driver /var/lib/edcb/lib/BonDriver_Dangling{suffix}")
        machine.succeed(f"echo manual > /var/lib/edcb/lib/BonDriver_Manual{suffix}")
        machine.succeed(f"ln -s /opt/missing-driver /var/lib/edcb/lib/BonDriver_External{suffix}")
    # Simulate the previous immutable layout, including a dangling store link.
    for index, name in enumerate(immutable_files):
        source = "${customSettingsFile}" if index % 2 == 0 else "/nix/store/missing-ini"
        machine.succeed(f"ln -sf {source} /var/lib/edcb/{name}")
    machine.succeed("ln -s ${customSettingsFile} /var/lib/edcb/Write_Unmanaged.so.ini")
    machine.succeed("/run/current-system/activate")
    for name in immutable_files + ["Write_Unmanaged.so.ini"]:
        machine.succeed(f"test ! -L /var/lib/edcb/{name}")
    machine.succeed("systemctl start edcb")
    for name in immutable_files:
        service_succeed(f"test -f /var/lib/edcb/{name} && test ! -L /var/lib/edcb/{name}")
    service_succeed("grep -Fx 'Value=42' /var/lib/edcb/Write_Custom.so.ini")
    service_succeed("cmp /var/lib/edcb/lib/BonDriver_Custom.so.ini ${customSettingsFile}")
    service_fail("test -e /var/lib/edcb/Write_Unmanaged.so.ini")
    machine.succeed("systemctl stop edcb")
    for suffix in [".so", ".so.ini"]:
        for name in ["Removed", "Dangling"]:
            machine.succeed(f"test ! -L /var/lib/edcb/lib/BonDriver_{name}{suffix}")
        machine.succeed(f"grep -Fx manual /var/lib/edcb/lib/BonDriver_Manual{suffix}")
        machine.succeed(f"test $(readlink /var/lib/edcb/lib/BonDriver_External{suffix}) = /opt/missing-driver")
        if suffix == ".so":
            machine.succeed(f"test -L /var/lib/edcb/lib/BonDriver_Custom{suffix}")
        else:
            machine.succeed(f"test ! -L /var/lib/edcb/lib/BonDriver_Custom{suffix}")
    machine.succeed("test -L /var/lib/edcb/lib/RecName_Macro.so")
    machine.succeed("grep -Fx custom /var/lib/edcb/Setting/HttpPublic.ini")
    for _ in range(2):
        machine.succeed("/run/current-system/activate")
        for name, (key, value) in files.items():
            path = "/var/lib/edcb/" + name
            machine.succeed(f"grep -Fx '{key}={value}' {path}")
            machine.succeed(f"grep -Fx 'Existing=keep%value' {path}")
            machine.succeed(f"grep -Fx 'MixedCase=保持' {path}")
            machine.fail(f"grep -F immutable {path}")
            machine.succeed(f"test $(stat -c %U {path}) = edcb")
        machine.succeed("grep -Fx 'TCPPort=4512' /var/lib/edcb/EpgTimerSrv.ini")
        machine.succeed("grep -Fx 'HttpPort=5510,5520,5511s,5521s' /var/lib/edcb/EpgTimerSrv.ini")
    # Transition from the old store-link layout must preserve existing values.
    machine.succeed("systemctl stop edcb")
    machine.succeed("ln -sf ${pkgs.writeText "previous-common.ini" "[SET]\nPrevious=retained\n"} /var/lib/edcb/Common.ini")
    machine.succeed("/run/current-system/activate")
    machine.succeed("systemctl start edcb")
    machine.succeed("test ! -L /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx Previous=retained /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx RecFolderNum=2 /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx RecFolderPath0=/mnt/tv/recordings /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx RecFolderPath1=/srv/tv/archive /var/lib/edcb/Common.ini")
    # Unmanaged plugin INIs retain regular files and non-store symlinks.
    machine.succeed("systemctl stop edcb")
    machine.succeed("echo manual > /var/lib/edcb/Write_Unmanaged.so.ini")
    machine.succeed("/run/current-system/activate")
    machine.succeed("grep -Fx manual /var/lib/edcb/Write_Unmanaged.so.ini")
    machine.succeed("rm /var/lib/edcb/Write_Unmanaged.so.ini; ln -s /opt/manual.ini /var/lib/edcb/Write_Unmanaged.so.ini")
    machine.succeed("/run/current-system/activate")
    machine.succeed("test $(readlink /var/lib/edcb/Write_Unmanaged.so.ini) = /opt/manual.ini")

  '';
}
