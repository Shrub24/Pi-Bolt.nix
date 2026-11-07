# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.1.2";
  stamp = "2e54e6641c78fd6d";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-esWNx3e78HVywS3d2B+J5+2CQ/+EDYnJFZVYHy2aJMI=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-RUuL6CEsB7Iz3R5rrZoOffXEjoeSzsNALZiOlkjddg4=";
    };
  };
}
