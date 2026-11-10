# The Pi-Bolt workspace: the build `npm run build:offline` makes from the root lockfile, as upstream Pi's flake does
# (workspacePackages). It is its own derivation, so it rebuilds only when a file it builds from changes (nix/source.nix).
{
  stdenv,
  nodejs,
  importNpmLock,
  autoPatchelfHook,
  src,
  # The source input, which holds the same two files the filter copies into src. The lockfile is read from there: reading it
  # from src would make evaluation realise a filtered store path, which is a build (`nix flake check --no-build`, how CI
  # evaluates). npmRoot stays src, so the workspace still changes only when the files it builds from do.
  lockfileRoot,
  version,
}:
stdenv.mkDerivation {
  pname = "pi-bolt-workspace";
  inherit src version;

  # Pi's own npm dependencies, all integrity-pinned in the lockfile: no hash to maintain here.
  npmDeps = importNpmLock {
    npmRoot = src;
    package = builtins.fromJSON (builtins.readFile "${lockfileRoot}/package.json");
    packageLock = builtins.fromJSON (builtins.readFile "${lockfileRoot}/package-lock.json");
  };
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
    autoPatchelfHook
  ];
  # The loader the prebuilt npm binaries ask for; the build sandbox has none of the host's.
  buildInputs = [ stdenv.cc.cc.lib ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
    # The build installs npm's prebuilt binaries and now runs some (biome, from Pi 1.2.0's schema check), which a sandbox
    # cannot start unpatched. `dontFixup` keeps the phase below as the only place that runs it.
    autoPatchelf node_modules/@biomejs
    npm run build:offline
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -a . $out
    runHook postInstall
  '';

  # An intermediate: the compile reads it as it is, and its scripts are the ones the build ran.
  dontFixup = true;
}
