{
  nixpkgs,
  pkgs,
  self,
  system,
}:
{
  px4_drv-package = pkgs.nix-dtv.px4_drv;
  recisdb-package = pkgs.nix-dtv.recisdb;
  isdb-scanner-package = pkgs.nix-dtv.isdb-scanner;
  edcb-package = pkgs.nix-dtv.edcb;
  edcb-material-webui-package = pkgs.nix-dtv.edcb-material-webui;
  bondriver-linux-mirakc-package = pkgs.nix-dtv.bondriver-linux-mirakc;
  module-eval = import ./module-eval.nix {
    inherit
      nixpkgs
      pkgs
      self
      system
      ;
  };
  mirakurun = import ./mirakurun.nix { inherit pkgs self; };
  edcb = import ./edcb.nix { inherit pkgs self; };
  integration = import ./integration.nix { inherit pkgs self; };
}
