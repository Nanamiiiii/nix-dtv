final: _prev:

let
  packages = import ../pkgs {
    pkgs = final;
    kernelPackages = final.linuxPackages;
  };
in
{
  nix-dtv = packages;

  # Keep the nixpkgs Mirakurun module while replacing its outdated package.
  mirakurun = packages.mirakurun;
}
