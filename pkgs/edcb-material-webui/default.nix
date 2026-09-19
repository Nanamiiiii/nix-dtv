{
  fetchFromGitHub,
  glibc,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "edcb-material-webui";
  version = "3-unstable-2026-09-19";

  src = fetchFromGitHub {
    owner = "EMWUI";
    repo = "EDCB_Material_WebUI";
    rev = "10e376a48f8dc0f01cd80cf299fcc2424ac56c35";
    hash = "sha256-e+N3PutNvG2uEvIUZ4Sq2E4DsqYExIOYfT0QNa+eLeY=";
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
