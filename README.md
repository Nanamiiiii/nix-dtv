# nix-dtv

日本の DTV 環境向けの Nix package と NixOS module です。Home Manager や Docker 内でのチューナー制御は使わず、次の構成を system-level で宣言します。

```text
physical tuner -> px4_drv -> Mirakurun -> BonDriver_LinuxMirakc -> EDCB
                                                            -> recordings (RW)
                                                            -> KonomiTV (RO)
```

## 提供するもの

- `packages.<system>.px4_drv`: tsukumijima/px4_drv の kernel module、firmware、udev rule
- `packages.<system>.mirakurun`: Node.js 22 でビルドする native Mirakurun
- `packages.<system>.recisdb`: 最新 commit を固定した recisdb unstable（chardev / DVBv5、ARIB STD-B25 対応）
- `packages.<system>.isdb-scanner`: 最新 release を固定した ISDBScanner（recisdb を実行時依存に含む）
- `packages.<system>.edcb`: `Document/Unix/Makefile` を使う Linux native EDCB
- `packages.<system>.edcb-material-webui`: EMWUI 3 の E3 ブランチを固定した Web UI
- `packages.<system>.bondriver-linux-mirakc`: picojson を含む native BonDriver `.so`
- `overlays.default`: 上記を `pkgs.nix-dtv` 以下へ追加する overlay
- `nixosModules.{default,dtv,px4_drv,bondriver,mirakurun,edcb,konomitv}`

px4_drv に含まれる udev rule は upstream と同じ `root:video`, mode `0664` です。

## 使用例

```nix
{
  inputs.nix-dtv.url = "github:Nanamiiiii/nix-dtv";

  outputs = { nixpkgs, nix-dtv, ... }: {
    nixosConfigurations.tv-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-dtv.nixosModules.default
        {
          services.dtv = {
            enable = true;
            recordingDir = [
              "/mnt/tv/recordings"
              "/mnt/tv/archive"
            ];

            px4_drv.enable = true;
            mirakurun.enable = true;
            edcb.enable = true;
            konomitv.enable = true;
          };

          # px4_drv が配布する firmware のライセンスに必要です。
          nixpkgs.config.allowUnfree = true;

          security.polkit.enable = true;
          services.pcscd.enable = true;

          services.mirakurun = {
            tunerSettings = [
              {
                name = "PX4-S1";
                types = [ "BS" "CS" ];
                command = "recisdb tune --device /dev/px4video0 --channel <channel> -";
              }
            ];
          };

          # 空のattrsetでも、そのINIをNix管理へ明示的に切り替えます。
          services.edcb = {
            settings = { };
            commonSettings = { };
          };
        }
      ];
    };
  };
}
```

Mirakurun service の `PATH` には既定で `recisdb` が追加されるため、`tunerSettings` の `command` では絶対 path を書く必要はありません。別の tuner command を使う場合は `services.mirakurun.tunerCommandPackages` にその packageを追加または指定します。カードリーダーを利用する場合は `security.polkit.enable = true` と `services.pcscd.enable = true` にします。Mirakurun用のpolkitルールはnixpkgs標準モジュールの `allowSmartCardAccess` により既定で導入されます。

ISDBScanner は flake から直接実行できます。

```console
nix run github:Nanamiiiii/nix-dtv#isdb-scanner -- --list-tuners
nix run github:Nanamiiiii/nix-dtv#isdb-scanner -- ./scanned
```

出力される Mirakurun の `channels.yml` は recisdb 形式（地上波は `T27`、衛星は `BS01_0` / `CS2` など）です。`tunerSettings` の `recisdb tune ...` と組み合わせて利用してください。`channelSettings` の既定値は `null` なので、生成したチャンネルリストをランタイム設定として配置できます。

`services.dtv.recordingDir` は録画先の文字列リストで、既定値は `[ "/mnt/tv/recordings" ]` です。`services.dtv` 自身は録画先を作成せず、EDCB の書き込み先と KonomiTV の `video.recorded_folders` へ伝播します。EDCB を有効にした場合は `services.edcb.manageRecordingDirs` に従って `dtv` group と setgid directoryを管理します。`services.edcb.commonSettings` を指定してNix管理を有効にした場合は、指定順に `RecFolderPath0`, `RecFolderPath1`, …を補完します。既存環境でgroup名が競合する場合は `services.dtv.recordingGroup` で変更できます。

NFS など、録画先の作成と権限を外部で管理する場合は `services.edcb.manageRecordingDirs = false` にします。この場合は tmpfiles による録画先の作成と `root:<recordingGroup>`, mode `2770` の適用を行いません。EDCB と KonomiTV への録画先の伝播は維持し、両serviceはすべての録画先に `RequiresMountsFor` を設定するため、必要なmountの後に起動します。NFS Server側では、強制map後のユーザーにEDCBの書き込み権限とKonomiTVの読み取り権限を与えてください。

KonomiTV の capture先をNFSなどで外部管理する場合は `services.konomitv.manageCaptureDirs = false` にします。tmpfilesによる作成と `root:root`, mode `0750` の適用だけを止め、`capture.upload_folders` とread-write mountは維持します。KonomiTV serviceの `RequiresMountsFor` には録画先とcapture先の両方が含まれます。

```nix
services.dtv = {
  recordingDir = [ "/mnt/nfs/tv-recordings" ];
};

services.edcb.manageRecordingDirs = false;

services.konomitv = {
  captureDir = [ "/mnt/nfs/tv-capture" ];
  manageCaptureDirs = false;
};
```

## 権限と状態

- Mirakurunはnixpkgs標準モジュールで `mirakurun:video` として動かし、このリポジトリでは最新版パッケージの直接起動とrecisdbのservice `PATH`だけを追加します。DBとlogoは `/var/lib/mirakurun`、ランタイム生成されるtuner/channel設定は `/etc/mirakurun` に置きます。
- EDCB は `edcb:edcb` で動き、`dtv` group だけを追加します。実行ファイルと `.so` の実体は Nix store、設定と状態は `/var/lib/edcb`、録画だけは指定した recording directories に書き込みます。
- `EpgTimerSrv.ini`、`Common.ini`、`EpgDataCap_Bon.ini`、`RecName_Macro.so.ini` と BonDriver の `<driver name>.ini` は、対応する設定optionを指定したファイルだけUTF-8（BOMなし）で生成します。BonDriver は `hardware.dtv.bondriver."<driver name>".settings` で指定し、`settings` と `settingsFile` が両方 `null` の場合は既存設定に任せます。`Bitrate.ini` と `BonCtrl.ini` は上流サンプルを初回だけmutableな設定として配置し、既存ファイルは上書きしません。
- `EpgTimerSrv.ini` をNix管理する場合はloopback限定のTCP接続、KonomiTV向けの `CompatFlags=128`、`TimeSync=0` を補完します。`Common.ini` には録画先を補完します。BonDriverごとのINI設定には値を補完しません。選択したBonDriverには後述のチューナー設定を補完します。接続先や台数の変更は必要に応じて明示してください。
- EPG取得時刻、録画マージン、ファイル名、ログ、B25処理などは環境依存です。モジュールが補完しない項目にはEDCBとBonDriverの上流既定値が使われます。チューナー数は各BonDriverで1台を初期値とし、実機構成に合わせて変更してください。
- recisdbは既定でB25処理を行うため、標準構成ではBonDriver側の `DECODE_B25` を設定しません。raw TSを出すチューナーコマンドとMirakurunのdecoderを使う場合だけ明示してください。
- EDCB の `TimeSync` は `0` のままにし、時刻同期は systemd-timesyncd や chrony に任せてください。
- KonomiTV は公式 `ghcr.io/tsukumijima/konomitv:latest` image を Docker backend と host network で起動します。upstream image の互換性を優先して container root のままです。
- KonomiTV の `config.yaml` は Nix store から read-only mount されます。Web UI で server config を永続変更せず、Nix の `services.konomitv` 以下の専用optionと `extraSettings` を変更してください。
- KonomiTV には録画 directory を read-only、capture/data/logs だけを read-write mount します。ホスト root 全体は mount しません。

KonomiTV の主要設定は専用optionから生成します。`recordingDir` と `captureDir` は複数指定でき、それぞれ `video.recorded_folders` と `capture.upload_folders` に反映されます。専用optionがない追加項目は `extraSettings` に指定します。`extraSettings` と専用optionが同じキーを指定した場合は専用optionが優先されます。

`encoder` に応じて、[KonomiTV公式のDocker Composeサンプル](https://github.com/tsukumijima/KonomiTV/blob/master/docker-compose.example.yaml)と同じGPUアクセスをcontainerへ設定します。

- `FFmpeg`: GPU deviceを追加しない
- `QSVEncC` / `VCEEncC`: `/dev/dri/` をcontainerへ渡す
- `NVEncC`: 全NVIDIA GPUを `compute,utility,video` capability付きで渡し、`hardware.nvidia-container-toolkit.enable` を既定で有効にする

NVEncCではホスト側のNVIDIA driver設定も必要です。通常は `services.xserver.videoDrivers = [ "nvidia" ];` または `hardware.nvidia.datacenter.enable = true;` を指定してください。`devices` はencoderから導出されるdeviceに加えて渡す追加device用です。

```nix
services.konomitv = {
  backend = "EDCB";
  streamFromMirakurun = true;
  edcbUrl = "tcp://127.0.0.1:4510/";
  mirakurunUrl = "http://127.0.0.1:40772/";
  encoder = "QSVEncC";
  serverPort = 7000;

  recordingDir = [
    "/mnt/tv/recordings"
    "/mnt/tv/archive"
  ];
  captureDir = [ "/var/lib/konomitv/capture" ];

  extraSettings.general.program_update_interval = 10.0;
};
```

ドライバー定義は `hardware.dtv` に集約しています。`hardware.dtv.px4_drv.enable` でカーネルドライバーを有効化し、BonDriverは `hardware.dtv.bondriver.<driver name>` に定義します。各定義は `package`、実バイナリへの絶対パス `driverPath`、INIへ書き出す `settings`、既存INIファイルを指定する `settingsFile` を持ちます。`mirakc` は同梱パッケージと、そのパッケージ内の `BonDriver_LinuxMirakc.so` を参照する定義です。INI設定の既定値は全ドライバー共通で `null` です。

`services.edcb.bondriver` は使用する定義名の文字列リストです。EDCBは選択された定義だけを参照し、`driverPath` の末尾のファイル名で本体を `/var/lib/edcb/lib/` にリンクします。`settingsFile`（既定値 `null`）が指定されていれば、そのファイルへのリンクを同じファイル名に `.ini` を付けて隣に配置します。`settingsFile` は `settings` より優先されます。`settingsFile` が `null` の場合は `settings` からINIを生成し、両方 `null` ならINIを管理しません。未定義の名前や選択ドライバー間のファイル名重複はエラーになります。`services.dtv` の標準構成は `[ "mirakc" ]` を選択します。

```nix
hardware.dtv.px4_drv.enable = true;
hardware.dtv.bondriver = {
  mirakc.settingsFile = ./BonDriver_LinuxMirakc.so.ini;
  custom = {
    package = pkgs.myBonDriver;
    driverPath = "${pkgs.myBonDriver}/lib/BonDriver_Custom.so";
    settings.GLOBAL.PRIORITY = 7;
  };
};
services.edcb.bondriver = [ "mirakc" "custom" ];
```

この例では `BonDriver_LinuxMirakc.so` と `BonDriver_Custom.so`、およびそれぞれの `.ini` を配置します。Linux版EDCBはWindows版の `BonDriver/` ではなくライブラリディレクトリ直下から読み込みます。Mirakcは読み込まれた `.so` に隣接する `.ini` を探しますが、ほかのドライバーの設定ファイル探索先は各実装を確認してください。

`services.edcb.settings` が非 `null` の場合、`services.edcb.bondriver` で選択したドライバーの `driverPath` のbasenameから、`EpgTimerSrv.ini` の `[TVTEST]` とチューナー設定を生成します。`settings = { };` と `bondriver = [ "mirakc" ];` の組み合わせでは、従来の `SET` 補完値に加えて次を生成します。

```ini
[TVTEST]
Num=1
0=BonDriver_LinuxMirakc.so
[BonDriver_LinuxMirakc.so]
Count=1
GetEpg=1
EPGCount=1
Priority=0
```

複数指定した場合は選択順に `TVTEST` の `0`、`1`、… と `Priority=0,1,…` を割り当てます。同じ定義名の重複は最初の1件にまとめます。選択が空なら `TVTEST.Num=0` だけを補完し、ドライバー別セクションは生成しません。`settings = null` の場合は、ドライバーを選択してもINIは管理しません。

`services.edcb.settings` に書いた同じセクション・キーが補完値より優先されます。視聴対象を絞る場合は `TVTEST.Num` と `TVTEST."0"` などを一緒に上書きしてください。`settingsImmutable = false` でも補完値はactivation時のマージ対象となるため、WebUIで変更した台数などは次回の構成適用・OS起動時にNix側の値に戻ります。

実機のチューナー数やEPG取得方針はホスト設定に記述します。たとえば4チューナー中2台をEPG取得に使い、毎日05:15に取得する場合は次のように指定します。

```nix
services.edcb.settings = {
  "BonDriver_LinuxMirakc.so" = {
    Count = 4;
    EPGCount = 2;
  };
  EPG_CAP = {
    Count = 1;
    "0" = "05:15";
    "0Select" = 1;
    "0BasicOnlyFlags" = 14;
  };
};
```

### EMWUI 3 (EDCB Material WebUI)

`services.edcb.materialWebUI.enable = true;` で [EMWUI 3 の E3 ブランチ](https://github.com/EMWUI/EDCB_Material_WebUI/tree/E3) を導入します。`/var/lib/edcb/HttpPublic/E3` と `api` は固定した package へのリンク、`/var/lib/edcb/Setting/HttpPublic.ini` と `XCODE_OPTIONS.lua` は初回だけ UTF-8（BOMなし）でコピーする編集可能なファイルです。上流のディレクトリ名は `Setting`（単数）です。既存の設定ファイルは上書きしません。

```nix
services.edcb = {
  materialWebUI.enable = true;
  settings = {
    SET = {
      HttpNumThreads = 50;
      # LAN からのアクセスを許可する場合だけ、HttpAccessControlList も指定します。
    };
  };
};
```

`settings` を指定すると、この module が補完する `EnableHttpSrv=1` により HTTP サーバーが有効になります。既定の待受ポートは `5510`、アクセス許可は EDCB の既定値に従い loopback のみです。`http://127.0.0.1:5510/E3/` からアクセスできます。HTTPS と PWA、TS-Live! を使う場合は上流の手順に従って証明書と HTTPS ポートを設定してください。リモート視聴には別途トランスコーダーが必要です。EDCB 本体は既に Lua 5.2 にリンクし、実行時にも Nix store 内の Lua ライブラリを参照します。

個別 module も直接利用できます。詳しい option は `nixos-option services.mirakurun`、`services.edcb`、`services.konomitv`、`hardware.dtv.px4_drv` を参照してください。

## BonDriver と Mirakurun の互換性

BonDriver_LinuxMirakc upstream は Mirakurun では未テストと明記しています。ドライバー自体の既定値は HTTP `127.0.0.1:40772`、`SERVICE_SPLIT=0` です。このmoduleはBonDriverのINIへ既定値を追加しません。実機でチューニング、連続受信、長時間録画を確認してください。VM test は module の配線と lifecycle を検証するもので、放送波や実機の検証を代替しません。

## 検証

```console
nix flake check
nix build .#checks.x86_64-linux.integration
nix build .#mirakurun
nix build .#recisdb
nix build .#isdb-scanner
nix build .#edcb
nix build .#edcb-material-webui
nix build .#bondriver-linux-mirakc
```

px4_drv は実際に利用する NixOS kernel に対して module 経由でビルドされます。自動評価や VM test だけでは USB 抜去、複数 tuner、TS drop、長時間録画を検証できません。

### EDCB INI の既存値とのマージ

`services.edcb` 直下の `settingsImmutable`、`commonSettingsImmutable`、
`epgDataCapBonSettingsImmutable`、`recNameMacroSettingsImmutable` は既定値 `true` です。
`true` なら生成した INI を Nix store への読み取り専用リンクとして配置します。
`false` なら NixOS activation（構成の適用時・OS 起動時）に既存 INI と Nix 定義を
マージし、edcb:edcb 所有の通常ファイル（UTF-8、BOMなし、mode 0640）として配置します。
EDCB のサービス再起動では再マージしません。

同じセクション・キーは Nix 定義（モジュールの補完値を含む）を優先し、
それ以外の既存値は保持します。ファイルがなければ Nix 定義から作成します。
Nix 定義から削除したキーも既存ファイルに残っていれば保持します。
既存ファイルのコメントや書式は保持しません。設定本体が `null` なら管理対象外です。
設定値の外に配置方式のオプションを置く、Home Manager の Zed と同様の形式です。

```nix
services.edcb = {
  settingsImmutable = false;
  settings.SET.SaveLog = 1;
};
```
