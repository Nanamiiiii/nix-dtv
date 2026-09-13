{
  description = "Nix packages and NixOS modules for a Japanese DTV stack";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = import ./overlays;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        in
        pkgs.nix-dtv
        // {
          default = pkgs.nix-dtv.mirakurun;
        }
      );

      nixosModules = {
        default = import ./modules;
        dtv = import ./modules/dtv.nix;
        px4_drv = import ./modules/px4_drv.nix;
        mirakurun = import ./modules/mirakurun.nix;
        edcb = import ./modules/edcb.nix;
        konomitv = import ./modules/konomitv.nix;
      };

      checks = forAllSystems (
        system:
        import ./tests {
          inherit nixpkgs self system;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
