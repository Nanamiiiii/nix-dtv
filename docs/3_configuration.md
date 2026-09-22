# Configuration
`nix-dtv`は以下のNixOS Optionsを定義します．

- `services.dtv`
  - DTV環境の共通設定
- `services.mirakurun`
  - Mirakurunの設定
  - 上流のnixpkgsに取り込まれているもの + α
- `services.edcb`
  - EDCBの設定
- `services.konomitv`
  - KonomiTVの設定
  - oci-container定義で公式配布のDockerイメージを使用
- `hardware.px4_drv`
  - アクティブなカーネルへの`px4_drv`のインストール

ここでは，基本的なOptionの利用方法を説明します．各Optionの型・デフォルト値・説明は，[Options Reference](./options.md) を確認してください．

## 共通設定
### DTVスタックの有効化
全体として必要な設定を一括で行う．
```nix
{
  services.dtv.enable = true;
}
```
- 共通の録画ディレクトリ指定の適用
- 録画ディレクトリの所有グループ設定
- スマートカードリーダーの利用設定

### 各種サービスの有効化
各種サービスにスタック共通設定を入れ込みます．
```nix
{
  services.dtv = {
    px4_drv.enable = true;
    mirakurun.enable = true;
    edcb.enable = true;
    konomitv.enable = true;
  };
}
```
- `px4_drv`
  - `hardware.px4_drv`を有効にし，アクティブなカーネル向けにビルドする
- `mirakurun`
  - Firewall Port開放設定の伝播
- `edcb`
  - 録画ディレクトリ・グループの設定の伝播
  - Firewall Port開放設定の伝播
- `konomitv`
  - 録画ディレクトリ設定の伝播
  - Firewall Port開放設定の伝播
  - 有効なサービスに応じたバックエンド設定の自動選択
  - 接続先ポートの連動

### Firewall Portの開放
各種サービスへlocalhost以外からアクセスするために，Firewallを一括で設定します．
```nix
{
  services.dtv.openFirewall = true;
}
```

### 録画ディレクトリの設定
EDCB, KonomiTVで使用する録画ディレクトリを指定します．
```nix
{
  services.dtv.recordingDir = [
    "/mnt/tv/recording"
    "/mnt/tv/recording-2"
  ];
}
```

### 録画ディレクトリの所有者グループ名の設定
録画ディレクトリの所有グループには書き込み権限が付与されます．
```nix
{
  services.dtv.recordingGroup = "dtv";
}
```

## 各サービスの設定
- [Mirakurun](./3_1_mirakurun.md)
- [EDCB](./3_2_edcb.md)
- [KonomiTV](./3_3_konomitv.md)
