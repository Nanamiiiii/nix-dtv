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
        nix-dtv = import ./modules/dtv;
        default = self.nixosModules.nix-dtv;
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
