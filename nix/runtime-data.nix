# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.3.0";
  stamp = "13ef7565ee8ee6b5";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-iBab0pNzmQXFpQSORdpmvMaAi0fm2fgkgeKLiSlcgvQ=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-bJkGyXSBcIL9Vv7PeSYQrbo6KIP9CzkfrKppIJkDIyY=";
    };
  };
}
