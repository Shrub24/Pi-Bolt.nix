---
title: Release maintenance
---

# Release maintenance

## Add a Pi-Bolt release

From the repository root:

1. Update the runtime data, specifying the intended release:

   ```sh
   nix run .#update-runtime -- 1.0.1
   ```

   Without a version the updater selects the newest stable release. It verifies the signature on `SHA256SUMS` against
   `keys/release.pub`, reads `RUNTIME_STAMP`, writes `nix/runtime-data.nix`, and compares evaluated versions, hashes and stamps
   for both platforms. It builds no runtime; repeating a recorded release changes nothing.

2. Change the `pi-bolt` input tag in `flake.nix`, then run `nix flake lock`.
3. Run the [repository checks](development.md#check-the-package), build the intended packages and inspect `--version`/`doctor`.

The runtime and release tag are separate pins. While they disagree, evaluation reports `the runtime is <v>, the release is <v>`
with the updater command. Older downstream locks retain their own runtime data.

## Invoke through nix-update

The runtime declares `passthru.updateScript`, so:

```sh
nix-update --use-update-script packages.x86_64-linux.pi-bolt-runtime
```

This dispatches to the same updater. Plain `nix-update` is not the replacement: it would not coordinate both hashes and the
stamp. Moving the release source input remains a separate lock/tag change.

Plugin dependency locks are consumer-owned and have a [different workflow](../guides/dependencies.md#keep-manifests-and-pins-together).

## Rotate the release key

`keys/release.pub` is the trusted repository copy, not a key supplied alongside an untrusted release. Replace it only after
confirming an upstream rotation and checking a release signed by the new key:

```sh
openssl dgst -sha256 -verify new-release.pub -signature SHA256SUMS.sig SHA256SUMS
```

The [architecture page](../architecture/build-and-resolution.md) describes runtime matching and build layers.
