# KonomiTV
KonomiTVは[こちら](./2_packages.md#konomitvについて)の理由から，Nixでパッケージングをせず，公式配布のDockerコンテナをsystemd serviceとして稼働させる形態をとっている．

デフォルトでは最新ビルドを取得するため，`ghcr.io/tsukumijima/konomitv:latest` を指定している．より厳密にrevisionを管理したい場合は，Manifest Hashの指定を推奨する．

KonomiTVで配布されている `docker-compose.yaml` のサンプルではホストrootfsを丸ごと`/host-rootfs`以下にマウントしているが，実際は録画・キャプチャディレクトリのみがマウントされていれば問題無い．

データ・ログはデフォルトで `/var/lib/konomitv` 以下に入るようにvolume mountを設定している．

yaml設定ファイルはNix Store配置のファイルを直接volume mountする．

## コンテナイメージの指定
以下のようにManifest Hash指定が可能．
```nix
{
  services.konomitv.image = "ghcr.io/tsukumijima/konomitv@sha256:956d4f53de003f4cb35522986236f583c94f6e475b6c3a88c089f6da5682cfd6";
}
```

`latest` タグ指定の場合，イメージ更新は手動で `docker pull` を行う必要がある．

## 各種ディレクトリの設定
```nix
{
  services.konomitv = {
    # 録画ディレクトリ 読み取り専用でマウントされる
    recordingDir = [
      "/mnt/tv/recordings"
    ];
    
    dataDir = "/var/lib/konomitv/data"; # データディレクトリ
    logDir = "/var/lib/konomitv/logs"; # ログディレクトリ
    
    # 画面キャプチャの保存先
    captureDir = [
      "/mnt/tv/captures"
    ];
  };
}
```

画面キャプチャ保存先ディレクトリがリモートマウントで，UID:GIDやパーミッションの扱いが通常と異なる場合，EDCB同様に `manageCaptureDirs = false` を指定して権限操作をスキップする．
```nix
{
  services.konomitv.manageCaptureDirs = false;
}
```

## チューナーバックエンド
メインの接続先として `EDCB` or `Mirakurun` を指定する．
```nix
{
  services.konomitv.backend = "Mirakurun";
}
```

録画でEDCBを使い，視聴ではMirakurunを使用するパターンでは，backendに `EDCB` を指定して `streamFromMirakurun = true` とする．
```nix
{
  services.konomitv.streamFromMirakurun = true;
}
```

各バックエンドの接続先ホスト，ポートは次のように指定する．
```nix
{
  services.konomitv = {
    edcbHost = "127.0.0.1";
    edcbPort = 4510;
    mirakurunHost = "127.0.0.1";
    mirakurunPort = 40772;
  };
}
```

KonomiTVのyaml内ではURL指定のため，上記設定から次のパターンに従ってURLを生成する．
- EDCB: `tcp://<edcbHost>:<edcbPort>/`
- Mirakurun: `http://<mirakurunHost>:<mirakurunPort>/`

## エンコーダー
エンコーダーとして `FFmpeg`, `QSVEncC`, `NVEncC`, `VCEEncC` を指定可能．
`rkmppenc` は，そもそもRockchipがNixOSではCommunity Supportであり，ドライバ周りの対応が不明なため除外．

```nix
{
  services.konomitv.encoder = "NVEncC";
}
```

`encoder` の指定に応じて，コンテナへ渡すデバイスの指定やNVIDIA Container Toolkitを有効化を自動的に行う．

## KonomiTVへのアクセス
ポート番号とFirewallポートの開放設定が可能．

```nix
{
  services.konomitv = {
    serverPort = 7000;
    openFirewall = true;
  };
}
```

## 追加設定
Optionにない設定項目は `extraSettings` から追加する．

```nix
{
  services.konomitv.extraSettings = {
    general.program_update_interval = 5.0;
    video.exclude_scan_paths = [ ];
  };
}
```
