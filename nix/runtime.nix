# The Pi-Bolt runtime: the patched Bun and WebKit that the executable links, released as a binary per platform.
# `nix run .#update-runtime -- <version>` moves the version and the hashes (scripts/update-runtime.sh, which runs nix-update) and
# checks them against the release's signed SHA256SUMS.
{
  fetchurl,
  stdenv,
}:
let
  version = "0.9.5";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-37XO2ZrMvgVFIKgwnVfuXiNdVtFzIwg4UzBhWbl9CrY=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-xnDKgqCU5NyrGlmpfQR8jnJppgIQbdfT7vzM1XevP8U=";
    };
  };
  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "pi-bolt-runtime: no release asset for ${stdenv.hostPlatform.system}");
in
fetchurl {
  pname = "pi-bolt-runtime";
  inherit version;
  url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${version}/${asset.name}";
  inherit (asset) hash;
  # The stamp of the release's engine (scripts/runtime-stamp.sh). The executable is built from the same engine, or the build fails.
  passthru.stamp = "34ccf3c94a5e9606";
}
