# The runtime updater, as the flake app and as the runtime's passthru.updateScript: one script, so `nix run .#update-runtime` and
# a shared workflow's `nix-update --use-update-script` do the same thing.
{
  writeShellApplication,
  coreutils,
  curl,
  gawk,
  jq,
  nix,
  openssl,
}:
writeShellApplication {
  name = "update-runtime";
  runtimeInputs = [
    coreutils
    curl
    gawk
    jq
    nix
    openssl
  ];
  text = builtins.readFile ../scripts/update-runtime.sh;
}
