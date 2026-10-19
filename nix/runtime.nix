# The Pi-Bolt runtime: the patched Bun and WebKit the executable runs on, from the release nix/runtime-data.nix names, unpacked
# and given this system's dynamic linker. The compile that follows copies it as it is, so the engine is prepared once per system
# rather than once per executable.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  callPackage,
}:
let
  data = import ./runtime-data.nix;
  asset =
    data.assets.${stdenv.hostPlatform.system}
      or (throw "pi-bolt-runtime: no release asset for ${stdenv.hostPlatform.system}");
  updateRuntime = callPackage ./update-runtime.nix { };
in
stdenv.mkDerivation {
  pname = "pi-bolt-runtime";
  version = data.version;
  src = fetchurl {
    url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${data.version}/${asset.name}";
    inherit (asset) hash;
  };

  nativeBuildInputs = [ patchelf ];
  dontConfigure = true;
  dontBuild = true;
  # The engine is an AOT image: stripping it or patching its ELF beyond the interpreter below damages it.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    chmod -R u+w $out
    # The compile links against this, and rewriting the compiled executable afterwards would damage its image.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} $out/bun
    runHook postInstall
  '';

  passthru = {
    inherit (data) stamp assets;
    # A shared update workflow runs `nix-update --use-update-script` on this attribute: the version, both platforms' hashes and
    # the stamp move together, which nix-update on its own cannot do (scripts/update-runtime.sh).
    updateScript = [ (lib.getExe updateRuntime) ];
  };
}
