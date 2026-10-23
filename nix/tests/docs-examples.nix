{
  pkgs,
  lib,
  runCommand,
  writeText,
}:
let
  home = import ../../examples/home-manager { inherit pkgs; };
  custom = import ../../examples/plugin-set { inherit pkgs; };
  # Force evaluation of the complete documented outputs without building a payload.
  evaluated = builtins.deepSeq {
    homePackage = home.programs.pi-coding-agent.package.drvPath;
    homeSettings = home.programs.pi-coding-agent.settings;
    customPackage = custom.package.drvPath;
    customSettings = custom.settings;
    customTools = map lib.getName custom.runtimeInputs;
  } true;
in
assert evaluated;
runCommand "pi-bolt-docs-examples" { } ''
  mkdir -p $out
  cp ${writeText "home-manager-settings.json" (builtins.toJSON home.programs.pi-coding-agent.settings)} $out/home-manager.json
  cp ${writeText "plugin-set-settings.json" (builtins.toJSON custom.settings)} $out/plugin-set.json
''
