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

A declared input without a `flake.nix` needs `flake = false`. Otherwise Nix fails while trying to evaluate it as a flake.

Alternatively override the source input already declared by Pi-Bolt.nix:

```nix
inputs.pi-bolt-nix.inputs.pi-bolt-source.url = "path:../Pi-Bolt";
```

For one build of a consuming flake whose input is named `pi-bolt-nix`:

```sh
nix build --override-input pi-bolt-nix/pi-bolt-source path:../Pi-Bolt
```

When building Pi-Bolt.nix itself, the input path is just `pi-bolt-source`.

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
