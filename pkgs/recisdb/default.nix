{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  pcsclite,
  v4l-utils,
}:

rustPlatform.buildRustPackage {
  pname = "recisdb";
  version = "1.3.2-unstable-2026-11-17";

  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "1cac43f2705e3c9735ac6871b91f1c5a6f333356";
    fetchSubmodules = true;
    hash = "sha256-Yd+CoAtn2JOG3oRgKujXyBHCmsySvzIbBLmOnT4Bdzg=";
  };

  cargoHash = "sha256-JEHEyYxNPLT2J66hlZkwnZo805mjyxpWOhuyZHj+17w=";

  nativeBuildInputs = [
    cmake
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    pcsclite
    v4l-utils
  ];

  cargoBuildFlags = [
    "--package"
    "recisdb"
    "--features"
    "dvb"
  ];

  cargoInstallFlags = [
    "--path"
    "recisdb-rs"
    "--features"
    "dvb"
  ];

  meta = {
    description = "Tuner reader and ARIB STD-B25 decoder for Japanese digital TV";
    homepage = "https://github.com/kazuki0824/recisdb-rs";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "recisdb";
  };
}
