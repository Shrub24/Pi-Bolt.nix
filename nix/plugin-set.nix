# The plugin set's npm dependencies: one lock for the plugins (docs/PLUGINS.md, "npm dependencies"), installed as a tree of their
# own. It is its own derivation, not layered onto Pi's workspace, so a Pi-Bolt bump does not invalidate the lock, and it rebuilds
# only when the lock or a plugin changes. The compile copies it into plugins/node_modules, which a compiled plugin resolves before
# Pi's own tree: a package two plugins share is one copy, one that needs another version than a sibling is nested under that
# plugin, and Pi's packages stay where they are.
{
  lib,
  stdenv,
  nodejs,
  importNpmLock,
  runCommand,
  jq,
  # The compiled plugins the lock installs for: [{ name, plugin }], name being the plugin's own (its folder in the lock).
  members,
  # The lock scripts/update-plugin-lock.sh writes.
  packageLock,
}:
let
  rootPackage = {
    name = "pi-bolt-plugins";
    version = "0.0.0";
    private = true;
    workspaces = [ "pbplugins/*" ];
  };
  # The member package.json files npm installs the lock from. They are projected at build time, not read at evaluation: a
  # plugin's package.json is a build output, and reading it would build every plugin before this system's evaluation finishes.
  # The same four fields scripts/update-plugin-lock.sh writes, so the tree is installed from what the lock was generated from.
  manifests = runCommand "pi-bolt-plugin-manifests" { nativeBuildInputs = [ jq ]; } (
    ''
      mkdir -p $out/pbplugins
      printf '%s' ${lib.escapeShellArg (builtins.toJSON rootPackage)} >$out/package.json
    ''
    + lib.concatMapStrings (member: ''
      mkdir -p $out/pbplugins/${member.name}
      jq '{ name, version, dependencies, optionalDependencies } | with_entries(select(.value != null))' \
        ${member.plugin}/package.json >$out/pbplugins/${member.name}/package.json
    '') members
  );
in
stdenv.mkDerivation {
  pname = "pi-bolt-plugin-set";
  version = "0.0.0";
  src = manifests;

  # Every package in it is integrity-pinned in the lock: no hash to maintain here. A workspace member resolves to its manifest
  # above, which is a store path below `manifests`, so nothing is fetched for it.
  npmDeps = importNpmLock {
    npmRoot = manifests;
    package = rootPackage;
    inherit packageLock;
  };
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
  ];
  # As scripts/update-plugin-lock.sh resolved the lock: without it npm would look, offline, for the peers the lock leaves out.
  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  installPhase = ''
    runHook preInstall
    cp -a . $out
    runHook postInstall
  '';

  # An intermediate: the compile copies it as it is.
  dontFixup = true;
}
