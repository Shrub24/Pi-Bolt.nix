# The Pi-Bolt workspace: the build `npm run build:offline` makes from the root lockfile, as upstream Pi's flake does
# (workspacePackages). It is its own derivation, so it rebuilds only when a file it builds from changes (nix/source.nix).
{
  stdenv,
  nodejs,
  importNpmLock,
  src,
  version,
}:
stdenv.mkDerivation {
  pname = "pi-bolt-workspace";
  inherit src version;

  # Pi's own npm dependencies, all integrity-pinned in the lockfile: no hash to maintain here.
  npmDeps = importNpmLock { npmRoot = src; };
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
  ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
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
