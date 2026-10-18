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

## Source and runtime

`pi-bolt` is a non-flake input, pinned by `flake.lock`. The runtime is the release runtime `nix/runtime.json` names,
checked against its hash. Engine changes on Pi-Bolt's main reach this flake when a new runtime is released: a source build does not
rebuild the runtime, which takes about an hour and 40 GB.

## Plugins

`buildPiBoltPlugin` takes a plugin's source and entry file, and lists its npm `libraries`, the other plugins it imports as
`dependencies`, and any `runtimeInputs`. Its output is the plugin's tree, which `pi-bolt.withPlugins` compiles in, or
`-e ${plugin.extensionPath}` loads at run time. Pi-Bolt's own docs (`docs/PLUGINS.md`) describe the contract.

## Checks

```
nix flake check
```

Linux only (x86_64 and aarch64), as Pi-Bolt's compile is.
