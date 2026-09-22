{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "tsreadex";
  version = "master-260428";

  src = fetchurl {
    url = "https://github.com/xtne6f/tsreadex/archive/refs/tags/${version}.tar.gz";
    hash = "sha256-pg+3qiILTf8Vs4TKKOdhgd5ZFI6L5IenKKORZd7lBSA=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 tsreadex "$out/bin/tsreadex"

    runHook postInstall
  '';

  meta = {
    description = "MPEG-TS stream selector and stabilizer";
    homepage = "https://github.com/xtne6f/tsreadex";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "tsreadex";
  };
}
