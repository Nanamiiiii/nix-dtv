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
  edcb-material-webui = pkgs.callPackage ./edcb-material-webui { };
  bondriver-linux-mirakc = pkgs.callPackage ./bondriver-linux-mirakc { };

  edcbExtraTools = {
    b24tovtt = pkgs.callPackage ./b24tovtt { };
    psisiarc = pkgs.callPackage ./psisiarc { };
    psisimux = pkgs.callPackage ./psisimux { };
    tsmemseg = pkgs.callPackage ./tsmemseg { };
    tsreadex = pkgs.callPackage ./tsreadex { };
  };
}
