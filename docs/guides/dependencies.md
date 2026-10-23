---
title: npm dependencies
---

# npm dependencies

A compiled plugin's npm dependencies must be available at build time. Use `pluginLock` for a shared set or `packageLock` for
a plugin's own lock. The two methods can be mixed.

| Need | Choose |
| --- | --- |
| Share compatible dependencies across a compiled plugin set | `pluginLock` on the payload. |
| Keep a plugin's own dependency pins, or load it at runtime | `packageLock` on that plugin. |
| Custom build steps, native artifacts or another package manager | A prepared `nodeModules` directory. |

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

For a larger packaging example, see the author's [`pkgs/pi-plugins`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-plugins)
catalogue: source recipes, a committed lock and a consumer-owned `passthru.updateScript`. Its public version exposes
`updateScript` and `updateLock` separately; it is not a ready-made implementation of the combined update above.

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

## Use a plugin's own lock

Pass its lock to `buildPiBoltPlugin`:

```nix
packageLock = ./plugin/package-lock.json;
```

Keep the lock and matching `package.json` beside each other in the consuming repository. The builder installs the locked
dependencies offline into the plugin's own `node_modules`, for compiled or runtime use. Identical libraries in separate plugin
folders can be bundled more than once.

For custom installation steps or a different package manager, pass a prepared directory instead:

```nix
nodeModules = "${preparedDeps}/node_modules";
```

Choose `packageLock` or `nodeModules` for each plugin, not both.

## Host packages and install scripts

Pi provides `@earendil-works/pi-*` and `typebox`; declare them as peers. Their copies are removed during staging and their
versions are not checked against the plugin's declared ranges. Legacy names have a [compile-path limitation](../architecture/build-and-resolution.md#host-package-aliases).

Both lock paths omit dev dependencies, do not auto-install peers, and disable lifecycle scripts. Optional dependencies are
included where the platform matches. Packages requiring generated/native artifacts need a separately prepared tree; the lock
is not a general native-addon build system.
