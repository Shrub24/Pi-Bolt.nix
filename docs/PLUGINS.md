# Plugins

A plugin is a Pi extension packaged as a Nix derivation. Use it in one of two ways:

- **Compiled in.** `pkgs.pi-bolt.withPlugins` builds an executable with the plugin inside. The plugin becomes a built-in
  extension, which Pi loads by default.
- **Loaded at run time.** Pass the plugin's entry file to Pi with `-e`. The executable does not change.

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
| `pname`, `version` | The derivation's name. `version` defaults to `"0"`. |
| `src` | The plugin's tree: a folder or an archive. |
| `entry` | The file, relative to the plugin's root, whose default export is the extension. |
| `pluginName` | The name Pi uses: `builtin:<pluginName>`. Defaults to `pname`. |
| `packageName` | The plugin's `package.json` `name`, needed when another plugin imports it through `dependencies`. |
| `dependencies` | Other `buildPiBoltPlugin` plugins this one imports. |
| `nodeModules` | A `node_modules` folder for the npm packages it imports. |
| `runtimeInputs` | Programs it needs on `PATH`. Its dependencies' programs are included. |
| `workers` | Worker scripts it starts, relative to its root. Each is compiled as an entry point. |
| `builtin` | `true` (default) compiles it in as `builtin:<pluginName>`. `false` compiles it in as an unnamed extension that a selection cannot switch off. |
| `patches`, `postPatch` | Patching, see below. |

Pi provides its own packages (`@earendil-works/pi-*` and `typebox`). The builder removes any copy a plugin brings.

### npm dependencies

A plugin that imports an npm package needs that package in its own `node_modules`. Build the folder from the plugin's lockfile
with nixpkgs' `importNpmLock`:

```nix
piBoltPlugins.buildPiBoltPlugin {
  # ...
  nodeModules = "${importNpmLock.buildNodeModules { npmRoot = ./.; inherit nodejs; }}/node_modules";
}
```

### Patching

Patch files apply to the plugin's root:

```nix
piBoltPlugins.buildPiBoltPlugin {
  # ...
  patches = [ ./fix-startup.patch ];
}
```

The paths in the patch are relative to the plugin's root, so `--- a/config.ts`, not `--- a/src/config.ts`, if the file is
`config.ts` at the root.

For a one-line replacement, `postPatch` runs shell in the plugin's root:

```nix
postPatch = ''
  substituteInPlace src/config.ts --replace-fail 'DEBUG = true' 'DEBUG = false'
'';
```

`--replace-fail` fails the build when the text is missing, instead of silently changing nothing.

## Compiling in

```nix
package = pkgs.pi-bolt.withPlugins (ps: [
  ps.word-count
  (ps.buildPiBoltPlugin { /* ... */ })
]);
```

`withPlugins` takes a function from the plugin set to a list of plugins. Plugins can come from `piBoltPlugins` or be built
anywhere. Two different plugins with the same `pluginName` fail the build.

## Settings for a selection

The package renders the `settings.json` keys for a selection of plugins, so the selection is written once. `select` returns
the settings and the tools the same selection needs:

```nix
let
  payload = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
  compiled = payload.select { };
  role = payload.select {
    plugins = [ runtimePlugin ];          # a subset of the compiled plugins, plus a plugin loaded at run time
    extensions = [ "${extraPlugin}/index.ts" ];  # a path listed as given
  };
in
{
  settings = compiled.settings;        # the keys, as a value
  roleSettings = role.settings;
  roleTools = role.runtimeInputs;      # for a launcher's `path`
}
```

Write `settings` to the agent directory with `builtins.toJSON` or Home Manager's JSON format. The renderer does not write the
file: Pi writes `settings.json` in place, and a store file is read-only, so copy the file at activation. Do not link it. The
value combines with `lib.recursiveUpdate` (which replaces lists) or a module (which appends them).

- A compiled plugin's entry carries its resources (`extensions = [ ]`). Its extension is the built-in one, so the compiled copy
  answers for it.
- A plugin the payload does not compile is an ordinary package entry, and Pi loads it from the store.
- A compiled plugin left out of `plugins` has no entry, so its skills and prompts do not load either.
- A package entry that is not a plugin (an npm or git source, or an object that filters its resources) passes through unchanged.
- `extensions` lists paths to load as given. A deny pattern does not block them, including under `closed`.
- `closed = true` admits only the selected compiled plugins and the built-ins named in `enable`. Package entries under `closed`
  are not tested.
- The renderer refuses two different plugins with one name, a name that is one of Pi's built-ins, a `builtin = false` plugin
  that the selection leaves out, and an `enable` name that is not one of Pi's built-ins. The built-in list is checked against
  Pi's source at build time. `herdr` is one of them, but it loads only inside a Herdr pane, so enabling it elsewhere has no effect.

### Footguns

- A plugin that is also installed as a package loads at run time, and that copy takes the compiled one's place. Keep it out of
  `packages`, or switch its extension off. `pi-bolt doctor` lists what loaded.
- `pi install` and `pi config` write `settings.json`, which fails when it is a store file. Declare plugins in Nix.
- Skill and command names are not checked across packages. Pi reports collisions when it loads them.

### Shared settings files

A `settings.json` that stock Pi also reads should keep Pi-Bolt's packages in the `piBolt.packages` overlay. Stock Pi then does
not see entries whose extensions are switched off:

```nix
packages = [ ];
piBolt = {
  packagesOverlay = true;
  packages = (payload.select { }).settings.packages;
};
```

Roles that only Pi-Bolt reads set `packages` directly.

## Large modules

The AOT compiler takes a module only up to a size limit. A larger module is left out of the compiled image and runs from the
interpreter. The compiler names the module it refused. Raise the limit for it, in bytes:

```nix
(pi-bolt.override { maxAotCandidateBytecodeSize = 500000; }).withPlugins (_: [ largePlugin ])
```

A higher limit makes the compile slower and larger.

## Built-in extensions

`pi-bolt doctor` lists the built-in extensions as `compiled in`:

- `llama.cpp`, `codemode`, `tool-search` and `mcp` load at start.
- `herdr` loads only inside a Herdr pane (`HERDR_ENV=1` with a pane id), and then reports pane state to Herdr.

A built-in is replaceable when it is `replaceable: true`, which Pi-Bolt sets for `codemode`, `tool-search` and `mcp`. A run-time
extension that registers a tool, command or flag of the same name takes its place, and the built-in does not load.

Turn one off with `-builtin:<name>` in `settings.json`. Do not run two extensions that publish pane state at once: `herdr` and
another extension that reports the same pane metadata.

## Loading at run time

A plugin can be loaded without being compiled in. `extensionPath` is its entry file in the store:

```sh
pi -e ${plugin.extensionPath}
```

`-e` is a flag. It belongs in the launcher that runs Pi, not before a subcommand: `pi-bolt -e <path> doctor` reads `doctor` as a
prompt. A plugin loaded this way needs its `runtimeInputs` on `PATH`, and the compiled executable does not add them for it. Put
them on `PATH` in the same launcher.

Add programs with `runtimeInputs` rather than Home Manager's `extraPackages`. That option wraps only `bin/pi`, in a new store
path, so the command you run is not the package's.

## Launchers

A launcher is a script that sets the environment and `PATH` it is given, then runs the `pi` beside it in `lib/pi-bolt`. Several
launchers share one compiled payload.

`launchers` installs them, and `bin/<name>` links to each:

```nix
pkgs.pi-bolt.override {
  launchers = {
    # `pi-bolt` is always installed and can be overridden by name.
    pi-bolt = { };

    pi-bolt-child = {
      env.PI_CODING_AGENT_DIR = "/home/me/.pi/roles/child";
      path = [ pkgs.git ];
    };
  };
}
```

- `env` values are quoted literally, so a path must be absolute. `$HOME` is not expanded.
- `path` is added before the existing `PATH`. The package's `runtimeInputs` and its plugins' tools stay on it.
- A launcher takes no flags. A flag before the user's arguments changes which subcommand Pi runs. Put what a role needs in its
  `settings.json`, in `env`, or in `path`.

### Linking launchers into your own output

To put the launchers in an installation tree you build, link them rather than copy them. Each link resolves into the package,
beside the executable. With the tree first on `PATH`, `pi-bolt doctor` reports its `pi-bolt` as this Pi-Bolt:

```nix
let
  pi = pkgs.pi-bolt.override { launchers = { /* ... */ }; };
in
pkgs.runCommand "pi-bolt-entrypoints" { } ''
  mkdir -p $out/bin
  for f in ${pi}/bin/*; do
    ln -s "$f" $out/bin/$(basename "$f")
  done
''
```

## Known limitations

- A plugin that ships its own `tsconfig.json` overrides the staged one for its own files. Its imports of `@earendil-works/pi-tui`
  can then resolve to a second copy of that package, so the plugin holds its own copy of `pi-tui`'s classes. Observed for
  `pi-tui` in a Pi-Bolt checkout build.
