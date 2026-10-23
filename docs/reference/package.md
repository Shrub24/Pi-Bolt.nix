---
title: Packages and launchers
---

# Packages and launchers

## Flake outputs

Available on `x86_64-linux` and `aarch64-linux`:

| Output | Meaning |
| --- | --- |
| `packages.<system>.default`, `.pi-bolt` | Baseline-CPU, JIT-off Pi-Bolt. Installs `pi-bolt` and `pi`. |
| `packages.<system>.pi-bolt-jit` | AOT executable with the JIT enabled for runtime code. |
| `packages.<system>.pi-bolt-runtime` | Released engine, unpacked and prepared for the system. Primarily an integration/maintenance output. |
| `packages.<system>.docs` | Built static documentation; independent of the executable. |
| `overlays.default` | Adds `pi-bolt`, `pi-bolt-runtime` and the `piBoltPlugins` scope to a package set. |
| `apps.<system>.update-runtime` | Repository maintainer's runtime updater. |
| `checks.<system>` | Build and integration checks, including docs and example evaluation. |
| `formatter.<system>` | Repository Nix formatter. |

No `nixosModules` or `homeManagerModules` output is supplied. See [installation](../getting-started.md).

## Package overrides

Use `pkgs.pi-bolt.override { ... }`. These consumer arguments are distinct from injected build dependencies:

| Argument | Default | Meaning |
| --- | --- | --- |
| `plugins` | `[ ]` | Extension derivations to register in the executable. Their plugin dependencies are staged transitively. |
| `pluginLock` | `null` | Path to an npm lock, or parsed lock attribute set. See [lock contract](plugin-lock.md). |
| `launchers` | `{ }` | Attribute set of entrypoint name to `{ env, path }`. |
| `jit` | `false` | Enable the JIT alongside AOT code. Runtime-loaded extensions are otherwise interpreted. |
| `maxAotCandidateBytecodeSize` | `null` | Override the upstream maximum candidate module bytecode size, in bytes. `null` leaves the upstream setting. |
| `checkRuntimeStamp` | `true` | Fail on a source/runtime stamp mismatch; `false` warns instead. |
| `runtimeInputs` | `[ pkgs.ripgrep pkgs.fd ]` | Programs provided by the package. This override replaces the default list. Launcher `path` is additive. |

A module larger than the AOT limit is left out of the compiled image and interpreted; the compiler names it. Raising the limit
can make compilation slower and the image larger. Use it for a named refusal, not as a general performance setting.

## Package helpers and attributes

| Interface | Meaning |
| --- | --- |
| `withPlugins (ps: [ ... ])` | Select registered plugins from `piBoltPlugins` or elsewhere. Returns another overridable package. |
| `select { ... }` | Return settings and tools for a selection; see [selection API](selection.md). |
| `updatePluginLock` | Derivation providing `bin/update-plugin-lock`; see [CLI](plugin-lock.md#updater-cli). |
| `plugins` | The explicitly selected compiled plugin list. |
| `runtimeInputs` | Package tools plus tools of explicitly selected compiled plugins and their declared plugin dependencies. |
| `unwrapped` | Compiled executable/assets without generated launchers; intended for integrations that own launch placement. |

`withPlugins` replaces the explicit plugin selection; it does not append to it. Override composition works in either order:

```nix
(pkgs.pi-bolt.override { jit = true; }).withPlugins (ps: [ ps.word-count ])
```

Different derivations sharing one `pluginName` in the compiled dependency closure fail rather than silently replacing each other.
Internal derivation arguments and staging helpers are not additional supported extension interfaces.

## Launchers

`launchers.<name>` accepts:

| Field | Default | Meaning |
| --- | --- | --- |
| `env` | `{ }` | Environment-variable names to literal string values. No shell expansion. |
| `path` | `[ ]` | Packages whose `bin` directories are added after the package's tools and before inherited `PATH`. |

`pi-bolt` always exists; a field of that name customises it. `bin/pi` links to the default launcher. Each other name creates
`bin/<name>`. There is no `flags` field and the launcher generator is not exported.

Creating directories, settings, credential links and sessions is the consumer's responsibility.
