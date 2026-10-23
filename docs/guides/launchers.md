---
title: Launchers and roles
---

# Launchers and roles

Use launchers for different launch configurations of the **same compiled package**. They share the executable and compiled
plugins; each can set environment variables and add tools.

```nix
pkgs.pi-bolt.override {
  launchers.pi-bolt-child = {
    env.PI_CODING_AGENT_DIR = "/home/me/.pi/roles/child";
    path = [ pkgs.git ];
  };
}
```

This adds `bin/pi-bolt-child`. The normal `pi-bolt` and `pi` commands remain available. Override the `pi-bolt` launcher by name
to change the default entrypoint's environment.

## Configure a role

The consumer creates the role directory, writes its settings and decides whether credentials and sessions are shared. A launcher
only points to it; it does not mirror another directory or create files.

Use `payload.select { ... }` to obtain the role's settings and `runtimeInputs`, then add the latter to the launcher's `path`.
The [plugin-set example](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set) demonstrates this combination.

- Environment values are literal. Use absolute paths; `$HOME` is not expanded.
- Added `path` entries do not remove the package's tools or its compiled plugins' tools.
- Launchers accept no flags. A flag prepended to user arguments can break subcommand dispatch. Put configuration in settings,
  `env` or `path` instead.

For programs needed by every entrypoint, use the package's `runtimeInputs` override. Avoid Home Manager's `extraPackages`
wrapper here: it wraps only `bin/pi`, not all Pi-Bolt entrypoints, and changes the installation layout.

## Link entrypoints into another output

Keep the package's launchers rather than copying or independently wrapping the executable:

```nix
pkgs.runCommand "pi-bolt-entrypoints" { } ''
  mkdir -p $out/bin
  for f in ${payload}/bin/*; do
    ln -s "$f" $out/bin/$(basename "$f")
  done
''
```

The links resolve into the package's executable directory. With this output first on `PATH`, `pi-bolt doctor` recognises the
launcher as this installation. See [launcher fields](../reference/package.md#launchers) and the
[layout explanation](../architecture/build-and-resolution.md#launcher-layout).
