---
title: Settings and selections
---

# Settings and selections

`select` returns settings and tools for one selection. It does not write files or install a package.

```nix
let
  payload = pkgs.pi-bolt.withPlugins (ps: [ ps.word-count ]);
  selection = payload.select { };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = payload;
    settings = selection.settings;
  };
}
```

A compiled extension is already in the executable. Its generated package entry uses `extensions = [ ];` so Pi reads its
resources without loading a second extension copy. This is how skills, prompt templates and themes remain available from the
store. See the [selection reference](../reference/selection.md) for exact rendering rules.

## Select a different set

```nix
selection = payload.select {
  plugins = [ runtimePlugin "npm:some-pi-package" ];
  extensions = [ "${extraExtension}/index.ts" ];
};
```

A plugin not compiled into `payload` is loaded at runtime. Omitted compiled plugins are disabled and their package resources
are omitted. Ordinary Pi package entries—npm/git sources or filtered objects—pass through unchanged.

Use `selection.runtimeInputs` on a launcher's `path` to include tools for runtime plugins. Raw package entries carry no tool
metadata: add their external programs explicitly. The payload's own tools are always included.

`closed = true` restricts discovered extensions and built-ins to the selection and the IDs in `enable`. Explicit `extensions`
paths still load. Runtime package entries under closed mode have not been behaviourally verified; do not treat this as a
security boundary. Unknown `enable` names are not rejected. Inspect the result with `pi-bolt doctor`.

## Combine with other settings

Home Manager's JSON options append lists across module definitions. `lib.recursiveUpdate` replaces lists instead. Choose the
merge deliberately; appending a second package entry can restore the runtime copy that the generated filter disabled.

Avoid also installing a compiled plugin through the shared `packages` list without filtering its extension: a colliding runtime
copy can replace the compiled one and lose its Nix patches. `pi-bolt doctor` shows which copy loaded. Skill and command names
are not checked across packages; Pi reports collisions at load time.

## Store-linked or writable settings

Home Manager normally links `settings.json` to the store. This keeps Nix authoritative. Pi cannot persist changes from
`/settings`, `pi config` or package-management commands into that read-only file. Some changes can appear to work for the
current session and disappear after restart; `pi-bolt doctor` reports recorded write errors.

Keep settings declarative unless persistent runtime edits are intentional. For a writable role directory, copy generated JSON
at activation with a writable mode—for example `cp --no-preserve=mode`—and decide when activation should replace local edits.
Do not add a second file manager for a file Home Manager already owns.

## Share configuration with stock Pi

Place Pi-Bolt-specific package entries in its overlay when stock Pi reads the same settings:

```nix
piBolt = {
  packagesOverlay = true;
  packages = (payload.select { }).settings.packages;
};
```

Keep stock Pi's ordinary entries in top-level `packages`. Exclude a conflicting inherited package with a `-source` entry in
`piBolt.packages`, such as `"-npm:some-pi-package"`, then add the selected store entry. Roles used only by Pi-Bolt can use the
selection's top-level `packages` directly.

This example moves package entries only; merge any generated `extensions` rules separately according to the intended behaviour
of the shared directory. The renderer does not construct a Pi-Bolt overlay automatically.
