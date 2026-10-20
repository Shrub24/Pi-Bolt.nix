# Pi's settings for a selection of plugins, as data. Usage: docs/PLUGINS.md.
#
# A compiled plugin is a built-in extension, builtin:<name>. Its package entry carries only its resources (skills, prompts,
# themes): `extensions = [ ]` switches off the extension the package would load, so the compiled copy answers for it. A plugin
# the payload does not compile is an ordinary package entry, and Pi loads it from the store. A plugin left out of the
# selection has no entry, so its resources are not loaded either.
{ lib }:
let
  # Pi's own built-in extensions (packages/coding-agent/src/extensions/index.ts). herdr is on only inside a Herdr pane.
  piBuiltins = [
    "llama.cpp"
    "codemode"
    "tool-search"
    "mcp"
    "herdr"
  ];

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
  render =
    {
      compiled,
      plugins ? compiled,
      closed ? false,
      enable ? [ ],
    }:
    let
      selected = unique plugins;
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
      extensions = denied ++ allowed;
    in
    assert validate { inherit compiled selected enable; };
    { packages = map entry selected; } // lib.optionalAttrs (extensions != [ ]) { inherit extensions; };
}
