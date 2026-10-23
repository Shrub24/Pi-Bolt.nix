{
  lib,
  stdenvNoCC,
  nodejs,
  importNpmLock,
  python3,
  autoPatchelfHook,
  stdenv,
}:
stdenvNoCC.mkDerivation {
  pname = "pi-bolt-nix-docs";
  version = "1";
  src = lib.cleanSourceWith {
    src = ../docs;
    filter =
      path: _type:
      !(lib.elem (builtins.baseNameOf path) [
        "node_modules"
        ".astro"
        "dist"
      ]);
  };
  npmDeps = importNpmLock { npmRoot = ../docs; };
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
    python3
    autoPatchelfHook
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  env.ASTRO_TELEMETRY_DISABLED = "1";

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    autoPatchelf node_modules
    npm run build
    python3 ${../scripts/check-docs.py} dist
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';
  dontFixup = true;
}
