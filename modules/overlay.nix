{ lib, ... }:
{
  nixpkgs.overlays = lib.mkDefault [ (import ../overlays) ];
}
