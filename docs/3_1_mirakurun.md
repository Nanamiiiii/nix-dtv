# Mirakurun
`services.mirakurun` は既にnixpkgsの上流に取り込まれており，基本的な設定が可能となっている．
`nix-dtv`では上流の定義を流用しつつ，一部項目を追加した．

設定ファイル群は `/etc/mirakurun`，ランタイムデータ (DB等) は `/var/lib/mirakurun` に配置される．

## サーバー設定
 Nixによって `server.yml` が生成される．設定項目は [こちら](https://github.com/Chinachu/Mirakurun/blob/master/doc/Configuration.ja.md#%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC%E8%A8%AD%E5%AE%9A%E4%B8%80%E8%A6%A7) を参照．

主要ないくつかの設定項目はoptionとして定義されている．それ以外は，`serverSettings` に記載することでyamlに追記される．

```nix
{
  services.mirakurun = {
    logLevel = 2;
    unixSocket = "/var/run/mirakurun/mirakurun.sock";
    port = 40772;

    serverSettings = {
      hostname = "tv.example.com";
      allowIPv4CidrRanges = [
        "172.16.0.0/24"
      ];
    };
  };
}
```

## チューナー設定
デフォルトではチューナー設定の `tuners.yml` はNix管理外 (`null`) となっているが，Nixで宣言的に管理することもできる．
以下はchardevチューナーデバイスを `recisdb` で扱う一例．

```nix
{
  services.mirakurun.tunerSettings = [
    {
      name = "PX4-S1";
      types = [ "GR" ];
      command = "recisdb tune --device /dev/px4video0 --channel <channel><satellite>-";
    }
  ];
}
```

ここで使用するチューナーコマンドはMirakurunから見えている必要がある．
`nix-dtv` では新たに `tunerCommandPackages` を定義し，チューナーコマンドを含むパッケージを指定可能にした．
ここで指定したパッケージは，Mirakurun実行時のパスに追加される．
デフォルトでは `recisdb` を含んでいる．

```nix
{
  services.mirakurun.tunerCommandPackages = [
    pkgs.recisdb
  ];
}
```

## チャンネル設定
チャンネル設定の `channels.yml` もデフォルトではNixの管理外 (`null`) だが，同様にNixでの宣言的な管理も可能．

```nix
{
  services.mirakurun.channelSettings = [
    {
      name = "NHK総合・東京";
      type = "GR";
      channel = "T27";
    }
  ];
}
```

全てのチャンネルを手書きするのは現実的ではないと思われる．そこで生成済みのyamlをjsonに変換し，Nixで読み込むという方法も考えられる．

```nix
{
  services.mirakurun.channelSettings = builtins.fromJSON (builtins.readFile ./channels.json);
}
```
