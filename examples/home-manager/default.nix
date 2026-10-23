{ pkgs, ... }:
let
  package = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
  selection = package.select { };
in
{
  programs.pi-coding-agent = {
    enable = true;
    inherit package;
    settings = selection.settings;
  };
}
