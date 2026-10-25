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
  version = "1.3.2-unstable-2026-10-22";

  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "f5ab7231ea89208f6123fce4ed81dd6c5e6e52b4";
    fetchSubmodules = true;
    hash = "sha256-FMnr/sVvJQ5aQRX/DXqjmIAfA3Bd3U4cNUC0I/ahlmo=";
  };

  cargoHash = "sha256-VXktPRGidYOltoBajcwRQRxqnQ43E6qkfxZTQs+dBiU=";

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
