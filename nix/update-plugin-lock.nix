# The plugin lock's generator, for the consumer's own pipeline (docs/PLUGINS.md, "npm dependencies": `update-plugin-lock`).
# It combines plugin manifests into a lock, so it reads no source: the lock is its own npm project.
{
  writeShellApplication,
  coreutils,
  jq,
  nodejs,
}:
writeShellApplication {
  name = "update-plugin-lock";
  runtimeInputs = [
    coreutils
    jq
    nodejs
  ];
  text = builtins.readFile ../scripts/update-plugin-lock.sh;
}
