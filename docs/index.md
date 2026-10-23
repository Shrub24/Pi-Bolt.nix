---
title: Pi-Bolt.nix
---

# Pi-Bolt.nix

Build [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt) with Nix, optionally compiling Pi extensions into the executable.
This is an unofficial package for x86_64 and aarch64 Linux.

## Start using it

[Getting started](getting-started.md) covers installation, Home Manager integration and a first compiled plugin.

## Configure a package

- [Package plugins](guides/plugins.md) from a directory or an archive.
- [Supply npm dependencies](guides/dependencies.md) with a shared lock or per-plugin modules.
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
