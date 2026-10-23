---
title: Getting started
---

# Getting started

Requires Nix with flakes enabled, on x86_64 or aarch64 Linux.

## Try Pi-Bolt

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
nix run github:Shrub24/Pi-Bolt.nix
```

The first build compiles Pi-Bolt from source. For provider login and agent usage, follow
[Pi's documentation](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/docs).

## Install declaratively

Choose the configuration that already manages the installation:

| Configuration | Route |
| --- | --- |
| NixOS system package | [NixOS](#nixos): apply the overlay in a NixOS module. |
| Standalone Home Manager | [Home Manager](#standalone-home-manager): apply it to the `pkgs` passed to Home Manager. |
| Home Manager inside NixOS | [Shared package set](#home-manager-inside-nixos): reuse NixOS's overlay. |
| Package output without customisation | Use `pi-bolt-nix.packages.${system}.default`; no overlay is needed. |

The examples below are consuming `flake.nix` files. Adapt names, architecture and paths; keep an existing configuration's
`stateVersion` and its chosen nixpkgs/Home Manager branches. Pi-Bolt.nix supplies packages and an overlay, not modules of its own.

### NixOS

This example adds Pi-Bolt to an existing `configuration.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pi-bolt-nix = {
      url = "github:Shrub24/Pi-Bolt.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, pi-bolt-nix, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ pi-bolt-nix.overlays.default ];
          environment.systemPackages = [ pkgs.pi-bolt ];
        })
      ];
    };
  };
}
```

Apply it with `sudo nixos-rebuild switch --flake .#my-host`.

### Standalone Home Manager

Use Home Manager's existing `programs.pi-coding-agent` module:

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
  };

  outputs = { nixpkgs, home-manager, pi-bolt-nix, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ pi-bolt-nix.overlays.default ];
      };
      modules = [
        ({ pkgs, ... }: {
          home.username = "me";
          home.homeDirectory = "/home/me";
          home.stateVersion = "25.11";
          programs.pi-coding-agent = {
            enable = true;
            package = pkgs.pi-bolt;
          };
        })
      ];
    };
  };
}
```

Apply it with `home-manager switch --flake .#me`. This assumes the Home Manager CLI is already installed.

### Home Manager inside NixOS

If the configuration already imports `home-manager.nixosModules.home-manager`, use the NixOS overlay above and add these
options to a NixOS module:

```nix
{ pkgs, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.users.me.programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-bolt;
  };
}
```

Keep the user's existing Home Manager settings. With `useGlobalPkgs`, configure the overlay on NixOS, not again inside the
Home Manager user module. Apply this route with `nixos-rebuild`, not a separate Home Manager switch.

All overlay routes above follow the consuming flake's `nixpkgs`. This can change dependencies and cache reuse; see
[cache boundaries](architecture/build-and-resolution.md#caching).

## Compile a first plugin

Replace the package with:

```nix
pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ])
```

This includes the example `/words` command as `builtin:word-count`. Rebuild your configuration, then run:

```sh
pi-bolt doctor --offline
```

Check that the intended installation is first on `PATH` and that `word-count` appears under compiled-in extensions.
Start `pi-bolt` and use `/words README.md` in a directory containing that file.

The [Home Manager example module](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/home-manager) also renders settings
for the selected plugins. The [custom plugin-set example](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set)
adds a local extension, npm dependencies and a launcher; see the [example instructions](https://github.com/Shrub24/Pi-Bolt.nix/blob/main/examples/README.md).
For other extensions, continue with [packaging plugins](guides/plugins.md).

## Update

```sh
nix flake update pi-bolt-nix
```

Rebuild the consuming configuration. Nix owns this installation: update the flake rather than using the upstream installer's
`pi-bolt update` or `pi-bolt compile` commands to modify it. Compiled plugins are selected in Nix.

A Pi-Bolt release update alone does not invalidate a standalone plugin lock. Regenerate that lock when the plugin dependencies
change; see [npm dependencies](guides/dependencies.md).
