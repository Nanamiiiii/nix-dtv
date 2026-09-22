# Packages

以下のパッケージを提供します．オーバーレイにより，`pkgs`から直接参照可能です．  

| Package                  | Source                                            | Version                   |
| ------------------------ | ------------------------------------------------- | ------------------------- |
| `px4_drv`                | https://github.com/tsukumijima/px4_drv            | 0.6.0                     |
| `mirakurun`              | https://github.com/Chinachu/Mirakurun             | 4.1.3                     |
| `recisdb`                | https://github.com/kazuki0824/recisdb-rs          | 1.2.4-unstable-2026-08-22 |
| `isdb-scanner`           | https://github.com/tsukumijima/ISDBScanner        | 1.3.3                     |
| `edcb`                   | https://github.com/xtne6f/EDCB                    | work-plus-s-2026-09-04    |
| `edcb-material-webui`    | https://github.com/EMWUI/EDCB_Material_WebUI      | 3-unstable-2026-09-19     |
| `bondriver-linux-mirakc` | https://github.com/matching/BonDriver_LinuxMirakc | 0-unstable-2024-10-14     |

現状は作者自身の環境で使用するものだけをパッケージングしていますが，以下は追加するかもしれません．
- EPGStation
- libaribb25
- recpt1
- BonDriver_LinuxPTX

## KonomiTVについて
現状，KonomiTVはNixでパッケージングをせず，配布されているDockerイメージを利用しています．
依存するサードパーティーライブラリをすべてNixでパッケージングして追跡する必要があり，また相対パス依存の設計箇所をパッチなしでパッケージングすることも困難で，維持管理が容易でないと判断したためです．

余裕があれば今後Nixでのパッケージングに挑戦するかもしれません．
