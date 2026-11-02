---
title: npm dependencies
---

# npm dependencies

A compiled plugin's npm dependencies must be available at build time. Use `pluginLock` for a shared set or `packageLock` for
a plugin's own lock. The two methods can be mixed.

Nothing here applies when a plugin comes from a package its own repository builds: that package already contains its
dependencies. `pluginLock` is for plugins packaged in the consuming tree, or for one repository that packages a whole set.

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

Generate the lock from the plugins' `package.json` files:

```sh
nix run .#pi-bolt.updatePluginLock -- -o plugins.lock.json \
  ./plugin-a/package.json ./plugin-b/package.json
```

Each plugin's folder in the lock is its name, taken from the manifest's folder. Prefix a manifest when they differ:
`radar=./checkouts/borrowed/package.json`. The name is the plugin's `pluginName`, the same string the payload compiles it as.

`.#pi-bolt` is whatever attribute your flake exposes the payload as. Paths are read from the current directory. The command
needs network access to resolve npm ranges; the resulting lock is committed, and builds fetch its integrity-pinned
dependencies and install offline without resolving new versions.

The shared project contains the plugins, not Pi. Compatible dependencies share a copy; incompatible versions can nest under a
plugin. Updating Pi-Bolt alone does not invalidate the lock. See the [lock reference](../reference/plugin-lock.md) for the exact
file contract and errors.

## Keep manifests and pins together

The lock is only correct for the manifests it was generated from. Resolve those manifests **during the update**, not from paths
frozen when an updater was evaluated: a script that does the latter can move a pin while regenerating the lock from the old
manifest.

### Recommended shape

One update step moves each plugin's pin, obtains that plugin's `package.json` in the same run, then calls `update-plugin-lock`
once with all the manifests. Commit the pins and the lock together, so they cannot disagree. Expose it as a
`passthru.updateScript` on the package that owns the plugin set; `nix-update --use-update-script` then drives it.

[`pkgs/pi-plugins`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-plugins) in the author's `nix-dotfiles` is a
working instance: source recipes, a committed `plugins.lock.json`, and an update script that runs `update-plugin-lock`.

This package ships no `updateScript` of its own, because the member list belongs to the consumer's plugin set. Any tool that
writes a compatible npm lock is acceptable; manifests may be checked in, generated, or extracted from an archive during the
update.

For the local [example plugin](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set), from the repository root:

```sh
nix run .#pi-bolt.updatePluginLock -- -o examples/plugin-set/plugins.lock.json \
  examples/plugin-set/greeting/package.json
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
