# Releases and runtimes

A Pi-Bolt executable is built from two things:

- **The source**: Pi and its packages, compiled by `scripts/build-pi.sh`.
- **The runtime**: the JavaScript engine the executable runs on (a patched Bun and WebKit). It takes about 1 hour 40 minutes
  and 40 GB to build, so the flake downloads it from the release instead.

The build has four layers, each its own derivation:

- the runtime: the release's engine, unpacked and given this system's dynamic linker;
- the workspace: Pi's npm dependencies and its own build (`npm run build:offline`);
- the compile: one executable, named for the source, the JIT mode, the AOT size limit and the plugin set;
- the launcher: a wrapper that adds `PATH` and does not touch the command line.

The first two are the same for every variant of a release, which is what makes them worth caching. A build against a different
`nixpkgs` hashes differently and can use neither.

## Which release is built

The `pi-bolt` input is a Pi-Bolt release tag, such as `bolt-v0.9.5`. Its `VERSION` names the version, and `nix/runtime-data.nix`
records the runtime for that version: the release, its engine stamp, and each platform's archive hash. The build fails if the two differ, so pointing `pi-bolt` at another tag needs that release's runtime
first (`nix run .#update-runtime -- <version>`), then `nix flake lock`. `pi-bolt-source` is what gets compiled; it follows
`pi-bolt` by default, so the default build is the release.

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

1. Move the runtime to the release:

   ```sh
   nix run .#update-runtime -- 0.9.6     (from the repository root)
   ```

   Without a version it takes the newest stable release. The script reads the release's `SHA256SUMS`, its signature and
   `RUNTIME_STAMP`, checks the signature against `keys/release.pub`, and writes the version, both platforms' hashes and the
   engine stamp into `nix/runtime-data.nix`. It then evaluates every system's runtime and checks its version, stamp and hash
   against the signed sums. Nothing is built, and running it again changes nothing.

   The runtime declares this script as `passthru.updateScript`, so the shared update workflow reaches it with
   `nix-update --use-update-script packages.<system>.pi-bolt-runtime`. That is the difference from an ordinary package:
   `nix-update` on its own edits one hash, for the system it runs on, and leaves the other platform's hash and the stamp stale.

2. Point the `pi-bolt` input at the tag in `flake.nix`, then run `nix flake lock`.

3. Run `nix flake check`.

The tag and the runtime are separate layers: the tag is a flake input, and moving it is a lock change (`nix flake update
pi-bolt`, or the input layer of a shared update workflow). The runtime is a package, and step 1 moves it. The build fails,
naming both versions, while the two disagree.

`nix/runtime-data.nix` holds one release. A downstream flake pinned to an older `pi-bolt-nix` revision gets that revision's
runtime from the lock, so older releases stay resolvable without a table of them.

`keys/release.pub` is this repository's copy of the release key. The script trusts that copy, not a key shipped with the release.
Replace the file only when the Pi-Bolt project rotates its key, and check the new key against a release it signed before
replacing it:

```sh
openssl dgst -sha256 -verify "$new_key" -signature SHA256SUMS.sig SHA256SUMS
```
