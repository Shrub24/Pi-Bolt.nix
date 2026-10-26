# The runtime's data: the release, the stamp of its engine, and the archive each platform uses with the sha256 the release's
# signed SHA256SUMS gives it. scripts/update-runtime.sh is the only writer; nix/runtime.nix builds from it, and flake.nix takes
# its platform list from it.
{
  version = "1.0.3";
  stamp = "4c59468c0c4b8d3f";
  assets = {
    x86_64-linux = {
      name = "pi-bolt-runtime-linux-x64.tar.gz";
      hash = "sha256-dFQI9YWTxMTWxrnhI6RJJ3YhKTfnJdIwuM15tPbZMvw=";
    };
    aarch64-linux = {
      name = "pi-bolt-runtime-linux-arm64.tar.gz";
      hash = "sha256-bCkGWd9KU5bI6GYWhwyJcb336tADBoikjLOkVjr8BkU=";
    };
  };
}
