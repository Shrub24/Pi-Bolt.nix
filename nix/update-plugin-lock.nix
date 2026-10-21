# The plugin lock's generator, for the consumer's own pipeline (docs/PLUGINS.md, "Dependencies"): it extends the lock of the
# source the package compiles.
{
  writeShellApplication,
  coreutils,
  findutils,
  gnutar,
  gzip,
  jq,
  nodejs,
  source,
}:
writeShellApplication {
  name = "update-plugin-lock";
  runtimeInputs = [
    coreutils
    findutils
    gnutar
    gzip
    jq
    nodejs
  ];
  runtimeEnv.PI_SOURCE = source.outPath;
  text = builtins.readFile ../scripts/update-plugin-lock.sh;
}
