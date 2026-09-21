{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "b24tovtt";
  version = "master-220402";

  src = fetchurl {
    url = "https://github.com/xtne6f/b24tovtt/archive/refs/tags/master-220402.tar.gz";
    hash = "sha256-H3MPwGrHXG5j4HfZwpfY5ay48YDCCPkPcdO3X4Dsb0c=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 b24tovtt "$out/bin/b24tovtt"

    runHook postInstall
  '';

  meta = {
    description = "Convert ARIB STD-B24 captions to WebVTT";
    homepage = "https://github.com/xtne6f/b24tovtt";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "b24tovtt";
  };
}
