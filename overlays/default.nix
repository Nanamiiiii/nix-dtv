final: prev:

let
  packages =
    kernelPackages:
    (import ../pkgs {
      pkgs = final;
      inherit kernelPackages;
    });
  defaultPackages = packages final.linuxPackages;
in
{
  nix-dtv = defaultPackages;

  # Keep the nixpkgs Mirakurun module while replacing its outdated package.
  mirakurun = defaultPackages.mirakurun;

  # px4_drv for each kernel
  kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
    (kernelFinal: kernelPrev: {
      nix-dtv = packages kernelFinal;
    })
  ];
}
