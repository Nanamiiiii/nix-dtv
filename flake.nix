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
        (nixpkgs.lib.mapAttrs (name: _: pkgs.${name}) (
          builtins.removeAttrs (import ./pkgs { inherit pkgs; }) [ "edcbExtraTools" ]
        ))
        // pkgs.edcbExtraTools
        // {
          default = pkgs.mirakurun;
          optionsDoc =
            let
              evaluated = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [ ./modules/dtv ];
              };
              optionsDoc = pkgs.nixosOptionsDoc {
                options = {
                  services = {
                    inherit (evaluated.options.services)
                      dtv
                      mirakurun
                      edcb
                      konomitv
                      ;
                  };
                  hardware = {
                    inherit (evaluated.options.hardware) px4_drv;
                  };
                };
                transformOptions =
                  option:
                  option
                  // {
                    declarations = map (
                      declaration:
                      let
                        path = toString declaration;
                        localPrefix = "${self}/";
                        nixpkgsPrefix = "${nixpkgs}/";
                      in
                      if nixpkgs.lib.hasPrefix localPrefix path then
                        {
                          name = nixpkgs.lib.removePrefix localPrefix path;
                          url = "../${nixpkgs.lib.removePrefix localPrefix path}";
                        }
                      else if nixpkgs.lib.hasPrefix nixpkgsPrefix path then
                        {
                          name = "nixpkgs/${nixpkgs.lib.removePrefix nixpkgsPrefix path}";
                          url = "https://github.com/NixOS/nixpkgs/blob/${nixpkgs.rev}/${nixpkgs.lib.removePrefix nixpkgsPrefix path}";
                        }
                      else
                        declaration
                    ) option.declarations;
                  };
              };
            in
            pkgs.runCommand "options.md" { nativeBuildInputs = [ pkgs.python3 ]; } ''
              python ${./docs/add-toc.py} ${optionsDoc.optionsCommonMark} "$out"
            '';
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

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          updatePackages = pkgs.writeShellApplication {
            name = "update-packages";
            runtimeInputs = with pkgs; [
              git
              nix
              nix-update
              python3
            ];
            text = ''
              exec python3 ${./scripts/update-packages.py} "$@"
            '';
          };
        in
        {
          update-packages = {
            type = "app";
            program = "${updatePackages}/bin/update-packages";
            meta.description = "Update DTV packages using their upstream tracking policies";
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
