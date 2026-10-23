# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "0.9.9";
  stamp = "a497d4c619f26017";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-lgAENmcDAtyimVj4oTqx4xXgr82OskIPIskbPWWM/50=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-W8k3HkBZV/ij3LHA9KJIQiOEFsq7jGOfFmjXZXElFDI=";
    };
  };
}
