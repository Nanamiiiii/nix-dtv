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
defaultPackages
// {
  # px4_drv for each kernel
  kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
    (kernelFinal: kernelPrev: {
      px4_drv = (packages kernelFinal).px4_drv;
    })
  ];
}
