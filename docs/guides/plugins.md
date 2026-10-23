---
title: Packaging plugins
---

# Packaging plugins

`withPlugins` accepts plugins from `pkgs.piBoltPlugins` or derivations built elsewhere with `buildPiBoltPlugin`.

## Package a local extension

```nix
{ pkgs }:
let
  greeting = pkgs.piBoltPlugins.buildPiBoltPlugin {
    pname = "greeting";
    src = ./greeting;
    entry = "index.ts";
  };
in
pkgs.pi-bolt.withPlugins (_: [ greeting ])
```

The source must contain `index.ts` with the extension factory as its default export. Keep the normal Pi `package.json` in the
source for resources and dependency metadata. `entry` is required, so this builder does not describe resource-only packages;
those can be ordinary Pi package entries in [settings](settings.md).

The [plugin-set example](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set) is runnable and includes an npm
dependency, settings and a launcher. The [builder reference](../reference/plugin-builder.md) lists all arguments.

## Use an archive

Replace `src` with a normal Nix fetcher:

```nix
src = pkgs.fetchurl {
  url = "https://registry.npmjs.org/pi-loop-police/-/pi-loop-police-1.14.1.tgz";
  hash = "sha512-...";
};
entry = "extensions/loop-police.ts";
```

The hash is illustrative: obtain the actual archive hash before using this recipe. The builder unpacks the archive; it does not
fetch npm dependencies automatically. Supply them using a [plugin lock or `nodeModules`](dependencies.md).

## Patch the source

```nix
patches = [ ./fix-startup.patch ];
postPatch = ''
  substituteInPlace config.ts --replace-fail 'DEBUG = true' 'DEBUG = false'
'';
```

Both operate at the plugin root. A root-level `config.ts` has patch paths such as `a/config.ts`, not `a/src/config.ts`.
`--replace-fail` makes upstream changes visible instead of silently skipping a replacement.

## Add tools or another plugin

`runtimeInputs = [ pkgs.git ];` adds executables the plugin needs. Dependencies' tools are included too.

Use `dependencies = [ otherPlugin ];` for another `buildPiBoltPlugin` derivation imported by this plugin. Give that dependency
its `packageName` when importing it by npm package name. It is staged once; list it in `withPlugins` too only if its extension
factory should also be registered.

To publish a catalogue, extend the existing scope:

```nix
final: prev: {
  piBoltPlugins = prev.piBoltPlugins.overrideScope (pfinal: _pprev: {
    greeting = pfinal.callPackage ./greeting.nix { };
  });
}
```

Apply this overlay after `pi-bolt-nix.overlays.default`. No catalogue membership is required to pass a plugin to `withPlugins`.

## Load at runtime instead

Use a plugin in `payload.select { plugins = [ runtimePlugin ]; }` when it is not in the payload's compiled set. Pi loads it as
an ordinary store package. Its npm dependencies must still be available to Pi; a compile-time `pluginLock` does not install a
runtime plugin's dependencies. A prepared `nodeModules` tree can accompany the plugin.

For a temporary invocation, `pi -e <entry-file>` loads the extension directly; `plugin.extensionPath` gives its store entry.
Do not prepend `-e` to a command that must dispatch subcommands: `pi-bolt -e <path> doctor` treats `doctor` as a prompt.
Use [settings](settings.md) for persistent configuration and [launchers](launchers.md) for tool paths.
