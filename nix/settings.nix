# Pi's settings for a selection of plugins, as data. Usage: docs/PLUGINS.md.
#
# A compiled plugin is a built-in extension, builtin:<name>. Its package entry carries only its resources (skills, prompts,
# themes): `extensions = [ ]` switches off the extension the package would load, so the compiled copy answers for it. A plugin
# the payload does not compile is an ordinary package entry, and Pi loads it from the store. A plugin left out of the
# selection has no entry, so its resources are not loaded either. Any other entry (an npm or git source, a filtered object)
# is passed through unchanged. `enable` and `extensions` are passed through as given, as the upstream Home Manager module
# passes `settings`: the names Pi knows are Pi's to check.
{ lib }:
let
  isPlugin = entry: builtins.isAttrs entry && entry ? piBolt;
  same = a: b: toString a == toString b;
  contains = list: plugin: lib.any (same plugin) list;
  unique = lib.foldl' (acc: plugin: if contains acc plugin then acc else acc ++ [ plugin ]) [ ];

  validate =
    {
      compiled,
      selected,
    }:
    let
      names = map (plugin: plugin.piBolt.name) (unique (selected ++ compiled));
      duplicated = lib.unique (lib.filter (name: lib.count (n: n == name) names > 1) names);
      inlined = lib.filter (plugin: !plugin.piBolt.builtin && !contains selected plugin) compiled;
    in
    if duplicated != [ ] then
      throw "pi-bolt: more than one plugin is named ${lib.concatStringsSep ", " duplicated}; builtin:<name> is one extension"
    else if inlined != [ ] then
      throw "pi-bolt: ${
        lib.concatMapStringsSep ", " (plugin: plugin.piBolt.name) inlined
      } is compiled in with builtin = false, so a selection cannot switch it off; select it"
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
    assert validate { inherit compiled selected; };
    {
      packages = map entry selected ++ passed;
    }
    // lib.optionalAttrs (generated != [ ]) { extensions = generated; };
}
