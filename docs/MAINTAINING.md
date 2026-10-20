# Maintaining

## The build's layers

Each layer is its own derivation:

- **Runtime** (`nix/runtime.nix`): the release's engine (a patched Bun and WebKit), unpacked and given this system's dynamic
  linker. Building the engine takes about 1 hour 40 minutes and 40 GB, so the release supplies it.
- **Workspace** (`nix/workspace.nix`): Pi's npm dependencies and its build (`npm run build:offline`).
- **Compile** (`nix/pi-bolt.nix`): one executable per source, JIT mode, AOT size limit and plugin set. It copies the runtime
  rather than preparing it.
- **Launcher**: a script per entry point that sets `PATH` and environment, then runs the `pi` beside it.

For one source, the runtime and the workspace are the same for every variant, so they are what a cache should hold. A build
against a different `nixpkgs` hashes every layer differently.

## Which release

`flake.nix` has two inputs:

- `pi-bolt`: a release tag, such as `bolt-v0.9.5`. Its `VERSION` names the version.
- `pi-bolt-source`: the source compiled. It follows `pi-bolt` by default, so the default build is the release.

`nix/runtime-data.nix` records one release: its version, the engine stamp, and each platform's archive name and hash. Nothing
else is recorded, so an older `pi-bolt-nix` revision in a downstream lock keeps its own runtime.

The engine stamp is the hash `scripts/runtime-stamp.sh` computes over the engine's inputs: `sources.json` (WebKit and Bun), the
patches, `scripts/build-runtime.sh` and `scripts/build-runtime.ps1`, `scripts/toolchain/*.sh`, and `profiles/runtime-*.hints`.
The Windows script is in it, so a Windows-only edit changes the stamp without changing the Linux engine. The build compares the
source's stamp with the runtime's and fails on a difference, unless `checkRuntimeStamp = false`, which only warns.

## Adding a release

1. Move the runtime to the release, from the repository root:

   ```sh
   nix run .#update-runtime -- 0.9.6
   ```

   Without a version it takes the newest stable release. The script reads the release's `SHA256SUMS`, its signature and
   `RUNTIME_STAMP`, and checks the signature against `keys/release.pub`. It writes the version, both platforms' hashes and the
   stamp into `nix/runtime-data.nix`, then evaluates each system's runtime and compares its version, stamp and hash with the
   signed sums. It builds nothing, and running it again on a recorded release changes nothing.

2. Point the `pi-bolt` input at the tag in `flake.nix`, then run `nix flake lock`.

3. Run `nix flake check`.

The runtime and the tag are separate steps. While they disagree, the build fails with `the runtime is <v>, the release is <v>`
and the update command to run.

### The update workflow

The runtime declares the updater as `passthru.updateScript`, so `nix-update --use-update-script packages.<system>.pi-bolt-runtime`
runs it. Plain `nix-update` would edit one platform's hash for the system it runs on and leave the other platform's hash and the
stamp stale. The tag is a flake input, so moving it is a lock change (`nix flake update pi-bolt`).

## Release key

`keys/release.pub` is this repository's copy of the release key, and the updater trusts it, not a key shipped with a release.
Replace it only when the Pi-Bolt project rotates its key. Check the new key against a release it signed before replacing:

```sh
openssl dgst -sha256 -verify new-release.pub -signature SHA256SUMS.sig SHA256SUMS
```
