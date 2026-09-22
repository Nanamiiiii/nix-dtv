# EDCB
`xtne6f`版のLinuxビルドをパッケージングしている．`make extra` でビルドされるサードパーティーツールに関しても個別にパッケージングし，EDCBの実行時パスに追加している．

オリジナルの状態では，EDCBは以下のディレクトリを使用するようにハードコードされている．
- バイナリインストール先: `/usr/local/bin`
- 設定ファイル群: `/var/local/edcb`
- ランタイムライブラリのロードパス: `/usr/local/lib/edcb` 

これらはNixの構成と親和性がないため，以下のように変更している．
- 各バイナリは `edcb` パッケージの `$out/bin` に配置
- 設定ファイルの読み込み元は `/var/lib/edcb` (`EDCB_INI_ROOT`)
- ライブラリロードパスは `/var/lib/edcb/lib` (`EDCB_LIB_ROOT`)

Nixで管理するランタイムライブラリは，activationの段階でロードパスへsymlinkが張られる．

## 設定ファイル
Nixで管理可能な設定ファイルは以下．
- `EpgTimerSrv.ini`
- `Common.ini`
- `EpgDataCap_Bon.ini`

EDCBの各種設定は非常に項目数が多く，GUIからの制御を前提とするところがあるため，完全にNixで管理してしまうのは望ましくない．
一方でNixから一部の項目のみを宣言的に入れ込む需要は少なからずあるとも考えられる．

そこで，既存の設定に対してNix側で定義したものをマージするのみにとどめ，Mutableなファイルとして扱う設定をデフォルトとしている．
WebUIなどを経由して調整した後，運用が安定したらImmutableに切り替え，完全にNix管理とすることも可能．

設定値を `null` とすることで，逆にNixからは何も生成しない構成をとることも可能．しかし，録画ディレクトリなど他の設定項目から伝播する値も反映されなくなってしまうため非推奨．

### `EpgTimerSrv.ini`
```nix
{
  services.edcb.settings = {
    SET = {
      EnableHttpSrv = 1;
      HttpPort = 5510;
    };
  };
}
```

完全にNix管理下に置く場合，`settingsImmutable = true` を指定する．
```nix
{  
  services.edcb.settingsImmutable = true;
}
```

### `Common.ini`
```nix
{
  services.edcb.commonSettings = {
    SET = {
      BSBasicOnly = 1;
    };
  };
}
```

完全にNix管理下に置く場合，`commonSettingsImmutable = true` を指定する．
```nix
{  
  services.edcb.commonSettingsImmutable = true;
}
```

### `EpgDataCap_Bon.ini`
```nix
{
  services.edcb.epgDataCapBonSettings = {
    SET = {
      SaveDebugLog = 1;
      TraceBonDriverLevel = 2;
    };
    SET_TCP = {
      Count = 1;
      IP0 = 1;
      Port0 = 0;
    };
  };
}
```

完全にNix管理下に置く場合，`epgDataCapBonSettingsImmutable = true` を指定する．
```nix
{  
  services.edcb.epgDataCapBonSettingsImmutable = true;
}
```

## Plugin
`RecName_Macro.so` や `Write_Default.so` のようなプラグインの配置，設定iniの宣言的定義を行う．  
上記2プラグインはデフォルトで配置されているものだが，iniのみの定義も可能．

Pluginの設定は `EDCB_INI_ROOT` から読まれることを想定しており，それ以外の場所から読み出しを行うプラグインについては非対応．

```nix
{
  services.edcb.plugins = [
    # 既にEDCB_LIB_ROOTへ配置済みの場合はpluginPathを指定しない
    {
      name = "RecName_Macro.so";
      settings = {
        SET.Macro = "$ZtoH(Title)$.ts";
      };
    }

    # EDCB_LIB_ROOTへ新規追加する場合
    {
      pluginPath = "${pkgs.edcb}/lib/edcb/RecName_Macro.so";
      name = "RecName_Macro2.so"; # /var/lib/edcb/lib/RecName_Macro2.so に配置される．
      settings = {
        SET.Macro = "$ZtoH(Title2)$.ts";
      };
    }
  ];
}
```

## BonDriver
BonDriverの `EDCB_LIB_ROOT` への配置と，設定iniの宣言的定義を行う．また， `EpgTimerSrv.ini` へ必要な設定を組みこむ．

BonDriver固有のiniは，BonDriverの配置場所，つまり `EDCB_LIB_ROOT` から読み込まれることを想定している．
しかし，これはBonDriverの実装依存であり，異なる場所からロードするケースもあり得る．
現在は `BonDriver_LinuxMirakc` でのみ検証しており，他のBonDriverとの互換性は不明．

EDCBは，`EDCB_LIB_ROOT` へ配置された `BonDriver_*.so` といった名前のShared LibraryをBonDriverとして認識する．
その上で，チューナー数やEPG取得の設定，視聴用チューナーとしての指定を `EpgTimerSrv.ini` で行う必要がある．
ここまでを一括で行う．

```nix
{
  services.edcb.bondriver = [
    {
      # BonDriver名
      name = "BonDriver_LinuxMirakc.so";
      
      # BonDriverの実体
      driverPath = "${pkgs.bondriver-linux-mirakc}/lib/BonDriver_LinuxMirakc.so";
      
      # BonDriver固有設定 <name>.ini としてEDCB_INI_ROOTへ配置される
      # セクション，キー，値についてはBonDriver固有
      settings = {
        GLOBAL = {
          SERVER_HOST = "127.0.0.1";
          SERVER_PORT = config.services.mirakurun.port;
          DECODE_B25 = 0; # decoded in mirakurun
          PRIORITY = 100;
          SERVICE_SPLIT = 0;
        };
      };
      
      # EpgTimerSrvでのチューナー設定
      # EpgTimerSrv.ini の [BonDriver_LinuxMirakc.so] セクションへ追加される
      tunerSettings = {
        Count = 4;
        GetEpg = 1;
        EPGCount = 2;
      };
    }
  ];
}
```

ここで定義したBonDriverについて，視聴用としての指定を `EpgTimerSrv.ini` の `[TVTEST]` セクションに追加する．
```ini
[TVTEST]
Num=1
0=BonDriver_LinuxMirakc.so
```

## 録画ディレクトリ
`recordingDir`で録画ディレクトリを設定する．ここで設定されたディレクトリは `Common.ini` の `RecFolderPath[0-9]+` へ追加される．  
また，`edcb` グルーブへ書き込み権限が付与される．

```nix
{
  services.edcb.recordingDir = [
    "/mnt/tv/recording"
  ];
}
```

録画ディレクトリがNFSやSMBのようなリモートマウントで，UID:GIDの扱いが通常と異なる場合，権限操作が正常に動作しない可能性がある．このようなケースでは，`manageRecordingDirs = false` を指定することで権限操作をスキップできる．

```nix
{
  services.edcb.manageRecordingDirs = false;
}
```

## ポート設定
視聴アプリケーションとのやりとりに使うTCPポート番号，WebUI用のHTTP/HTTPSポート番号を設定する．

```nix
{
  services.edcb = {
    tcpPort = 4510;
    httpPorts = [ 5510 5520 ];
    httpsPorts = [ 5511 5521 ];
  };
}
```

Firewallでlocalhost以外からの上記ポートへのアクセスを許可する場合，`openFirewall = true` とする．

```nix
{
  services.edcb.openFirewall = true;
}
```

## Web UI
内蔵のLegacy WebUIに加え，[EDCB Material WebUI](https://github.com/EMWUI/EDCB_Material_WebUI) を導入可能．

EWMUI3はTS-Live!によるリアルタイム視聴を備えているが，SecureContextを必要とするためHTTPS対応(オレオレでもOK)が必要．
そのため，有効時に証明書が存在しなければ，自己署名証明書を自動生成するように実装している．

合わせて追加でHTTP/HTTPSポートをリッスンする必要があり，こちらの設定も上書きしない限り連動する．

```nix
{
  services.edcb.materialWebUI = {
    enable = true;

    # 必要に応じて自己署名証明書へSubjectAltNameを追加できる
    extraCertificateSubjectAltNames = [
      "DNS:tv.example.com"
      "IP:192.168.50.10"
    ];
  };
}
```

`EpgDataCap_Bon.ini` で `SrvPipe` を有効にすることで，TS-Live!によるリアルタイム視聴が可能であることを確認済み．
