# nix-dtv
NixOS上で日本国内のDTV視聴・録画環境を構築するNixOS moduleとpackageを提供する．  
所謂TS抜き環境をNixOS上で比較的容易に構築できるようにするmoduleです．

> [!WARNING]
> Optionの構成は試行錯誤している段階ですので，頻繁に変更が入る可能性があります．

## Index
- [Why Nix?](./0_why-nix.md)
- [Getting Started](./1_getting_started.md)
- [Packages](./2_packages.md)
- [Configuration](./3_configuration.md)
  - [Mirakurun](./3_1_mirakurun.md)
  - [EDCB](./3_2_edcb.md)
  - [KonomiTV](./3_3_konomitv.md)
- [Options Reference](./options.md)

## 動作確認済み環境
以下の環境で px4_drv + Mirakurun + EDCB + KonomiTV が正常動作することを確認しています．  
Windows機上のTVTest w/ BonDriver_Mirakurunでの受信も確認．

- OS: NixOS Unstable
- CPU: Intel Core i5-8259U
- RAM: 16GiB
- Tuner: e-Better DTV02A-4TS-P (地上/BS/CS 混合4チューナー)
  - PCIeライザーボード経由で電源供給し，9-pin USB端子は変換を介してUSB Type-Aで接続
- Card Reader: SCR3310/v2.0

> [!CAUTION]
> `aarch64-linux` をsupported architectureに含めていますが，動作確認はしていません．現状は，あくまでビルド可能というだけです．
