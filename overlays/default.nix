final: _prev: {
  nix-dtv = import ../pkgs {
    pkgs = final;
    kernelPackages = final.linuxPackages;
  };
}
