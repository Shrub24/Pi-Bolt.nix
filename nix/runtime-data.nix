# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.0.9";
  stamp = "2e54e6641c78fd6d";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-yvnXTW9iA+iT4NyrYSeVnJdAsq++WCr/1zqCUItZyrg=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-5yEfdDN4wzlbrBKLqgZE5Us82SOoW15+ml72rDIJraA=";
    };
  };
}
