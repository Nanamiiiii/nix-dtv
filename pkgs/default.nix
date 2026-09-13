{
  pkgs,
  kernelPackages ? pkgs.linuxPackages,
}:
rec {
  px4_drv = kernelPackages.callPackage ./px4_drv { };
  mirakurun = pkgs.callPackage ./mirakurun { };
  recisdb = pkgs.callPackage ./recisdb { };
  isdb-scanner = pkgs.callPackage ./isdb-scanner { inherit recisdb; };
  edcb = pkgs.callPackage ./edcb { };
  bondriver-linux-mirakc = pkgs.callPackage ./bondriver-linux-mirakc { };
}
