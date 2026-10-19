{
  description = "Pi-Bolt, built from source: Pi compiled ahead of time, with Nix-packaged plugins compiled in (unofficial)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # The release: its VERSION must match the runtime (nix/runtime.nix), and it is the default source.
    pi-bolt = {
      url = "github:opensec-git/Pi-Bolt/bolt-v0.9.5";
      flake = false;
    };
    # What gets compiled: the release by default. Downstream, follow your own input, which may be a fork branch:
    # `inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "<your input>"` (docs/RELEASES.md).
    pi-bolt-source = {
      follows = "pi-bolt";
      # A source, not a flake: an override that has no flake.nix must still evaluate.
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pi-bolt,
      pi-bolt-source,
    }:
    let
      # The platforms are the runtime's (nix/runtime-data.nix), so there is one list and not three.
      systems = builtins.attrNames (import ./nix/runtime-data.nix).assets;
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system: f (nixpkgs.legacyPackages.${system}.extend self.overlays.default)
        );
    in
    {
      overlays.default = final: _prev: {
        piBoltPlugins = final.callPackage ./nix/plugins { source = pi-bolt-source; };
        pi-bolt-runtime = final.callPackage ./nix/runtime.nix { };
        pi-bolt = final.callPackage ./nix/pi-bolt.nix {
          release = pi-bolt;
          source = pi-bolt-source;
        };
      };

      packages = forAllSystems (pkgs: {
        default = pkgs.pi-bolt;
        inherit (pkgs) pi-bolt;
        pi-bolt-jit = pkgs.pi-bolt.override { jit = true; };
        # The release's runtime: one version drives two platform hashes and the stamp (scripts/update-runtime.sh).
        inherit (pkgs) pi-bolt-runtime;
      });

      checks = forAllSystems (pkgs: {
        # The plugin contract: compiled in, and loaded from the store.
        plugins = pkgs.callPackage ./nix/tests { };
        # The launcher generator: env, PATH and argv, and that the launcher still finds pi when moved.
        launcher = pkgs.callPackage ./nix/tests/launcher.nix { };
        # The plugin builder keeps the caller's passthru, build flags and nativeBuildInputs.
        plugin-builder = pkgs.callPackage ./nix/tests/plugin-builder.nix { };
        # The JIT build, which no package output builds on its own.
        jit = pkgs.pi-bolt.override { jit = true; };
        # The word-count example from Pi-Bolt's examples/plugins, compiled in.
        pi-bolt-example = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
      });

      # Run from the repository root: it edits nix/runtime.nix there.
      apps = forAllSystems (pkgs: {
        update-runtime = {
          type = "app";
          program = nixpkgs.lib.getExe (pkgs.callPackage ./nix/update-runtime.nix { });
          meta.description = "Move the runtime to a Pi-Bolt release: the version, both platforms' hashes and the engine stamp";
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
