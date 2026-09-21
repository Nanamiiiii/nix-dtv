{
  pkgs,
  self,
}:

let
  fakeMirakurun = pkgs.writeShellApplication {
    name = "mirakurun";
    meta.description = "Fake Mirakurun for the module test";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python -m http.server 40772 --bind 127.0.0.1
    '';
  };
in
pkgs.testers.runNixOSTest {
  node.pkgsReadOnly = false;
  name = "mirakurun-module";
  nodes.machine = {
    imports = [ self.nixosModules.mirakurun ];
    security.polkit.enable = true;
    services.pcscd.enable = true;
    services.mirakurun = {
      enable = true;
      package = fakeMirakurun;
      tunerSettings = [
        {
          name = "test";
          types = [ "GR" ];
          command = "cat /dev/null";
        }
      ];
      channelSettings = [
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
    machine.wait_for_unit("pcscd.socket")
    machine.succeed("test $(stat -c %U /var/lib/mirakurun) = mirakurun")
    machine.succeed("systemctl show mirakurun -p Environment | grep SERVER_CONFIG_PATH")
    machine.succeed("systemctl show mirakurun -p Environment | grep recisdb")
    machine.succeed("test -f /etc/mirakurun/tuners.yml")
    machine.succeed("test -f /etc/mirakurun/channels.yml")
    machine.succeed("test $(stat -c %U /etc/mirakurun/tuners.yml) = mirakurun")
    machine.succeed("test -f /run/current-system/sw/share/polkit-1/rules.d/10-mirakurun.rules")
    machine.succeed("grep -F 'subject.user == \"mirakurun\"' /run/current-system/sw/share/polkit-1/rules.d/10-mirakurun.rules")
    machine.succeed("systemctl cat mirakurun | grep -F '${fakeMirakurun}/bin/mirakurun'")
  '';
}
