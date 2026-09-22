{
  edcbExtraTools,
  fetchFromGitHub,
  lib,
  lua5_2,
  openssl,
  patchelf,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "edcb";
  version = "work-plus-s-260904";

  src = fetchFromGitHub {
    owner = "xtne6f";
    repo = "EDCB";
    rev = version;
    hash = "sha256-XoPyWJA+LknTJpdQSdhICyHV/P1p+E2NhAfHLr/ghhs=";
  };

  buildInputs = [
    lua5_2
    openssl
  ];

  nativeBuildInputs = [ patchelf ];

  postPatch = ''
    substituteInPlace Common/PathUtil.h \
      --replace-fail 'L"/var/local/edcb"' 'L"/var/lib/edcb"' \
      --replace-fail 'L"/usr/local/lib/edcb"' 'L"/var/lib/edcb/lib"'
    substituteInPlace EpgTimerSrv/EpgTimerSrv/Makefile \
      --replace-fail '-L. -llua5.2' '-L${lib.getLib lua5_2}/lib -llua'
  '';

  buildPhase = ''
    runHook preBuild

    make -C Document/Unix all \
      LDFLAGS="-Wl,-rpath,${lib.getLib lua5_2}/lib"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 EpgDataCap_Bon/EpgDataCap_Bon/EpgDataCap_Bon "$out/bin/EpgDataCap_Bon"
    install -Dm755 EpgTimerSrv/EpgTimerSrv/EpgTimerSrv "$out/bin/EpgTimerSrv"

    for tool in asyncbuf relayread tsidmove-edcb tspgtxt; do
      install -Dm755 "Document/Unix/$tool" "$out/bin/$tool"
    done

    ln -s ${edcbExtraTools.b24tovtt}/bin/b24tovtt "$out/bin/b24tovtt"
    ln -s ${edcbExtraTools.psisiarc}/bin/psisiarc "$out/bin/psisiarc"
    ln -s ${edcbExtraTools.psisimux}/bin/psisimux "$out/bin/psisimux"
    ln -s ${edcbExtraTools.tsmemseg}/bin/tsmemseg "$out/bin/tsmemseg"
    ln -s ${edcbExtraTools.tsreadex}/bin/tsreadex "$out/bin/tsreadex"

    install -Dm444 EpgDataCap3/EpgDataCap3/EpgDataCap3.so "$out/lib/edcb/EpgDataCap3.so"
    install -Dm444 RecName_Macro/RecName_Macro/RecName_Macro.so "$out/lib/edcb/RecName_Macro.so"
    install -Dm444 SendTSTCP/SendTSTCP/SendTSTCP.so "$out/lib/edcb/SendTSTCP.so"
    install -Dm444 Write_Default/Write_Default/Write_Default.so "$out/lib/edcb/Write_Default.so"

    mkdir -p "$out/share/edcb/initial-state/HttpPublic"
    iconv -f CP932 -t UTF-8 ini/Bitrate.ini | tr -d '\r' \
      > "$out/share/edcb/initial-state/Bitrate.ini"
    iconv -f CP932 -t UTF-8 ini/BonCtrl.ini | tr -d '\r' | sed 's/\.dll$/.so/' \
      > "$out/share/edcb/initial-state/BonCtrl.ini"
    tr -d '\r' < ini/ContentTypeText.txt \
      > "$out/share/edcb/initial-state/ContentTypeText.txt"
    cp -r ini/HttpPublic/. "$out/share/edcb/initial-state/HttpPublic/"

    runHook postInstall
  '';

  # CivetWeb opens libssl.so.3 and libcrypto.so.3 with dlopen(), so the
  # standard fixup removes their unused linker rpath. Add it afterwards.
  postFixup = ''
    patchelf --add-rpath ${lib.getLib openssl}/lib "$out/bin/EpgTimerSrv"
  '';

  meta = {
    description = "Linux-native build of EDCB EpgTimerSrv and related tools";
    homepage = "https://github.com/xtne6f/EDCB";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
