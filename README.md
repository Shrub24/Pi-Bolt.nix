# Pi-Bolt.nix

A Nix flake that builds [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt), the Pi coding agent compiled ahead of time, with
Nix-packaged plugins compiled in.

This is unofficial and not maintained by the Pi-Bolt project. It builds for Linux on x86_64 and aarch64.

## Quickstart

Run it without installing:

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
```

Install it with Home Manager's `programs.pi-coding-agent`. Apply the flake's overlay to the package set your configuration
uses; it provides `pkgs.pi-bolt`:

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

`ps` is the plugin set, `pkgs.piBoltPlugins`. A compiled-in plugin is a built-in extension: Pi loads it by default, and
`-builtin:<name>` in settings turns it off. [Plugins](docs/PLUGINS.md) covers building your own, settings for a selection, and
launchers.

Building compiles Pi from source, so the first build of a source takes a while. Following your own `nixpkgs` keeps one copy in
your closure, but the workspace and the executable then hash differently from this flake's, so this flake's cache cannot serve
them.

## Packages

| Output | Contents |
| --- | --- |
| `packages.<system>.pi-bolt` | Pi-Bolt, baseline CPU |
| `packages.<system>.pi-bolt-jit` | Pi-Bolt with the JIT |
| `packages.<system>.pi-bolt-runtime` | The engine the executable runs on, for this system |

The overlay also provides `pkgs.pi-bolt.withPlugins`, `pkgs.piBoltPlugins` (the plugin set), and `pkgs.pi-bolt.unwrapped` (the
executable, without a launcher). `pkgs.pi-bolt` takes `jit`, `plugins`, and `launchers`
([Launchers](docs/PLUGINS.md#launchers)).

## Documentation

- [Plugins](docs/PLUGINS.md): building a plugin, compiling it in or loading it at run time, settings for a selection, built-in
  extensions, and launchers.
- [Releases and sources](docs/RELEASES.md): which release is built, and building a fork or a branch.
- [Maintaining](docs/MAINTAINING.md): for maintainers, adding a release and the runtime layer.

## Checks

```sh
nix flake check
```

`nix flake check` builds the checks for your system and evaluates the rest. CI builds every check on x86_64 and aarch64.
