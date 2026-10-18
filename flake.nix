{
  description = "Pi-Bolt, built from source: Pi compiled ahead of time, with Nix-packaged plugins compiled in (unofficial)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # The Pi-Bolt source. The fork branch carries the staged-tsconfig fix (opensec-git/Pi-Bolt PR 51) until it is merged.
    pi-bolt = {
      url = "github:Shrub24/Pi-Bolt/fix/compiled-plugin-host-modules";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, pi-bolt }:
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
        piBoltPlugins = final.callPackage ./nix/plugins { source = pi-bolt; };
        pi-bolt = final.callPackage ./nix/pi-bolt.nix { source = pi-bolt; };
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
