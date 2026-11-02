---
title: Getting started
---

# Getting started

Requires Nix with flakes enabled, on x86_64 or aarch64 Linux.

## Try it

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
nix run github:Shrub24/Pi-Bolt.nix
```

The first build compiles Pi-Bolt from source. Provider login and agent usage are Pi's; see
[Pi's documentation](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/docs).

## Install with your plugins compiled in

One package carries the agent, the plugins compiled into it, and its launch configuration. Here it compiles two plugins from
[`pi-extensions`](https://github.com/Shrub24/pi-extensions) and takes their npm dependencies from a shared lock:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-bolt-nix = {
      url = "github:Shrub24/Pi-Bolt.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-extensions = {
      url = "github:Shrub24/pi-extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pi-bolt-nix.follows = "pi-bolt-nix";
      };
    };
  };

  outputs = { nixpkgs, home-manager, pi-bolt-nix, pi-extensions, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ pi-bolt-nix.overlays.default ];
      };
      modules = [{
        home.username = "me";
        home.homeDirectory = "/home/me";
        home.stateVersion = "25.11";

        programs.pi-coding-agent = {
          enable = true;
          package = (pkgs.pi-bolt.withPlugins (_: [
            pi-extensions.packages.${pkgs.stdenv.hostPlatform.system}.herdsman
            pi-extensions.packages.${pkgs.stdenv.hostPlatform.system}.tool-renderer
          ])).override {
            # One lock for the plugins' npm dependencies (guides/dependencies.md).
            pluginLock = ./plugins.lock.json;
            # Extra programs on every entrypoint's PATH; rg and fd are already there.
            extraPackages = [ pkgs.wl-clipboard ];
          };
        };
      }];
    };
  };
}
```

Apply with `home-manager switch --flake .#me`. `programs.pi-coding-agent` is Home Manager's module; this flake supplies packages and
an overlay, not modules of its own.

The result installs `pi-bolt` and `pi`, both running the same compiled executable. `pi-bolt` is the package's default launcher:
it puts the plugin and package tools on `PATH` and starts Pi with no environment of its own, so it uses Pi's usual agent
directory.

Two overrides worth knowing:

- `extraPackages` **adds** programs to every entrypoint; `runtimeInputs` is the base list (`ripgrep`, `fd`) and overriding it
  replaces them. A single launcher can add its own with `launchers.<name>.path`.
- `maxAotCandidateBytecodeSize` raises the compiler's per-module ceiling. Set it only when the build refuses a module and names
  it; large modules then compile instead of failing.

Elsewhere only the package set the overlay goes into changes:

- **NixOS:** `nixpkgs.overlays = [ pi-bolt-nix.overlays.default ];` with `environment.systemPackages = [ pkgs.pi-bolt ];`.
- **Home Manager inside NixOS:** the same overlay on the NixOS side and `home-manager.useGlobalPkgs = true`, so the user's
  `programs.pi-coding-agent.package` resolves. Apply with `nixos-rebuild`, not a separate switch.
- **Nothing to customise:** `pi-bolt-nix.packages.${system}.default` is the package without an overlay or plugins.

Following the consuming flake's `nixpkgs` can change dependencies and cache reuse; see
[cache boundaries](architecture/build-and-resolution.md#caching).

## Check what was compiled in

```sh
pi-bolt doctor --offline
```

It reports the installation it resolved, each extension it loads and whether it is compiled in or loaded at run time, and any
settings-file error it recorded. Start `pi-bolt` and work as usual; the plugins' commands and tools are already in the
executable.

## Share that configuration with native Pi

This part is optional. `pkgs.pi-bolt` needs neither stock Pi nor stock Pi's settings to be installed, and installing the package
on its own leaves your settings file alone.

The default agent directory is `~/.pi/agent`, the same one the upstream `pi` CLI uses, so when both binaries are installed they
read one settings file. Adding `programs.pi-coding-agent.settings` puts that file under Nix's control, as a read-only store link.

- **One configuration for both:** keep the default directory and render the settings with `payload.select { shared = true; }`. The
  plugin's store entry stays loadable for stock Pi, while Pi-Bolt's overlay replaces it with a resources-only entry, so Pi-Bolt runs
  the AOT copy and stock Pi loads the same derivation itself. See
  [share configuration with stock Pi](guides/settings.md#share-configuration-with-stock-pi). Which binary runs is decided by
  `PATH`.
- **Separate configurations:** set `programs.pi-coding-agent.configDir` to a private directory, or give an entrypoint its own
  directory with a [launcher](guides/launchers.md). Home Manager exports `PI_CODING_AGENT_DIR` when the directory is not the
  default.

## Start without external inputs

The package ships one example plugin, which is the shortest way to see a compiled command:

```nix
pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ])
```

That compiles `/words` in as `builtin:word-count`; `/words README.md` works in a directory containing that file.

## Add a second entrypoint

Launchers are how one payload serves several directories, each with its own settings and plugin subset:

```nix
let
  payload = pkgs.pi-bolt.withPlugins (_: [ extensions.herdsman extensions.tool-renderer ]);
  child = payload.select {
    plugins = [ extensions.herdsman ];
    closed = true;
  };
in
payload.override {
  launchers.pi-bolt-child = {
    env.PI_CODING_AGENT_DIR = "/home/me/.pi/roles/child";
    path = child.runtimeInputs;
  };
}
```

`payload.select` returns the settings and tools for that subset; [settings and selections](guides/settings.md) covers writing
them into the role's directory.

## Update

```sh
nix flake update pi-bolt-nix pi-extensions
```

Rebuild the consuming configuration. Nix owns this installation: update the flake rather than using the upstream installer's
`pi-bolt update` or `pi-bolt compile` commands to modify it. Compiled plugins are selected in Nix.

A Pi-Bolt release update alone does not invalidate a standalone plugin lock. Regenerate that lock when a plugin's dependencies
change; see [npm dependencies](guides/dependencies.md).
