# Getting Started

## Prerequisite
- NixOSをインストールしている
- 受信に必要なチューナー・B-CASカード・カードリーダーが接続されている
  - 現状，ドライバは`px4_drv`のみを同梱しています．こちらに対応するチューナーが対象です．
  - 他のドライバに関しても，独自にパッケージングして導入できれば動作はすると思います．
    - Issue/PRは歓迎します．

## Quick Start
px4_drv + Mirakurun + EDCB + KonomiTV が連携動作する最小構成の一例．  
作者の構成例は[こちら](https://github.com/Nanamiiiii/dotfiles/blob/main/profiles/mafu/dtv.nix).

### モジュールの導入
nix flakesの使用を前提としています．`niv`や`fetchTarball`を使用することも可能かと思いますが，未検証のためここでは言及しません．

```nix
{
  inputs = {
    nix-dtv = {
      url = "github:Nanamiiiii/nix-dtv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { nixpkgs, nix-dtv, ... }: {
    nixosConfigurations.tv-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nix-dtv.nixosModules.default
      ];
    };
  };
}
```

### 設定
`configuration.nix`で必要な設定をします．

```nix
{ config, pkgs, ... }:
{
  # px4_drvに含まれるファームウェアのため
  nixpkgs.config.allowUnfree = true;

  services.dtv = {
    # DTV環境の共通設定有効化
    enable = true;

    # 録画ディレクトリの指定
    # EDCB, KonomiTVで共通して使用されます
    recordingDir = [
      "/mnt/tv/recordings"
      "/mnt/tv/archive"
    ];

    # px4_drvの有効化
    px4_drv.enable = true;

    # Mirakurunの有効化
    mirakurun.enable = true;

    # EDCBの有効化
    edcb.enable = true;
    
    # KonomiTVの有効化
    konomitv.enable = true;
  };

  # Mirakurunの設定
  services.mirakurun = {
    # チューナーとチューナーコマンドの設定
    tunerSettings = [
      {
        name = "PX4-S1";
        types = [ "GR" ];
        command = "recisdb tune --device /dev/px4video0 --channel <channel> -";
      }
    ];
  };

  services.edcb = {
    # BonDriverの設定
    # ここで定義したBonDriverとその設定がEDCBのLibrary Load Pathに配置されます．
    bondriver = [
      {
        name = "BonDriver_LinuxMirakc.so";
        driverPath = "${pkgs.bondriver-linux-mirakc}/lib/BonDriver_LinuxMirakc.so";
        settings = {
          GLOBAL = {
            SERVER_HOST = "127.0.0.1";
            SERVER_PORT = config.services.mirakurun.port;
            DECODE_B25 = 0;
            PRIORITY = 100;
            SERVICE_SPLIT = 0;
          };
        };
        tunerSettings.Count = 1;
      }
    ];

    # EDCB Material WebUIの有効化
    materialWebUI.enable = true;
  };

  services.konomitv = {
      # チューナーバックエンドの指定
      backend = "EDCB";
  
      # 視聴にMirakurunを使用する
      streamFromMirakurun = true;
  
      # スクリーンキャプチャの保存先指定
      captureDir = [ "/mnt/tv/capture" ];
  };
}
```

`nixos-rebuild --flake .#tv-server switch` で適用．必要があれば再起動後にドライバの動作を確認．

### チャンネル設定
チャンネル設定はデフォルトではNixの管理外にしているため，手動でスキャンを行ってください．Mirakurunはチューナーが正しく設定されていれば自身でスキャンを行うかもしれません．

#### ISDBScanner
Mirakurun用のチャンネルデータを生成できます．EDCB-Wineの設定も生成しますが，Native Linux環境のEDCBとBonDriverとの互換性は未検証です．
```bash
nix run github:Nanamiiiii/nix-dtv#isdb-scanner -- --list-tuners # チューナーを確認
nix run github:Nanamiiiii/nix-dtv#isdb-scanner
```

スキャンデータは `./scanned` に生成されます．
```bash
sudo -u mirakurun cp ./scanned/Mirakurun/channels.yml /etc/mirakurun/channels.yml
```

### EpgDataCap_Bon
EDCB用のチャンネルデータを生成します．BonDriverが正しく配置されていれば，以下でスキャン可能です．`EpgDataCap_Bon` は `services.edcb.enable = true` のときにシステムのパスに追加されます．BonDriverへのアクセスとスキャン結果の保存に必要な権限を持つ `edcb` ユーザーで実行してください．
```bash
# BonDriver_LinuxMirakcの場合
sudo -u edcb /run/current-system/sw/bin/EpgDataCap_Bon -d BonDriver_LinuxMirakc.so -chscan
```
