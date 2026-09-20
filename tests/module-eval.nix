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
        security.polkit.enable = true;
        services.pcscd.enable = true;
        services.mirakurun.serverSettings.logLevel = 1;
        services.edcb.settings.SET.SaveLog = 1;
        services.edcb.materialWebUI.enable = true;
        services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount = 5000;
        services.edcb.recNameMacroSettings.SET.Macro = "$ZtoH(Title)$.ts";
        hardware.dtv.bondriver.mirakc.settings.GLOBAL.PRIORITY = 5;
        services.edcb.bondriver = [
          "mirakc"
          "custom"
        ];
        hardware.dtv.bondriver.custom.package = fakeCustomBonDriver;
        hardware.dtv.bondriver.custom.driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
        hardware.dtv.bondriver.unselected = {
          package = fakeCustomBonDriver;
          driverPath = "${fakeCustomBonDriver}/other/BonDriver_Unselected.so";
          settings.GLOBAL.PRIORITY = 9;
        };
        hardware.dtv.bondriver.custom.settings.GLOBAL.PRIORITY = 7;
        hardware.dtv.bondriver.custom.settingsFile = customSettingsFile;
        services.konomitv = {
          recordingDir = [
            "/mnt/tv/recordings"
            "/srv/tv/archive"
          ];
          captureDir = [
            "/var/lib/konomitv/capture"
            "/srv/tv/capture"
          ];
          backend = "mirakurun";
          streamFromMirakurun = true;
          edcbUrl = "tcp://127.0.0.1:4511/";
          mirakurunUrl = "http://127.0.0.1:40773/";
          encoder = "QSVEncC";
          devices = [ "/dev/video0:/dev/video0" ];
          serverPort = 7100;
          extraSettings = {
            general.program_update_interval = 10.0;
            server.port = 7200;
            video.exclude_scan_paths = [ "/mnt/tv/recordings/tmp" ];
          };
        };
      }
    ];
  };
  cfg = evaluated.config;
  customSettingsFile = pkgs.writeText "custom-driver.ini" "[GLOBAL]\nPRIORITY=17\n";
  fakeCustomBonDriver = pkgs.runCommand "fake-custom-bondriver" { } ''
    mkdir -p "$out/other"
    touch "$out/other/BonDriver_Custom.so"
  '';
  unknownDriver = evaluated.extendModules {
    modules = [ { services.edcb.bondriver = nixpkgs.lib.mkForce [ "missing" ]; } ];
  };
  duplicateBinary = evaluated.extendModules {
    modules = [
      {
        hardware.dtv.bondriver.duplicate = {
          package = fakeCustomBonDriver;
          driverPath = "${fakeCustomBonDriver}/another/BonDriver_Custom.so";
        };
        services.edcb.bondriver = nixpkgs.lib.mkForce [
          "custom"
          "duplicate"
        ];
      }
    ];
  };
  withoutWebUI = evaluated.extendModules {
    modules = [ { services.edcb.materialWebUI.enable = nixpkgs.lib.mkForce false; } ];
  };
  mergedSettings = evaluated.extendModules {
    modules = [
      {
        services.edcb = {
          settingsImmutable = false;
          commonSettingsImmutable = false;
          commonSettings = { };
          epgDataCapBonSettingsImmutable = false;
          recNameMacroSettingsImmutable = false;
        };
      }
    ];
  };
  emptyDrivers = evaluated.extendModules {
    modules = [ { services.edcb.bondriver = nixpkgs.lib.mkForce [ ]; } ];
  };
  reorderedDrivers = evaluated.extendModules {
    modules = [
      {
        services.edcb.bondriver = nixpkgs.lib.mkForce [
          "custom"
          "mirakc"
          "custom"
        ];
      }
    ];
  };
  overriddenTuners = evaluated.extendModules {
    modules = [
      {
        services.edcb.settings = {
          TVTEST = {
            Num = 1;
            "0" = "BonDriver_Custom.so";
          };
          "BonDriver_LinuxMirakc.so" = {
            Count = 4;
            EPGCount = 2;
            GetEpg = 0;
            Priority = 7;
          };
        };
      }
    ];
  };
  unmanagedSettings = evaluated.extendModules {
    modules = [ { services.edcb.settings = nixpkgs.lib.mkForce null; } ];
  };
  ffmpegEncoder = evaluated.extendModules {
    modules = [ { services.konomitv.encoder = nixpkgs.lib.mkForce "FFmpeg"; } ];
  };
  vceEncoder = evaluated.extendModules {
    modules = [ { services.konomitv.encoder = nixpkgs.lib.mkForce "VCEEncC"; } ];
  };
  nvencEncoder = evaluated.extendModules {
    modules = [
      {
        services.konomitv.encoder = nixpkgs.lib.mkForce "NVEncC";
        hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;
      }
    ];
  };
  srvIni =
    config:
    nixpkgs.lib.last (
      nixpkgs.lib.splitString " " (
        nixpkgs.lib.findFirst (nixpkgs.lib.hasPrefix "L+ /var/lib/edcb/EpgTimerSrv.ini ")
          (throw "missing EpgTimerSrv.ini link")
          config.systemd.tmpfiles.rules
      )
    );
  konomitvVolumes = cfg.virtualisation.oci-containers.containers.konomitv.volumes;
  konomitvDevices = config: config.virtualisation.oci-containers.containers.konomitv.devices;
  konomitvOptions = config: config.virtualisation.oci-containers.containers.konomitv.extraOptions;
  konomitvConfig = nixpkgs.lib.removeSuffix ":/code/config.yaml:ro" (
    nixpkgs.lib.findFirst (nixpkgs.lib.hasSuffix ":/code/config.yaml:ro")
      (throw "missing KonomiTV config.yaml mount")
      konomitvVolumes
  );
in
assert nixpkgs.lib.any (
  a: !a.assertion && nixpkgs.lib.hasInfix "undefined hardware.dtv.bondriver" a.message
) unknownDriver.config.assertions;
assert nixpkgs.lib.any (
  a: !a.assertion && nixpkgs.lib.hasInfix "duplicate binary filenames" a.message
) duplicateBinary.config.assertions;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/EpgTimerSrv.ini ") unmanagedSettings.config.systemd.tmpfiles.rules);
assert cfg.services.edcb.settingsImmutable;
assert cfg.services.edcb.materialWebUI.enable;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/HttpPublic/E3 ") withoutWebUI.config.systemd.tmpfiles.rules);
assert nixpkgs.lib.hasInfix "removeMaterialWebUILink /var/lib/edcb/HttpPublic/E3"
  withoutWebUI.config.system.activationScripts.edcb-unmanage-files.text;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/HttpPublic/E3 ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/HttpPublic/api ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Setting/HttpPublic.ini ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Setting/XCODE_OPTIONS.lua ")
  cfg.systemd.tmpfiles.rules;
assert builtins.elem cfg.services.edcb.materialWebUI.package
  cfg.systemd.services.edcb.restartTriggers;
assert cfg.services.edcb.commonSettingsImmutable;
assert mergedSettings.config.systemd.services.edcb.preStart == "";
assert builtins.elem "users"
  mergedSettings.config.system.activationScripts.edcb-merge-settings.deps;
assert cfg.services.edcb.epgDataCapBonSettingsImmutable;
assert cfg.services.edcb.recNameMacroSettingsImmutable;
assert nixpkgs.lib.all
  (
    name:
    !(nixpkgs.lib.any (nixpkgs.lib.hasInfix (
      "/var/lib/edcb/" + name + " "
    )) mergedSettings.config.systemd.tmpfiles.rules)
    && nixpkgs.lib.hasInfix name mergedSettings.config.system.activationScripts.edcb-merge-settings.text
  )
  [
    "EpgTimerSrv.ini"
    "Common.ini"
    "EpgDataCap_Bon.ini"
    "RecName_Macro.so.ini"
  ];
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/EpgTimerSrv.ini ")
  cfg.systemd.tmpfiles.rules;
assert cfg.hardware.dtv.px4_drv.enable;
assert builtins.elem cfg.hardware.dtv.px4_drv.package cfg.boot.extraModulePackages;
assert builtins.elem cfg.hardware.dtv.px4_drv.package cfg.services.udev.packages;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "BonDriver_Unselected.so") cfg.systemd.tmpfiles.rules);
assert cfg.services.edcb.recordingDir == "/mnt/tv/recordings";
assert
  cfg.services.konomitv.recordingDir == [
    "/mnt/tv/recordings"
    "/srv/tv/archive"
  ];
assert cfg.users.users.mirakurun.group == "video";
assert cfg.services.mirakurun.allowSmartCardAccess;
assert cfg.services.pcscd.enable;
assert cfg.security.polkit.enable;
assert cfg.services.mirakurun.tunerSettings == null;
assert cfg.services.mirakurun.channelSettings == null;
assert cfg.services.mirakurun.serverSettings.port == 40772;
assert evaluated.pkgs.mirakurun == cfg.services.mirakurun.package;
assert builtins.length cfg.services.mirakurun.tunerCommandPackages == 1;
assert builtins.elem (builtins.head cfg.services.mirakurun.tunerCommandPackages)
  cfg.systemd.services.mirakurun.path;
assert builtins.elem "dtv" cfg.users.users.edcb.extraGroups;
assert cfg.services.edcb.settings.SET.SaveLog == 1;
assert !(cfg.services.edcb.settings.SET ? EnableTCPSrv);
assert !(cfg.services.edcb.settings ? EPG_CAP);
assert !(cfg.services.edcb.settings ? "BonDriver_LinuxMirakc.so");
assert cfg.services.edcb.commonSettings == null;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Common.ini ") cfg.systemd.tmpfiles.rules);
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Bitrate.ini ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/BonCtrl.ini ")
  cfg.systemd.tmpfiles.rules;
assert cfg.services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount == 5000;
assert cfg.services.edcb.recNameMacroSettings.SET.Macro == "$ZtoH(Title)$.ts";
assert cfg.hardware.dtv.bondriver.mirakc.settingsFile == null;
assert builtins.elem customSettingsFile cfg.systemd.services.edcb.restartTriggers;
assert
  !(nixpkgs.lib.hasInfix "BonDriver_Custom.so.ini" cfg.system.activationScripts.edcb-unmanage-files.text);
assert cfg.hardware.dtv.bondriver.mirakc.settings.GLOBAL.PRIORITY == 5;
assert !(cfg.hardware.dtv.bondriver.mirakc.settings.GLOBAL ? SERVER_HOST);
assert !(cfg.hardware.dtv.bondriver.mirakc.settings.GLOBAL ? DECODE_B25);
assert cfg.hardware.dtv.bondriver.custom.settings.GLOBAL.PRIORITY == 7;
assert cfg.hardware.dtv.bondriver.custom.package == fakeCustomBonDriver;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/lib/BonDriver_LinuxMirakc.so ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/lib/BonDriver_Custom.so ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/lib/BonDriver_Custom.so.ini ")
  cfg.systemd.tmpfiles.rules;
assert cfg.services.konomitv.extraSettings.general.program_update_interval == 10.0;
assert builtins.elem "/mnt/tv/recordings:/host-rootfs/mnt/tv/recordings:ro" konomitvVolumes;
assert builtins.elem "/srv/tv/archive:/host-rootfs/srv/tv/archive:ro" konomitvVolumes;
assert builtins.elem "/var/lib/konomitv/capture:/host-rootfs/var/lib/konomitv/capture:rw"
  konomitvVolumes;
assert builtins.elem "/srv/tv/capture:/host-rootfs/srv/tv/capture:rw" konomitvVolumes;
assert nixpkgs.lib.any (nixpkgs.lib.hasPrefix "d /srv/tv/capture ") cfg.systemd.tmpfiles.rules;
assert cfg.virtualisation.oci-containers.backend == "docker";
assert builtins.elem "/dev/dri/:/dev/dri/" (konomitvDevices cfg);
assert builtins.elem "/dev/video0:/dev/video0" (konomitvDevices cfg);
assert !(builtins.elem "--gpus=all,capabilities=compute,utility,video" (konomitvOptions cfg));
assert !(builtins.elem "/dev/dri/:/dev/dri/" (konomitvDevices ffmpegEncoder.config));
assert builtins.elem "/dev/video0:/dev/video0" (konomitvDevices ffmpegEncoder.config);
assert builtins.elem "/dev/dri/:/dev/dri/" (konomitvDevices vceEncoder.config);
assert builtins.elem "--gpus=all,capabilities=compute,utility,video" (
  konomitvOptions nvencEncoder.config
);
assert !(builtins.elem "/dev/dri/:/dev/dri/" (konomitvDevices nvencEncoder.config));
assert nvencEncoder.config.hardware.nvidia-container-toolkit.enable;
pkgs.runCommand "nix-dtv-module-eval"
  {
    nativeBuildInputs = [ (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ])) ];
  }
  ''
    python <<'PYTHON'
    import configparser
    import yaml

    def read(path):
        ini = configparser.ConfigParser()
        ini.optionxform = str
        ini.read(path)
        return ini

    ini = read("${srvIni cfg}")
    assert dict(ini["TVTEST"]) == {"Num": "2", "0": "BonDriver_LinuxMirakc.so", "1": "BonDriver_Custom.so"}
    for name, priority in [("BonDriver_LinuxMirakc.so", "0"), ("BonDriver_Custom.so", "1")]:
        assert dict(ini[name]) == {"Count": "1", "GetEpg": "1", "EPGCount": "1", "Priority": priority}
    assert "BonDriver_Unselected.so" not in ini
    assert ini["SET"]["SaveLog"] == "1"

    empty = read("${srvIni emptyDrivers.config}")
    assert dict(empty["TVTEST"]) == {"Num": "0"}
    assert not any(section.startswith("BonDriver") for section in empty.sections())

    reordered = read("${srvIni reorderedDrivers.config}")
    assert dict(reordered["TVTEST"]) == {"Num": "2", "0": "BonDriver_Custom.so", "1": "BonDriver_LinuxMirakc.so"}
    assert reordered["BonDriver_Custom.so"]["Priority"] == "0"
    assert reordered["BonDriver_LinuxMirakc.so"]["Priority"] == "1"

    overridden = read("${srvIni overriddenTuners.config}")
    assert overridden["TVTEST"]["Num"] == "1"
    assert overridden["TVTEST"]["0"] == "BonDriver_Custom.so"
    assert dict(overridden["BonDriver_LinuxMirakc.so"]) == {"Count": "4", "GetEpg": "0", "EPGCount": "2", "Priority": "7"}
    assert overridden["BonDriver_Custom.so"]["Count"] == "1"

    with open("${konomitvConfig}", encoding="utf-8") as file:
        konomitv = yaml.safe_load(file)

    assert konomitv["general"] == {
        "backend": "Mirakurun",
        "always_receive_tv_from_mirakurun": True,
        "edcb_url": "tcp://127.0.0.1:4511/",
        "mirakurun_url": "http://127.0.0.1:40773/",
        "encoder": "QSVEncC",
        "program_update_interval": 10.0,
    }
    assert konomitv["server"]["port"] == 7100
    assert konomitv["video"] == {
        "recorded_folders": ["/mnt/tv/recordings", "/srv/tv/archive"],
        "exclude_scan_paths": ["/mnt/tv/recordings/tmp"],
    }
    assert konomitv["capture"]["upload_folders"] == [
        "/var/lib/konomitv/capture",
        "/srv/tv/capture",
    ]
    PYTHON
    touch "$out"
  ''
