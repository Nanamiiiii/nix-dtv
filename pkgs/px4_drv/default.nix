{
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags ? kernel.makeFlags,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "px4_drv";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "px4_drv";
    rev = "v${version}";
    hash = "sha256-YdB2kiVhYLi8TxZVL9eCksYtvri82Ybdlbe6uthkU/c=";
  };

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    : > driver/revision.h
  '';

  buildPhase = ''
    runHook preBuild

    make ${lib.escapeShellArgs kernelModuleMakeFlags} \
      -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      "M=$PWD/driver" modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    make ${lib.escapeShellArgs kernelModuleMakeFlags} \
      -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      "M=$PWD/driver" "INSTALL_MOD_PATH=$out" INSTALL_MOD_DIR=misc \
      DEPMOD=true modules_install
    install -Dm444 etc/it930x-firmware.bin \
      "$out/lib/firmware/it930x-firmware.bin"
    install -Dm444 etc/99-px4video.rules \
      "$out/lib/udev/rules.d/99-px4video.rules"

    runHook postInstall
  '';

  meta = {
    description = "Unofficial Linux driver for PLEX PX4/PX5/PX-MLT ISDB-T/S receivers";
    homepage = "https://github.com/tsukumijima/px4_drv";
    license = with lib.licenses; [
      gpl2Only
      unfreeRedistributableFirmware
    ];
    platforms = lib.platforms.linux;
  };
}
