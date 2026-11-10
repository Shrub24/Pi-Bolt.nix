# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.2.0";
  stamp = "9606e2f852e92ee9";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-/k3lqgGTlBCMnswJloBpR1RDjWYCDd4r0/OLgtdOYwc=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-h9XE4+mvfBJH61p2PPHF3OI67wLLFkHzjqh48bDNZ9s=";
    };
  };
}
