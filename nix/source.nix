# The parts of the Pi-Bolt source each build reads, as store paths that change only when those parts do: an edit to the root docs,
# tests or examples moves none of them, so the caches that hold the npm workspace and the compiled executable are not invalidated.
#
# lib.fileset needs a local path, and a flake input is a store path, so the filter is builtins.path's.
{
  lib,
  source,
}:
let
  root = toString source.outPath;

  only =
    name: keep:
    builtins.path {
      path = source.outPath;
      inherit name;
      filter =
        path: _:
        let
          rel = lib.removePrefix "${root}/" (toString path);
        in
        rel == root || lib.any (k: rel == k || lib.hasPrefix "${k}/" rel || lib.hasPrefix "${rel}/" k) keep;
    };

  # What the workspace (Pi's own build) reads: its manifests, the packages, and the root scripts a package build calls.
  workspaceFiles = [
    "package.json"
    "package-lock.json"
    "tsconfig.json"
    "tsconfig.base.json"
    "packages"
    "scripts/build-coding-agent-bundle.mjs"
    "scripts/package-files.mjs"
    # The build formats generated modules with biome (Pi 1.2.0), which reads its config and that config's plugin. Without them
    # biome falls back to its defaults and the regenerated modules no longer match the committed ones.
    "biome.json"
    "scripts/biome"
  ];
in
{
  workspace = only "pi-bolt-workspace-source" workspaceFiles;
  # What the compile reads on top of the workspace: its scripts, the training profile, the engine's patches (the runtime's stamp
  # is a hash of them), and the release's version.
  compile = only "pi-bolt-source" (
    workspaceFiles
    ++ [
      "scripts"
      "patches"
      "profiles"
      "docs"
      "VERSION"
      "sources.json"
    ]
  );
}
