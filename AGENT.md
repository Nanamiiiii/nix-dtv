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
  - `bondriver-linux-mirakc`
- NixOS module:
  - `nixosModules.default`: 全 module を import する統合入口
  - `nixosModules.dtv`: `services.dtv` convenience layer
  - `nixosModules.px4_drv`: `hardware.px4_drv`
  - `nixosModules.mirakurun`: `services.mirakurun`
  - `nixosModules.edcb`: `services.edcb`
  - `nixosModules.konomitv`: `services.konomitv`

主なファイル:

```text
flake.nix
pkgs/default.nix
pkgs/{px4_drv,mirakurun,recisdb,isdb-scanner,edcb,bondriver-linux-mirakc}/default.nix
modules/{default,dtv,px4_drv,mirakurun,edcb,konomitv}.nix
tests/{default,module-eval,mirakurun,edcb,integration}.nix
```

## package の固定値と方針

2026-09-13 時点の固定値です。

| package | version / revision | 方針 |
| --- | --- | --- |
| px4_drv | `0.5.6-unstable-2026-09-09`, `16ba2eefae6b0bb0ca21bebc17ecd1aa7894ab3f` | `Nanamiiiii/px4_drv` を対象kernelでbuild |
| Mirakurun | `4.1.3`, `5770073e9b30d523512858ca82f45386f51a08fd` | Node.js 22 native package。Dockerは使わない |
| recisdb | `1.2.4-unstable-2026-08-22`, `d4210d1540d3003c23d7138357a1e4b91794e767` | default branchの最新commitを固定するunstable package |
| ISDBScanner | `1.3.3` / tag `v1.3.3` | GitHubの最新releaseを固定 |
| EDCB | `work-plus-s-2026-09-04`, `ebf50c730ccf8c1732e0bd8a4e2a3417a94d9b2b` | `Document/Unix/Makefile` に基づくLinux native build |
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
- upstream forkと同じくdevice permissionは `root:video`, mode `0664`。least privilegeとしての`0660`化は将来検討であり、現在は変更しない。

### Mirakurun

- nixpkgs標準の同名moduleはdisableし、このリポジトリのmoduleだけを使う。
- native packageを `mirakurun:mirakurun` で実行し、supplementary groupはdefaultで`video`。
- `server.yml`, `tuners.yml`, `channels.yml` は `pkgs.formats.yaml` で生成し、Nix storeをsource of truthにする。
- mutable DB/logoは `/var/lib/mirakurun`、socketはdefaultで `/run/mirakurun/mirakurun.sock`。
- `services.mirakurun.tunerCommandPackages` のdefaultはrecisdb。systemd serviceの`PATH`へ追加されるため、`tuners.yml`では `recisdb tune ...` と書ける。
- recisdb以外のcommandを使う場合は `tunerCommandPackages` へpackageを明示する。
- recpt1はpackage化していない。

### EDCB / BonDriver

- EDCBはWineではなくLinux nativeのEpgTimerSrvを `edcb:edcb` で実行する。
- immutable binaryと`.so`はNix store、mutable settings/stateは `/var/lib/edcb` に分離する。
- EDCB userはrecording group `dtv` にだけ追加する。
- recording directory以外へ広いwrite権限を与えない。
- `EpgTimerSrv.ini`, `Common.ini`, `EpgDataCap_Bon.ini`, `RecName_Macro.so.ini`, `BonDriver_LinuxMirakc.so.ini` はUTF-8（BOMなし）でNixから生成する。
- EDCBのsystem clock変更機能はdefaultで `TimeSync=0`。時刻同期はsystemd-timesyncdやchronyへ任せる。
- EpgTimerSrvのdefaultはloopback限定TCP `4510`、KonomiTV互換用 `CompatFlags=128`、BonDriver同時利用数1に絞る。
- BonDriverのdefault接続先はHTTP `127.0.0.1:40772`。recisdbが既定でB25処理するため `DECODE_B25` は書かず、上流既定値の0を使う。
- EPG取得時刻、実チューナー数、録画方針、ログなどの環境固有値はmodule defaultに含めず、ホスト設定で指定する。
- BonDriver_LinuxMirakc upstreamはMirakurun互換性を未テストとしている。warningを消さず、実機で長時間録画を検証する。

### KonomiTV

- native package化せず、公式 `ghcr.io/tsukumijima/konomitv:latest` をNixOSの`virtualisation.oci-containers`とDocker backendで起動する。
- host networkを使用する。
- `config.yaml` はNixから生成してread-only mountし、Web UIでのserver config変更をsource of truthにしない。
- recording directoryはread-only mount。capture/data/logsだけをread-write mountする。
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
