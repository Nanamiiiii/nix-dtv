{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.konomitv;

  yaml = pkgs.formats.yaml { };

  managedSettings = {
    general = {
      backend = cfg.backend;
      always_receive_tv_from_mirakurun = cfg.streamFromMirakurun;
      edcb_url = "tcp://${cfg.edcbHost}:${toString cfg.edcbPort}/";
      mirakurun_url = "http://${cfg.mirakurunHost}:${toString cfg.mirakurunPort}/";
      encoder = cfg.encoder;
    };
    server.port = cfg.serverPort;
    video.recorded_folders = cfg.recordingDir;
    capture.upload_folders = cfg.captureDir;
  };

  generatedSettings = lib.recursiveUpdate (lib.recursiveUpdate {
    video.exclude_scan_paths = [ ];
  } cfg.extraSettings) managedSettings;

  configFile = yaml.generate "konomitv-config.yaml" generatedSettings;

  hostRootTarget = path: "/host-rootfs${path}";

  encoderDevices = lib.optionals (lib.elem cfg.encoder [
    "QSVEncC"
    "VCEEncC"
  ]) [ "/dev/dri:/dev/dri" ];

  containerDevices = lib.unique (encoderDevices ++ cfg.devices);

  encoderExtraOptions = lib.optionals (cfg.encoder == "NVEncC") [
    "--gpus=all,capabilities=compute,utility,video"
  ];
in
{
  options.services.konomitv = {
    enable = lib.mkEnableOption "KonomiTV OCI container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/tsukumijima/konomitv:latest";
      description = "Official KonomiTV OCI image.";
    };

    recordingDir = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/tv/recordings" ];
      description = "Host recording directories, mounted read-only.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/konomitv/data";
      description = "Writable KonomiTV data directory.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/konomitv/logs";
      description = "Writable KonomiTV log directory.";
    };

    captureDir = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/var/lib/konomitv/capture" ];
      description = "Writable capture upload directory.";
    };

    manageCaptureDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the capture directories and enforce root ownership and mode 0750. Disable this for externally managed directories such as NFS shares.";
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/dev/video0:/dev/video0" ];
      description = "Additional host devices passed to the container, in addition to devices selected by the encoder option.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "EDCB"
        "Mirakurun"
      ];
      default = "EDCB";
      description = "Tuner backend application.";
    };

    streamFromMirakurun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use mirakurun as stream backend instead of EDCB.";
    };

    edcbHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP or hostname that EDCB service listens to.";
    };

    edcbPort = lib.mkOption {
      type = lib.types.port;
      default = config.services.edcb.tcpPort;
      description = "TCP port that EDCB service listens to.";
    };

    mirakurunHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP or hostname that mirakurun service listens to.";
    };

    mirakurunPort = lib.mkOption {
      type = lib.types.port;
      default = config.services.mirakurun.port;
      description = "HTTP port that mirakurun service listens to.";
    };

    encoder = lib.mkOption {
      type = lib.types.enum [
        "FFmpeg"
        "QSVEncC"
        "NVEncC"
        "VCEEncC"
      ];
      default = "FFmpeg";
      description = "Video encoder.";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      example = 7000;
      description = "Server port konomitv listens on.";
    };

    openFirewallPort = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall port for konomitv.";
    };

    extraSettings = lib.mkOption {
      type = yaml.type;
      default = { };
      example = {
        general.program_update_interval = 5.0;
        video.exclude_scan_paths = [ ];
      };
      description = "Additional KonomiTV config.yaml settings. Values managed by dedicated options take precedence.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia-container-toolkit.enable = lib.mkIf (cfg.encoder == "NVEncC") (lib.mkDefault true);

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewallPort cfg.serverPort;

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.konomitv = {
      image = cfg.image;
      autoStart = true;
      volumes = [
        "${configFile}:/code/config.yaml:ro"
      ]
      ++ map (path: "${path}:${hostRootTarget path}:ro") cfg.recordingDir
      ++ map (path: "${path}:${hostRootTarget path}:rw") cfg.captureDir
      ++ [
        "${cfg.dataDir}:/code/server/data:rw"
        "${cfg.logDir}:/code/server/logs:rw"
      ];
      devices = containerDevices;
      extraOptions = [ "--network=host" ] ++ encoderExtraOptions;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/konomitv 0750 root root - -"
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.dataDir}/account-icons 0750 root root - -"
      "d ${cfg.dataDir}/thumbnails 0750 root root - -"
      "d ${cfg.logDir} 0750 root root - -"
    ]
    ++ lib.optionals cfg.manageCaptureDirs (map (path: "d ${path} 0750 root root - -") cfg.captureDir);

    systemd.services.docker-konomitv = {
      unitConfig.RequiresMountsFor = lib.unique (cfg.recordingDir ++ cfg.captureDir);
      after = [
        "edcb.service"
        "mirakurun.service"
      ];
      wants = [
        "edcb.service"
        "mirakurun.service"
      ];
    };
  };
}
