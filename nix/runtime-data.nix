# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "0.9.6";
  stamp = "de71ae35e809f880";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-YHf9723rOJRdbWelgDTkkW5u45aRQC9V+kvOM1cL4g4=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-2FKu/l6VD4LGYy29Ia/2W7fC0Afi4QEqpYjid19CO/s=";
    };
  };
}
