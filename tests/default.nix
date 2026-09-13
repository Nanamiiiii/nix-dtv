{
  nixpkgs,
  pkgs,
  self,
  system,
}:
{
  recisdb-package = pkgs.nix-dtv.recisdb;
  isdb-scanner-package = pkgs.nix-dtv.isdb-scanner;
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
