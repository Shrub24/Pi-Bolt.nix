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
| `dependencies` | Other plugins it imports, by their `packageName`. |
| `nodeModules` | A ready `node_modules` folder for the npm packages it imports. |
| `runtimeInputs` | Programs it needs on `PATH`. Those of its dependencies are included. |
| `pluginName` | The name for `builtin:<name>`. Defaults to `pname`. |
| `packageName` | The name other plugins import it by: its `package.json` `name`. |
| `workers` | Worker scripts it starts, relative to its root. Each is compiled as an entry point. |
| `builtin` | Whether it is a built-in extension (`builtin:<name>`), replaceable by an extension of the same tools loaded at run time. `false` compiles it in as an unnamed extension instead. Defaults to `true`. |

Pi provides its own packages (`@earendil-works/pi-*` and `typebox`); the builder removes any copy a plugin brings.

A plugin that imports an npm package needs it in that plugin's own `node_modules`. Build the folder from a lockfile, as
nixpkgs' `importNpmLock` does (`importNpmLock` and `nodejs` are from `pkgs`), and pass it:

```nix
piBoltPlugins.buildPiBoltPlugin {
  # ...
  nodeModules = "${importNpmLock.buildNodeModules { npmRoot = ./.; inherit nodejs; }}/node_modules";
}
```

### Patching

Patches apply to the plugin's tree before it is built:

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

`--replace-fail` fails the build when the text is missing, rather than silently patching nothing.

## Compiling in

```nix
package = pkgs.pi-bolt.withPlugins (ps: [
  ps.word-count
  (ps.buildPiBoltPlugin { /* ... */ })
]);
```

`withPlugins` takes a function from the plugin set to a list of plugins. The plugins can come from `piBoltPlugins` or be
built anywhere. Two different plugins with the same `pluginName` fail the build.

## Settings for a selection

The package renders the `settings.json` keys for its plugins, so the list is written once. `mkSettings` returns the keys as a
value; `mkSettingsFile` writes them to a store file.

```nix
let
  payload = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
in
{
  # The compiled plugins and their resources.
  settings = payload.mkSettings { };
  # A subset of the compiled plugins, with a run-time plugin added. The run-time plugin must be passed in.
  roleSettings = payload.mkSettings { plugins = [ runtimePlugin ]; };
  # The tools that selection needs, for a launcher's `path`.
  roleTools = payload.runtimeInputsFor [ runtimePlugin ];
}
```

- A compiled plugin's entry carries only its resources (`extensions = [ ]`); its extension is the built-in one.
- A plugin the payload does not compile is an ordinary package entry, and Pi loads it from the store.
- A compiled plugin left out of `plugins` gets no entry, so its skills and prompts stop loading too.
- `closed = true` admits only the selected compiled plugins and the built-ins named in `enable`. Run-time plugins under
  `closed` are not verified.
- The renderer refuses two different plugins of one name, a name that is one of Pi's built-ins, a `builtin = false` plugin that
  the selection leaves out, and an `enable` name that is no built-in.

What the renderer does not do:

- It does not place the file. Pi writes `settings.json` in place, and a store file is read-only. Copy the file into the agent
  directory at activation; never link it.
- It does not emit resources for a package that has no extension. Add such a package yourself, as `{ source = pkg; }` in the
  `packages` list.
- Its output is a value, so compose it with `lib.recursiveUpdate` or a module. Module merging appends lists and
  `recursiveUpdate` replaces them.

Precedence, when a shared settings file also holds patterns: `-` beats `+`, `+` beats `!`, and `!` beats a plain include.
A `+builtin:<name>` written by hand cannot re-enable a built-in the renderer switched off with `-builtin:<name>`.

### Footguns

- A plugin that is also listed as an npm package loads at run time, and its copy replaces the compiled one. Keep it out of
  `packages`, or filter its extension off. `pi-bolt doctor` shows what loaded.
- Pattern syntax (`+`, `-`, `!`) is Pi's, so stock Pi reads it in a shared settings file. Whether a given stock version does is
  not verified here, and a shared directory is not supported. A broad pattern such as `!extensions/**` can switch off stock Pi's
  own extensions. Use `closed` only in a directory that only Pi-Bolt reads.
- `pi install` and `pi config` write `settings.json`, which fails when it is a store file. Declare plugins in Nix.
- Nothing checks that skill and command names are unique across the selected packages. Pi reports collisions when it loads them.

### Moving a shared directory onto the overlay

The renderer emits `packages` for the selection. A directory that stock Pi also reads should keep its packages in the
`piBolt.packages` overlay, so stock Pi does not see entries whose extensions are filtered off:

```nix
packages = [ ];
piBolt = {
  packagesOverlay = true;
  packages = (payload.mkSettings { }).packages;
};
```

Roles that only Pi-Bolt reads take `packages` directly.

## Large modules

The AOT compiler compiles a module only if its top-level bytecode is at most 256 KB (`BUN_JSC_maximumAOTCandidateBytecodeSize`,
in bytes). A larger module, such as a bundled `dist/index.js` with a big literal, is left out of the compiled image and runs
from the interpreter. A plugin of 288,350 bytes, for example, needs a limit of 500000:

```nix
(pi-bolt.override { maxAotCandidateBytecodeSize = 500000; }).withPlugins (_: [ largePlugin ])
```

A higher limit makes the compile take minutes and tens of gigabytes.

## Built-in extensions

Pi-Bolt compiles in its own extensions, and `pi-bolt doctor` lists them as `compiled in`:

- `llama.cpp`, `codemode`, `tool-search` and `mcp` load at start. `codemode`, `tool-search` and `mcp` are replaceable: an
  extension that registers the same tools, or `/mcp`, takes over from them.
- `herdr` loads only in a Herdr pane (`HERDR_ENV=1` with a pane id). It then reports pane state to Herdr in place of Herdr's own
  Pi integration.

Disable one with `-builtin:<name>` in the `extensions` setting. Do not run two publishers of pane state at once: `herdr` and
another extension that reports the same pane metadata.

## Loading at run time

A plugin can be loaded without being compiled in: pass its entry file to `-e`.

```sh
pi -e ${plugin.extensionPath}
```

`-e` is a flag, so it belongs to the launcher that runs Pi, and it must not come before a subcommand: `pi-bolt -e <path> doctor`
reads `doctor` as a prompt. A plugin loaded this way needs its `runtimeInputs` on `PATH`, which the compiled executable does not set
for it: put them on `PATH` in the same launcher.

Add programs to Pi with `runtimeInputs`, not with Home Manager's `extraPackages`. Home Manager wraps only Pi's own `bin/pi`
inside a new store path, so the command you run is not the package's.

## Launchers

A launcher is a script that sets the environment and `PATH` it is given, then runs the `pi` beside it in `lib/pi-bolt`. One
package carries as many as you have entrypoints: each is a config root and a tool set over the same compiled payload, so a
second role costs a script, not a second copy of Pi.

`launchers` installs them; `bin/<name>` links to each:

```nix
pkgs.pi-bolt.override {
  launchers = {
    # The default: `pi-bolt` is always installed and can be overridden by name.
    pi-bolt = { };

    pi-bolt-child = {
      env.PI_CODING_AGENT_DIR = "/home/me/.pi/roles/child";  # this role's agent directory
      path = [ pkgs.git ];                                   # added to the package's tools
    };
  };
}
```

- `env` values are quoted literally, so a path there must be absolute (`$HOME` would not expand).
- `path` is *added* to the launcher's `PATH`; the package's `runtimeInputs` and its plugins' tools are always there.
- A launcher takes no flags. A flag before the user's arguments changes which subcommand Pi takes, so what a role needs goes in
  its `settings.json` (in its agent directory), in `env`, or in `path`.
- What a launcher changes is the launch configuration only. A different compiled plugin set is a different package, not another
  launcher.

### Publishing the launchers from your own output

If your configuration builds its own installation tree, take the package's launchers rather than writing scripts: both the
launcher and the executable then resolve into the package, which is what `pi-bolt doctor` reads.

```nix
pkgs.runCommand "pi-bolt-entrypoints" { } ''
  mkdir -p $out/bin
  for f in ${launchers}/bin/*; do
    ln -s "$f" $out/bin/$(basename "$f")
  done
''
```

`readlink -f` on such a symlink lands in the package's `lib/pi-bolt`, beside the executable, so `doctor` reports it as this
installation. A copy of `lib/pi-bolt` works too, as long as the launcher ends up in the same folder as `pi`.

## Known limitations

- A plugin that ships its own `tsconfig.json` overrides the staged one for its own files. Its imports of `@earendil-works/pi-tui`
  can then resolve to a second copy of that package, so the plugin holds its own copy of `pi-tui`'s classes. Observed for
  `pi-tui` in a Pi-Bolt checkout build.
