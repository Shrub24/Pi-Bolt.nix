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

The first build compiles from source. Usage and provider login are Pi's: see
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

Apply with `home-manager switch --flake .#me`. `programs.pi-coding-agent` is
[Home Manager's module](https://nix-community.github.io/home-manager/options.xhtml#opt-programs.pi-coding-agent.enable); this
flake supplies the package and overlay only.

This installs `pi-bolt` and `pi`, the same compiled executable. `pi-bolt` is the default launcher: it adds the plugins' tools to
`PATH` and uses Pi's usual agent directory. `extraPackages` adds programs to every entrypoint; the other overrides are in the
[package reference](reference/package.md).

Elsewhere only the package set the overlay goes into changes:

- **NixOS:** `nixpkgs.overlays = [ pi-bolt-nix.overlays.default ];` with `environment.systemPackages = [ pkgs.pi-bolt ];`.
- **Home Manager inside NixOS:** the same overlay on the NixOS side and `home-manager.useGlobalPkgs = true`, so the user's
  `programs.pi-coding-agent.package` resolves. Apply with `nixos-rebuild`, not a separate switch.
- **Nothing to customise:** `pi-bolt-nix.packages.${system}.default` is the package without an overlay or plugins.

## Check what was compiled in

```sh
pi-bolt doctor --offline
```

It reports the installation it resolved, each extension it loads and whether it is compiled in or loaded at run time, and any
settings-file error it recorded. Start `pi-bolt` and work as usual; the plugins' commands and tools are already in the
executable.

## Share that configuration with native Pi

Optional. Installing the package leaves your settings alone. Both binaries read `~/.pi/agent` by default, and setting
`programs.pi-coding-agent.settings` makes that file a read-only store link.

- **One file for both:** render it with `payload.select { shared = true; }`; see [run it beside stock Pi](guides/settings.md#run-it-beside-stock-pi).
- **Separate:** set `programs.pi-coding-agent.configDir`, or give an entrypoint its own directory with a
  [launcher](guides/launchers.md).

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

Then rebuild. Nix owns this installation, so do not use upstream's `pi-bolt update` or `pi-bolt compile` on it. A plugin lock
is regenerated only when a plugin's dependencies change; see [npm dependencies](guides/dependencies.md).
