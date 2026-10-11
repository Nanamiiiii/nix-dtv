{
  fetchFromGitHub,
  glibc,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "edcb-material-webui";
  version = "3-unstable-2026-10-08";

  src = fetchFromGitHub {
    owner = "EMWUI";
    repo = "EDCB_Material_WebUI";
    rev = "0eb88e3a38b4ba2bfb2df0accab66dc08daa0b6d";
    hash = "sha256-W88pW5ikD2PF9rf/JvMuFJeh5QrCFf6h/gdBIl6tjwk=";
  };

  nativeBuildInputs = [ glibc.bin ];

  # An unset NVRAM.ZIP makes the E3 landing page concatenate nil.
  postPatch = ''
    substituteInPlace HttpPublic/E3/util.lua \
      --replace-fail "..zip.." "..(zip or NVRAM_ZIP).."
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/edcb-material-webui/HttpPublic" "$out/share/edcb-material-webui/Setting"
    cp -r HttpPublic/E3 HttpPublic/api "$out/share/edcb-material-webui/HttpPublic/"
    iconv -f CP932 -t UTF-8 Setting/HttpPublic.ini | tr -d '\r' \
      > "$out/share/edcb-material-webui/Setting/HttpPublic.ini"
    cp Setting/XCODE_OPTIONS.lua "$out/share/edcb-material-webui/Setting/"
    mkdir -p "$out/share/doc/edcb-material-webui"
    cp -r LICENSE "$out/share/doc/edcb-material-webui/"

    runHook postInstall
  '';

  meta = {
    description = "EMWUI 3 web interface for EDCB";
    homepage = "https://github.com/EMWUI/EDCB_Material_WebUI";
    platforms = lib.platforms.linux;
  };
}
