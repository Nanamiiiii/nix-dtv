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

  pluginIniFiles = map (plugin: {
    name = "${plugin.name}.ini";
    path = "/var/lib/edcb/${plugin.name}.ini";
    settings = plugin.settings;
    settingsFile = plugin.settingsFile;
  }) cfg.plugins;

  binaryPlugins = lib.filter (plugin: plugin.pluginPath != null) cfg.plugins;

  pluginLibraryLinks = map (
    plugin: "L+ ${runtimeLibDir}/${plugin.name} - - - - ${plugin.pluginPath}"
  ) binaryPlugins;

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
  ]
  ++ bonDriverIniFiles
  ++ pluginIniFiles;

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

  polkitRule = pkgs.writeTextDir "share/polkit-1/rules.d/10-edcb.rules" ''
    polkit.addRule(function (action, subject) {
      if (
        (action.id == "org.debian.pcsc-lite.access_pcsc" ||
          action.id == "org.debian.pcsc-lite.access_card") &&
        subject.user == "edcb"
      ) {
        return polkit.Result.YES;
      }
    });
  '';
in
{
  options.services.edcb = {
    enable = lib.mkEnableOption "Linux-native EDCB EpgTimerSrv";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.edcb or (pkgs.callPackage ../../pkgs/edcb { });
      defaultText = lib.literalExpression "pkgs.edcb";
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

    plugins = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              pluginPath = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Absolute path to the plugin binary, normally inside the Nix store. Null installs only the INI file.";
              };

              name = lib.mkOption (
                {
                  type = lib.types.str;
                  defaultText = lib.literalExpression "builtins.baseNameOf pluginPath";
                  description = "Filename used for the plugin symlink in /var/lib/edcb/lib. The INI symlink uses /var/lib/edcb/<name>.ini. Defaults to the basename of pluginPath; must be specified when pluginPath is null.";
                }
                // lib.optionalAttrs (config.pluginPath != null) {
                  default = builtins.baseNameOf config.pluginPath;
                }
              );

              settingsFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Existing INI file to link as /var/lib/edcb/<name>.ini. Takes precedence over settings.";
              };

              settings = lib.mkOption {
                type = lib.types.nullOr (pkgs.formats.ini { }).type;
                default = null;
                description = "INI settings linked as /var/lib/edcb/<name>.ini. Used when settingsFile is null; null leaves the INI unmanaged if settingsFile is also null.";
              };
            };
          }
        )
      );
      default = [ ];
      description = "Plugin definitions to install in runtime library path.";
    };

    materialWebUI = {
      enable = lib.mkEnableOption "EMWUI 3 for EDCB";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.edcb-material-webui or (pkgs.callPackage ../../pkgs/edcb-material-webui { });
        defaultText = lib.literalExpression "pkgs.edcb-material-webui";
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
              driverPath = lib.mkOption {
                type = lib.types.str;
                description = "Absolute path to the BonDriver shared library, normally inside the Nix store.";
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
      default = [ 5510 ] ++ lib.optional cfg.materialWebUI.enable 5520;
      defaultText = lib.literalExpression "[ 5510 ] ++ lib.optional config.services.edcb.materialWebUI.enable 5520";
      example = [
        5510
        5520
      ];
      description = "HTTP ports for integrated civetweb.";
    };

    httpsPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = lib.optionals cfg.materialWebUI.enable [
        5511
        5521
      ];
      defaultText = lib.literalExpression "lib.optionals config.services.edcb.materialWebUI.enable [ 5511 5521 ]";
      example = [
        5511
        5521
      ];
      description = "HTTPS ports for integrated civetweb.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall ports for edcb.";
    };

    allowSmartCardAccess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install polkit rules to allow EDCB to access smart card readers
        which is commonly used along with tuner devices.
      '';
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
    ++ map (plugin: {
      assertion = plugin.pluginPath != null || plugin.settings != null || plugin.settingsFile != null;
      message = "services.edcb.plugins requires at least one of pluginPath, settings or settingsFile for each plugin.";
    }) cfg.plugins
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

    environment.systemPackages = [ cfg.package ] ++ lib.optional cfg.allowSmartCardAccess polkitRule;

    users.groups.${cfg.recordingGroup} = { };

    users.groups.edcb = { };

    users.users.edcb = {
      isSystemUser = true;
      group = "edcb";
      extraGroups = [ cfg.recordingGroup ];
    };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall (
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
      ++ pluginLibraryLinks
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
      # tmpfiles does not remove links whose rules have been withdrawn.
      for filePath in ${runtimeLibDir}/BonDriver*.so ${runtimeLibDir}/BonDriver*.so.ini; do
        case "$filePath" in
          ${
            lib.concatStringsSep "|" (
              [ "''" ]
              ++ lib.concatMap (driver: [
                (lib.escapeShellArg "${runtimeLibDir}/${driver.name}")
                (lib.escapeShellArg "${runtimeLibDir}/${driver.name}.ini")
              ]) selectedDrivers
            )
          }) ;;
          *) removeEdcbStoreLink "$filePath" ;;
        esac
      done
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
      path = [
        cfg.package
        pkgs.coreutils
        pkgs.procps
      ];
      unitConfig.RequiresMountsFor = cfg.recordingDir;
      after = [
        "network.target"
        "mirakurun.service"
      ];
      wants = [ "mirakurun.service" ];
      restartTriggers =
        map (file: file.source) configuredIniFiles
        ++ map (driver: driver.driverPath) selectedDrivers
        ++ map (plugin: plugin.pluginPath) binaryPlugins
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
