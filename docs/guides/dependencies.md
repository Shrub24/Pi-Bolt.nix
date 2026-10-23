---
title: npm dependencies
---

# npm dependencies

A compiled plugin's npm dependencies must be available at build time. Use one shared lock for a set of plugins, or provide a
plugin's own `nodeModules`. The two methods can be mixed.

## Use a shared lock

```nix
(pkgs.pi-bolt.withPlugins (_: [ pluginA pluginB ])).override {
  pluginLock = ./plugins.lock.json;
}
```

Generate the lock from each plugin's `package.json`, using its `pluginName` as the argument name:

```sh
updater=$(nix build --no-link --print-out-paths .#pi-bolt.updatePluginLock)
"$updater/bin/update-plugin-lock" plugins.lock.json \
  plugin-a=./plugin-a/package.json plugin-b=./plugin-b/package.json
```

This command assumes the consuming flake exports its payload as `pi-bolt`. It needs network access to resolve npm ranges.
Commit the resulting lock. Builds fetch integrity-pinned dependencies and install offline; they do not resolve new versions.

The shared project contains the plugins, not Pi. Compatible dependencies share a copy; incompatible versions can nest under a
plugin. Updating Pi-Bolt alone does not invalidate the lock. See the [lock reference](../reference/plugin-lock.md) for the exact
file contract and errors.

## Keep manifests and pins together

Pass manifests available **during the update**, not paths frozen from plugin derivations when an updater was evaluated.
Otherwise a script can move a pin while regenerating the lock from the old manifest.

A recommended organisation is:

```text
plugins/
  plugin-a.nix
  plugin-a/package.json
  plugin-b.nix
  plugin-b/package.json
  plugins.lock.json
```

Each plugin definition owns its source pin. Its update step also writes or extracts the matching manifest; after all selected
updates, invoke `update-plugin-lock` once with those manifest paths. Commit the pins, manifests and lock together.

This is a workflow recommendation, not a required layout. Manifests may be checked in, generated or extracted from archives.
Any tool producing a compatible npm lock is acceptable. `nix-update` can invoke each plugin's update step, but is optional;
this package does not provide a member-specific `passthru.updateScript` for the lock.

For the local [example plugin](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set), the update command from the
repository root is:

```sh
updater=$(nix build --no-link --print-out-paths .#pi-bolt.updatePluginLock)
"$updater/bin/update-plugin-lock" examples/plugin-set/plugins.lock.json \
  greeting=examples/plugin-set/greeting/package.json
```

## Supply a plugin's own modules

Use this when a plugin has its own installation requirements or should not use the set's dependency tree:

```nix
nodeModules = "${pkgs.importNpmLock.buildNodeModules {
  npmRoot = ./plugin;
  nodejs = pkgs.nodejs;
}}/node_modules";
```

`./plugin` must contain a `package.json` and npm lock. Pass the resulting folder to `buildPiBoltPlugin`; a different installer
can supply the same interface. Identical libraries in separate plugin folders can be bundled more than once.

## Host packages and install scripts

Pi provides `@earendil-works/pi-*` and `typebox`; declare them as peers. Their copies are removed during staging and their
versions are not checked against the plugin's declared ranges. Legacy names have a [compile-path limitation](../architecture/build-and-resolution.md#host-package-aliases).

The shared-lock path omits dev dependencies, does not install peers, and disables lifecycle scripts. Optional dependencies are
included where the platform matches. Packages requiring generated/native artifacts need a separately prepared tree; the lock
is not a general native-addon build system.
