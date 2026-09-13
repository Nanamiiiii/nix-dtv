# nix-dtv

日本の DTV 環境向けの Nix package と NixOS module です。Home Manager や Docker 内でのチューナー制御は使わず、次の構成を system-level で宣言します。

```text
physical tuner -> px4_drv -> Mirakurun -> BonDriver_LinuxMirakc -> EDCB
                                                            -> recordings (RW)
                                                            -> KonomiTV (RO)
```

## 提供するもの

- `packages.<system>.px4_drv`: Nanamiiiii/px4_drv の kernel module、firmware、udev rule
- `packages.<system>.mirakurun`: Node.js 22 でビルドする native Mirakurun
- `packages.<system>.recisdb`: 最新 commit を固定した recisdb unstable（chardev / DVBv5、ARIB STD-B25 対応）
- `packages.<system>.isdb-scanner`: 最新 release を固定した ISDBScanner（recisdb を実行時依存に含む）
- `packages.<system>.edcb`: `Document/Unix/Makefile` を使う Linux native EDCB
- `packages.<system>.bondriver-linux-mirakc`: picojson を含む native BonDriver `.so`
- `overlays.default`: 上記を `pkgs.nix-dtv` 以下へ追加する overlay
- `nixosModules.{default,dtv,px4_drv,mirakurun,edcb,konomitv}`

px4_drv に含まれる udev rule は upstream fork と同じ `root:video`, mode `0664` です。

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
            recordingDir = "/mnt/tv/recordings";

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

`services.dtv.recordingDir` から EDCB の `Common.ini`、`dtv` group と setgid directory、KonomiTV の `video.recorded_folders` と read-only bind mount を導出します。既存環境で名前が競合する場合は `services.dtv.recordingGroup` で変更できます。

## 権限と状態

- Mirakurunはnixpkgs標準モジュールで `mirakurun:video` として動かし、このリポジトリでは最新版パッケージの直接起動とrecisdbのservice `PATH`だけを追加します。DBとlogoは `/var/lib/mirakurun`、ランタイム生成されるtuner/channel設定は `/etc/mirakurun` に置きます。
- EDCB は `edcb:edcb` で動き、`dtv` group だけを追加します。実行ファイルと `.so` の実体は Nix store、設定と状態は `/var/lib/edcb`、録画だけは指定した recording directory に書き込みます。
- `EpgTimerSrv.ini`、`Common.ini`、`EpgDataCap_Bon.ini`、`RecName_Macro.so.ini`、`BonDriver_LinuxMirakc.so.ini` は UTF-8（BOM なし）で Nix から生成します。追加設定はそれぞれ `services.edcb.settings`、`commonSettings`、`epgDataCapBonSettings`、`recNameMacroSettings`、`bonDriver.settings` で指定します。
- EDCB の既定値は、loopback限定のTCP接続、KonomiTV向けの `CompatFlags=128`、`TimeSync=0`、保守的なBonDriver同時利用数1、録画先、localhost上のMirakurun接続だけです。
- EPG取得時刻、実際のチューナー数、録画マージン、ファイル名、ログ、B25処理などは環境依存です。指定しない項目にはEDCBとBonDriverの上流既定値が使われます。
- recisdbは既定でB25処理を行うため、標準構成ではBonDriver側の `DECODE_B25` を設定しません。raw TSを出すチューナーコマンドとMirakurunのdecoderを使う場合だけ明示してください。
- EDCB の `TimeSync` は `0` のままにし、時刻同期は systemd-timesyncd や chrony に任せてください。
- KonomiTV は公式 `ghcr.io/tsukumijima/konomitv:latest` image を Docker backend と host network で起動します。upstream image の互換性を優先して container root のままです。
- KonomiTV の `config.yaml` は Nix store から read-only mount されます。Web UI で server config を永続変更せず、Nix の `services.konomitv.settings` を変更してください。
- KonomiTV には録画 directory を read-only、capture/data/logs だけを read-write mount します。ホスト root 全体は mount しません。

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

個別 module も直接利用できます。詳しい option は `nixos-option services.mirakurun`、`services.edcb`、`services.konomitv`、`hardware.px4_drv` を参照してください。

## BonDriver と Mirakurun の互換性

BonDriver_LinuxMirakc upstream は Mirakurun では未テストと明記しています。この repository の既定値は HTTP `127.0.0.1:40772`、`SERVICE_SPLIT=0` ですが、実機でチューニング、連続受信、長時間録画を確認してください。VM test は module の配線と lifecycle を検証するもので、放送波や実機の検証を代替しません。

## 検証

```console
nix flake check
nix build .#checks.x86_64-linux.integration
nix build .#mirakurun
nix build .#recisdb
nix build .#isdb-scanner
nix build .#edcb
nix build .#bondriver-linux-mirakc
```

px4_drv は実際に利用する NixOS kernel に対して module 経由でビルドされます。自動評価や VM test だけでは USB 抜去、複数 tuner、TS drop、長時間録画を検証できません。
