# buildPiBoltPlugin: a Pi extension as a derivation, for compiling into Pi-Bolt (pi-bolt.withPlugins) or loading at run time
# (`pi -e ${plugin.extensionPath}`). Usage: docs/PLUGINS.md.
#
# The output is the plugin's tree with a node_modules of its own. Pi's packages are never in it: Pi provides them, to a compiled
# plugin and to one loaded at run time alike.
{
  lib,
  stdenvNoCC,
  nodejs,
}:
lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;

  excludeDrvArgNames = [
    "entry"
    "pluginName"
    "packageName"
    "dependencies"
    "nodeModules"
    "workers"
    "builtin"
    "runtimeInputs"
  ];

  extendDrvArgs =
    finalAttrs:
    args@{
      # A plugin's version lives in its own package.json, so this only names the derivation.
      version ? "0",
      # The file, relative to the plugin's root, whose default export is the extension factory.
      entry,
      # The name Pi knows it by: builtin:<pluginName> turns it on and -builtin:<pluginName> off.
      pluginName ? finalAttrs.pname,
      # The name other plugins import it by (its package.json "name"), when it is a dependency of theirs.
      packageName ? null,
      # Other plugins (buildPiBoltPlugin) this one imports. Compiled in, each is staged once and shared, registered or not.
      dependencies ? [ ],
      # A ready node_modules folder for the npm packages the plugin imports, as
      # importNpmLock.buildNodeModules makes it: "${deps}/node_modules".
      nodeModules ? null,
      # External programs this plugin needs at run time; dependencies' programs are included too.
      runtimeInputs ? [ ],
      # Worker scripts the plugin starts (new Worker(new URL("./worker.ts", import.meta.url))), relative to its root. Each is
      # compiled as an entry point of its own.
      workers ? [ ],
      # Registered as a built-in extension (builtin:<name>). Settings can turn it off, and a run-time copy replaces it.
      builtin ? true,
      meta ? { },
      ...
    }:
    let
      depInfo =
        dep:
        dep.piBolt
          or (throw "buildPiBoltPlugin ${finalAttrs.pname}: dependency ${dep.name or "?"} is not a Pi-Bolt plugin");
      # A dependency without a packageName is imported by a relative path to its staged sibling, so it needs no link.
      linkDependency =
        dep:
        let
          package = (depInfo dep).packageName;
        in
        lib.optionalString (package != null) ''
          rm -rf $out/node_modules/${package}
          mkdir -p $(dirname $out/node_modules/${package})
          ln -s ${dep} $out/node_modules/${package}
        '';
    in
    {
      inherit version;
      # Defaults a caller can override: stdenv runs make when the plugin's source has a Makefile.
      dontConfigure = args.dontConfigure or true;
      dontBuild = args.dontBuild or true;
      # A plugin is source: its TypeScript is the deliverable, so there is nothing to strip or patch.
      dontFixup = args.dontFixup or true;
      nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ lib.optional (packageName != null) nodejs;

      installPhase = ''
        runHook preInstall
        ${lib.optionalString (packageName != null) ''
          # The declared packageName must be the plugin's package.json name.
          if [ -f package.json ]; then
            actual=$(node -p 'require("./package.json").name')
            if [ "$actual" != ${lib.escapeShellArg packageName} ]; then
              echo "buildPiBoltPlugin ${finalAttrs.pname}: packageName is ${packageName} but its package.json names $actual" >&2
              exit 1
            fi
          fi
        ''}
        mkdir -p $out
        cp -r . $out/
        chmod -R u+w $out
        ${lib.optionalString (nodeModules != null) ''
          mkdir -p $out/node_modules
          cp -rL --no-preserve=mode ${nodeModules}/. $out/node_modules/
        ''}
        ${lib.concatMapStrings linkDependency dependencies}
        # Pi provides its packages: a copy here would be a second Pi.
        rm -rf $out/node_modules/@earendil-works/pi-* $out/node_modules/typebox
        test -f $out/${lib.escapeShellArg entry} || {
          echo "buildPiBoltPlugin: entry ${entry} is not in the plugin's tree" >&2
          exit 1
        }
        runHook postInstall
      '';

      passthru = (args.passthru or { }) // {
        # What pi-bolt's build reads (nix/pi-bolt.nix).
        piBolt = {
          name = pluginName;
          inherit
            entry
            packageName
            dependencies
            workers
            builtin
            ;
          runtimeInputs = lib.unique (
            runtimeInputs ++ lib.concatMap (dep: (depInfo dep).runtimeInputs) dependencies
          );
        };
        # For loading it at run time instead: `pi -e ${plugin.extensionPath}`, or a settings.json "extensions" row.
        extensionPath = "${finalAttrs.finalPackage}/${entry}";
      };

      meta = {
        description = "Pi extension ${pluginName}";
      }
      // meta;
    };
}
