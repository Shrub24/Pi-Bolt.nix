---
title: Pi-Bolt.nix
---

# Pi-Bolt.nix

Install [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt) through Nix, with optional Pi extensions compiled into the executable.
Keep the agent, plugin dependencies and launch configuration in the same declarative setup. Runtime-loaded extensions are also
supported.

This is an unofficial package for **x86_64-linux** and **aarch64-linux**, not a NixOS or Home Manager module. The first build
compiles from source using Pi-Bolt's released engine; it can take a while.

## Start using it

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
```

[Getting started](getting-started.md) has complete NixOS and standalone Home Manager configurations, guidance for Home Manager
inside NixOS, and a first compiled plugin. Nix owns this installation; updates go through the consuming flake.

## Adapt an example

- [Home Manager](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/home-manager): a compiled plugin and its generated settings.
- [Custom plugin set](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set): a local extension, shared npm lock,
  settings and a named launcher.

The [example instructions](https://github.com/Shrub24/Pi-Bolt.nix/blob/main/examples/README.md) explain how to integrate each one.

## Configure a package

- [Package plugins](guides/plugins.md) from a directory or an archive.
- [Supply npm dependencies](guides/dependencies.md) with a shared set lock or a plugin's own lock.
- [Render settings](guides/settings.md) for compiled and runtime plugins, including their skills, prompts and themes.
- [Add launchers](guides/launchers.md) with different configuration roots and tools.
- [Build another source](guides/sources.md), such as a fork or a branch.

## Look up an interface

- [Packages and launchers](reference/package.md): outputs, overrides, helpers and launcher fields.
- [Plugin builder](reference/plugin-builder.md): arguments and returned attributes.
- [Selection API](reference/selection.md): settings, tools and selection constraints.
- [Plugin locks](reference/plugin-lock.md): file shape, updater CLI and failure messages.

## Understand or contribute

- [Build and resolution](architecture/build-and-resolution.md): layers, caching, dependency resolution and runtime matching.
- [Development](contributing/development.md), [documentation policy](contributing/documentation.md) and [release maintenance](contributing/releases.md).

These docs describe this repository's current `main`. For a pinned configuration, consult the docs at the revision in its
`flake.lock`. General agent configuration and commands belong to [Pi](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/docs)
and [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt#documentation).
