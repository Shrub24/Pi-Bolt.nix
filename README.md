# Pi-Bolt.nix

[Pi-Bolt](https://github.com/opensec-git/Pi-Bolt), packaged with Nix, with optional Pi extensions compiled into the executable.

Unofficial; not maintained by the Pi-Bolt project. Supports **x86_64-linux** and **aarch64-linux**.

## Try it

```sh
nix run github:Shrub24/Pi-Bolt.nix -- --version
```

## Configure it

Apply `pi-bolt-nix.overlays.default` to the package set used by your configuration. With Home Manager's existing Pi module:

```nix
programs.pi-coding-agent = {
  enable = true;
  package = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
};
```

This compiles the example `/words` command into Pi-Bolt. The first build compiles from source and can take a while.

## Documentation

- [Getting started](docs/getting-started.md): installation, a first plugin and updates.
- [Documentation index](docs/index.md): guides, interface reference and architecture.
- [Complete examples](examples/README.md): Home Manager and a custom plugin set.
- [Contributing](docs/contributing/development.md): checks and documentation development.

General agent usage is documented by [Pi](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/docs)
and [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt#documentation).
