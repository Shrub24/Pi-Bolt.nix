# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.1.0";
  stamp = "2e54e6641c78fd6d";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-x38lQQGSBMfA62dw9Mr2/Afx4Wz5yl+jBzYlpENgps4=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-IrRqMNN58BlxUM7l/3n0WxuMZcCuAI694JJ4tXQCm4c=";
    };
  };
}
