# The Pi-Bolt plugin set, a scope in the manner of nixpkgs' package sets: its builders, and the plugins this repository carries.
#
# Add your own with an overlay, as for any nixpkgs scope:
#
#   final: prev: {
#     piBoltPlugins = prev.piBoltPlugins.overrideScope (pfinal: pprev: {
#       my-plugin = pfinal.buildPiBoltPlugin { ... };
#     });
#   }
#
# or pass plugins built anywhere straight to `pi-bolt.withPlugins` (they need not be in this set).
{
  lib,
  newScope,
  source,
}:
lib.makeScope newScope (self: {
  buildPiBoltPlugin = self.callPackage ./build-plugin.nix { };
  # One package from the npm registry, unpacked: a plugin published to npm, or a
  # library a plugin imports. A producer set reads both builders from the scope, so
  # a recipe written against the application's scope has this one here too, as far
  # as the two builders' arguments agree.
  fetchNpmPackage = self.callPackage ./fetch-npm-package.nix { };

  # Pi-Bolt's examples/plugins: the /words command (docs/PLUGINS.md).
  word-count = self.buildPiBoltPlugin {
    pname = "word-count";
    # Only its own folder, so that the rest of the source does not move it.
    src = builtins.path {
      path = "${source.outPath}/examples/plugins/extensions";
      name = "word-count-source";
    };
    entry = "word-count.ts";
    meta.license = lib.licenses.mit;
  };
})
