{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mirakurun;
  yaml = pkgs.formats.yaml { };
  serverConfig = yaml.generate "mirakurun-server.yml" cfg.serverSettings;
  tunersConfig = yaml.generate "mirakurun-tuners.yml" cfg.tuners;
  channelsConfig = yaml.generate "mirakurun-channels.yml" cfg.channels;
in
{
  # nixpkgs already has a module with the same public namespace. nix-dtv owns
  # this namespace when imported so its package and stricter user model are
  # used consistently instead of combining two service implementations.
  disabledModules = [ "services/video/mirakurun.nix" ];

  options.services.mirakurun = {
    enable = lib.mkEnableOption "Mirakurun";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/mirakurun { };
      defaultText = lib.literalExpression "pkgs.nix-dtv.mirakurun";
      description = "Mirakurun package to run.";
    };

    tunerCommandPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ (pkgs.callPackage ../pkgs/recisdb { }) ];
      defaultText = lib.literalExpression "[ pkgs.nix-dtv.recisdb ]";
      description = "Packages containing tuner commands referenced by tuners.yml.";
    };

    serverSettings = lib.mkOption {
      type = yaml.type;
      default = { };
      example = {
        logLevel = 2;
        path = "/run/mirakurun/mirakurun.sock";
        port = 40772;
      };
      description = "Contents of server.yml.";
    };

    tuners = lib.mkOption {
      type = yaml.type;
      default = [ ];
      example = [
        {
          name = "PX4-S1";
          types = [
            "BS"
            "CS"
          ];
          command = "recisdb tune --device /dev/px4video0 --channel <channel> -";
        }
      ];
      description = "Contents of tuners.yml.";
    };

    channels = lib.mkOption {
      type = yaml.type;
      default = [ ];
      description = "Contents of channels.yml.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "video" ];
      description = "Supplementary groups for the Mirakurun service user.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.mirakurun.serverSettings = {
      logLevel = lib.mkDefault 2;
      path = lib.mkDefault "/run/mirakurun/mirakurun.sock";
      port = lib.mkDefault 40772;
    };

    users.users.mirakurun = {
      isSystemUser = true;
      group = "mirakurun";
      extraGroups = cfg.extraGroups;
    };
    users.groups.mirakurun = { };

    systemd.services.mirakurun = {
      description = "Mirakurun DVR tuner server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [
        serverConfig
        tunersConfig
        channelsConfig
      ];
      path = cfg.tunerCommandPackages;
      environment = {
        SERVER_CONFIG_PATH = serverConfig;
        TUNERS_CONFIG_PATH = tunersConfig;
        CHANNELS_CONFIG_PATH = channelsConfig;
        SERVICES_DB_PATH = "/var/lib/mirakurun/services.json";
        PROGRAMS_DB_PATH = "/var/lib/mirakurun/programs.json";
        LOGO_DATA_DIR_PATH = "/var/lib/mirakurun/logo-data";
        NODE_ENV = "production";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/mirakurun";
        User = "mirakurun";
        Group = "mirakurun";
        SupplementaryGroups = cfg.extraGroups;
        StateDirectory = "mirakurun";
        RuntimeDirectory = "mirakurun";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/var/lib/mirakurun"
          "/run/mirakurun"
        ];
      };
    };
  };
}
