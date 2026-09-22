# Repository Guidelines

## Project Structure & Module Organization

This flake packages a Japanese DTV stack for `x86_64-linux` and `aarch64-linux`.

- `pkgs/<name>/default.nix`: upstream package derivations; register packages in `pkgs/default.nix`.
- `modules/dtv/`: NixOS modules for px4_drv, Mirakurun, EDCB, and KonomiTV. `default.nix` imports modules and connects shared settings.
- `overlays/default.nix`: exposes packages and kernel-specific driver builds.
- `tests/`: module evaluation assertions, service VM tests, and integration tests, registered in `tests/default.nix`.
- `flake.nix`: package, module, check, and formatter outputs. `README.md` contains Japanese configuration documentation and examples.

Upstream application code and Web UI assets are fetched by derivations rather than maintained here.

## Build, Test, and Development Commands

Run commands from the repository root with Nix flakes enabled:

- `nix fmt`: format Nix files using the configured `nixfmt-tree` formatter.
- `nix build .#mirakurun`: build a package; substitute `edcb`, `recisdb`, or another exported name.
- `nix flake check`: run checks for the current system, including package builds and VM tests.
- `nix build .#checks.x86_64-linux.module-eval`: run module evaluation assertions.
- `nix build .#checks.x86_64-linux.integration`: exercise the real Mirakurun–EDCB stack in a VM.
- `nix run .#isdb-scanner -- --list-tuners`: inspect locally available tuners.

VM tests require a builder capable of running NixOS test VMs. Use the appropriate system attribute for your builder.

## Coding Style & Naming Conventions

Use two-space indentation and let `nix fmt` determine layout. Follow existing `let`/`in` module structure, camelCase option names, and upstream package naming. Define options with types, defaults, and descriptions; use `lib.mkIf` for conditional configuration. Pin upstream sources and update hashes alongside revisions.

## Testing Guidelines

Extend `tests/module-eval.nix` for option defaults, assertions, and generated configuration. Add runtime checks to the relevant service test using `pkgs.testers.runNixOSTest` and its Python driver. Keep service tests hardware-independent with fake packages; reserve real package interactions for `integration.nix`. Name new tests descriptively and register them in `tests/default.nix`. No numeric coverage threshold is configured.

## Documentation Changes

Do not edit documentation files, including `README.md`, files under `docs/`, and `AGENTS.md`, unless the user explicitly requests or approves those changes. If code changes warrant documentation updates, ask for approval before editing documentation.

## Commit & Pull Request Guidelines

Recent commits commonly use `component: imperative summary`, such as `edcb: fix http port settings`; follow that pattern. Keep changes focused. Describe behavior changes, affected options, and validation commands/results in pull requests. Link relevant issues. When configuration changes warrant updates to README examples, ask for approval before editing them.
