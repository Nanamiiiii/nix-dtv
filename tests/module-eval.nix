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
          recordingDir = [
            "/mnt/tv/recordings"
            "/srv/tv/archive"
          ];
          px4_drv.enable = true;
          mirakurun.enable = true;
          edcb.enable = true;
          konomitv.enable = true;
        };
        security.polkit.enable = true;
        services.pcscd.enable = true;
        services.mirakurun.serverSettings.logLevel = 1;
        services.edcb.settings.SET.SaveLog = 1;
        services.edcb.settingsImmutable = true;
        services.edcb.commonSettingsImmutable = true;
        services.edcb.epgDataCapBonSettingsImmutable = true;
        services.edcb.recNameMacroSettingsImmutable = true;
        services.edcb.materialWebUI.enable = true;
        services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount = 5000;
        services.edcb.recNameMacroSettings.SET.Macro = "$ZtoH(Title)$.ts";
        services.edcb.bondriver = [
          {
            driverPath = "${pkgs.bondriver-linux-mirakc}/lib/BonDriver_LinuxMirakc.so";
            settings.GLOBAL.PRIORITY = 5;
            tunerSettings = {
              Count = 4;
              GetEpg = 1;
              EPGCount = 2;
            };
          }
          {
            driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
            settings.GLOBAL.PRIORITY = 7;
            settingsFile = customSettingsFile;
            tunerSettings.Count = 2;
          }
        ];
        services.konomitv = {
          captureDir = [
            "/var/lib/konomitv/capture"
            "/srv/tv/capture"
          ];
          backend = "Mirakurun";
          streamFromMirakurun = true;
          edcbHost = "edcb.example.test";
          edcbPort = 4511;
          mirakurunHost = "mirakurun.example.test";
          mirakurunPort = 40773;
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
  firewallEnabled = evaluated.extendModules {
    modules = [
      {
        networking.firewall.allowedTCPPorts = [ 12345 ];
        services.edcb = {
          openFirewall = true;
          tcpPort = 14510;
          httpPorts = [
            15510
            15520
          ];
          httpsPorts = [
            15511
            15521
          ];
        };
        services.konomitv.openFirewall = true;
      }
    ];
  };
  firewallServicesDisabled = firewallEnabled.extendModules {
    modules = [
      {
        services.edcb.enable = nixpkgs.lib.mkForce false;
        services.konomitv.enable = nixpkgs.lib.mkForce false;
      }
    ];
  };
  sharedFirewall = evaluated.extendModules {
    modules = [
      {
        services.dtv.openFirewall = true;
        networking.firewall.allowedTCPPorts = [ 12345 ];
      }
    ];
  };
  overriddenFirewall = sharedFirewall.extendModules {
    modules = [
      {
        services.mirakurun.openFirewall = false;
        services.edcb.openFirewall = false;
        services.konomitv.openFirewall = false;
      }
    ];
  };
  disabledSharedFirewall = sharedFirewall.extendModules {
    modules = [
      {
        services.dtv.mirakurun.enable = nixpkgs.lib.mkForce false;
        services.dtv.edcb.enable = nixpkgs.lib.mkForce false;
        services.dtv.konomitv.enable = nixpkgs.lib.mkForce false;
      }
    ];
  };
  withoutSmartCardAccess = evaluated.extendModules {
    modules = [ { services.edcb.allowSmartCardAccess = false; } ];
  };
  edcbPolkitRules =
    config:
    builtins.filter (package: package.name or "" == "10-edcb.rules") config.environment.systemPackages;
  defaultDtv = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.nix-dtv
      {
        services.dtv.enable = true;
        services.dtv.edcb.enable = true;
      }
    ];
  };
  dtvWithMirakurun = defaultDtv.extendModules {
    modules = [
      {
        services.dtv.mirakurun.enable = true;
        services.edcb.tcpPort = 14510;
        services.mirakurun.port = 14077;
      }
    ];
  };
  dtvMirakurunOnly = dtvWithMirakurun.extendModules {
    modules = [ { services.dtv.edcb.enable = nixpkgs.lib.mkForce false; } ];
  };
  konomitvBackendCases = nixpkgs.lib.cartesianProduct {
    enable = [
      false
      true
    ];
    konomitv = [
      false
      true
    ];
    mirakurun = [
      false
      true
    ];
    edcb = [
      false
      true
    ];
  };
  checkKonomitvBackend =
    case:
    let
      evaluatedCase = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.nix-dtv
          {
            services.dtv = {
              inherit (case) enable;
              konomitv.enable = case.konomitv;
              mirakurun.enable = case.mirakurun;
              edcb.enable = case.edcb;
            };
          }
        ];
      };
      failedBackendAssertions = builtins.filter (
        a: !a.assertion && a.message == "KonomiTV requires at least one of EDCB or Mirakurun."
      ) evaluatedCase.config.assertions;
      missingBackend = case.konomitv && !case.mirakurun && !case.edcb;
    in
    if case.enable && missingBackend then
      builtins.length failedBackendAssertions == 1
    else
      failedBackendAssertions == [ ];
  standaloneKonomitv = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.nix-dtv
      {
        services.konomitv.enable = true;
        services.edcb.tcpPort = 14510;
        services.mirakurun.port = 14077;
      }
    ];
  };
  withCustomOverlay = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.default
      {
        nixpkgs.overlays = [ (_: _: { dtvTestOverlay = true; }) ];
        hardware.px4_drv.enable = true;
        services.mirakurun.enable = true;
        services.edcb.enable = true;
      }
    ];
  };
  customSettingsFile = pkgs.writeText "custom-driver.ini" "[GLOBAL]\nPRIORITY=17\n";
  fakeCustomBonDriver = pkgs.runCommand "fake-custom-bondriver" { } ''
    mkdir -p "$out/other"
    touch "$out/other/BonDriver_Custom.so"
  '';
  duplicateBinary = evaluated.extendModules {
    modules = [
      {
        services.edcb.bondriver = nixpkgs.lib.mkForce [
          (builtins.elemAt cfg.services.edcb.bondriver 1)
          {
            driverPath = "${fakeCustomBonDriver}/another/BonDriver_Custom.so";
          }
        ];
      }
    ];
  };
  sameBinaryDifferentNames = evaluated.extendModules {
    modules = [
      {
        services.edcb.bondriver = nixpkgs.lib.mkForce [
          (builtins.elemAt cfg.services.edcb.bondriver 1)
          {
            driverPath = "${fakeCustomBonDriver}/other/BonDriver_Custom.so";
            name = "BonDriver_Custom_2.so";
            settings.GLOBAL.PRIORITY = 8;
            tunerSettings.Count = 3;
          }
        ];
      }
    ];
  };
  withoutWebUI = evaluated.extendModules {
    modules = [ { services.edcb.materialWebUI.enable = nixpkgs.lib.mkForce false; } ];
  };
  webUIWithDefaultSettings = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.nix-dtv
      {
        services.edcb.enable = true;
        services.edcb.materialWebUI.enable = true;
      }
    ];
  };
  withoutWebUIWithDefaultSettings = webUIWithDefaultSettings.extendModules {
    modules = [ { services.edcb.materialWebUI.enable = nixpkgs.lib.mkForce false; } ];
  };
  webUIWithUnmanagedSettings = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.nix-dtv
      {
        services.edcb.enable = true;
        services.edcb.materialWebUI.enable = true;
        services.edcb.settings = null;
      }
    ];
  };
  mergedSettings = evaluated.extendModules {
    modules = [
      {
        services.edcb = {
          settingsImmutable = nixpkgs.lib.mkForce false;
          commonSettingsImmutable = nixpkgs.lib.mkForce false;
          commonSettings = { };
          epgDataCapBonSettingsImmutable = nixpkgs.lib.mkForce false;
          recNameMacroSettingsImmutable = nixpkgs.lib.mkForce false;
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
          (builtins.elemAt cfg.services.edcb.bondriver 1)
          (builtins.elemAt cfg.services.edcb.bondriver 0)
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
  externallyManagedRecordingDirs = evaluated.extendModules {
    modules = [ { services.edcb.manageRecordingDirs = nixpkgs.lib.mkForce false; } ];
  };
  externallyManagedCaptureDirs = evaluated.extendModules {
    modules = [ { services.konomitv.manageCaptureDirs = nixpkgs.lib.mkForce false; } ];
  };
  dtvWithoutEdcb = evaluated.extendModules {
    modules = [ { services.dtv.edcb.enable = nixpkgs.lib.mkForce false; } ];
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
assert !cfg.services.dtv.openFirewall;
assert !cfg.services.mirakurun.openFirewall;
assert sharedFirewall.config.services.mirakurun.openFirewall;
assert sharedFirewall.config.services.edcb.openFirewall;
assert sharedFirewall.config.services.konomitv.openFirewall;
assert
  builtins.sort builtins.lessThan sharedFirewall.config.networking.firewall.allowedTCPPorts == [
    4510
    5510
    5511
    5520
    5521
    7100
    12345
    40772
  ];
assert overriddenFirewall.config.networking.firewall.allowedTCPPorts == [ 12345 ];
assert disabledSharedFirewall.config.networking.firewall.allowedTCPPorts == [ 12345 ];
assert cfg.services.edcb.allowSmartCardAccess;
assert builtins.length (edcbPolkitRules cfg) == 1;
assert edcbPolkitRules withoutSmartCardAccess.config == [ ];
assert edcbPolkitRules dtvWithoutEdcb.config == [ ];
assert !cfg.services.edcb.openFirewall;
assert !cfg.services.konomitv.openFirewall;
assert cfg.networking.firewall.allowedTCPPorts == [ ];
assert
  builtins.sort builtins.lessThan firewallEnabled.config.networking.firewall.allowedTCPPorts == [
    7100
    12345
    14510
    15510
    15511
    15520
    15521
  ];
assert firewallServicesDisabled.config.networking.firewall.allowedTCPPorts == [ 12345 ];
assert nixpkgs.lib.any (
  a: !a.assertion && nixpkgs.lib.hasInfix "duplicate names" a.message
) duplicateBinary.config.assertions;
assert !(cfg.hardware ? dtv);
assert builtins.all checkKonomitvBackend konomitvBackendCases;
assert defaultDtv.config.services.edcb.bondriver == [ ];
assert defaultDtv.config.services.konomitv.backend == "EDCB";
assert !defaultDtv.config.services.konomitv.streamFromMirakurun;
assert dtvWithMirakurun.config.services.konomitv.backend == "EDCB";
assert dtvWithMirakurun.config.services.konomitv.streamFromMirakurun;
assert dtvWithMirakurun.config.services.konomitv.edcbPort == 14510;
assert dtvWithMirakurun.config.services.konomitv.mirakurunPort == 14077;
assert dtvMirakurunOnly.config.services.konomitv.backend == "Mirakurun";
assert !dtvMirakurunOnly.config.services.konomitv.streamFromMirakurun;
assert standaloneKonomitv.config.services.konomitv.edcbPort == 4510;
assert standaloneKonomitv.config.services.konomitv.mirakurunPort == 40772;
assert !(defaultDtv.pkgs ? nix-dtv);
assert builtins.all (name: defaultDtv.pkgs.${name} == self.packages.${system}.${name}) (
  builtins.attrNames (builtins.removeAttrs (import ../pkgs { inherit pkgs; }) [ "edcbExtraTools" ])
);
assert builtins.all
  (name: defaultDtv.pkgs.edcbExtraTools.${name} == self.packages.${system}.${name})
  [
    "b24tovtt"
    "psisiarc"
    "psisimux"
    "tsmemseg"
    "tsreadex"
  ];
assert defaultDtv.pkgs.edcb == defaultDtv.config.services.edcb.package;
assert !withCustomOverlay.config.services.dtv.enable;
assert !(withCustomOverlay.pkgs ? nix-dtv);
assert
  withCustomOverlay.pkgs.linuxPackages.px4_drv == withCustomOverlay.config.hardware.px4_drv.package;
assert withCustomOverlay.pkgs.dtvTestOverlay;
assert withCustomOverlay.pkgs.mirakurun == withCustomOverlay.config.services.mirakurun.package;
assert withCustomOverlay.config.hardware.px4_drv.package.pname == "px4_drv";
assert withCustomOverlay.config.services.mirakurun.package.version == "4.1.3";
assert withCustomOverlay.config.services.edcb.package.pname == "edcb";
assert withCustomOverlay.config.services.edcb.materialWebUI.package.pname == "edcb-material-webui";
assert
  !(nixpkgs.lib.any (
    a: !a.assertion && nixpkgs.lib.hasInfix "duplicate names" a.message
  ) sameBinaryDifferentNames.config.assertions);
assert
  (builtins.elemAt sameBinaryDifferentNames.config.services.edcb.bondriver 0).name
  == "BonDriver_Custom.so";
assert
  (builtins.elemAt sameBinaryDifferentNames.config.services.edcb.bondriver 1).name
  == "BonDriver_Custom_2.so";
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/lib/BonDriver_Custom_2.so - - - - ")
  sameBinaryDifferentNames.config.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/lib/BonDriver_Custom_2.so.ini - - - - ")
  sameBinaryDifferentNames.config.systemd.tmpfiles.rules;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/EpgTimerSrv.ini ") unmanagedSettings.config.systemd.tmpfiles.rules);
assert cfg.services.edcb.settingsImmutable;
assert cfg.services.edcb.materialWebUI.enable;
assert !webUIWithDefaultSettings.config.services.edcb.settingsImmutable;
assert webUIWithDefaultSettings.config.services.edcb.tcpPort == 4510;
assert
  webUIWithDefaultSettings.config.services.edcb.httpPorts == [
    5510
    5520
  ];
assert
  webUIWithDefaultSettings.config.services.edcb.httpsPorts == [
    5511
    5521
  ];
assert withoutWebUIWithDefaultSettings.config.services.edcb.httpPorts == [ 5510 ];
assert withoutWebUIWithDefaultSettings.config.services.edcb.httpsPorts == [ ];
assert webUIWithDefaultSettings.config.services.edcb.settings.SET.EnableHttpSrv == 1;
assert webUIWithUnmanagedSettings.config.services.edcb.settings == null;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/EpgTimerSrv.ini ") webUIWithUnmanagedSettings.config.systemd.tmpfiles.rules);
assert nixpkgs.lib.hasInfix "ssl_cert.pem" cfg.systemd.services.edcb.preStart;
assert nixpkgs.lib.hasInfix "DNS:localhost" cfg.systemd.services.edcb.preStart;
assert withoutWebUI.config.systemd.services.edcb.preStart == "";
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
assert nixpkgs.lib.hasInfix "ssl_cert.pem" mergedSettings.config.systemd.services.edcb.preStart;
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
assert cfg.hardware.px4_drv.enable;
assert builtins.elem cfg.hardware.px4_drv.package cfg.boot.extraModulePackages;
assert builtins.elem cfg.hardware.px4_drv.package cfg.services.udev.packages;
assert
  !(nixpkgs.lib.any (nixpkgs.lib.hasInfix "BonDriver_Unselected.so") cfg.systemd.tmpfiles.rules);
assert
  cfg.services.edcb.recordingDir == [
    "/mnt/tv/recordings"
    "/srv/tv/archive"
  ];
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
assert builtins.elem "/mnt/tv/recordings" cfg.systemd.services.edcb.serviceConfig.ReadWritePaths;
assert builtins.elem "/srv/tv/archive" cfg.systemd.services.edcb.serviceConfig.ReadWritePaths;
assert cfg.systemd.services.edcb.unitConfig.RequiresMountsFor == cfg.services.edcb.recordingDir;
assert
  cfg.systemd.services.docker-konomitv.unitConfig.RequiresMountsFor
  == nixpkgs.lib.unique (cfg.services.konomitv.recordingDir ++ cfg.services.konomitv.captureDir);
assert nixpkgs.lib.any (nixpkgs.lib.hasPrefix "d /mnt/tv/recordings 2770 root dtv ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasPrefix "d /srv/tv/archive 2770 root dtv ")
  cfg.systemd.tmpfiles.rules;
assert !dtvWithoutEdcb.config.services.edcb.enable;
assert !(dtvWithoutEdcb.config.users.groups ? dtv);
assert
  !(nixpkgs.lib.any (
    rule:
    nixpkgs.lib.hasPrefix "d /mnt/tv/recordings 2770 root dtv " rule
    || nixpkgs.lib.hasPrefix "d /srv/tv/archive 2770 root dtv " rule
  ) dtvWithoutEdcb.config.systemd.tmpfiles.rules);
assert !externallyManagedRecordingDirs.config.services.edcb.manageRecordingDirs;
assert
  !(nixpkgs.lib.any (
    rule:
    nixpkgs.lib.hasPrefix "d /mnt/tv/recordings 2770 root dtv " rule
    || nixpkgs.lib.hasPrefix "d /srv/tv/archive 2770 root dtv " rule
  ) externallyManagedRecordingDirs.config.systemd.tmpfiles.rules);
assert
  externallyManagedRecordingDirs.config.systemd.services.edcb.unitConfig.RequiresMountsFor
  == externallyManagedRecordingDirs.config.services.edcb.recordingDir;
assert
  externallyManagedRecordingDirs.config.systemd.services.docker-konomitv.unitConfig.RequiresMountsFor
  == nixpkgs.lib.unique (
    externallyManagedRecordingDirs.config.services.konomitv.recordingDir
    ++ externallyManagedRecordingDirs.config.services.konomitv.captureDir
  );
assert !externallyManagedCaptureDirs.config.services.konomitv.manageCaptureDirs;
assert
  !(nixpkgs.lib.any (
    rule:
    nixpkgs.lib.hasPrefix "d /var/lib/konomitv/capture 0750 root root " rule
    || nixpkgs.lib.hasPrefix "d /srv/tv/capture 0750 root root " rule
  ) externallyManagedCaptureDirs.config.systemd.tmpfiles.rules);
assert
  externallyManagedCaptureDirs.config.systemd.services.docker-konomitv.unitConfig.RequiresMountsFor
  == nixpkgs.lib.unique (
    externallyManagedCaptureDirs.config.services.konomitv.recordingDir
    ++ externallyManagedCaptureDirs.config.services.konomitv.captureDir
  );
assert cfg.services.edcb.settings.SET.SaveLog == 1;
assert !(cfg.services.edcb.settings.SET ? EnableTCPSrv);
assert !(cfg.services.edcb.settings ? EPG_CAP);
assert !(cfg.services.edcb.settings ? "BonDriver_LinuxMirakc.so");
assert cfg.services.edcb.commonSettings == { };
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Common.ini ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/Bitrate.ini ")
  cfg.systemd.tmpfiles.rules;
assert nixpkgs.lib.any (nixpkgs.lib.hasInfix "/var/lib/edcb/BonCtrl.ini ")
  cfg.systemd.tmpfiles.rules;
assert cfg.services.edcb.epgDataCapBonSettings.SET.TsBuffMaxCount == 5000;
assert cfg.services.edcb.recNameMacroSettings.SET.Macro == "$ZtoH(Title)$.ts";
assert (builtins.elemAt cfg.services.edcb.bondriver 0).settingsFile == null;
assert builtins.elem customSettingsFile cfg.systemd.services.edcb.restartTriggers;
assert
  !(nixpkgs.lib.hasInfix "BonDriver_Custom.so.ini" cfg.system.activationScripts.edcb-unmanage-files.text);
assert (builtins.elemAt cfg.services.edcb.bondriver 0).settings.GLOBAL.PRIORITY == 5;
assert !((builtins.elemAt cfg.services.edcb.bondriver 0).settings.GLOBAL ? SERVER_HOST);
assert !((builtins.elemAt cfg.services.edcb.bondriver 0).settings.GLOBAL ? DECODE_B25);
assert (builtins.elemAt cfg.services.edcb.bondriver 1).settings.GLOBAL.PRIORITY == 7;
assert builtins.all (
  driver: builtins.elem driver.driverPath cfg.systemd.services.edcb.restartTriggers
) cfg.services.edcb.bondriver;
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
assert builtins.elem "/dev/dri:/dev/dri" (konomitvDevices cfg);
assert builtins.elem "/dev/video0:/dev/video0" (konomitvDevices cfg);
assert !(builtins.elem "--gpus=all,capabilities=compute,utility,video" (konomitvOptions cfg));
assert !(builtins.elem "/dev/dri:/dev/dri" (konomitvDevices ffmpegEncoder.config));
assert builtins.elem "/dev/video0:/dev/video0" (konomitvDevices ffmpegEncoder.config);
assert builtins.elem "/dev/dri:/dev/dri" (konomitvDevices vceEncoder.config);
assert builtins.elem "--gpus=all,capabilities=compute,utility,video" (
  konomitvOptions nvencEncoder.config
);
assert !(builtins.elem "/dev/dri:/dev/dri" (konomitvDevices nvencEncoder.config));
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
    assert dict(ini["BonDriver_LinuxMirakc.so"]) == {"Count": "4", "GetEpg": "1", "EPGCount": "2"}
    assert dict(ini["BonDriver_Custom.so"]) == {"Count": "2"}
    assert "BonDriver_Unselected.so" not in ini
    assert ini["SET"]["SaveLog"] == "1"

    empty = read("${srvIni emptyDrivers.config}")
    assert dict(empty["TVTEST"]) == {"Num": "0"}
    assert not any(section.startswith("BonDriver") for section in empty.sections())

    reordered = read("${srvIni reorderedDrivers.config}")
    assert dict(reordered["TVTEST"]) == {"Num": "2", "0": "BonDriver_Custom.so", "1": "BonDriver_LinuxMirakc.so"}
    assert dict(reordered["BonDriver_Custom.so"]) == {"Count": "2"}
    assert dict(reordered["BonDriver_LinuxMirakc.so"]) == {"Count": "4", "GetEpg": "1", "EPGCount": "2"}

    overridden = read("${srvIni overriddenTuners.config}")
    assert overridden["TVTEST"]["Num"] == "1"
    assert overridden["TVTEST"]["0"] == "BonDriver_Custom.so"
    assert dict(overridden["BonDriver_LinuxMirakc.so"]) == {"Count": "4", "GetEpg": "0", "EPGCount": "2", "Priority": "7"}
    assert overridden["BonDriver_Custom.so"]["Count"] == "2"

    shared = read("${srvIni sameBinaryDifferentNames.config}")
    assert dict(shared["TVTEST"]) == {"Num": "2", "0": "BonDriver_Custom.so", "1": "BonDriver_Custom_2.so"}
    assert dict(shared["BonDriver_Custom.so"]) == {"Count": "2"}
    assert dict(shared["BonDriver_Custom_2.so"]) == {"Count": "3"}

    with open("${konomitvConfig}", encoding="utf-8") as file:
        konomitv = yaml.safe_load(file)

    assert konomitv["general"] == {
        "backend": "Mirakurun",
        "always_receive_tv_from_mirakurun": True,
        "edcb_url": "tcp://edcb.example.test:4511/",
        "mirakurun_url": "http://mirakurun.example.test:40773/",
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
