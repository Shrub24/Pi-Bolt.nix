# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.0.0";
  stamp = "2294704d3dd59887";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-omIxR1IR2O66rXNAo2+Oj7gSXV5Bz5a91L7C2PO4swU=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-n572IBEKSXiMQYa9qTvxcPHNHAL81WevBG173twUALM=";
    };
  };
}
