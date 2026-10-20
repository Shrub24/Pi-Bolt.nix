# Pi's settings for a selection of plugins, as data. Usage: docs/PLUGINS.md.
#
# A compiled plugin is a built-in extension, builtin:<name>. Its package entry carries only its resources (skills, prompts,
# themes): `extensions = [ ]` switches off the extension the package would load, so the compiled copy answers for it. A plugin
# the payload does not compile is an ordinary package entry, and Pi loads it from the store. A plugin left out of the
# selection has no entry, so its resources are not loaded either. Any other entry (an npm or git source, a filtered object)
# is passed through unchanged.
{ lib }:
let
  # Pi's built-in extension names (packages/coding-agent/src/extensions/index.ts). herdr is on only inside a Herdr pane.
  # nix/tests/settings.nix checks this list against that file.
  piBuiltins = [
    "llama.cpp"
    "codemode"
    "tool-search"
    "mcp"
    "herdr"
  ];

  isPlugin = entry: builtins.isAttrs entry && entry ? piBolt;
  same = a: b: toString a == toString b;
  contains = list: plugin: lib.any (same plugin) list;
  unique = lib.foldl' (acc: plugin: if contains acc plugin then acc else acc ++ [ plugin ]) [ ];

  validate =
    {
      compiled,
      selected,
      enable,
    }:
    let
      names = map (plugin: plugin.piBolt.name) (unique (selected ++ compiled));
      duplicated = lib.unique (lib.filter (name: lib.count (n: n == name) names > 1) names);
      reserved = lib.intersectLists names piBuiltins;
      inlined = lib.filter (plugin: !plugin.piBolt.builtin && !contains selected plugin) compiled;
      known =
        piBuiltins
        ++ map (plugin: plugin.piBolt.name) (lib.filter (plugin: plugin.piBolt.builtin) compiled);
      unknown = lib.subtractLists known enable;
      list = lib.concatMapStringsSep ", " (plugin: plugin.piBolt.name);
    in
    if duplicated != [ ] then
      throw "pi-bolt: more than one plugin is named ${lib.concatStringsSep ", " duplicated}; builtin:<name> is one extension"
    else if reserved != [ ] then
      throw "pi-bolt: a plugin is named ${lib.concatStringsSep ", " reserved}, one of Pi's own built-in extensions"
    else if inlined != [ ] then
      throw "pi-bolt: ${list inlined} is compiled in with builtin = false, so a selection cannot switch it off; select it"
    else if unknown != [ ] then
      throw "pi-bolt: enable names no built-in extension: ${lib.concatStringsSep ", " unknown}"
    else
      true;
in
{
  inherit piBuiltins;

  render =
    {
      compiled,
      plugins ? compiled,
      closed ? false,
      enable ? [ ],
      extensions ? [ ],
    }:
    let
      selected = unique (lib.filter isPlugin plugins);
      passed = lib.filter (entry: !isPlugin entry) plugins;
      selectedBuiltins = lib.filter (plugin: contains compiled plugin && plugin.piBolt.builtin) selected;
      leftOut = lib.filter (plugin: !contains selected plugin && plugin.piBolt.builtin) compiled;
      entry =
        plugin:
        { source = "${plugin}"; } // lib.optionalAttrs (contains compiled plugin) { extensions = [ ]; };
      denied =
        if closed then
          [
            "!builtin:*"
            "!extensions/**"
          ]
        else
          map (plugin: "-builtin:${plugin.piBolt.name}") leftOut;
      # Under `closed`, the selected built-ins must be allowed back past the `!builtin:*` above; otherwise they load anyway.
      allowed = map (id: "+builtin:${id}") (
        lib.optionals closed (map (plugin: plugin.piBolt.name) selectedBuiltins) ++ enable
      );
      # Paths the caller lists load as given: a deny pattern above does not match an explicitly listed path.
      generated = denied ++ allowed ++ extensions;
    in
    assert validate { inherit compiled selected enable; };
    {
      packages = map entry selected ++ passed;
    }
    // lib.optionalAttrs (generated != [ ]) { extensions = generated; };
}
