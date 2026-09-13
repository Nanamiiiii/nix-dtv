{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  lsof,
  makeWrapper,
  python3Packages,
  recisdb,
}:

let
  ariblib = python3Packages.buildPythonPackage {
    pname = "ariblib";
    version = "0.1.4";
    format = "wheel";

    src = fetchurl {
      url = "https://github.com/tsukumijima/ariblib/releases/download/v0.1.4/ariblib-0.1.4-py3-none-any.whl";
      hash = "sha256-rDu2LvKZiBHCOwDW2WSNzeTB351ODFp5OFywSwv7IxA=";
    };

    pythonImportsCheck = [ "ariblib" ];

    meta = {
      description = "Python implementation of ARIB STD-B10 and ARIB STD-B24";
      homepage = "https://github.com/youzaka/ariblib";
      license = lib.licenses.mit;
    };
  };

  pythonDependencies = with python3Packages; [
    ariblib
    devtools
    libusb-package
    pydantic
    pyusb
    rich
    ruamel-yaml
    typer
    typing-extensions
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "isdb-scanner";
  version = "1.3.3";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "ISDBScanner";
    tag = "v${version}";
    hash = "sha256-FjGVrfcQX24EckdUW9xEo45bCbxDjeOzPRVWqCW0cIE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/isdb-scanner"
    cp -r isdb_scanner "$out/share/isdb-scanner/"

    makeWrapper ${python3Packages.python.interpreter} "$out/bin/isdb-scanner" \
      --add-flags "-m isdb_scanner" \
      --set PYTHONPATH "${python3Packages.makePythonPath pythonDependencies}:$out/share/isdb-scanner" \
      --prefix PATH : "${
        lib.makeBinPath [
          lsof
          recisdb
        ]
      }"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/isdb-scanner" --version | grep -F "ISDBScanner version ${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Automatic ISDB-T/ISDB-S channel scanner for Japanese digital TV";
    homepage = "https://github.com/tsukumijima/ISDBScanner";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "isdb-scanner";
  };
}
