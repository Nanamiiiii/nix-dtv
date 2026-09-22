{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "psisimux";
  version = "master-260422";

  src = fetchurl {
    url = "https://github.com/xtne6f/psisimux/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-zGmWNwEjBCumoXV9kSpS3gzZezZF+jK1eZ8RI2X6eyU=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 psisimux "$out/bin/psisimux"

    runHook postInstall
  '';

  meta = {
    description = "Multiplex PSI/SI and captions into MPEG-TS";
    homepage = "https://github.com/xtne6f/psisimux";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "psisimux";
  };
}
