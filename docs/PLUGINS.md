# Plugins

A plugin is a Pi extension packaged as a Nix derivation. A plugin can be used in two ways:

- **Compiled in.** `pkgs.pi-bolt.withPlugins` builds an executable with the plugin inside it. The plugin is a built-in
  extension. Pi loads it by default, and `-builtin:<name>` in settings turns it off.
- **Loaded at run time.** Pass the plugin's path to Pi with `-e`. The executable does not change, so this suits a plugin that
  changes often or a launcher that chooses plugins per run.

## Building a plugin

`buildPiBoltPlugin` takes a plugin's source and returns its derivation:

```nix
{ piBoltPlugins, fetchurl }:
piBoltPlugins.buildPiBoltPlugin {
  pname = "loop-police";
  version = "1.14.1";
  src = fetchurl {
    url = "https://registry.npmjs.org/pi-loop-police/-/pi-loop-police-1.14.1.tgz";
    hash = "sha512-...";
  };
  entry = "extensions/loop-police.ts";
}
```

| Argument | Meaning |
| --- | --- |
| `pname`, `version` | The derivation's name. `version` defaults to `"0"`, since a plugin's version lives in its own `package.json`. |
| `src` | The plugin: a folder, or a tarball. |
| `entry` | The file, relative to the plugin's root, whose default export is the extension. |
| `patches` | Patch files applied to the plugin's tree. Paths are relative to the plugin's root. |
| `postPatch` | Shell run after the patches, in the plugin's root. |
| `libraries` | npm packages it imports, from `piBoltPlugins.fetchNpmPackage`. |
| `dependencies` | Other plugins it imports, by their `packageName`. |
| `nodeModules` | A ready `node_modules` folder. Its packages are merged under `libraries`. |
| `runtimeInputs` | Programs it needs on `PATH`. Those of its dependencies are included. |
| `pluginName` | The name for `builtin:<name>`. Defaults to `pname`. |
| `packageName` | The name other plugins import it by: its `package.json` `name`. |
| `workers` | Worker scripts it starts, relative to its root. Each is compiled as an entry point. |
| `builtin` | Whether it is a built-in extension when compiled in. Defaults to `true`. |

Pi provides its own packages (`@earendil-works/pi-*` and `typebox`). A plugin does not bundle them.

### Patching

A patch changes a plugin before it is built, and the patched plugin is what gets compiled in or loaded:

```nix
piBoltPlugins.buildPiBoltPlugin {
  # ...
  patches = [ ./fix-startup.patch ];
}
```

For a one-line replacement, `substituteInPlace` in `postPatch` is simpler:

```nix
postPatch = ''
  substituteInPlace src/config.ts --replace-fail 'DEBUG = true' 'DEBUG = false'
'';
```

Use `--replace-fail`, which fails the build if the text is missing. A patch that stops applying after an upgrade then breaks
the build, not the running plugin.

## Compiling in

```nix
package = pkgs.pi-bolt.withPlugins (ps: [
  ps.word-count
  (ps.buildPiBoltPlugin { /* ... */ })
]);
```

`withPlugins` takes a function from the plugin set to a list of plugins. The plugins can come from `piBoltPlugins` or be
built anywhere. Two plugins with the same `pluginName` are an error.

## Loading at run time

A plugin's `extensionPath` is its entry file in the store:

```sh
pi -e ${plugin.extensionPath}
```

A plugin loaded this way needs its `runtimeInputs` on `PATH`, which the compiled executable does not set for it. A launcher that
loads it adds them:

```nix
pkgs.runCommand "pi-bolt-with-plugin" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
  mkdir -p $out/bin
  makeBinaryWrapper ${lib.getExe pkgs.pi-bolt} $out/bin/pi-bolt \
    --prefix PATH : ${lib.makeBinPath plugin.piBolt.runtimeInputs} \
    --add-flag -e --add-flag ${plugin.extensionPath}
''
```

Add programs to Pi with `runtimeInputs`, not with Home Manager's `extraPackages`. Home Manager wraps only Pi's own `bin/pi`
inside a new store path, so the command you run is not the package's.

## Known limitations

- A plugin that ships its own `tsconfig.json` overrides the staged one for its own files. Its imports of `@earendil-works/pi-tui`
  can then resolve to a second copy of that package, so a patch that relies on one shared copy does not apply. Observed for
  `pi-tui` in a Pi-Bolt checkout build.
