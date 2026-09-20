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
  edcb-material-webui-package = pkgs.nix-dtv.edcb-material-webui;
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
