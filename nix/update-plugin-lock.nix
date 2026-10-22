# The plugin lock's generator, for the consumer's own pipeline (docs/PLUGINS.md, "npm dependencies": `update-plugin-lock`).
# The lock is its own npm project, so it does not depend on the source this package compiles.
{
  writeShellApplication,
  coreutils,
  gnutar,
  gzip,
  jq,
  nodejs,
}:
writeShellApplication {
  name = "update-plugin-lock";
  runtimeInputs = [
    coreutils
    gnutar
    gzip
    jq
    nodejs
  ];
  text = builtins.readFile ../scripts/update-plugin-lock.sh;
}
