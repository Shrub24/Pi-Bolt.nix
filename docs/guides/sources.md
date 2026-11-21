---
title: Releases and custom sources
---

# Releases and custom sources

The flake's `pi-bolt` input pins a release tag; `pi-bolt-source` follows it by default. Update the consuming lock with
`nix flake update pi-bolt-nix`, then rebuild.

## Build a fork or branch

Follow a source input in the consuming flake:

```nix
inputs.pi-bolt-nix.url = "github:Shrub24/Pi-Bolt.nix";
inputs.my-pi-bolt = {
  url = "github:me/Pi-Bolt/my-branch";
  flake = false;
};
inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "my-pi-bolt";
```

For a one-off build, `nix build --override-input pi-bolt-nix/pi-bolt-source path:../Pi-Bolt` (just `pi-bolt-source` when building
Pi-Bolt.nix itself).

## Patch the source

For a change carried on top of the release, pass patches instead of following a branch:

```nix
pkgs.pi-bolt.override { patches = [ ./patches/my-change.patch ]; }
```

They apply with `-p1` from the repository root, when the npm workspace builds, so evaluation reads the unpatched source and
needs no import-from-derivation. A patch may change anything under `packages/`, the root `tsconfig` files and the build scripts the
workspace runs. It must not change `package.json` or `package-lock.json`, whose dependencies are read during evaluation, nor the
files outside the workspace (`scripts/build-pi.sh`, `patches/`, `profiles/`): those fail the patch phase with "can't find file to
patch". A patched release keeps the release's version label.

## Match the released runtime

Changing the agent source is supported; changing its engine requires a matching runtime. A mismatch fails with:

```text
pi-bolt: this source's engine is not release <version>'s (source stamp <stamp>, runtime stamp <stamp>); ...
```

The flake consumes the released engine rather than compiling a new one. Wait for or provide the matching runtime when the
engine changes. The [architecture page](../architecture/build-and-resolution.md#runtime-matching) explains what the stamp covers.

Some changes, such as edits to the Windows runtime build script, change the stamp without changing the Linux engine. Only when
the engine is known to be unchanged, turn the failure into a warning:

```nix
pkgs.pi-bolt.override { checkRuntimeStamp = false; }
```

A non-release source is labelled `<version>-unstable-<date>`. This label is not a guarantee that a different engine is compatible.
