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

Add this input to an existing flake:

```nix
inputs.pi-bolt-nix = {
  url = "github:Shrub24/Pi-Bolt.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Apply the overlay to the package set your configuration actually uses:

```nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [ pi-bolt-nix.overlays.default ];
};
```

Following `nixpkgs` uses your package set's dependencies; it can also change build hashes and cache reuse.
See [cache boundaries](architecture/build-and-resolution.md#caching).

Choose an installation route:

- **Home Manager:** `programs.pi-coding-agent = { enable = true; package = pkgs.pi-bolt; };`
- **NixOS:** `environment.systemPackages = [ pkgs.pi-bolt ];`
- **Another package output:** use `pi-bolt-nix.packages.${system}.default` directly when no overlay customisation is needed.

Pi-Bolt.nix supplies packages and an overlay, not a Home Manager or NixOS module. The Home Manager option above belongs to
Home Manager. Keep its package/module integration in the configuration that already owns your user setup.

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

The [complete Home Manager example](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/home-manager) also renders settings
for the selected plugins. For other extensions, continue with [packaging plugins](guides/plugins.md).

## Update

```sh
nix flake update pi-bolt-nix
```

Rebuild the consuming configuration. Nix owns this installation: update the flake rather than using the upstream installer's
`pi-bolt update` or `pi-bolt compile` commands to modify it. Compiled plugins are selected in Nix.

A Pi-Bolt release update alone does not invalidate a standalone plugin lock. Regenerate that lock when the plugin dependencies
change; see [npm dependencies](guides/dependencies.md).
