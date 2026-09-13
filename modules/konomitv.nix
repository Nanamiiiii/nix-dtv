{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.konomitv;
  yaml = pkgs.formats.yaml { };
  generatedSettings = lib.recursiveUpdate cfg.settings {
    video.recorded_folders = [ cfg.recordingDir ];
    capture.upload_folders = [ cfg.captureDir ];
  };
  configFile = yaml.generate "konomitv-config.yaml" generatedSettings;
  hostRootTarget = path: "/host-rootfs${path}";
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
      type = lib.types.str;
      default = "/mnt/tv/recordings";
      description = "Host recording directory, mounted read-only.";
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
      type = lib.types.str;
      default = "/var/lib/konomitv/capture";
      description = "Writable capture upload directory.";
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/dev/dri:/dev/dri" ];
      description = "Additional host devices passed to the container.";
    };

    settings = lib.mkOption {
      type = yaml.type;
      default = { };
      example = {
        general = {
          backend = "EDCB";
          always_receive_tv_from_mirakurun = true;
          edcb_url = "tcp://127.0.0.1:4510/";
          mirakurun_url = "http://127.0.0.1:40772/";
          encoder = "FFmpeg";
        };
        server.port = 7000;
        tv = { };
        video.exclude_scan_paths = [ ];
        capture = { };
      };
      description = "KonomiTV config.yaml settings. Recording and capture folders are managed by dedicated options.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.konomitv.settings = {
      general = {
        backend = lib.mkDefault "EDCB";
        always_receive_tv_from_mirakurun = lib.mkDefault true;
        edcb_url = lib.mkDefault "tcp://127.0.0.1:4510/";
        mirakurun_url = lib.mkDefault "http://127.0.0.1:40772/";
        encoder = lib.mkDefault "FFmpeg";
      };
      server.port = lib.mkDefault 7000;
      video.exclude_scan_paths = lib.mkDefault [ ];
    };

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.konomitv = {
      image = cfg.image;
      autoStart = true;
      volumes = [
        "${configFile}:/code/config.yaml:ro"
        "${cfg.recordingDir}:${hostRootTarget cfg.recordingDir}:ro"
        "${cfg.captureDir}:${hostRootTarget cfg.captureDir}:rw"
        "${cfg.dataDir}:/code/server/data:rw"
        "${cfg.logDir}:/code/server/logs:rw"
      ];
      extraOptions = [ "--network=host" ] ++ map (device: "--device=${device}") cfg.devices;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/konomitv 0750 root root - -"
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.logDir} 0750 root root - -"
      "d ${cfg.captureDir} 0750 root root - -"
    ];

    systemd.services.docker-konomitv = {
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
