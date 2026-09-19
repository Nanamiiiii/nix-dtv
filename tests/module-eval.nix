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
        services.konomitv.settings.server.port = 7100;
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
  konomitvVolumes = cfg.virtualisation.oci-containers.containers.konomitv.volumes;
in
assert nixpkgs.lib.any (
  a: !a.assertion && nixpkgs.lib.hasInfix "undefined hardware.dtv.bondriver" a.message
) unknownDriver.config.assertions;
assert nixpkgs.lib.any (
  a: !a.assertion && nixpkgs.lib.hasInfix "duplicate binary filenames" a.message
) duplicateBinary.config.assertions;
assert cfg.services.edcb.settingsImmutable;
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
assert cfg.services.konomitv.recordingDir == "/mnt/tv/recordings";
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
assert cfg.services.konomitv.settings.general.always_receive_tv_from_mirakurun;
assert builtins.elem "/mnt/tv/recordings:/host-rootfs/mnt/tv/recordings:ro" konomitvVolumes;
assert cfg.virtualisation.oci-containers.backend == "docker";
pkgs.runCommand "nix-dtv-module-eval" { } ''
  touch "$out"
''
