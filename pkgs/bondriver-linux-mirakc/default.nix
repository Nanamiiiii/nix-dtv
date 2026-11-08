{
  fetchFromGitHub,
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "bondriver-linux-mirakc";
  version = "0-unstable-2026-11-07";

  src = fetchFromGitHub {
    owner = "matching";
    repo = "BonDriver_LinuxMirakc";
    rev = "bc1d70c7415ea5b49b8384151045b0c826fded5c";
    hash = "sha256-nbqlFteVdLB90Bh5hmgPMvT2AFRx0YDlRYJFrxCDhIA=";
  };

  picojson = fetchFromGitHub {
    owner = "kazuho";
    repo = "picojson";
    rev = "111c9be5188f7350c2eac9ddaedd8cca3d7bf394";
    hash = "sha256-5sXzVZESvzQkyNyzK2+u+Q9wx1F55Tw2YRHOnAlLx8M=";
  };

  postPatch = ''
    rmdir include/picojson
    cp -r "$picojson" include/picojson
    chmod -R u+w include/picojson
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 BonDriver_LinuxMirakc.so \
      "$out/lib/BonDriver_LinuxMirakc.so"
    install -Dm444 BonDriver_LinuxMirakc.so.ini_sample \
      "$out/share/edcb/BonDriver_LinuxMirakc.so.ini.sample"

    runHook postInstall
  '';

  meta = {
    description = "BonDriver for connecting Linux EDCB to mirakc-compatible HTTP servers";
    homepage = "https://github.com/matching/BonDriver_LinuxMirakc";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
