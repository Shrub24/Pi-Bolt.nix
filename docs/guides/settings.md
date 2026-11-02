---
title: Settings and selections
---

# Settings and selections

A payload decides what is compiled into the executable. A **selection** decides what one agent directory loads from it, and
returns the two things that directory needs: its `settings.json` entries, and the tools its launcher must add. Both are values;
nothing is written.

```nix
let
  extensions = pi-extensions.packages.${pkgs.stdenv.hostPlatform.system};
  payload = pkgs.pi-bolt.withPlugins (_: [ extensions.herdsman extensions.tool-renderer ]);
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = payload;
    settings = (payload.select { }).settings;
  };
}
```

With one directory that is the whole story: the selection is everything the payload compiled, and `settings` is the JSON Pi would
otherwise have to hand-write. The rest of this page is for more than one directory.

## One payload, several directories

That split is what lets one payload serve several directories. The executable and its compiled plugins are shared, and each
directory gets its own selection: a subset of plugins, a closed toolset, a different model or different prompts.

```nix
let
  extensions = pi-extensions.packages.${pkgs.stdenv.hostPlatform.system};
  payload = pkgs.pi-bolt.withPlugins (_: [ extensions.herdsman extensions.tool-renderer ]);
  lead = payload.select { };
  child = payload.select {
    plugins = [ extensions.herdsman ];
    closed = true;
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = payload.override {
      launchers.pi-bolt-child = {
        env.PI_CODING_AGENT_DIR = "/home/me/.pi/roles/child";
        path = child.runtimeInputs;
      };
    };
    settings = lead.settings;
  };
}
```

The lead directory takes the whole compiled set. The child entrypoint points at a directory of its own, where activation writes
`child.settings`; see [where the settings go](#where-the-settings-go). One payload is built, so both directories run the same
executable — only their settings differ.

## What a selection renders

`settings.packages` contains each selected plugin once:

| Entry | Rendered value |
| --- | --- |
| Plugin compiled in this payload | `{ source = "<store path>"; extensions = [ ]; }` |
| Plugin not compiled in this payload | `{ source = "<store path>"; }` |
| Ordinary Pi package entry | Passed through unchanged. |

`extensions = [ ]` is the point of the first row: the plugin is already in the executable, so its package entry exists only to let
Pi find its skills, prompt templates and themes in the store. Without it, Pi loads a second copy of the extension.

`settings.extensions` carries the rules for what the selection leaves out: `-builtin:<name>` for a compiled plugin it excludes,
and under `closed`, `!builtin:*` and `!extensions/**` followed by `+builtin:<name>` for each selected one.

## A subset, or a plugin at run time

`plugins` replaces the selection; the default is everything the payload compiled.

```nix
child = payload.select {
  plugins = [ runtimePlugin "npm:some-pi-package" ];
  extensions = [ "${extraExtension}/index.ts" ];
};
```

A plugin the payload does not compile loads from the store at run time, so its npm dependencies must reach Pi another way:
`packageLock` on that plugin, or a prepared `nodeModules` tree. A compile-time `pluginLock` does not provision a run-time plugin.

`closed = true` restricts the directory to the selection plus the IDs in `enable`; explicit `extensions` paths still load.
Unknown `enable` names are not rejected, and runtime package entries under closed mode are untested. Inspect the result with
`pi-bolt doctor`; this is configuration, not a sandbox.

## Where the settings go

Home Manager links `settings.json` to the store, which keeps Nix authoritative. Pi cannot then persist edits from `/settings`,
`pi config` or `pi install`: the write fails, the change applies for the running process, and it is gone after a restart. The
command that tried to write reports it — `pi install` prints the `EACCES` and still exits 0 — while a later `pi-bolt doctor` does
not, because the error lives in the process that recorded it. Recovery is `home-manager switch` or editing the Nix option.

Keep settings declarative unless persistent runtime edits are intended. A directory Pi must write needs its own copy, made at
activation with a writable mode (`cp --no-preserve=mode`), and a rule for when activation replaces local edits. Do not add a
second file manager for a file Home Manager already owns.

## Share configuration with stock Pi

One settings file can serve both binaries: Pi-Bolt compiled a plugin in, and stock Pi loads that same plugin from the store. There
is no second copy to fetch — both point at the one derivation. What differs is only which part of it runs.

```nix
programs.pi-coding-agent.settings = (payload.select {
  shared = true;
}).settings;
```

For each compiled plugin the selection emits the store entry, and an overlay that replaces it with the same source minus its
extension:

```json
{
  "packages": [{ "source": "/nix/store/…-radar" }],
  "piBolt": {
    "packagesOverlay": true,
    "packages": [{ "source": "/nix/store/…-radar", "extensions": [] }]
  }
}
```

Stock Pi reads `packages` and loads the plugin's extension from the store. Pi-Bolt applies its overlay first — matching on the
same source, so it replaces that entry in place — and `extensions = []` switches off the extension while leaving the plugin's
skills, prompts and themes discoverable. Pi-Bolt then runs its AOT copy and no runtime copy is loaded.

Entries are matched by source, so a replacement needs no exclusion: the overlay entry names the identical store path, removes the
earlier entry and takes its position. Without the overlay that entry loads at run time, and that copy wins over the compiled one —
the AOT code and any patches applied to it go unused. That is why the two declarations are generated together.

When the payload takes its plugins' dependencies from a `pluginLock`, the entry names a **runtime view** instead of the plugin's
own store path: a copy of each plugin's sources under one root whose `node_modules` is the lock's installed tree. Pi resolves a
local package's imports from where its files are, and a plugin's own store path has none of them, so pointing stock Pi there fails
with `Cannot find module`. The view costs the source copies only; the dependency tree stays one shared copy. Its member names are the plugin names the
payload compiles — `tool-renderer`, not the manifest's folder — so pass `NAME=…` to `update-plugin-lock` when the two differ; a
lock that names something else is refused rather than rendered.

An exclusion (`-npm:<name>`) is for the other case: the same plugin also declared from a different source, such as an npm entry
left in `packages`. Identities differ then, both entries survive, and Pi-Bolt would load the runtime copy — remove that source in
`piBolt.packages` before adding the store entry.

`piBolt` is Pi-Bolt's alone — stock Pi validates settings with extra keys allowed and never reads it.

Pi-Bolt-only entries need no pair; add them to the overlay directly.

```nix
programs.pi-coding-agent.settings = {
  packages = [ "npm:some-shared-package" ];
  piBolt = {
    packagesOverlay = true;
    packages = (payload.select { }).settings.packages;
  };
};
```

### Plugins you do not compile

A plugin that should stay on npm in both binaries is listed as its source, not as a derivation:

```nix
payload.select {
  shared = true;
  plugins = [
    # compiled in: AOT for Pi-Bolt, npm for stock Pi
    pi-extensions.packages.${system}.herdsman
    # not compiled: npm for both, installed into the agent directory at run time
    "npm:some-runtime-plugin"
  ];
}
```

The renderer passes ordinary entries through unchanged, adding no `extensions` filter and no overlay entry, so both binaries
resolve and install the source the same way. This is the whole difference: a compiled plugin is AOT in Pi-Bolt and npm in stock
Pi; an uncompiled one is npm in both.

Two consequences. The tools such an entry needs on `PATH` are not in `select.runtimeInputs`, because a raw entry carries no
plugin metadata — add them with `extraPackages` or the launcher's `path`. And it is installed at run time from the registry, so it
needs network and a package manager, and `nix flake update` does not pin it.

Listing a plugin both ways declares both, and they have different sources, so each is honoured: stock Pi loads the npm entry,
and in Pi-Bolt the runtime copy answers, because a runtime extension replaces a compiled built-in of the same name. Listing only
the derivation gives both binaries a copy to run — AOT in Pi-Bolt, the store path in stock Pi — which is what `shared` exists for.

`shared` changes package entries only; merge any generated `extensions` rules separately, according to the intended behaviour of
the shared directory.

## Combine with other settings

Home Manager's JSON options append lists across module definitions. `lib.recursiveUpdate` replaces lists instead. Choose the
merge deliberately; appending a second package entry can restore the runtime copy that the generated filter disabled.

A compiled plugin installed through the shared `packages` list without filtering its extension loads at run time, and a runtime
extension replaces the compiled built-in of the same name — so that copy answers, without the AOT code or the Nix patches.
`pi-bolt doctor` shows which copy loaded. Skill and command names
are not checked across packages; Pi reports collisions at load time.

The [selection reference](../reference/selection.md) lists the arguments, the exact rendering rules and the constraints.
