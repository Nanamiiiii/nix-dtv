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
  version = "1.3.2-unstable-2026-11-10";

  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "7987a31d464987b5be742e736bc59593d4bd0289";
    fetchSubmodules = true;
    hash = "sha256-B+RSyLs2oQOYvu5IHvKagS0QFo93TNvYJYg6YPSuE1c=";
  };

  cargoHash = "sha256-llX0HNu8ErpQzbqFUHx8AlIyyuHGVrUEizp1SxTxOG8=";

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
