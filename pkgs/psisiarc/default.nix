{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "psisiarc";
  version = "master-230324";

  src = fetchurl {
    url = "https://github.com/xtne6f/psisiarc/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-VNGrSC3A0crtgNt4WOXEYW90mG9Sequ2nUQ+wEWtKgI=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 psisiarc "$out/bin/psisiarc"

    runHook postInstall
  '';

  meta = {
    description = "PSI/SI section archiver for MPEG-TS";
    homepage = "https://github.com/xtne6f/psisiarc";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "psisiarc";
  };
}
