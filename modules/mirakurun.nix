{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mirakurun;
in
{
  imports = [ ./overlay.nix ];

  # Extend the nixpkgs Mirakurun module instead of replacing it. This keeps
  # smart-card access, runtime-generated tuner/channel settings, firewall and
  # socket options in one upstream-maintained implementation.
  options.services.mirakurun = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix-dtv.mirakurun or (pkgs.callPackage ../pkgs/mirakurun { });
      defaultText = lib.literalExpression "pkgs.nix-dtv.mirakurun";
      description = "Mirakurun package used by the nixpkgs service module.";
    };

    tunerCommandPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ (pkgs.nix-dtv.recisdb or (pkgs.callPackage ../pkgs/recisdb { })) ];
      defaultText = lib.literalExpression "[ pkgs.nix-dtv.recisdb ]";
      description = "Packages containing tuner commands referenced by tuners.yml.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The upstream module refers to pkgs.mirakurun directly. Override that one
    # package so its service and system package both use the selected 4.x build.
    nixpkgs.overlays = lib.mkAfter [
      (_final: _prev: { mirakurun = cfg.package; })
    ];

    # The nixpkgs module currently targets Mirakurun 3.x and invokes
    # `mirakurun start`. Mirakurun 4.x removed that CLI, so use the direct
    # server wrapper supplied by this repository's current package.
    systemd.services.mirakurun = {
      path = cfg.tunerCommandPackages;
      serviceConfig.ExecStart = lib.mkForce "${cfg.package}/bin/mirakurun";
    };
  };
}
