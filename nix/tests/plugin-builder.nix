# buildPiBoltPlugin keeps what its caller passes: passthru (an updateScript, say), the build flags and nativeBuildInputs. The
# assertions run at evaluation, so `nix flake check --no-build` catches a builder that drops them.
{
  lib,
  runCommand,
  piBoltPlugins,
  hello,
}:
let
  plugin = piBoltPlugins.buildPiBoltPlugin {
    pname = "builder-probe";
    src = ./helper;
    entry = "index.ts";
    passthru.updateScript = "kept";
    dontBuild = false;
    nativeBuildInputs = [ hello ];
  };
in
runCommand "pi-bolt-plugin-builder-check" { } (
  assert lib.assertMsg (
    (plugin.passthru.updateScript or null) == "kept"
  ) "buildPiBoltPlugin dropped the caller's passthru";
  assert lib.assertMsg (
    !plugin.dontBuild
  ) "buildPiBoltPlugin forced dontBuild over the caller's dontBuild = false";
  assert lib.assertMsg (lib.any (
    d: lib.hasPrefix "hello-" d.name
  ) plugin.nativeBuildInputs) "buildPiBoltPlugin dropped the caller's nativeBuildInputs";
  "touch $out"
)
