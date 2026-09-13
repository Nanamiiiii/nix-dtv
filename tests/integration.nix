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
      recordingDir = "/mnt/tv/recordings";
      mirakurun.enable = true;
      edcb.enable = true;
    };

    services.mirakurun.tunerSettings = [ ];

    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    machine.wait_for_unit("mirakurun.service")
    machine.wait_for_open_port(40772)
    machine.succeed("curl --fail --silent http://127.0.0.1:40772/api/status >/dev/null")

    machine.wait_for_unit("edcb.service")
    machine.wait_for_open_port(4510)
    machine.succeed("systemctl show edcb -p After | grep mirakurun.service")
    machine.succeed("test -L /var/lib/edcb/lib/BonDriver_LinuxMirakc.so")
  '';
}
