---
title: Build and resolution
---

# Build and resolution

Pi-Bolt.nix packages a source build of the agent with a **released binary engine**. It does not rebuild Bun/WebKit. The
package's provenance includes both source-built code and that binary runtime.

## Build layers

| Layer | Responsibility |
| --- | --- |
| Runtime (`nix/runtime.nix`) | Fetch the released engine, unpack it and set this system's dynamic linker. |
| Workspace (`nix/workspace.nix`) | Install Pi's dependencies and build its packages offline. |
| Plugin set (`nix/plugin-set.nix`, when a lock is supplied) | Install the standalone plugin dependency lock. |
| Compile (`nix/pi-bolt.nix`, `unwrapped`) | Stage source, workspace and plugins; run Pi-Bolt's baseline-CPU AOT build. |
| Launchers | Place environment/PATH scripts beside the compiled executable. |

Changing launcher configuration does not recompile the executable. Compile variants share the applicable workspace, runtime
and plugin-set inputs. The plugin-set install is independent of Pi's dependency lock.

These boundaries explain caching and override costs; internal staging paths are not extra consumer configuration APIs.

## Caching

A plugin selection, JIT setting or AOT-size limit changes the compile output, not the source's workspace dependency install.
A plugin lock/member change can rebuild the plugin-set install. Nix can reuse unchanged derivations across these variants.

Following a different `nixpkgs` revision can change dependencies and derivation hashes, so a cache built against this flake's
pin may not serve a consumer following another pin. There is no guarantee of a prebuilt payload for arbitrary plugin sets.

The committed locks pin dependency resolution. That alone is not a claim of byte-identical upstream AOT output: build stamps
and upstream compiler determinism are separate concerns.

## Plugin dependency resolution

A staged plugin resolves imports in this order:

1. Its own `node_modules`, including versions nested for it by the set lock and explicit plugin-dependency links.
2. The shared plugin-set `plugins/node_modules`.
3. Pi's workspace dependency tree.

Compatible plugin dependencies share a resolved path; conflicts can stay nested. A dependency also present in Pi can be bundled
a second time because the two projects are deliberately independent. This avoids coupling plugin locks to each Pi release.

The precompile check validates declared dependencies against the staged versions. It does not prohibit an undeclared import
from finding a package through a sibling or Pi. Lifecycle scripts are disabled in the shared install; native/generated
artifacts need separate preparation.

### Host-package aliases

Pi supplies `@earendil-works/pi-*` and `typebox` to extensions. The compile staging excludes copies with those names; no range
check is imposed on the host copy.

Pi's runtime loader also aliases legacy `@mariozechner/pi-*` and `@sinclair/typebox` names. The compile staging/TypeScript
mapping does not mirror that full alias set: legacy imports can fail to resolve or bundle another copy. Prefer the current
host package names when compiling extensions.

A plugin's own `tsconfig.json` can override the staged configuration. A second `pi-tui` copy and duplicated class identities
have been observed in a checkout build with such a configuration; inspect its import mapping if extension behaviour differs.

## Extensions and resources

The manifest/source-build path used by this flake registers compiled plugins as named, replaceable built-ins. A runtime
extension that registers a colliding tool, command or flag can displace that built-in. This is name-based replacement, not a
universal guarantee against loading an extension twice.

Upstream `pi-bolt compile` uses a different installed-extension substitution path with source paths and fingerprints. Its
single installed-package declaration should not be confused with adding a runtime copy alongside this flake's built-in.

Skills, prompt templates and themes are not embedded by the plugin compiler. `select` keeps a filtered store package entry so
Pi can discover them normally while suppressing that package's runtime extension.

Pi-Bolt also ships its own built-ins. In the pinned release, `llama.cpp`, `codemode`, `tool-search` and `mcp` load at startup;
`herdr` is gated on a Herdr pane environment. Replaceable built-ins can be displaced by colliding runtime registrations.
`-builtin:<name>` disables a named built-in. Avoid two extensions reporting the same Herdr pane state.

## Runtime matching

`pi-bolt` pins the release; `pi-bolt-source` chooses the source compiled, defaulting to that release. `nix/runtime-data.nix`
records the released engine's version, stamp and platform archive hashes.

The source's `scripts/runtime-stamp.sh` hashes engine inputs: Bun/WebKit source pins, patches, runtime build scripts (including
Windows), toolchain scripts and runtime profile hints. A changed hash normally means the source needs another runtime.
Windows-only edits can change the stamp without changing the Linux engine. The [source guide](../guides/sources.md) describes
the explicit warning-only override for that case.

## Launcher layout

The executable and its launchers reside together in `lib/pi-bolt`, with entrypoint symlinks in `bin`. The launcher resolves its
own path and executes its sibling `pi`; assets remain beside the executable.

`doctor` identifies a launcher by comparing its resolved directory with the executable's. A thin wrapper in another store
output does not satisfy that comparison. Linking the packaged entrypoints preserves it. The wrapper output copies the payload;
Nix store optimisation may deduplicate identical files locally, but separate outputs still have separate cache archives.
