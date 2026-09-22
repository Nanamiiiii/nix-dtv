{
  config,
  lib,
  ...
}:

let
  cfg = config.services.dtv;
in
{
  imports = [
    ./px4_drv.nix
    ./mirakurun.nix
    ./edcb.nix
    ./konomitv.nix
  ];

  options.services.dtv = {
    enable = lib.mkEnableOption "the integrated Japanese DTV stack";

    recordingDir = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/tv/recordings" ];
      description = "Shared recording directories.";
    };

    recordingGroup = lib.mkOption {
      type = lib.types.str;
      default = "dtv";
      description = "Group allowed to write recordings.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports to access each service externally.";
    };

    px4_drv.enable = lib.mkEnableOption "px4_drv as part of the DTV stack";
    mirakurun.enable = lib.mkEnableOption "Mirakurun as part of the DTV stack";
    edcb.enable = lib.mkEnableOption "EDCB as part of the DTV stack";
    konomitv.enable = lib.mkEnableOption "KonomiTV as part of the DTV stack";
  };

  config = lib.mkMerge [
    { nixpkgs.overlays = [ (import ../../overlays) ]; }
    (lib.mkIf cfg.enable {
      # assertions
      assertions = [
        {
          assertion = !cfg.konomitv.enable || (cfg.mirakurun.enable || cfg.edcb.enable);
          message = "KonomiTV requires at least one of EDCB or Mirakurun.";
        }
      ];

      # enable px4_drv kernel module
      hardware.px4_drv.enable = lib.mkDefault cfg.px4_drv.enable;

      # enable mirakurun service
      services.mirakurun = {
        enable = lib.mkDefault cfg.mirakurun.enable;
        openFirewall = lib.mkDefault cfg.openFirewall;
      };

      # enable EDCB EpgTimerSrv service
      services.edcb = {
        enable = lib.mkDefault cfg.edcb.enable;
        recordingDir = lib.mkDefault cfg.recordingDir;
        recordingGroup = lib.mkDefault cfg.recordingGroup;
        openFirewall = lib.mkDefault cfg.openFirewall;
      };

      # enable konomitv service (via oci-container)
      services.konomitv = {
        enable = lib.mkDefault cfg.konomitv.enable;
        recordingDir = lib.mkDefault cfg.recordingDir;
        edcbPort = lib.mkIf cfg.edcb.enable (lib.mkDefault config.services.edcb.tcpPort);
        mirakurunPort = lib.mkIf cfg.mirakurun.enable (lib.mkDefault config.services.mirakurun.port);
        backend = lib.mkIf (cfg.mirakurun.enable && !cfg.edcb.enable) (lib.mkDefault "Mirakurun");
        streamFromMirakurun = lib.mkIf (cfg.mirakurun.enable && cfg.edcb.enable) (lib.mkDefault true);
        openFirewall = lib.mkDefault cfg.openFirewall;
      };

      # enable PC/SC smart card daemon to read B-CAS card
      services.pcscd.enable = true;

      # enable polkit daemon
      security.polkit.enable = true;
    })
  ];
}
