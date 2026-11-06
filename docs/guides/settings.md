---
title: Settings and selections
---

# Settings and selections

A payload is what is compiled into the executable. A **selection** is what one agent directory loads from it: it returns the
`settings` entries and the `runtimeInputs` tools for that directory. Both are values; nothing is written.

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

With one directory that is all there is. Compiled plugins render as package entries with `extensions = [ ]`, so Pi finds their
skills, prompts and themes without loading a second copy of the extension. Arguments and exact output are in the
[selection reference](../reference/selection.md).

## Several directories from one payload

Each directory gets its own selection of the same executable: a subset of plugins, a closed toolset, its own settings.

```nix
let
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
    settings = (payload.select { }).settings;
  };
}
```

Write `child.settings` into the child directory yourself; a [launcher](launchers.md) only points at it.

## Run it beside stock Pi

Both binaries read `~/.pi/agent` by default. To run them on one settings file, render it with `shared = true`:

```nix
programs.pi-coding-agent.settings = (payload.select { shared = true; }).settings;
```

Stock Pi loads each compiled plugin from the store; Pi-Bolt replaces that entry with its AOT copy. To keep them apart, give
Pi-Bolt its own directory with `configDir` or a launcher. The rendered JSON and matching rules are in the
[reference](../reference/selection.md#shared-settings).

An entry that is not a plugin derivation is passed through to both binaries, so `"npm:some-package"` installs at run time in
each. Its tools are not in `runtimeInputs`; add them with `extraPackages` or a launcher's `path`.

## Settings are read-only

Home Manager links `settings.json` into the store. Pi cannot then save edits from `/settings`, `pi config` or `pi install`: the
write fails, applies to the running process and is gone on restart. Change the Nix option and switch. A directory Pi must write
needs its own writable copy made at activation.

## Combining settings

Home Manager's JSON options append lists across definitions; `lib.recursiveUpdate` replaces them. Appending a second entry for a
compiled plugin restores its run-time copy, which then answers instead of the AOT one. `pi-bolt doctor` shows which copy loaded.
