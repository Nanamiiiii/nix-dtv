{
  pkgs,
  self,
}:

let
  fakeMirakurun = pkgs.writeShellApplication {
    name = "mirakurun";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python -m http.server 40772 --bind 127.0.0.1
    '';
  };
in
pkgs.testers.runNixOSTest {
  name = "mirakurun-module";
  nodes.machine = {
    imports = [ self.nixosModules.mirakurun ];
    services.mirakurun = {
      enable = true;
      package = fakeMirakurun;
      tuners = [
        {
          name = "test";
          types = [ "GR" ];
          command = "cat /dev/null";
        }
      ];
      channels = [
        {
          name = "test";
          type = "GR";
          channel = "T27";
        }
      ];
    };
  };
  testScript = ''
    machine.wait_for_unit("mirakurun.service")
    machine.wait_for_open_port(40772)
    machine.succeed("test $(stat -c %U /var/lib/mirakurun) = mirakurun")
    machine.succeed("systemctl show mirakurun -p Environment | grep SERVER_CONFIG_PATH")
    machine.succeed("systemctl show mirakurun -p Environment | grep recisdb")
  '';
}
