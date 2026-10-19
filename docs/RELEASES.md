# Releases and runtimes

A Pi-Bolt executable is built from two things:

- **The source**: Pi and its packages, compiled by `scripts/build-pi.sh`.
- **The runtime**: the JavaScript engine the executable runs on (a patched Bun and WebKit). It takes about 1 hour 40 minutes
  and 40 GB to build, so the flake downloads it from the release instead.

## Which release is built

The `pi-bolt` input is a Pi-Bolt release tag, such as `bolt-v0.9.5`. Its `VERSION` names the version, and `nix/runtime.json`
gives the runtime for that version. `pi-bolt-source` is what gets compiled. It follows `pi-bolt` by default, so the default
build is the release.

## Building from another source

To compile a fork or a branch, follow your own input from your flake:

```nix
{
  inputs.pi-bolt-nix.url = "github:Shrub24/Pi-Bolt.nix";
  inputs.my-pi-bolt = {
    url = "github:me/Pi-Bolt/my-branch";
    flake = false;
  };
  inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "my-pi-bolt";
}
```

A source with no `flake.nix` of its own (an archive, a source tarball) must be declared as a plain source (`flake = false`), or
Nix fetches it as a flake and fails. The snippet above does that. A source that has a `flake.nix` works either way.

Instead of declaring an input, the URL can be overridden directly:

```nix
inputs.pi-bolt-nix.inputs.pi-bolt-source.url = "path:../Pi-Bolt";
```

`nix ... --override-input pi-bolt-nix/pi-bolt-source path:../Pi-Bolt` does the same for one command, which is the way to build a
local checkout without editing the flake.

The source must have the same engine as the release. The build runs `scripts/runtime-stamp.sh` on the source. It hashes the
engine's sources, patches, build scripts and toolchain files, and the script lists them. If the hash differs from the runtime's
stamp, the build fails and names the stamp it needs. That runtime must be recorded first, as below.

A source that differs only in files which do not affect your system, such as `scripts/build-runtime.ps1`, has a different stamp
without a different engine. Build it with `checkRuntimeStamp = false`, which warns instead of failing:

```nix
pkgs.pi-bolt.override { checkRuntimeStamp = false; }
```

## Adding a release

1. Record the release's runtime:

   ```sh
   scripts/update-runtime.sh 0.9.6
   ```

   The script downloads the release's `SHA256SUMS`, its signature, `RUNTIME_STAMP` and the runtime archives. It checks the
   signature against `keys/release.pub`, then each archive's hash against the signed sums, and writes the entry to
   `nix/runtime.json`. Running it again for a recorded version changes nothing. A version recorded with different values is
   refused.

2. Point the `pi-bolt` input at the tag in `flake.nix`, then run `nix flake lock`.

3. Run `nix flake check`.

A release's entry stays after the next release, so a downstream flake pinning that release's input still resolves. Delete old
entries when the list gets long.

`keys/release.pub` is this repository's copy of the release key. The script trusts that copy, not a key shipped with the release.
Replace the file only when the Pi-Bolt project rotates its key, and check the new key against a release it signed before
replacing it:

```sh
openssl dgst -sha256 -verify "$new_key" -signature SHA256SUMS.sig SHA256SUMS
```
