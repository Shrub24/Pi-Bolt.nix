---
title: Plugin builder
---

# Plugin builder

`pkgs.piBoltPlugins.buildPiBoltPlugin { ... }` returns a derivation containing the extension's source tree.
See [packaging plugins](../guides/plugins.md) for recipes.

## Arguments

| Argument | Default | Meaning |
| --- | --- | --- |
| `pname` | Required | Derivation name; also the default plugin ID. |
| `src` | Required | Source directory or archive, unpacked by stdenv. |
| `entry` | Required | File relative to the plugin root with the default extension factory export. Must exist in the installed tree. |
| `version` | `"0"` | Derivation version only; does not rewrite `package.json`. |
| `pluginName` | `pname` | Staging directory/extension ID, used as `builtin:<pluginName>`. |
| `packageName` | `null` | npm import name for links from dependent plugins. Not checked against the manifest. |
| `dependencies` | `[ ]` | Other plugin derivations imported by this plugin. Their sources are staged transitively; registration remains explicit. |
| `nodeModules` | `null` | Prepared `node_modules` directory copied into the plugin. |
| `runtimeInputs` | `[ ]` | Programs needed at runtime. Declared plugin dependencies' tools are included. |
| `workers` | `[ ]` | Worker entry files relative to the plugin root; passed to Pi-Bolt as separate compile entries. |
| `builtin` | `true` | Register as a named, replaceable built-in. `false` opts out of that mechanism and cannot be disabled by a selection. |

Standard derivation fields such as `patches`, `postPatch`, `meta`, `nativeBuildInputs` and `passthru` are accepted. The builder
preserves caller inputs/passthru and defaults `dontConfigure`, `dontBuild` and `dontFixup` to `true`; callers can override them.
A build step is not run unless enabled explicitly.

A supplied `nodeModules` tree is copied; declared plugin dependencies with a non-null `packageName` are linked into it.
Root copies of `@earendil-works/pi-*` and `typebox` are removed because Pi supplies them. The compile staging also excludes these
names; see [host-package aliases](../architecture/build-and-resolution.md#host-package-aliases).

## Returned attributes

| Attribute | Meaning |
| --- | --- |
| `extensionPath` | Store path to the installed entry file, suitable for `-e` or an explicit extension path. |
| `piBolt.name` | Plugin ID. |
| `piBolt.entry`, `.packageName`, `.dependencies`, `.workers`, `.builtin` | Builder metadata consumed by the payload. |
| `piBolt.runtimeInputs` | Deduplicated plugin/dependency tool list. |

`piBolt` is generated metadata, not an alternative authoring API. Normal Pi manifests remain stock-Pi-compatible; do not add
Pi-Bolt-specific fields to `package.json` for this builder.
