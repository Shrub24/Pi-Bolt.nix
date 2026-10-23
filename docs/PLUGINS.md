---
title: Plugin documentation
pagefind: false
---

# Plugin documentation

Plugin documentation is now split by task. Start with [getting started](getting-started.md), or use the links below.

## Building a plugin

[Packaging guide](guides/plugins.md) · [Builder reference](reference/plugin-builder.md)

### npm dependencies

[Dependency guide](guides/dependencies.md) · [Lock contract and updater](reference/plugin-lock.md)

### Patching

[Patch a plugin](guides/plugins.md#patch-the-source).

## Compiling in

[First compiled plugin](getting-started.md#compile-a-first-plugin) · [Package reference](reference/package.md)

## Settings for a selection

[Settings guide](guides/settings.md) · [Selection API](reference/selection.md)

### Footguns

[Settings merging and duplicate runtime copies](guides/settings.md#combine-with-other-settings).

### Shared settings files

[Share configuration with stock Pi](guides/settings.md#share-configuration-with-stock-pi).

## Large modules

[AOT size override](reference/package.md#package-overrides).

## Built-in extensions

[Extensions, replacement and resources](architecture/build-and-resolution.md#extensions-and-resources).

## Loading at run time

[Runtime loading](guides/plugins.md#load-at-runtime-instead).

## Launchers

[Launcher guide](guides/launchers.md) · [Launcher fields](reference/package.md#launchers)

### Linking launchers into your own output

[Link entrypoints](guides/launchers.md#link-entrypoints-into-another-output).

## Known limitations

[Host-package aliases and TypeScript mapping](architecture/build-and-resolution.md#host-package-aliases).
