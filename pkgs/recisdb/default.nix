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
  version = "1.2.4-unstable-2026-09-19";

  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "b742fa171d37331f7d9a87eb3c40e1b7ddf9a36f";
    fetchSubmodules = true;
    hash = "sha256-0/SbEESQ2vc//pP/Vo5UL5Zg6sVfD4CDXnL+ZirqftY=";
  };

  cargoHash = "sha256-c4yL5V1G9mU0vg9m9v9s6qji8jsIpHWtugO6tOPJm9Q=";

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
