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

### Recommended shape (optional)

One update script moves the pins, obtains each plugin's `package.json` in the same run, then calls `update-plugin-lock` once
with those manifests. Commit the pins, manifests and lock together, so they cannot disagree.

The plugin set in [`pkgs/pi-plugins`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-plugins) of the author's
`nix-dotfiles` is a working sample of this shape:

- `default.nix` declares the recipes and exposes the updater as `passthru.updateScript`. One updater owns the whole set, because
  `nix-update` cannot locate individual helper calls.
- `update.py` moves each npm pin, extracts `package/package.json` from the new tarball, reads directory-shaped plugins' manifests
  from their checkout input, and runs `update-plugin-lock` once.
- `plugins.lock.json` is committed beside them.
- `updateLock` regenerates the lock from the pins already in the tree, for when a checkout input moved a manifest without moving
  an npm pin.

The sample is one way to organise it, not a requirement. Manifests may be checked in, generated or extracted from archives,
and any tool that produces a compatible npm lock is acceptable. A `passthru.updateScript` like the sample's lets
`nix-update --use-update-script` drive it. This package ships no `updateScript` for the lock, because the member list belongs to
the consumer's plugin set.

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
