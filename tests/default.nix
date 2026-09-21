{
  nixpkgs,
  pkgs,
  self,
  system,
}:
{
  px4_drv-package = pkgs.px4_drv;
  recisdb-package = pkgs.recisdb;
  isdb-scanner-package = pkgs.isdb-scanner;
  edcb-package = pkgs.edcb;
  edcb-material-webui-package = pkgs.edcb-material-webui;
  bondriver-linux-mirakc-package = pkgs.bondriver-linux-mirakc;
  b24tovtt-package = pkgs.edcbExtraTools.b24tovtt;
  psisiarc-package = pkgs.edcbExtraTools.psisiarc;
  psisimux-package = pkgs.edcbExtraTools.psisimux;
  tsmemseg-package = pkgs.edcbExtraTools.tsmemseg;
  tsreadex-package = pkgs.edcbExtraTools.tsreadex;
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
