{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "tsmemseg";
  version = "master-with-d-260611";

  src = fetchurl {
    url = "https://github.com/xtne6f/tsmemseg/archive/refs/tags/master-with-d-260611.tar.gz";
    hash = "sha256-sP/wf8eFiq/erCSe9ih2n+r/1zw9j0uh0qGZbVK/LdI=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 tsmemseg "$out/bin/tsmemseg"

    runHook postInstall
  '';

  meta = {
    description = "MPEG-TS stream segmenter for EDCB web streaming";
    homepage = "https://github.com/xtne6f/tsmemseg";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "tsmemseg";
  };
}
