{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  nodejs_22,
  stdenv,
}:

buildNpmPackage {
  pname = "mirakurun";
  version = "4.1.3";

  src = fetchFromGitHub {
    owner = "Chinachu";
    repo = "Mirakurun";
    rev = "5770073e9b30d523512858ca82f45386f51a08fd";
    hash = "sha256-LkZuuWchGYK6CZJ5SPbPf5Xc02Dp77Nb/D2eexVY8Cg=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-0eHTvJ57LF593XKHSqmF9FBuUtyHTeP+NgTvcms1GaY=";
  npmInstallFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [ makeWrapper ];

  postConfigure = ''
    substituteInPlace node_modules/@node-rs/crc32/index.js \
      --replace-fail "/usr/bin/ldd" "${stdenv.cc.libc.bin}/bin/ldd"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/mirakurun" "$out/bin"
    cp -r api.yml bin config lib node_modules package.json "$out/lib/mirakurun/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/mirakurun" \
      --chdir "$out/lib/mirakurun" \
      --add-flags "--max-semi-space-size=64" \
      --add-flags "-r $out/lib/mirakurun/node_modules/source-map-support/register" \
      --add-flags "$out/lib/mirakurun/lib/server.js"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/mirakurun-epgdump" \
      --add-flags "$out/lib/mirakurun/bin/epgdump.js"

    runHook postInstall
  '';

  meta = {
    description = "DVR tuner server for Japanese TV";
    homepage = "https://github.com/Chinachu/Mirakurun";
    license = lib.licenses.asl20;
    mainProgram = "mirakurun";
    platforms = lib.platforms.linux;
  };
}
