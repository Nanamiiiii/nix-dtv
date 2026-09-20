# nix-dtv project context

この文書は、新しい agent や session がリポジトリの現状と設計意図を短時間で把握するための handoff document です。実装を変更したときは、README と併せてこの文書も更新してください。

## 目的

`Nanamiiiii/nix-dtv` は、日本の DTV 環境を system-level の Nix package と NixOS module で宣言的に構築するリポジトリです。Home Manager は使用しません。

想定するデータフローは次の通りです。

```text
physical tuner
  -> px4_drv
  -> /dev/px4video* (root:video, 0664)
  -> Mirakurun (mirakurun user, video supplementary group)
  -> BonDriver_LinuxMirakc.so over localhost HTTP
  -> EDCB / EpgTimerSrv (edcb user)
  -> recording directory (RW, dtv group, setgid)
  -> KonomiTV official OCI image (recordings are RO)
```

## 現在の構成

- 対応 system は `x86_64-linux` と `aarch64-linux`。
- overlay は全 package を `pkgs.nix-dtv` 以下に公開する。
- flake package の default は Mirakurun。
- package:
  - `px4_drv`
  - `mirakurun`
  - `recisdb`
  - `isdb-scanner`
  - `edcb`
  - `edcb-material-webui`
  - `bondriver-linux-mirakc`
- NixOS module:
  - `nixosModules.default`: 全 module を import する統合入口
  - `nixosModules.dtv`: `services.dtv` convenience layer
  - `nixosModules.px4_drv`: `hardware.dtv.px4_drv`
  - `nixosModules.mirakurun`: `services.mirakurun`
  - `nixosModules.bondriver`: `hardware.dtv.bondriver`
  - `nixosModules.edcb`: `services.edcb`
  - `nixosModules.konomitv`: `services.konomitv`

主なファイル:

```text
flake.nix
pkgs/default.nix
pkgs/{px4_drv,mirakurun,recisdb,isdb-scanner,edcb,edcb-material-webui,bondriver-linux-mirakc}/default.nix
modules/{default,dtv,px4_drv,bondriver,mirakurun,edcb,konomitv}.nix
tests/{default,module-eval,mirakurun,edcb,integration}.nix
```

## package の固定値と方針

2026-09-14 時点の固定値です。

| package | version / revision | 方針 |
| --- | --- | --- |
| px4_drv | `0.5.6-unstable-2026-07-26`, `9eedea8c502875a788697984b93b50032339b9aa` | `tsukumijima/px4_drv` を対象kernelでbuild |
| Mirakurun | `4.1.3`, `5770073e9b30d523512858ca82f45386f51a08fd` | Node.js 22 native package。Dockerは使わない |
| recisdb | `1.2.4-unstable-2026-08-22`, `d4210d1540d3003c23d7138357a1e4b91794e767` | default branchの最新commitを固定するunstable package |
| ISDBScanner | `1.3.3` / tag `v1.3.3` | GitHubの最新releaseを固定 |
| EDCB | `work-plus-s-2026-09-04`, `ebf50c730ccf8c1732e0bd8a4e2a3417a94d9b2b` | `Document/Unix/Makefile` に基づくLinux native build |
| EDCB Material WebUI | `3-unstable-2026-09-19`, `10e376a48f8dc0f01cd80cf299fcc2424ac56c35` | E3 branch の `E3`、`api`、`Setting` を固定し、INI は CP932 から UTF-8 に変換 |
| BonDriver_LinuxMirakc | `0-unstable-2024-10-14`, `cfbefc6d21dab4009db5f124984c1b720b76d869` | picojsonも固定しnative `.so` をbuild |

recisdb は submodule の libaribb25 を含め、`dvb` feature を有効にしてあります。したがって chardev と DVBv5 の両方に対応し、build/runtime dependency として CMake、bindgen、pcsc-lite、v4l-utils が必要です。

ISDBScanner は上流sourceをPythonで実行し、次をNix closureに含めています。

- 上流指定の ariblib 0.1.4 wheel
- Python dependencies
- recisdb
- lsof

`nix run .#isdb-scanner -- --version` のように単独で実行でき、recisdb の別途installは不要です。

## NixOS module の重要な設計

### services.dtv

- `services.dtv.recordingDir` のdefaultは `/mnt/tv/recordings`。
- `services.dtv.recordingGroup` のdefaultは短い `dtv`。以前の案にあった `tv-recordings` は使わない。
- recording directory は `root:dtv`, mode `2770` で作る。group名を変更した場合も同じ値をEDCBへ伝播する。
- `services.dtv.{px4_drv,mirakurun,edcb,konomitv}.enable` から個別moduleを有効化する。

### px4_drv

- 実際の `config.boot.kernelPackages` に対してbuildする。
- kernel module、firmware、udev ruleをpackageから登録する。
- upstreamと同じくdevice permissionは `root:video`, mode `0664`。least privilegeとしての`0660`化は将来検討であり、現在は変更しない。

### Mirakurun

- nixpkgs標準の同名moduleを使い、このリポジトリのmoduleは最新版packageの直接起動とtuner commandのservice `PATH`だけを追加する。
- nixpkgs標準packageは3.9.0-rc.4のため使わず、このリポジトリで固定するMirakurun 4.1.3を `services.mirakurun.package` のdefaultにする。4.xは従来の `mirakurun start` CLIを削除したため、systemdはpackageの直接起動wrapperを呼ぶ。
- native serviceは `mirakurun:video` で実行する。nixpkgs標準moduleの `allowSmartCardAccess` とpolkit ruleを利用し、カードリーダー利用時は `security.polkit.enable = true` と `services.pcscd.enable = true` を指定する。
- `server.yml` はNixで生成する。`tunerSettings` と `channelSettings` はdefaultの `null` なら `/etc/mirakurun` にランタイム生成でき、チャンネルスキャン結果は宣言的管理しない。
- mutable DB/logoは `/var/lib/mirakurun`、socketはdefaultで `/var/run/mirakurun/mirakurun.sock`。
- `services.mirakurun.tunerCommandPackages` のdefaultはrecisdb。systemd serviceの`PATH`へ追加されるため、`tuners.yml`では `recisdb tune ...` と書ける。
- recisdb以外のcommandを使う場合は `tunerCommandPackages` へpackageを明示する。
- recpt1はpackage化していない。

### EDCB / BonDriver

- EDCBはWineではなくLinux nativeのEpgTimerSrvを `edcb:edcb` で実行する。
- immutable binaryと`.so`はNix store、mutable settings/stateは `/var/lib/edcb`。BonDriverは `hardware.dtv.bondriver.<name>` の `package`、実バイナリへの絶対パス `driverPath`、`settings`、`settingsFile` で定義する。`settingsFile` は既定値 `null`。指定されたファイルへのリンクをEDCB側で配置し、`settings` より優先する。両方 `null` ならINIは管理しない。`mirakc` は同梱ドライバーの定義。EDCBは `services.edcb.bondriver` の文字列リストで選択された定義だけを配置する。本体は `driverPath` のbasenameで `/var/lib/edcb/lib` にリンクし、INIは隣に `<basename>.ini` として配置する。未定義の名前と選択ドライバーのbasename重複を検出する。
- `services.edcb.bondriver` の既定値は空リスト。`services.dtv` の標準構成では `[ "mirakc" ]` を選択する。
- EDCB userはrecording group `dtv` にだけ追加する。
- recording directory以外へ広いwrite権限を与えない。
- `EpgTimerSrv.ini`, `Common.ini`, `EpgDataCap_Bon.ini`, `RecName_Macro.so.ini` と `hardware.dtv.bondriver."<driver name>".settings` の設定optionはdefaultを `null` とし、明示された `<driver name>.ini` だけUTF-8（BOMなし）でNixから生成する。未指定ならEDCBが生成したmutable fileを使う。`Bitrate.ini` と `BonCtrl.ini` は上流サンプルを初回だけmutableな設定として配置し、既存ファイルを上書きしない。
- EpgTimerSrvをNix管理する場合はsystem clock変更を無効にする `TimeSync=0`、loopback限定TCP `4510`、KonomiTV互換用 `CompatFlags=128` を補完する。選択したBonDriverには同時利用数1を補完し、ホスト設定で変更できる。時刻同期はsystemd-timesyncdやchronyへ任せる。
- BonDriverのINI設定にはドライバー別の値を補完しない。BonDriver_LinuxMirakc自体の既定接続先はHTTP `127.0.0.1:40772`。recisdbが既定でB25処理するため `DECODE_B25` は書かず、上流既定値の0を使う。
- `services.edcb.settings` が非 `null` なら、`services.edcb.bondriver` の選択順（同名の重複は最初だけ）から `[TVTEST]` の `Num` と0始まりの番号キー、および各 `driverPath` のbasenameをセクション名にした `Count=1`, `GetEpg=1`, `EPGCount=1`, `Priority=0,1,…` を補完する。空リストでは `TVTEST.Num=0`、ドライバー別セクションなし。明示した `services.edcb.settings` の同じキーを優先し、`settings = null` は引き続きINIを管理しない。mutableマージでもこれらの補完値はactivation時に適用する。
- EPG取得時刻、録画方針、ログなどの環境固有値はホスト設定で指定する。チューナー数の初期値1は実機構成に合わせて上書きする。
- BonDriver_LinuxMirakc upstreamはMirakurun互換性を未テストとしている。warningを消さず、実機で長時間録画を検証する。

### EDCB Material WebUI

- `services.edcb.materialWebUI.enable` は既定で `false`。有効時、固定した E3 package の `HttpPublic/E3` と `HttpPublic/api` を `/var/lib/edcb/HttpPublic` 以下にリンクする。
- 無効化した場合は managed な `E3` と `api` の store link だけを削除し、mutable な設定ファイルは残す。
- 上流のディレクトリ名は `Setting`（単数）。`Setting/HttpPublic.ini` と `Setting/XCODE_OPTIONS.lua` は `/var/lib/edcb/Setting` に初回だけ mutable なファイルとしてコピーし、既存値を上書きしない。INI は CP932 から UTF-8（BOMなし）に変換する。
- HTTP サーバーは `services.edcb.settings` を非 `null` にしたときに補完される `EnableHttpSrv=1` で有効になる。E3 の利用例では `HttpNumThreads=50` を明示する。標準ポートは `5510`、アクセス制御は EDCB の loopback 既定値を使う。
- EDCB package は Lua 5.2 を build input に含め、Lua ライブラリへの rpath を設定済み。WebUI 用に別の Lua interpreter は不要。E3 側には未設定の `NVRAM.ZIP` を連結すると失敗するため、空値を許す最小 patch を適用。
- HTTPS/PWA/TS-Live! には証明書と HTTPS port、リモート視聴にはトランスコーダーが別途必要。

### KonomiTV

- native package化せず、公式 `ghcr.io/tsukumijima/konomitv:latest` をNixOSの`virtualisation.oci-containers`とDocker backendで起動する。
- host networkを使用する。
- `config.yaml` はNixから生成してread-only mountし、Web UIでのserver config変更をsource of truthにしない。
- `backend`、`streamFromMirakurun`、`edcbUrl`、`mirakurunUrl`、`encoder`、`serverPort` と各directory optionから `config.yaml` の主要項目を生成する。`extraSettings` はその他の項目を追加し、専用optionと同じキーでは専用optionを優先する。
- `recordingDir` と `captureDir` は文字列リスト。録画directoryはすべてread-only mountし、capture directoryはすべてread-write mountする。data/logsもread-write mountする。
- `encoder = "QSVEncC"` または `"VCEEncC"` では `/dev/dri/` をcontainerへ渡す。`"NVEncC"` では全NVIDIA GPUを `compute,utility,video` capability付きで渡し、`hardware.nvidia-container-toolkit.enable` を既定で有効にする。`"FFmpeg"` ではGPUを自動追加しない。`devices` は追加device用。
- `services.dtv.recordingDir` はKonomiTVの `recordingDir` に1要素のリストとして伝播する。
- upstream imageとの互換性を優先し、containerは現在rootで実行する。

## 既存Docker版Mirakurun設定との互換性

比較に使用した既存設定はrepo外の次のファイルです。

```text
/home/myuu/Downloads/docker-mirakurun-epgstation/mirakurun/conf/channels.yml
/home/myuu/Downloads/docker-mirakurun-epgstation/mirakurun/conf/tuners.yml
/home/myuu/Downloads/docker-mirakurun-epgstation/mirakurun/conf/server.yml
```

確認済み事項:

- 有効なtunerは `recisdb tune --device ... --channel <channel> -` を使っており、そのまま互換。
- 無効化されたrecpt1 tuner定義が残っているが、`isDisabled: true` のためrecpt1をpackage化しなくても動作上の問題はない。
- 地上波の `T13`〜`T27`、BSの `BS01_0` 形式、CSの `CS2` 形式はrecisdbが受理する。
- `server.yml` のport `40772` はmodule defaultと一致する。
- 既存の `/var/run/mirakurun.sock` は通常 `/run/mirakurun.sock` と同義だが、新構成ではdefaultの `/run/mirakurun/mirakurun.sock` を使う。古いsocket pathを必要とするconsumerがないか移行時に確認する。
- Docker container固有の `hostname` はNixOS移行時にそのまま持ち込まず、必要性を確認する。

設定内容はNixの `services.mirakurun.serverSettings`, `tuners`, `channels` へ移す。YAMLをmutable fileとして直接管理しない。

## 検証状況

2026-09-13 時点で次を確認済みです。

- recisdbのx86_64-linux build成功、`recisdb --version` は`1.2.4`。
- ISDBScannerのx86_64-linux build成功、`isdb-scanner --version` は`1.3.3`。
- `nix flake check`成功。
- Mirakurun module VM testでservice起動、generated environment、recisdbを含むservice PATHを確認。
- EDCB module VM test成功。
- native Mirakurun API `40772`とEDCB TCP `4510`を同時に起動するintegration VM test成功。
- `nix flake check --all-systems --no-build`でaarch64-linuxを含む全outputの評価成功。

標準の確認command:

```console
nix fmt
nix flake check
nix flake check --all-systems --no-build
nix build .#recisdb
nix build .#isdb-scanner
nix build .#edcb-material-webui
nix build .#checks.x86_64-linux.integration
```

## 未検証・次に必要なこと

VMでは代替できないため、実機で次を確認する必要があります。

- px4_drvでの各tuner device生成とudev ownership
- recisdbによるchardev/DVBv5の選局
- B-CAS readerとpcscd経由のdecode
- 地上波・BS・CSのchannel scan
- Mirakurunから複数tunerを同時利用した際の排他制御
- EDCB/BonDriver経由の連続受信、予約録画、長時間録画
- TS drop、USB抜去・再接続、service restart後の復旧
- KonomiTVからのライブ視聴と録画ファイル読み取り

## 変更時の原則

- upstream sourceの変更は避け、Nix store/runtime path適合に必要な最小patchだけを使う。
- package更新時はrevision/tagとsource hash、Cargo/npm/Python dependency hashを固定する。
- recisdbはunstable方針、ISDBScannerはlatest release方針を維持する。
- packageとmutable stateを混在させない。
- serviceをroot実行へ戻さない。例外は現在の公式KonomiTV containerだけ。
- recording directory以外のwrite範囲を安易に広げない。
- public optionやdefaultを変更したらmodule-eval testとREADMEも更新する。
- packageを追加・更新したら`tests/default.nix`のflake check対象に含める。
- hardwareがなくてもpackage build、module evaluation、VM testまでは必ず実行する。

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
