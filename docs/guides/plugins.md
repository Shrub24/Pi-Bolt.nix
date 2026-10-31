---
title: Packaging plugins
---

# Packaging plugins

`withPlugins` accepts plugins from `pkgs.piBoltPlugins` or derivations built elsewhere with `buildPiBoltPlugin`.

## Consume a plugin that ships its own package

The payload reads only `plugin.piBolt` from a plugin derivation, so a plugin repository can build itself and export the result as
its own flake package. That is the shape to prefer when it exists: the plugin's repository owns its source, version, patches and
npm dependencies, and its update step moves them together.

```nix
plugins = [ inputs.pi-greeting.packages.${system}.default ];
```

Pass it to the payload without going through the scope:

```nix
pkgs.pi-bolt.withPlugins (_: [ inputs.pi-greeting.packages.${system}.default ])
```

The rest of this page is for a plugin that ships no Nix package: you supply the recipe.

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

The hash is illustrative: obtain the actual archive hash before using this recipe. The builder unpacks the archive. Supply npm
dependencies using a [shared `pluginLock` or per-plugin `packageLock`](dependencies.md).

### Published to npm

The scope's fetcher takes the registry URL and naming for you:

```nix
src = pkgs.piBoltPlugins.fetchNpmPackage {
  pname = "pi-loop-police";
  version = "1.14.1";
  hash = "sha512-...";
};
entry = "extensions/loop-police.ts";
```

`hash` is the package's `dist.integrity` from the registry (`npm view pi-loop-police@1.14.1 dist.integrity`). The fetched tree is
the package itself, so `entry` paths match the published package; see the [reference](../reference/plugin-builder.md#fetched-npm-packages).

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
runtime plugin's dependencies. Use `packageLock` on the plugin, or supply a prepared `nodeModules` tree.

For a temporary invocation, `pi -e <entry-file>` loads the extension directly; `plugin.extensionPath` gives its store entry.
Do not prepend `-e` to a command that must dispatch subcommands: `pi-bolt -e <path> doctor` treats `doctor` as a prompt.
Use [settings](settings.md) for persistent configuration and [launchers](launchers.md) for tool paths.
