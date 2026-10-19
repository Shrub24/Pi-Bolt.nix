# Pi-Bolt.nix

A Nix flake that builds [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt) from source: Pi, the coding agent, compiled ahead of
time, with Nix-packaged plugins compiled in.

This is unofficial. It is not maintained by the Pi-Bolt project.

## Use

```nix
{
  inputs.pi-bolt-nix.url = "github:Shrub24/Pi-Bolt.nix";

  outputs = { nixpkgs, pi-bolt-nix, ... }: {
    # with Home Manager's programs.pi-coding-agent:
    #   package = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
  };
}
```

With the overlay (`overlays.default`), `pkgs.pi-bolt`, `pkgs.pi-bolt.withPlugins`, `pkgs.piBoltPlugins` and
`pkgs.pi-bolt.unwrapped` are available.

| Output | What it is |
| --- | --- |
| `packages.<system>.pi-bolt` | Pi-Bolt, baseline CPU, JIT off |
| `packages.<system>.pi-bolt-jit` | the JIT build |
| `packages.<system>.pi-bolt-example` | with the word-count example compiled in |

## Layout

- `nix/workspace.nix`: Pi's own build (`npm run build:offline` over the root lockfile). It rebuilds only when a file it builds
  from changes.
- `nix/pi-bolt.nix`: the compile. `scripts/build-pi.sh --plugins` makes the executable from the workspace, the runtime named in
  `nix/runtime.json`, and the plugins. Then a launcher that sets `PATH`.
- `nix/plugins/`: `buildPiBoltPlugin` and `fetchNpmPackage`, and the scope that carries the examples.
- `nix/tests/`: the plugin contract, compiled in and loaded from the store.

## Release, source and runtime

- `pi-bolt` (input): the release, `bolt-vX.Y.Z`. Its `VERSION` selects the runtime, and its tag names the release.
- `pi-bolt-source` (input): what gets compiled. It follows `pi-bolt`. To compile another source (a fork branch, say), follow
  your own input: `inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "<your input>"`.
- `nix/runtime.json`: the runtime per release version, with its engine stamp and each platform's release-asset hash.
- `keys/release.pub`: the release key, pinned here. The signature of a release's checksums is checked against it.

Adding a release's runtime is `scripts/update-runtime.sh <version>`. It fetches the release's signed `SHA256SUMS`, checks the
signature and the archives' hashes, and records the entry in `nix/runtime.json`. Re-running it for a recorded version changes
nothing.

The compile checks that the source's engine (`scripts/runtime-stamp.sh`) is the runtime's. A source that changes webkit, bun,
or their patches fails with the stamp it needs, and that runtime must be recorded first.

A source build does not rebuild the runtime, which takes about an hour and 40 GB, so it is fetched.

## Plugins

`buildPiBoltPlugin` takes a plugin's source and entry file, and lists its npm `libraries`, the other plugins it imports as
`dependencies`, and any `runtimeInputs`. Its output is the plugin's tree, which `pi-bolt.withPlugins` compiles in, or
`-e ${plugin.extensionPath}` loads at run time. Pi-Bolt's own docs (`docs/PLUGINS.md`) describe the contract.

## Checks

```
nix flake check
```

Linux only (x86_64 and aarch64), as Pi-Bolt's compile is.
