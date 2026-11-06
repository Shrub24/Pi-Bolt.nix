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

`.#pi-bolt` is whatever attribute your flake exposes the payload as. Resolving ranges needs network; commit the lock, and builds
install its integrity-pinned dependencies offline. The lock covers the plugins, not Pi, so a Pi-Bolt update does not invalidate
it. File contract and errors: [lock reference](../reference/plugin-lock.md).

## Keep manifests and pins together

The lock is correct only for the manifests it was generated from, so obtain them during the update, not from paths frozen when
an updater was evaluated. The recommended shape is one update step that moves each pin, fetches that plugin's `package.json` in
the same run, and calls `update-plugin-lock` once; commit pins and lock together. Expose it as `passthru.updateScript` and
[`nix-update --use-update-script`](https://github.com/Mic92/nix-update) drives it. A working instance is
[`pkgs/pi-plugins`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-plugins) in `nix-dotfiles`. Any tool that writes a
compatible npm lock will do.

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

Keep it beside the plugin's `package.json` in the consuming repository. The locked dependencies install offline into the
plugin's own `node_modules`, for compiled or runtime use; a library two plugins both carry is bundled twice.

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
