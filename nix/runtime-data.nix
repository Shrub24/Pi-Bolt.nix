# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.0.7";
  stamp = "d615e931f06bb5a4";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-KpAr4x0dljL47HehARpmP4iZ9nbeI8cpZ2DN+885IGA=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-pxd89CcjXEssgRwriDmddvBZeaOmYAdR7LIrdZDG2KY=";
    };
  };
}
