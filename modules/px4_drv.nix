{
  config,
  lib,
  ...
}:

let
  cfg = config.hardware.px4_drv;
in
{
  options.hardware.px4_drv = {
    enable = lib.mkEnableOption "the px4_drv kernel module";

    package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.callPackage ../pkgs/px4_drv { };
      defaultText = lib.literalExpression "config.boot.kernelPackages.callPackage <nix-dtv/pkgs/px4_drv> { }";
      description = "px4_drv built for the configured NixOS kernel.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ cfg.package ];
    boot.kernelModules = [ "px4_drv" ];
    hardware.firmware = [ cfg.package ];
    services.udev.packages = [ cfg.package ];
  };
}
