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
in
pkgs.testers.runNixOSTest {
  name = "edcb-module";
  nodes.machine = {
    imports = [ self.nixosModules.edcb ];
    services.edcb = {
      enable = true;
      package = fakeEdcb;
      bonDriver.package = fakeBonDriver;
      recordingDir = "/mnt/tv/recordings";
      settings.SET.SaveLog = 1;
      commonSettings = { };
      epgDataCapBonSettings.SET = {
        TsBuffMaxCount = 5000;
        WriteBuffMaxCount = -1;
      };
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
    machine.succeed("grep -F 'RecFolderPath0=/mnt/tv/recordings' /var/lib/edcb/Common.ini")
    machine.succeed("grep -F 'EnableTCPSrv=1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TCPAccessControlList=+127.0.0.1,+::1,+::ffff:127.0.0.1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'CompatFlags=128' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'TimeSync=0' /var/lib/edcb/EpgTimerSrv.ini")
    machine.succeed("grep -F 'Count=1' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F 'EnableHttpSrv=' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("grep -F '[EPG_CAP]' /var/lib/edcb/EpgTimerSrv.ini")
    machine.fail("test -e /var/lib/edcb/lib/BonDriver_LinuxMirakc.so.ini")
    machine.succeed("grep -F 'TsBuffMaxCount=5000' /var/lib/edcb/EpgDataCap_Bon.ini")
    machine.succeed("grep -F 'WriteBuffMaxCount=-1' /var/lib/edcb/EpgDataCap_Bon.ini")
    machine.succeed("grep -F 'Macro=$ZtoH(Title)$.ts' /var/lib/edcb/RecName_Macro.so.ini")
  '';
}
