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
  webUIRoot = "${cfg.materialWebUI.package}/share/edcb-material-webui";
  epgTimerSrvSettings =
    if cfg.settings == null then
      null
    else
      lib.recursiveUpdate (
        tunerSettings
        // {
          SET = {
            EnableHttpSrv = 1;
            HttpAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
            EnableTCPSrv = 1;
            TCPAccessControlList = "+127.0.0.1,+::1,+::ffff:127.0.0.1";
            TCPPort = 4510;
            CompatFlags = 128;
            TimeSync = 0;
          };
        }
      ) cfg.settings;
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
  selectedNames = lib.unique cfg.bondriver;
  missingDrivers = lib.filter (
    name: !(builtins.hasAttr name config.hardware.dtv.bondriver)
  ) selectedNames;
  selectedDrivers = map (
    name:
    let
      driver = config.hardware.dtv.bondriver.${name};
    in
    driver // { fileName = builtins.baseNameOf driver.driverPath; }
  ) (lib.filter (name: builtins.hasAttr name config.hardware.dtv.bondriver) selectedNames);
  tunerSettings = {
    TVTEST = {
      Num = builtins.length selectedDrivers;
    }
    // builtins.listToAttrs (
      lib.imap0 (index: driver: {
        name = toString index;
        value = driver.fileName;
      }) selectedDrivers
    );
  }
  // builtins.listToAttrs (
    lib.imap0 (index: driver: {
      name = builtins.unsafeDiscardStringContext driver.fileName;
      value = {
        Count = 1;
        GetEpg = 1;
        EPGCount = 1;
        Priority = index;
      };
    }) selectedDrivers
  );
  bonDriverIniFiles = map (driver: {
    name = "${driver.fileName}.ini";
    path = "${runtimeLibDir}/${driver.fileName}.ini";
    settings = driver.settings;
    settingsFile = driver.settingsFile;
  }) selectedDrivers;
  bonDriverLibraryLinks = map (
    driver: "L+ ${runtimeLibDir}/${driver.fileName} - - - - ${driver.driverPath}"
  ) selectedDrivers;
  iniFiles = [
    {
      name = "EpgTimerSrv.ini";
      path = "/var/lib/edcb/EpgTimerSrv.ini";
      immutable = cfg.settingsImmutable;
      settings = epgTimerSrvSettings;
    }
    {
      name = "Common.ini";
      path = "/var/lib/edcb/Common.ini";
      immutable = cfg.commonSettingsImmutable;
      settings = commonSettings;
    }
    {
      name = "EpgDataCap_Bon.ini";
      path = "/var/lib/edcb/EpgDataCap_Bon.ini";
      immutable = cfg.epgDataCapBonSettingsImmutable;
      settings = cfg.epgDataCapBonSettings;
    }
    {
      name = "RecName_Macro.so.ini";
      path = "/var/lib/edcb/RecName_Macro.so.ini";
      immutable = cfg.recNameMacroSettingsImmutable;
      settings = cfg.recNameMacroSettings;
    }
  ]
  ++ bonDriverIniFiles;
  resolvedIniFiles = map (
    file:
    file
    // {
      source =
        if (file.settingsFile or null) != null then
          file.settingsFile
        else if file.settings != null then
          ini.generate file.name file.settings
        else
          null;
    }
  ) iniFiles;
  configuredIniFiles = lib.filter (file: file.source != null) resolvedIniFiles;
  linkedIniFiles = lib.filter (file: file.immutable or true) configuredIniFiles;
  mergedIniFiles = lib.filter (file: !(file.immutable or true)) configuredIniFiles;
  mergeIni = pkgs.writeText "edcb-merge-ini.py" ''
    import configparser
    import os
    import pwd
    from pathlib import Path
    import sys
    import tempfile

    target, source = map(Path, sys.argv[1:])
    parser = configparser.ConfigParser(
        interpolation=None, strict=False, delimiters=("=",),
        comment_prefixes=(";", "#"), default_section="__EDCB_DEFAULT__",
    )
    parser.optionxform = str

    def read_ini(path):
        data = path.read_bytes()
        encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
        parser.read_string(data.decode(encoding), source=str(path))

    if target.exists():
        read_ini(target)
    read_ini(source)
    # Replace symlinks instead of writing through them into the Nix store.
    fd, temporary = tempfile.mkstemp(prefix="." + target.name, dir=target.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            parser.write(output, space_around_delimiters=False)
            output.flush()
            owner = pwd.getpwnam("edcb")
            os.fchown(output.fileno(), owner.pw_uid, owner.pw_gid)
            os.fchmod(output.fileno(), 0o640)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
  '';
  unmanagedIniFiles = lib.filter (file: file.source == null) resolvedIniFiles;
  edcbLibraries = [
    "EpgDataCap3.so"
    "RecName_Macro.so"
    "SendTSTCP.so"
    "Write_Default.so"
  ];
in
{
  imports = [ ./bondriver.nix ];

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

    settingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when settings is null.";
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
      description = "Managed EpgTimerSrv.ini settings. Null leaves the file unmanaged. A non-null value receives integration defaults and TVTEST/tuner defaults for the selected BonDrivers; explicit settings take precedence.";
    };

    commonSettingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when commonSettings is null.";
    };

    commonSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      description = "Managed Common.ini settings. Null leaves the file unmanaged; a non-null value also receives the recording directory defaults.";
    };

    epgDataCapBonSettingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when epgDataCapBonSettings is null.";
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

    recNameMacroSettingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when recNameMacroSettings is null.";
    };

    recNameMacroSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      example.SET.Macro = "$ZtoH(Title)$.ts";
      description = "Managed RecName_Macro.so.ini settings. Null leaves the file unmanaged.";
    };

    materialWebUI = {
      enable = lib.mkEnableOption "EMWUI 3 for EDCB";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../pkgs/edcb-material-webui { };
        defaultText = lib.literalExpression "pkgs.nix-dtv.edcb-material-webui";
        description = "EMWUI 3 package to place in EDCB's HttpPublic and Setting directories.";
      };
    };

    bondriver = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mirakc" ];
      description = "Names of BonDrivers to install from hardware.dtv.bondriver. When settings is non-null, their binary filenames populate TVTEST and each receives Count=1, GetEpg=1, EPGCount=1 and a zero-based Priority in selection order. Repeated names are included only once. Override these defaults through settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingDrivers == [ ];
        message = "services.edcb.bondriver references undefined hardware.dtv.bondriver entries: ${lib.concatStringsSep ", " missingDrivers}";
      }
      {
        assertion =
          builtins.length (lib.unique (map (driver: driver.fileName) selectedDrivers))
          == builtins.length selectedDrivers;
        message = "services.edcb.bondriver selects drivers with duplicate binary filenames.";
      }
    ]
    ++ map (driver: {
      assertion =
        lib.hasPrefix "/" driver.driverPath
        && builtins.match "[A-Za-z0-9/._+-]+" driver.driverPath != null
        && lib.hasPrefix "BonDriver" driver.fileName
        && lib.hasSuffix ".so" driver.fileName;
      message = "Selected BonDriver driverPath must be an absolute path without whitespace or special characters to a BonDriver*.so file.";
    }) selectedDrivers;

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
    ]
    ++ lib.optionals cfg.materialWebUI.enable [
      "d /var/lib/edcb/Setting 0750 edcb edcb - -"
      "L+ /var/lib/edcb/HttpPublic/E3 - - - - ${webUIRoot}/HttpPublic/E3"
      "L+ /var/lib/edcb/HttpPublic/api - - - - ${webUIRoot}/HttpPublic/api"
      "C /var/lib/edcb/Setting/HttpPublic.ini 0640 edcb edcb - ${webUIRoot}/Setting/HttpPublic.ini"
      "C /var/lib/edcb/Setting/XCODE_OPTIONS.lua 0640 edcb edcb - ${webUIRoot}/Setting/XCODE_OPTIONS.lua"
    ]
    ++ bonDriverLibraryLinks
    ++ map (file: "L+ ${file.path} - - - - ${file.source}") linkedIniFiles
    ++ map (name: "L+ ${runtimeLibDir}/${name} - - - - ${cfg.package}/lib/edcb/${name}") edcbLibraries;

    # When both INI sources are null, remove only its store link.
    # Mutable files are deliberately preserved.
    system.activationScripts.edcb-unmanage-files.text = ''
      removeEdcbStoreLink() {
        filePath="$1"
        if [ -L "$filePath" ]; then
          case "$(${pkgs.coreutils}/bin/readlink "$filePath")" in
            /nix/store/*) ${pkgs.coreutils}/bin/rm -f -- "$filePath" ;;
          esac
        fi
      }
      ${lib.concatMapStringsSep "\n" (
        file: "removeEdcbStoreLink ${lib.escapeShellArg file.path}"
      ) unmanagedIniFiles}
      ${lib.optionalString (!cfg.materialWebUI.enable) ''
        removeMaterialWebUILink() {
          filePath="$1"
          if [ -L "$filePath" ]; then
            case "$(${pkgs.coreutils}/bin/readlink "$filePath")" in
              /nix/store/*/share/edcb-material-webui/HttpPublic/*) ${pkgs.coreutils}/bin/rm -f -- "$filePath" ;;
            esac
          fi
        }
        removeMaterialWebUILink /var/lib/edcb/HttpPublic/E3
        removeMaterialWebUILink /var/lib/edcb/HttpPublic/api
      ''}
    '';

    system.activationScripts.edcb-merge-settings = lib.mkIf (mergedIniFiles != [ ]) {
      deps = [
        "users"
        "edcb-unmanage-files"
      ];
      text = ''
        ${pkgs.coreutils}/bin/install -d -m 0750 -o edcb -g edcb /var/lib/edcb
        ${lib.concatMapStringsSep "\n" (
          file:
          "${pkgs.python3}/bin/python ${mergeIni} ${lib.escapeShellArg file.path} ${lib.escapeShellArg (toString file.source)}"
        ) mergedIniFiles}
      '';
    };

    systemd.services.edcb = {
      description = "EDCB EpgTimerSrv";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "mirakurun.service"
      ];
      wants = [ "mirakurun.service" ];
      restartTriggers =
        map (file: file.source) configuredIniFiles
        ++ map (driver: driver.package) selectedDrivers
        ++ map (driver: driver.driverPath) selectedDrivers
        ++ lib.optional cfg.materialWebUI.enable cfg.materialWebUI.package;
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

    warnings = lib.optional (builtins.elem "mirakc" selectedNames) "BonDriver_LinuxMirakc upstream states that Mirakurun compatibility is untested; verify tuning and long-running recording with your hardware.";
  };
}
