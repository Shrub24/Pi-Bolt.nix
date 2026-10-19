# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "0.9.5";
  stamp = "34ccf3c94a5e9606";
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
}
