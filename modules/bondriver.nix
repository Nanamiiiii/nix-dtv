{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hardware.dtv.bondriver = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.package;
            description = "Package providing this BonDriver.";
          };
          driverPath = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path to the BonDriver shared library, normally inside package. Its basename is used when installing the driver.";
          };
          settingsFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Existing INI file to link beside the selected driver as <binary filename>.ini. Takes precedence over settings.";
          };
          settings = lib.mkOption {
            type = lib.types.nullOr (pkgs.formats.ini { }).type;
            default = null;
            description = "INI settings written beside the selected driver as <binary filename>.ini. Used when settingsFile is null; null leaves the INI unmanaged if settingsFile is also null. No driver-specific values are added.";
          };
        };
      }
    );
    default = { };
    description = "Named BonDriver definitions available to DTV services.";
  };

  config.hardware.dtv.bondriver.mirakc = {
    package = lib.mkDefault (pkgs.callPackage ../pkgs/bondriver-linux-mirakc { });
    driverPath = lib.mkDefault "${config.hardware.dtv.bondriver.mirakc.package}/lib/edcb/BonDriver_LinuxMirakc.so";
    settings = lib.mkDefault {
      GLOBAL = {
        SERVER_HOST = "localhost";
        SERVER_PORT = config.services.mirakurun.port;
        DECODE_B25 = 0;
        PRIORITY = 100;
        SERVICE_SPLIT = 0;
      };
    };
  };
}
