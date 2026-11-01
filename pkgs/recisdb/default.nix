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
  version = "1.3.2-unstable-2026-11-01";

  src = fetchFromGitHub {
    owner = "kazuki0824";
    repo = "recisdb-rs";
    rev = "710d7041f44267b50c67969cffca6202d843b64e";
    fetchSubmodules = true;
    hash = "sha256-eKwFGGysxbIFQTatCKxcSW+GL4j/mUtUJ1jgWDfIXhc=";
  };

  cargoHash = "sha256-fRFyOJXU83n3DeqGVbQVHU1k0DGwPJ7b9VY2+UckguI=";

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
