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
  certificateSubjectAltNames = lib.unique (
    [
      "DNS:localhost"
      "IP:127.0.0.1"
    ]
    ++ lib.optional (config.networking.hostName != "") "DNS:${config.networking.hostName}"
    ++ cfg.materialWebUI.extraCertificateSubjectAltNames
  );
  epgTimerSrvSettings =
    if cfg.settings == null then
      null
    else
      lib.recursiveUpdate (lib.recursiveUpdate tunerSettings cfg.settings) portSettings;
  portSettings = {
    SET = {
      TCPPort = cfg.tcpPort;
      HttpPort = lib.concatStringsSep "," (
        map toString cfg.httpPorts ++ map (port: "${toString port}s") cfg.httpsPorts
      );
    };
  };
  commonSettings =
    if cfg.commonSettings == null then
      null
    else
      lib.recursiveUpdate {
        SET = {
          RecFolderNum = builtins.length cfg.recordingDir;
        }
        // builtins.listToAttrs (
          lib.imap0 (index: path: {
            name = "RecFolderPath${toString index}";
            value = path;
          }) cfg.recordingDir
        );
      } cfg.commonSettings;
  selectedDrivers = cfg.bondriver;
  tunerSettings = {
    TVTEST = {
      Num = builtins.length selectedDrivers;
    }
    // builtins.listToAttrs (
      lib.imap0 (index: driver: {
        name = toString index;
        value = driver.name;
      }) selectedDrivers
    );
  }
  // builtins.listToAttrs (
    map (driver: {
      name = builtins.unsafeDiscardStringContext driver.name;
      value = driver.tunerSettings;
    }) (lib.filter (driver: driver.tunerSettings != { }) selectedDrivers)
  );
  bonDriverIniFiles = map (driver: {
    name = "${driver.name}.ini";
    path = "${runtimeLibDir}/${driver.name}.ini";
    settings = driver.settings;
    settingsFile = driver.settingsFile;
  }) selectedDrivers;
  bonDriverLibraryLinks = map (
    driver: "L+ ${runtimeLibDir}/${driver.name} - - - - ${driver.driverPath}"
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
  imports = [ ./overlay.nix ];

  options.services.edcb = {
    enable = lib.mkEnableOption "Linux-native EDCB EpgTimerSrv";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix-dtv.edcb or (pkgs.callPackage ../pkgs/edcb { });
      defaultText = lib.literalExpression "pkgs.nix-dtv.edcb";
      description = "EDCB package to run.";
    };

    recordingDir = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/tv/recordings" ];
      description = "Directories in which EDCB writes recordings.";
    };

    recordingGroup = lib.mkOption {
      type = lib.types.str;
      default = "dtv";
      description = "Group with write access to the recording directories.";
    };

    manageRecordingDirs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the recording directories and enforce root ownership, the recording group, and mode 2770. Disable this for externally managed directories such as NFS shares.";
    };

    settingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when settings is null.";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = {
        SET = {
          EnableHttpSrv = 1;
          HttpAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
          EnableTCPSrv = 1;
          TCPAccessControlList = "+127.0.0.0/8,+10.0.0.0/8,+172.16.0.0/12,+192.168.0.0/16,+169.254.0.0/16,+100.64.0.0/10";
          CompatFlags = 128;
          TimeSync = 0;
        };
      };
      example = {
        EPG_CAP = {
          Count = 1;
          "0" = "05:15";
          "0Select" = 1;
          "0BasicOnlyFlags" = 14;
        };
      };
      description = "Managed EpgTimerSrv.ini settings. Null leaves the file unmanaged. The option default provides integration settings; an explicit value replaces it. A non-null value receives TVTEST entries and each BonDriver's tunerSettings. TCPPort and HttpPort are always derived from the dedicated port options.";
    };

    commonSettingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when commonSettings is null.";
    };

    commonSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = { };
      description = "Managed Common.ini settings. Null leaves the file unmanaged; a non-null value also receives the recording directory defaults.";
    };

    epgDataCapBonSettingsImmutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Link the generated INI from the Nix store. When false, merge Nix settings into the existing writable INI during system activation, with Nix values taking precedence. Has no effect when epgDataCapBonSettings is null.";
    };

    epgDataCapBonSettings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = { };
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
      default = false;
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
        default = pkgs.nix-dtv.edcb-material-webui or (pkgs.callPackage ../pkgs/edcb-material-webui { });
        defaultText = lib.literalExpression "pkgs.nix-dtv.edcb-material-webui";
        description = "EMWUI 3 package to place in EDCB's HttpPublic and Setting directories.";
      };

      extraCertificateSubjectAltNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "DNS:tv.example.com"
          "IP:192.168.1.10"
        ];
        description = "Additional OpenSSL subjectAltName entries for the self-signed HTTPS certificate generated on first EDCB startup. Localhost, 127.0.0.1, and the NixOS host name are included automatically. Changing this option does not replace an existing certificate.";
      };
    };

    bondriver = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              package = lib.mkOption {
                type = lib.types.package;
                description = "Package providing this BonDriver.";
              };
              driverPath = lib.mkOption {
                type = lib.types.str;
                description = "Absolute path to the BonDriver shared library, normally inside package.";
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = builtins.baseNameOf config.driverPath;
                defaultText = lib.literalExpression "builtins.baseNameOf driverPath";
                description = "Filename used for the BonDriver library symlink. The adjacent INI symlink uses <name>.ini. Defaults to the basename of driverPath.";
              };
              settingsFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Existing INI file to link beside the selected driver as <name>.ini. Takes precedence over settings.";
              };
              settings = lib.mkOption {
                type = lib.types.nullOr (pkgs.formats.ini { }).type;
                default = null;
                description = "INI settings written beside the selected driver as <name>.ini. Used when settingsFile is null; null leaves the INI unmanaged if settingsFile is also null. No driver-specific values are added.";
              };
              tunerSettings = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.oneOf [
                    lib.types.str
                    lib.types.int
                    lib.types.bool
                  ]
                );
                default = { };
                description = "Settings written to the section named after this BonDriver in EpgTimerSrv.ini. No tuner values are added automatically.";
              };
            };
          }
        )
      );
      default = [ ];
      description = "BonDriver definitions to install in selection order. Their names populate TVTEST in EpgTimerSrv.ini.";
    };

    tcpPort = lib.mkOption {
      type = lib.types.port;
      default = 4510;
      example = 4510;
      description = "TCP port for edcb service.";
    };

    httpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 5510 ];
      example = [
        5510
        5511
      ];
      description = "HTTP ports for integrated civetweb.";
    };

    httpsPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [
        5520
        5521
      ];
      description = "HTTPS ports for integrated civetweb.";
    };

    openFirewallPorts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall ports for edcb.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          builtins.length (lib.unique (map (driver: driver.name) selectedDrivers))
          == builtins.length selectedDrivers;
        message = "services.edcb.bondriver selects drivers with duplicate names.";
      }
    ]
    ++ map (driver: {
      assertion =
        lib.hasPrefix "/" driver.driverPath
        && builtins.match "[A-Za-z0-9/._+-]+" driver.driverPath != null
        && lib.hasSuffix ".so" driver.driverPath;
      message = "Selected BonDriver driverPath must be an absolute path without whitespace or special characters to a .so file.";
    }) selectedDrivers
    ++ map (driver: {
      assertion = builtins.match "BonDriver[A-Za-z0-9._+-]*[.]so" driver.name != null;
      message = "Selected BonDriver name must be a BonDriver*.so filename without path separators, whitespace or special characters.";
    }) selectedDrivers;

    users.groups.${cfg.recordingGroup} = { };
    users.groups.edcb = { };
    users.users.edcb = {
      isSystemUser = true;
      group = "edcb";
      extraGroups = [ cfg.recordingGroup ];
    };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewallPorts (
      [ cfg.tcpPort ] ++ cfg.httpPorts ++ cfg.httpsPorts
    );

    systemd.tmpfiles.rules =
      lib.optionals cfg.manageRecordingDirs (
        map (path: "d ${path} 2770 root ${cfg.recordingGroup} - -") cfg.recordingDir
      )
      ++ [
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
      unitConfig.RequiresMountsFor = cfg.recordingDir;
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
      preStart = lib.optionalString cfg.materialWebUI.enable ''
        certificate=/var/lib/edcb/ssl_cert.pem
        if [ ! -e "$certificate" ] && [ ! -L "$certificate" ]; then
          umask 077
          temporary=$(${pkgs.coreutils}/bin/mktemp -d /var/lib/edcb/.ssl-cert.XXXXXXXX)
          trap '${pkgs.coreutils}/bin/rm -rf -- "$temporary"' EXIT
          ${pkgs.openssl}/bin/openssl req -new -newkey rsa:2048 -nodes -x509 \
            -days 3650 -sha256 -subj /CN=localhost \
            -addext ${lib.escapeShellArg "subjectAltName=${lib.concatStringsSep "," certificateSubjectAltNames}"} \
            -keyout "$temporary/server.key" -out "$temporary/server.crt"
          ${pkgs.coreutils}/bin/cat "$temporary/server.crt" "$temporary/server.key" > "$temporary/ssl_cert.pem"
          ${pkgs.coreutils}/bin/chmod 0600 "$temporary/ssl_cert.pem"
          ${pkgs.coreutils}/bin/mv -nT -- "$temporary/ssl_cert.pem" "$certificate"
        fi
      '';
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
        ReadWritePaths = [ "/var/lib/edcb" ] ++ cfg.recordingDir;
      };
    };
  };
}
