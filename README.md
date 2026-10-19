# Pi-Bolt.nix

A Nix flake that builds [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt), the Pi coding agent compiled ahead of time, with
Nix-packaged plugins compiled in.

This is unofficial and not maintained by the Pi-Bolt project. It supports Linux on x86_64 and aarch64.

## Quickstart

Run it without installing:

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
```

Install it with Home Manager's `programs.pi-coding-agent`. Add the flake's overlay to the package set your configuration uses,
which provides `pkgs.pi-bolt`:

```nix
{
  inputs.pi-bolt-nix.url = "github:Shrub24/Pi-Bolt.nix";
  inputs.pi-bolt-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, home-manager, pi-bolt-nix, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; overlays = [ pi-bolt-nix.overlays.default ]; };
  in {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          programs.pi-coding-agent = {
            enable = true;
            package = pkgs.pi-bolt;
          };
        }
      ];
    };
  };
}
```

To compile plugins in, select them in the package:

```nix
package = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
```

`ps` is the plugin set, `pkgs.piBoltPlugins`. Compiled-in plugins are built-in extensions: Pi loads them by default, and
`-builtin:<name>` in settings turns one off.

Pi-Bolt is built from source on your machine, which takes several minutes. It follows this flake's `nixpkgs` unless you follow
yours; following yours keeps one nixpkgs in the closure, but the workspace and the executable then hash differently from this
flake's, so a cache of its builds cannot serve them.

## Packages

| Output | Contents |
| --- | --- |
| `packages.<system>.pi-bolt` | Pi-Bolt, baseline CPU |
| `packages.<system>.pi-bolt-jit` | Pi-Bolt with the JIT |
| `packages.<system>.pi-bolt-runtime` | The engine the executable runs on, unpacked for this system |

The overlay also provides `pkgs.pi-bolt.withPlugins`, `pkgs.piBoltPlugins`, and `pkgs.pi-bolt.unwrapped` (the executable,
without any launcher). `pkgs.pi-bolt` takes `launchers` for entrypoints with their own environment and `PATH`
([Plugins](docs/PLUGINS.md#launchers)), `plugins` to compile plugins in, and `jit`.

## Documentation

- [Plugins](docs/PLUGINS.md): building, patching, compiling in or loading plugins, built-in extensions, and launchers
- [Releases and runtimes](docs/RELEASES.md): which release is built, building from another source, and adding a release

## Checks

```sh
nix flake check
```

CI runs it on x86_64 and aarch64.
