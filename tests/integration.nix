{
  pkgs,
  self,
}:

pkgs.testers.runNixOSTest {
  name = "mirakurun-edcb-integration";

  nodes.machine = {
    imports = [ self.nixosModules.default ];

    services.dtv = {
      enable = true;
      recordingDir = [ "/mnt/tv/recordings" ];
      mirakurun.enable = true;
      edcb.enable = true;
    };

    services.mirakurun.tunerSettings = [ ];
    services.edcb.materialWebUI.enable = true;
    services.edcb.bondriver = [
      {
        package = pkgs.nix-dtv.bondriver-linux-mirakc;
        driverPath = "${pkgs.nix-dtv.bondriver-linux-mirakc}/lib/BonDriver_LinuxMirakc.so";
        tunerSettings = {
          Count = 1;
          GetEpg = 1;
          EPGCount = 1;
          Priority = 0;
        };
      }
    ];

    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    machine.wait_for_unit("mirakurun.service")
    machine.wait_for_open_port(40772)
    machine.succeed("curl --fail --silent http://127.0.0.1:40772/api/status >/dev/null")

    machine.wait_for_unit("edcb.service")
    import configparser

    class EdcbIni(configparser.ConfigParser):
        def optionxform(self, optionstr: str) -> str:
            return optionstr

    ini = EdcbIni()
    ini.read_string(machine.succeed("cat /var/lib/edcb/EpgTimerSrv.ini"))
    assert dict(ini["TVTEST"]) == {"Num": "1", "0": "BonDriver_LinuxMirakc.so"}
    assert dict(ini["BonDriver_LinuxMirakc.so"]) == {"Count": "1", "GetEpg": "1", "EPGCount": "1", "Priority": "0"}
    machine.wait_for_open_port(4510)
    machine.wait_for_open_port(5510)
    machine.wait_for_open_port(5511)
    machine.wait_for_open_port(5521)
    machine.succeed("curl --fail --silent http://127.0.0.1:5510/E3/ -o /tmp/e3.html")
    machine.succeed("grep -q '<html' /tmp/e3.html")
    machine.succeed("curl --insecure --fail --silent https://127.0.0.1:5511/E3/ -o /tmp/e3-https.html")
    machine.succeed("grep -q '<html' /tmp/e3-https.html")
    machine.succeed("curl --insecure --fail --silent https://127.0.0.1:5521/E3/ >/dev/null")
    machine.succeed("curl --fail --silent http://127.0.0.1:5510/api/EnumService >/dev/null")
    machine.succeed("systemctl show edcb -p After | grep mirakurun.service")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_LinuxMirakc.so")
  '';
}
