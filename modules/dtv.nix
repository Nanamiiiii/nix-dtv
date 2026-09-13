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
      type = lib.types.str;
      default = "/mnt/tv/recordings";
      description = "Shared recording directory.";
    };

    recordingGroup = lib.mkOption {
      type = lib.types.str;
      default = "dtv";
      description = "Group allowed to write recordings.";
    };

    px4_drv.enable = lib.mkEnableOption "px4_drv as part of the DTV stack";
    mirakurun.enable = lib.mkEnableOption "Mirakurun as part of the DTV stack";
    edcb.enable = lib.mkEnableOption "EDCB as part of the DTV stack";
    konomitv.enable = lib.mkEnableOption "KonomiTV as part of the DTV stack";
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.recordingGroup} = { };
    systemd.tmpfiles.rules = [
      "d ${cfg.recordingDir} 2770 root ${cfg.recordingGroup} - -"
    ];

    hardware.px4_drv.enable = lib.mkDefault cfg.px4_drv.enable;
    services.mirakurun.enable = lib.mkDefault cfg.mirakurun.enable;
    services.edcb = {
      enable = lib.mkDefault cfg.edcb.enable;
      recordingDir = lib.mkDefault cfg.recordingDir;
      recordingGroup = lib.mkDefault cfg.recordingGroup;
    };
    services.konomitv = {
      enable = lib.mkDefault cfg.konomitv.enable;
      recordingDir = lib.mkDefault cfg.recordingDir;
    };
  };
}
