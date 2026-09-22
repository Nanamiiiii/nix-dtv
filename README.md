# nix-dtv
NixOS module and Nix packages for Japanese DTV environment.  
日本のDTV受信環境を構築するNixOS modules / Nix packages

For more information, see the [docs](./docs/README.md) (in Japanese).

## Features
- Provide packages for receiving Japanese DTV broadcasting.
- Provide a NixOS module to configure a software stacks for Japanese DTV.

## Supported Platform
- `x86_64-linux`
- `aarch64-linux` (Untested)

## Quick Start
This module requires several environment specific settings. Please see the [docs](./docs/README.md) before configuration.

An example of px4_drv + Mirakurun + EDCB + KonomiTV environment.
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
        nix-dtv.nixosModules.default
        ({ config, pkgs, ... }: {
          # For the firmware included in px4_drv
          nixpkgs.config.allowUnfree = true;

          # For the smart card reader
          security.polkit.enable = true;
          services.pcscd.enable = true;

          services.dtv = {
            # Enable DTV stack configurations
            enable = true;

            # Specify recording directories
            # Used for EDCB and KonomiTV configuration
            recordingDir = [
              "/mnt/tv/recordings"
              "/mnt/tv/archive"
            ];

            # Enable tuner driver
            px4_drv.enable = true;

            # Enable mirakurun service
            mirakurun.enable = true;

            # Enable edcb service
            edcb.enable = true;
            
            # Enable KonomiTV docker container
            konomitv.enable = true;
          };

          services.mirakurun = {
            # Configure the tuner and tuner command
            tunerSettings = [
              {
                name = "PX4-S1";
                types = [ "GR" ];
                command = "recisdb tune --device /dev/px4video0 --channel <channel> -";
              }
            ];
          };

          services.edcb = {
            # Configure BonDriver
            bondriver = [
              {
                name = "BonDriver_LinuxMirakc.so";
                driverPath = "${pkgs.bondriver-linux-mirakc}/lib/BonDriver_LinuxMirakc.so";
                settings = {
                  GLOBAL = {
                    SERVER_HOST = "127.0.0.1";
                    SERVER_PORT = config.services.mirakurun.port;
                    DECODE_B25 = 0; # decoded in mirakurun
                    PRIORITY = 100;
                    SERVICE_SPLIT = 0;
                  };
                };
                tunerSettings.Count = 1;
              }
            ];

            # Enable EDCB Material WebUI
            materialWebUI.enable = true;
          };

          services.konomitv = {
              # Select tuner backend
              backend = "EDCB";
          
              # Use mirakurun as streaming tuner
              streamFromMirakurun = true;
          
              # Specify the directory to save screen capture
              captureDir = [ "/mnt/tv/capture" ];
          };
        })
      ];
    };
  };
}
```

## Provided Packages
- [px4_drv](https://github.com/tsukumijima/px4_drv)
  - Fork of the unofficial driver for PLEX and e-Better tuners.
- [Mirakurun](https://github.com/Chinachu/Mirakurun)
  - Japanese DTV tuner API server.
  - Upstream nixpkgs already provide `mirakurun` package, but its version is too old. `nix-dtv` overrides the version to the latest one. 
- [recisdb](https://github.com/kazuki0824/recisdb-rs)
  - Tuner reader and ARIB STD-B25 decoder written in Rust.
- [ISDBScanner](https://github.com/tsukumijima/ISDBScanner)
  - ISDB-T/S channel scanner.
- [EDCB](https://github.com/xtne6f/EDCB)
  - BonDriver based EPG software.
  - Extra tools are included.
- [EDCB Material WebUI 3](https://github.com/EMWUI/EDCB_Material_WebUI)
  - Modern WebUI for EDCB.
- [BonDriver_LinuxMirakc](https://github.com/matching/BonDriver_LinuxMirakc)
  - BonDriver to connect mirakc/mirakurun.

## NixOS Options
`nix-dtv` module provides following services and configuration.

- `services.dtv`
  - Configure integrated DTV stack.
- `services.mirakurun`
  - Configure Mirakurun service.
  - Upstream nixpkgs already provide miakurun service. `nix-dtv` overrides the original one and provide additional options. 
- `services.edcb`
  - Configure EDCB service.
- `services.konomitv`
  - Configure KonomiTV service.
  - KonomiTV is difficult to package with Nix. `nix-dtv` provide KonomiTV as an oci-container definition.
- `hardware.px4_drv`
  - Configure px4_drv kernel module.

## License
MIT
