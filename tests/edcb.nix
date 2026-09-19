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
  fakeBonDriver = pkgs.runCommand "fake-bondriver" { } ''
    mkdir -p "$out/lib/edcb"
    touch "$out/lib/edcb/BonDriver_LinuxMirakc.so"
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
in
pkgs.testers.runNixOSTest {
  name = "edcb-module";
  nodes.machine = {
    imports = [ self.nixosModules.edcb ];
    hardware.dtv.bondriver = {
      mirakc = {
        package = fakeBonDriver;
        settings.GLOBAL.PRIORITY = 5;
      };
      custom = {
        package = fakeCustomBonDriver;
        driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
        settings.GLOBAL.PRIORITY = 7;
        settingsFile = customSettingsFile;
      };
      fileOnly = {
        package = fakeCustomBonDriver;
        driverPath = "${fakeCustomBonDriver}/other/BonDriver_FileOnly.so";
        settingsFile = customSettingsFile;
      };
      unselected = {
        package = fakeCustomBonDriver;
        driverPath = "${fakeCustomBonDriver}/other/BonDriver_Unselected.so";
        settings.GLOBAL.PRIORITY = 9;
        settingsFile = customSettingsFile;
      };
    };
    services.edcb = {
      enable = true;
      package = fakeEdcb;
      bondriver = [
        "mirakc"
        "custom"
        "fileOnly"
      ];
      recordingDir = "/mnt/tv/recordings";
      settingsImmutable = false;
      settings = {
        SET.SaveLog = 1;
      };
      commonSettingsImmutable = false;
      commonSettings = { };
      epgDataCapBonSettingsImmutable = false;
      epgDataCapBonSettings.SET = {
        TsBuffMaxCount = 5000;
        WriteBuffMaxCount = -1;
      };
      recNameMacroSettingsImmutable = false;
      recNameMacroSettings.SET.Macro = "$ZtoH(Title)$.ts";
    };
  };
  testScript = ''
    machine.wait_for_unit("edcb.service")
    machine.succeed("test $(stat -c %U /var/lib/edcb) = edcb")
    machine.succeed("test $(stat -c %a /mnt/tv/recordings) = 2770")
    machine.succeed("test -f /var/lib/edcb/Bitrate.ini")
    machine.succeed("test -f /var/lib/edcb/BonCtrl.ini")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_LinuxMirakc.so")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_Custom.so")
    machine.fail("test -e /var/lib/edcb/lib/BonDriver_Unselected.so")
    machine.fail("test -e /var/lib/edcb/lib/BonDriver_Unselected.so.ini")
    machine.succeed("test $(readlink -f /var/lib/edcb/lib/BonDriver_LinuxMirakc.so) = ${fakeBonDriver}/lib/edcb/BonDriver_LinuxMirakc.so")
    machine.succeed("test $(readlink -f /var/lib/edcb/lib/BonDriver_Custom.so) = ${fakeCustomBonDriver}/other/BonDriver_Custom.so")
    machine.succeed("grep -F 'RecFolderPath0=/mnt/tv/recordings' /var/lib/edcb/Common.ini")
    machine.succeed("grep -F 'EnableTCPSrv=1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TCPAccessControlList=+127.0.0.1,+::1,+::ffff:127.0.0.1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'CompatFlags=128' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TimeSync=0' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F '[BonDriver_LinuxMirakc.so]' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F 'EnableHttpSrv=' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F '[EPG_CAP]' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F 'SERVER_HOST=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    machine.fail("grep -F 'SERVER_PORT=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    machine.fail("grep -F 'SERVER_TYPE=' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    machine.succeed("grep -F 'PRIORITY=5' /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    machine.succeed("test $(readlink /var/lib/edcb/lib/BonDriver_Custom.so.ini) = ${customSettingsFile}")
    machine.succeed("cmp /var/lib/edcb/lib/BonDriver_Custom.so.ini ${customSettingsFile}")
    machine.succeed("test $(readlink /var/lib/edcb/lib/BonDriver_FileOnly.so.ini) = ${customSettingsFile}")
    machine.succeed("cmp /var/lib/edcb/lib/BonDriver_FileOnly.so.ini ${customSettingsFile}")
    machine.fail("grep -F 'SERVER_HOST=' /var/lib/edcb/lib/BonDriver_Custom.so.ini")
    machine.succeed("grep -F 'TsBuffMaxCount=5000' /var/lib/edcb/EpgDataCap_Bon.ini")
    machine.succeed("grep -F 'WriteBuffMaxCount=-1' /var/lib/edcb/EpgDataCap_Bon.ini")
    machine.succeed("grep -F 'Macro=$ZtoH(Title)$.ts' /var/lib/edcb/RecName_Macro.so.ini")
    import base64

    files = {
        "EpgTimerSrv.ini": ("SaveLog", "1"),
        "Common.ini": ("RecFolderPath0", "/mnt/tv/recordings"),
        "EpgDataCap_Bon.ini": ("TsBuffMaxCount", "5000"),
        "RecName_Macro.so.ini": ("Macro", "$ZtoH(Title)$.ts"),
    }
    machine.succeed("systemctl stop edcb")
    for name, (key, value) in files.items():
        path = "/var/lib/edcb/" + name
        machine.succeed(f"test ! -L {path}; test $(stat -c %a {path}) = 640")
        content = f"[SET]\n{key}=old\nExisting=keep%value\n[RuntimeOnly]\nMixedCase=保持\n"
        encoding = "utf-16" if name == "EpgTimerSrv.ini" else "utf-8-sig"
        encoded = base64.b64encode(content.encode(encoding)).decode()
        machine.succeed(f"echo {encoded} | base64 -d > {path}")
    # A service restart must not reapply Nix settings.
    before = machine.succeed("sha256sum /var/lib/edcb/*.ini")
    machine.succeed("systemctl restart edcb")
    assert machine.succeed("sha256sum /var/lib/edcb/*.ini") == before
    machine.succeed("systemctl stop edcb")
    for _ in range(2):
        machine.succeed("/run/current-system/activate")
        for name, (key, value) in files.items():
            path = "/var/lib/edcb/" + name
            machine.succeed(f"grep -Fx '{key}={value}' {path}")
            machine.succeed(f"grep -Fx 'Existing=keep%value' {path}")
            machine.succeed(f"grep -Fx 'MixedCase=保持' {path}")
            machine.fail(f"grep -F immutable {path}")
            machine.succeed(f"test $(stat -c %U {path}) = edcb")
    # Transition from the old store-link layout must preserve existing values.
    machine.succeed("systemctl stop edcb")
    machine.succeed("ln -sf ${pkgs.writeText "previous-common.ini" "[SET]\nPrevious=retained\n"} /var/lib/edcb/Common.ini")
    machine.succeed("/run/current-system/activate")
    machine.succeed("systemctl start edcb")
    machine.succeed("test ! -L /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx Previous=retained /var/lib/edcb/Common.ini")
    machine.succeed("grep -Fx RecFolderPath0=/mnt/tv/recordings /var/lib/edcb/Common.ini")

  '';
}
