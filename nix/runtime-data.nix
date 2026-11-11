# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.2.1";
  stamp = "9606e2f852e92ee9";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-JdfExfjaUb0hzY7ChOmbDa22u0f6nO7QcS6eMJPckzc=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-gKVweKbshoBqtbpOTYM2yo1Sz0IV7YjMl8ef+3YMaeI=";
    };
  };
}
