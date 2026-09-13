{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.edcb;
  ini = pkgs.formats.ini { };
  runtimeLibDir = "/var/lib/edcb/lib";
  epgTimerSrvSettings =
    if cfg.settings == null then
      null
    else
      lib.recursiveUpdate {
        SET = {
          EnableTCPSrv = 1;
          TCPAccessControlList = "+127.0.0.1,+::1,+::ffff:127.0.0.1";
          TCPPort = 4510;
          CompatFlags = 128;
          TimeSync = 0;
        };
        "BonDriver_LinuxMirakc.so".Count = 1;
      } cfg.settings;
  commonSettings =
    if cfg.commonSettings == null then
      null
    else
      lib.recursiveUpdate {
        SET = {
          RecFolderNum = 1;
          RecFolderPath0 = cfg.recordingDir;
        };
      } cfg.commonSettings;
  bonDriverSettings =
    if cfg.bonDriver.settings == null then
      null
    else
      lib.recursiveUpdate {
        GLOBAL = {
          SERVER_TYPE = "http";
          SERVER_HOST = "127.0.0.1";
          SERVER_PORT = 40772;
        };
      } cfg.bonDriver.settings;
  iniFiles = [
    {
      name = "EpgTimerSrv.ini";
      path = "/var/lib/edcb/EpgTimerSrv.ini";
      settings = epgTimerSrvSettings;
    }
    {
      name = "Common.ini";
      path = "/var/lib/edcb/Common.ini";
      settings = commonSettings;
    }
    {
      name = "EpgDataCap_Bon.ini";
      path = "/var/lib/edcb/EpgDataCap_Bon.ini";
      settings = cfg.epgDataCapBonSettings;
    }
    {
      name = "RecName_Macro.so.ini";
      path = "/var/lib/edcb/RecName_Macro.so.ini";
      settings = cfg.recNameMacroSettings;
    }
    {
      name = "BonDriver_LinuxMirakc.so.ini";
      path = "${runtimeLibDir}/BonDriver_LinuxMirakc.so.ini";
      settings = bonDriverSettings;
    }
  ];
  configuredIniFiles = map (file: file // { source = ini.generate file.name file.settings; }) (
    lib.filter (file: file.settings != null) iniFiles
  );
  unmanagedIniFiles = lib.filter (file: file.settings == null) iniFiles;
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
      type = lib.types.nullOr ini.type;
      default = null;
      example = {
        EPG_CAP = {
          Count = 1;
          "0" = "05:15";
          "0Select" = 1;
          "0BasicOnlyFlags" = 14;
        };
        "BonDriver_LinuxMirakc.so".Count = 4;
      };
      description = "Managed EpgTimerSrv.ini settings. Null leaves the file unmanaged; a non-null value also receives the minimal integration defaults.";
    };

    commonSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      description = "Managed Common.ini settings. Null leaves the file unmanaged; a non-null value also receives the recording directory defaults.";
    };

    epgDataCapBonSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      example = {
        SET = {
          SaveDebugLog = 1;
          TraceBonDriverLevel = 2;
          TsBuffMaxCount = 5000;
          WriteBuffMaxCount = -1;
        };
      };
      description = "Managed EpgDataCap_Bon.ini settings. Null leaves the file unmanaged.";
    };

    recNameMacroSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      example.SET.Macro = "$ZtoH(Title)$.ts";
      description = "Managed RecName_Macro.so.ini settings. Null leaves the file unmanaged.";
    };

    bonDriver = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../pkgs/bondriver-linux-mirakc { };
        defaultText = lib.literalExpression "pkgs.nix-dtv.bondriver-linux-mirakc";
        description = "BonDriver_LinuxMirakc package loaded by EDCB.";
      };

      settings = lib.mkOption {
        type = lib.types.nullOr ini.type;
        default = null;
        example = {
          GLOBAL = {
            SERVER_TYPE = "http";
            SERVER_HOST = "127.0.0.1";
            SERVER_PORT = 40772;
          };
        };
        description = "Managed BonDriver_LinuxMirakc.so.ini settings. Null leaves the file unmanaged; a non-null value also receives the localhost Mirakurun defaults.";
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
      "L+ ${runtimeLibDir}/BonDriver_LinuxMirakc.so - - - - ${cfg.bonDriver.package}/lib/edcb/BonDriver_LinuxMirakc.so"
    ]
    ++ map (file: "L+ ${file.path} - - - - ${file.source}") configuredIniFiles
    ++ map (name: "L+ ${runtimeLibDir}/${name} - - - - ${cfg.package}/lib/edcb/${name}") edcbLibraries;

    # When a formerly managed INI is unset, remove only the old Nix-store
    # symlink. Mutable files created by EDCB itself are deliberately preserved.
    system.activationScripts.edcb-unmanage-ini.text = ''
      removeEdcbStoreLink() {
        iniPath="$1"
        if [ -L "$iniPath" ]; then
          case "$(${pkgs.coreutils}/bin/readlink "$iniPath")" in
            /nix/store/*) ${pkgs.coreutils}/bin/rm -f -- "$iniPath" ;;
          esac
        fi
      }
      ${lib.concatMapStringsSep "\n" (
        file: "removeEdcbStoreLink ${lib.escapeShellArg file.path}"
      ) unmanagedIniFiles}
    '';

    systemd.services.edcb = {
      description = "EDCB EpgTimerSrv";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "mirakurun.service"
      ];
      wants = [ "mirakurun.service" ];
      restartTriggers = map (file: file.source) configuredIniFiles;
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
