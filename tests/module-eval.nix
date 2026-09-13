{
  nixpkgs,
  pkgs,
  self,
  system,
}:

let
  evaluated = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.default
      {
        boot.kernelPackages = pkgs.linuxPackages;
        services.dtv = {
          enable = true;
          recordingDir = "/mnt/tv/recordings";
          px4_drv.enable = true;
          mirakurun.enable = true;
          edcb.enable = true;
          konomitv.enable = true;
        };
        services.mirakurun.serverSettings.logLevel = 1;
        services.edcb.settings.SET.SaveLog = 1;
        services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount = 5000;
        services.edcb.recNameMacroSettings.SET.Macro = "$ZtoH(Title)$.ts";
        services.edcb.bonDriver.settings.GLOBAL.PRIORITY = 5;
        services.konomitv.settings.server.port = 7100;
      }
    ];
  };
  cfg = evaluated.config;
  konomitvVolumes = cfg.virtualisation.oci-containers.containers.konomitv.volumes;
in
assert cfg.services.edcb.recordingDir == "/mnt/tv/recordings";
assert cfg.services.konomitv.recordingDir == "/mnt/tv/recordings";
assert cfg.users.users.mirakurun.extraGroups == [ "video" ];
assert cfg.services.mirakurun.serverSettings.port == 40772;
assert builtins.length cfg.services.mirakurun.tunerCommandPackages == 1;
assert builtins.elem (builtins.head cfg.services.mirakurun.tunerCommandPackages)
  cfg.systemd.services.mirakurun.path;
assert builtins.elem "dtv" cfg.users.users.edcb.extraGroups;
assert cfg.services.edcb.settings.SET.EnableTCPSrv == 1;
assert cfg.services.edcb.settings.SET.TimeSync == 0;
assert cfg.services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount == 5000;
assert cfg.services.edcb.recNameMacroSettings.SET.Macro == "$ZtoH(Title)$.ts";
assert cfg.services.edcb.bonDriver.settings.GLOBAL.SERVER_HOST == "127.0.0.1";
assert cfg.services.konomitv.settings.general.always_receive_tv_from_mirakurun;
assert builtins.elem "/mnt/tv/recordings:/host-rootfs/mnt/tv/recordings:ro" konomitvVolumes;
assert cfg.virtualisation.oci-containers.backend == "docker";
pkgs.runCommand "nix-dtv-module-eval" { } ''
  touch "$out"
''
