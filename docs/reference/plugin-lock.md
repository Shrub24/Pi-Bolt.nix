---
title: Plugin lock contract
---

# Plugin lock contract

`pluginLock` accepts a path to JSON or a parsed npm lock attribute set. It describes a standalone npm workspace project for
plugin dependencies, not Pi's workspace. `null` leaves dependency preparation to the plugins' own `nodeModules`.

## File shape

The root project is:

```json
{
  "name": "pi-bolt-plugins",
  "version": "0.0.0",
  "private": true,
  "workspaces": ["pbplugins/*"]
}
```

The lock contains a workspace member at `pbplugins/<pluginName>` for each plugin whose dependencies it supplies. The name must
identify a plugin in the compiled dependency closure. Plugins outside the lock can carry their own modules.

Member manifests project these fields from each plugin's root `package.json`:

| Field | Meaning |
| --- | --- |
| `name` | The package's npm name. May differ from `pluginName`; used for package imports. |
| `version` | The package's own version. |
| `dependencies` | Declared runtime dependencies. Omitted if absent. |
| `optionalDependencies` | Optional runtime dependencies. Omitted if absent. |

Use an npm lock compatible with those root/member manifests, including integrity-pinned registry dependencies. The shipped
helper writes this shape. Any other generator may write it; no particular derivation shape, source layout or update framework
is required. See the [complete example](https://github.com/Shrub24/Pi-Bolt.nix/tree/main/examples/plugin-set).

## Updater CLI

`payload.updatePluginLock` provides:

```text
update-plugin-lock OUT NAME=MANIFEST...
```

- `OUT` is the destination lockfile; its parent directory must exist. An existing file is replaced.
- `NAME` is the plugin's `pluginName`, used for its workspace folder. Give each name once.
- `MANIFEST` is a file containing a JSON object with string `name` and `version` fields. Folders and archives are not accepted.
- At least one member is required. Resolve manifests at update time, not from old evaluation-time plugin store paths.

It creates a temporary project, projects the four fields above, runs npm's lock-only resolver with
`--ignore-scripts --legacy-peer-deps`, and copies the result to `OUT`. Network access is required for resolution. It does not
fetch plugin sources, update pins, build plugins or know how their manifests were produced.

The build installs from the lock offline, omits dev dependencies, skips lifecycle scripts and does not auto-install peers.
Optional packages are subject to platform constraints. The source manifests are read at build time, avoiding plugin builds
during evaluation.

## Errors

| Failure | Meaning / action |
| --- | --- |
| `pluginLock has …, which this package does not compile` | Member names do not match the compiled closure. Regenerate for the intended set. |
| `npm error Invalid: lock file's … does not satisfy …` | Source manifest and dependency lock disagree. Regenerate after updating manifests. |
| `a plugin's dependencies are not what it declares` | A declared dependency is missing or out of range in the staged tree; the message names the plugin, range and version. Fix its lock or own modules. |
| `is not a file (pass the plugin's package.json)` | A folder/archive was supplied rather than a manifest. |
| `is not a package.json with a name and a version` | Invalid manifest input. |

Declared `dependencies` are checked before compilation, except Pi-provided packages and explicitly linked plugin dependencies.
Undeclared imports may resolve through another plugin or Pi; successful resolution does not validate the plugin's manifest.
A member's own version changing without dependency changes need not invalidate installed dependencies.
