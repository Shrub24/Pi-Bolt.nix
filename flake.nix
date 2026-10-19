{
  description = "Pi-Bolt, built from source: Pi compiled ahead of time, with Nix-packaged plugins compiled in (unofficial)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # The release: its VERSION selects the runtime (nix/runtime.json), and it is the default source.
    pi-bolt = {
      url = "github:opensec-git/Pi-Bolt/bolt-v0.9.5";
      flake = false;
    };
    # What gets compiled: the release by default. Downstream, follow your own input, which may be a fork branch:
    # `inputs.pi-bolt-nix.inputs.pi-bolt-source.follows = "<your input>"` (a nested URL does not override a follows).
    pi-bolt-source.follows = "pi-bolt";
  };

  outputs =
    { self, nixpkgs, pi-bolt, pi-bolt-source }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f (nixpkgs.legacyPackages.${system}.extend self.overlays.default));
    in
    {
      overlays.default = final: _prev: {
        piBoltPlugins = final.callPackage ./nix/plugins { source = pi-bolt-source; };
        pi-bolt = final.callPackage ./nix/pi-bolt.nix {
          release = pi-bolt;
          source = pi-bolt-source;
        };
      };

      packages = forAllSystems (pkgs: {
        default = pkgs.pi-bolt;
        inherit (pkgs) pi-bolt;
        pi-bolt-jit = pkgs.pi-bolt.override { jit = true; };
        # The word-count example from Pi-Bolt's examples/plugins, compiled in.
        pi-bolt-example = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
      });

      checks = forAllSystems (pkgs: {
        plugins = pkgs.callPackage ./nix/tests { };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
