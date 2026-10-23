---
title: Selection API
---

# Selection API

```nix
payload.select {
  plugins = payload.plugins;
  closed = false;
  enable = [ ];
  extensions = [ ];
}
```

Returns `{ settings; runtimeInputs; }`. Both are values: no settings file is written and no launcher is attached.

## Arguments

| Argument | Default | Meaning |
| --- | --- | --- |
| `plugins` | Payload's explicit compiled plugin list | Compiled subset plus runtime plugin derivations and ordinary Pi package entries. |
| `closed` | `false` | Emit deny patterns for built-ins and auto-discovered local extensions, then allow the selected built-ins and `enable`. |
| `enable` | `[ ]` | Additional built-in IDs emitted as `+builtin:<id>`. Names are passed through unchecked. |
| `extensions` | `[ ]` | Explicit paths/patterns appended after generated extension rules, unchecked. |

## Result

`settings.packages` contains each selected plugin derivation once, followed by the ordinary Pi package entries:

| Entry | Rendered value |
| --- | --- |
| Plugin compiled in this payload | `{ source = "<store path>"; extensions = [ ]; }` |
| Plugin not compiled in this payload | `{ source = "<store path>"; }` |
| Ordinary Pi package entry | Passed through unchanged. |

Compiled package entries disable only their runtime extension resource; skills, prompts and themes remain discoverable through
Pi's manifest/conventions. An omitted plugin has no generated package entry, so its resources are omitted too.

In open mode, omitted named compiled plugins get `-builtin:<name>`. In closed mode the rules begin with `!builtin:*` and
`!extensions/**`; selected named compiled plugins and `enable` IDs get `+builtin:<name>`. Explicit paths are appended and can
load even under closed mode. `settings.extensions` is omitted when there are no rules or explicit entries.

`runtimeInputs` combines the package's own tools with tools of the selected plugin derivations, including their declared plugin
dependencies. Raw npm/git/filter entries supply no tool metadata. This value does not change the payload's tool list.

## Constraints and limits

- Different plugin derivations cannot share a name across the selected and compiled sets. Repeated references to the same
  derivation are deduplicated.
- A compiled `builtin = false` plugin must remain selected because the renderer cannot disable it.
- Built-in IDs and extension paths are not validated. Unknown IDs can have no effect; use `pi-bolt doctor` to inspect loading.
- The renderer does not create `piBolt.packages` overlays, resolve resource-name collisions or manage writable files.
- Runtime package entries under `closed` have not been behaviourally verified. Extension filtering is not process sandboxing.

For merging and stock-Pi coexistence, see [settings and selections](../guides/settings.md).
The renderer is in [`nix/settings.nix`](https://github.com/Shrub24/Pi-Bolt.nix/blob/main/nix/settings.nix);
[`nix/tests/settings.nix`](https://github.com/Shrub24/Pi-Bolt.nix/blob/main/nix/tests/settings.nix) exercises selection and loading.
