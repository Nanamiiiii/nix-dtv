{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.edcb;
  ini = pkgs.formats.ini { };
  epgTimerSrvIni = ini.generate "EpgTimerSrv.ini" cfg.settings;
  commonIni = ini.generate "Common.ini" cfg.commonSettings;
  epgDataCapBonIni = ini.generate "EpgDataCap_Bon.ini" cfg.epgDataCapBonSettings;
  recNameMacroIni = ini.generate "RecName_Macro.so.ini" cfg.recNameMacroSettings;
  bonDriverIni = ini.generate "BonDriver_LinuxMirakc.so.ini" cfg.bonDriver.settings;
  runtimeLibDir = "/var/lib/edcb/lib";
  edcbLibraries = [
    "EpgDataCap3.so"
    "RecName_Macro.so"
    "SendTSTCP.so"
    "Write_Default.so"
  ];
in
{
  options.services.edcb = {
    enable = lib.mkEnableOption "Linux-native EDCB EpgTimerSrv";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/edcb { };
      defaultText = lib.literalExpression "pkgs.nix-dtv.edcb";
      description = "EDCB package to run.";
    };

    recordingDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/tv/recordings";
      description = "Directory in which EDCB writes recordings.";
    };

    recordingGroup = lib.mkOption {
      type = lib.types.str;
      default = "dtv";
      description = "Group with write access to the recording directory.";
    };

    settings = lib.mkOption {
      type = ini.type;
      default = { };
      example = {
        EPG_CAP = {
          Count = 1;
          "0" = "05:15";
          "0Select" = 1;
          "0BasicOnlyFlags" = 14;
        };
        "BonDriver_LinuxMirakc.so".Count = 4;
      };
      description = "Managed EpgTimerSrv.ini settings. Defaults only cover local TCP access, KonomiTV compatibility, safe clock handling, and one conservative BonDriver instance.";
    };

    commonSettings = lib.mkOption {
      type = ini.type;
      default = { };
      description = "Additional managed Common.ini settings.";
    };

    epgDataCapBonSettings = lib.mkOption {
      type = ini.type;
      default = { };
      example = {
        SET = {
          SaveDebugLog = 1;
          TraceBonDriverLevel = 2;
          TsBuffMaxCount = 5000;
          WriteBuffMaxCount = -1;
        };
      };
      description = "Managed EpgDataCap_Bon.ini settings.";
    };

    recNameMacroSettings = lib.mkOption {
      type = ini.type;
      default = { };
      example.SET.Macro = "$ZtoH(Title)$.ts";
      description = "Managed RecName_Macro.so.ini settings.";
    };

    bonDriver = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../pkgs/bondriver-linux-mirakc { };
        defaultText = lib.literalExpression "pkgs.nix-dtv.bondriver-linux-mirakc";
        description = "BonDriver_LinuxMirakc package loaded by EDCB.";
      };

      settings = lib.mkOption {
        type = ini.type;
        default = { };
        example = {
          GLOBAL = {
            SERVER_TYPE = "http";
            SERVER_HOST = "127.0.0.1";
            SERVER_PORT = 40772;
          };
        };
        description = "Managed BonDriver_LinuxMirakc.so.ini settings.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.recordingGroup} = { };
    users.groups.edcb = { };
    users.users.edcb = {
      isSystemUser = true;
      group = "edcb";
      extraGroups = [ cfg.recordingGroup ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.recordingDir} 2770 root ${cfg.recordingGroup} - -"
      "d ${runtimeLibDir} 0750 edcb edcb - -"
      "C /var/lib/edcb/Bitrate.ini 0640 edcb edcb - ${cfg.package}/share/edcb/initial-state/Bitrate.ini"
      "C /var/lib/edcb/BonCtrl.ini 0640 edcb edcb - ${cfg.package}/share/edcb/initial-state/BonCtrl.ini"
      "C /var/lib/edcb/ContentTypeText.txt 0640 edcb edcb - ${cfg.package}/share/edcb/initial-state/ContentTypeText.txt"
      "C /var/lib/edcb/HttpPublic - edcb edcb - ${cfg.package}/share/edcb/initial-state/HttpPublic"
      "L+ /var/lib/edcb/EpgTimerSrv.ini - - - - ${epgTimerSrvIni}"
      "L+ /var/lib/edcb/Common.ini - - - - ${commonIni}"
      "L+ /var/lib/edcb/EpgDataCap_Bon.ini - - - - ${epgDataCapBonIni}"
      "L+ /var/lib/edcb/RecName_Macro.so.ini - - - - ${recNameMacroIni}"
      "L+ ${runtimeLibDir}/BonDriver_LinuxMirakc.so - - - - ${cfg.bonDriver.package}/lib/edcb/BonDriver_LinuxMirakc.so"
      "L+ ${runtimeLibDir}/BonDriver_LinuxMirakc.so.ini - - - - ${bonDriverIni}"
    ]
    ++ map (name: "L+ ${runtimeLibDir}/${name} - - - - ${cfg.package}/lib/edcb/${name}") edcbLibraries;

    services.edcb.commonSettings.SET = {
      RecFolderNum = lib.mkDefault 1;
      RecFolderPath0 = lib.mkDefault cfg.recordingDir;
    };

    # formats.ini is one leaf option, so an attrset in mkOption.default would be
    # replaced wholesale by any partial user definition. Per-key mkDefault
    # definitions preserve these integration defaults while remaining overridable.
    services.edcb.settings = {
      SET = {
        EnableTCPSrv = lib.mkDefault 1;
        TCPAccessControlList = lib.mkDefault "+127.0.0.1,+::1,+::ffff:127.0.0.1";
        TCPPort = lib.mkDefault 4510;
        CompatFlags = lib.mkDefault 128;
        TimeSync = lib.mkDefault 0;
      };
      "BonDriver_LinuxMirakc.so".Count = lib.mkDefault 1;
    };

    services.edcb.bonDriver.settings.GLOBAL = {
      SERVER_TYPE = lib.mkDefault "http";
      SERVER_HOST = lib.mkDefault "127.0.0.1";
      SERVER_PORT = lib.mkDefault 40772;
    };

    systemd.services.edcb = {
      description = "EDCB EpgTimerSrv";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "mirakurun.service"
      ];
      wants = [ "mirakurun.service" ];
      restartTriggers = [
        epgTimerSrvIni
        commonIni
        epgDataCapBonIni
        recNameMacroIni
        bonDriverIni
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/EpgTimerSrv";
        User = "edcb";
        Group = "edcb";
        SupplementaryGroups = [ cfg.recordingGroup ];
        StateDirectory = "edcb";
        WorkingDirectory = "/var/lib/edcb";
        UMask = "0007";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectClock = true;
        ReadWritePaths = [
          "/var/lib/edcb"
          cfg.recordingDir
        ];
      };
    };

    warnings = [
      "BonDriver_LinuxMirakc upstream states that Mirakurun compatibility is untested; verify tuning and long-running recording with your hardware."
    ];
  };
}
