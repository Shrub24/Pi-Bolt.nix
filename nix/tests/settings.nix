# The settings renderer (nix/settings.nix): the rules it keeps, and what Pi does with the settings it renders.
#
# Evaluation checks the rules that are ours: a plugin loads once, a compiled plugin's extension is switched off where its
# entry is, a left-out plugin has no entry, a raw entry and a listed path pass through, invalid selections are refused. The
# built checks ask Pi which commands it has, with each rendered file as the agent directory's settings, and compare the
# renderer's built-in list with Pi's source.
{
  lib,
  runCommand,
  jq,
  writeShellScriptBin,
  writeText,
  pi-bolt,
  piBoltPlugins,
  source,
}:
let
  inherit (piBoltPlugins) buildPiBoltPlugin;
  settingsFor = import ../settings.nix { inherit lib; };
  inherit (settingsFor) render piBuiltins;

  tool = writeShellScriptBin "pi-bolt-check-settings-tool" "printf tool";
  plugin = buildPiBoltPlugin {
    pname = "settings-plugin";
    src = ./settings/plugin;
    entry = "index.ts";
    pluginName = "settings-compiled";
  };
  runtime = buildPiBoltPlugin {
    pname = "settings-runtime";
    src = ./settings/runtime;
    entry = "index.ts";
    runtimeInputs = [ tool ];
  };
  impostor = buildPiBoltPlugin {
    pname = "settings-impostor";
    src = ./settings/runtime;
    entry = "index.ts";
    pluginName = "settings-compiled";
  };
  reserved = buildPiBoltPlugin {
    pname = "settings-reserved";
    src = ./settings/runtime;
    entry = "index.ts";
    pluginName = "mcp";
  };
  inlined = buildPiBoltPlugin {
    pname = "settings-inlined";
    src = ./settings/runtime;
    entry = "index.ts";
    builtin = false;
  };
  rawEntry = {
    source = "${runtime}";
    skills = [ ];
  };

  sources = map (entry: entry.source);
  entryOf =
    plugin: lib.findFirst (entry: entry.source == "${plugin}") (throw "no entry for ${plugin}");
  accepts = args: (builtins.tryEval (builtins.deepSeq (render args) true)).success;

  both = render {
    compiled = [ plugin ];
    plugins = [
      plugin
      runtime
    ];
  };
  leftOut = render {
    compiled = [ plugin ];
    plugins = [ runtime ];
  };

  payload = pi-bolt.withPlugins (_: [ plugin ]);
  settingsFile =
    selection: writeText "settings.json" (builtins.toJSON (payload.select selection).settings);
  allFile = settingsFile {
    plugins = [
      plugin
      runtime
    ];
  };
  leftOutFile = settingsFile { plugins = [ runtime ]; };
  closedFile = settingsFile {
    plugins = [ plugin ];
    closed = true;
    enable = [ "mcp" ];
  };
  closedPathFile = settingsFile {
    plugins = [ plugin ];
    closed = true;
    extensions = [ "${runtime}/index.ts" ];
  };

  chained = ((pi-bolt.override { jit = true; }).withPlugins (_: [ plugin ])).select { };

  builtinIds = runCommand "pi-bolt-builtin-ids" { } ''
    sed -n '/builtInExtensions/,/^];/p' ${source}/packages/coding-agent/src/extensions/index.ts \
      | grep -o 'name: "[^"]*"' | cut -d'"' -f2 | sort -u > pi
    printf '%s\n' ${lib.escapeShellArgs piBuiltins} | sort -u > ours
    diff ours pi
    touch $out
  '';
in
# A plugin listed twice loads once.
assert
  sources
    (render {
      compiled = [ plugin ];
      plugins = [
        plugin
        plugin
      ];
    }).packages == [ "${plugin}" ];
# A compiled plugin's entry switches its extension off; a run-time plugin's entry loads it.
assert (entryOf plugin both.packages).extensions == [ ];
assert !((entryOf runtime both.packages) ? extensions);
# A plugin left out of the selection has no entry, and its compiled copy is switched off by name.
assert sources leftOut.packages == [ "${runtime}" ];
assert lib.elem "-builtin:settings-compiled" leftOut.extensions;
# A raw entry is passed through unchanged, and a listed path is appended as given.
assert lib.elem rawEntry
  (render {
    compiled = [ plugin ];
    plugins = [
      plugin
      rawEntry
    ];
  }).packages;
assert lib.elem "/x/extra.ts"
  (render {
    compiled = [ plugin ];
    extensions = [ "/x/extra.ts" ];
  }).extensions or [ ];
# A selection's tools reach the launcher's PATH with the package's own, and a raw entry adds none.
assert lib.elem tool (pi-bolt.select { plugins = [ runtime ]; }).runtimeInputs;
assert
  (pi-bolt.select {
    plugins = [
      runtime
      rawEntry
    ];
  }).runtimeInputs == (pi-bolt.select { plugins = [ runtime ]; }).runtimeInputs;
# Refused: two plugins of one name, a Pi built-in's name, a compiled plugin built builtin = false and left out, and an enable
# id that names nothing. The first assertion shows the renderer accepts a valid selection, so the refusals are its own.
assert accepts {
  compiled = [ plugin ];
  plugins = [
    plugin
    runtime
  ];
  enable = [ "mcp" ];
};
assert
  !accepts {
    compiled = [
      plugin
      impostor
    ];
  };
assert !accepts { compiled = [ reserved ]; };
assert
  !accepts {
    compiled = [ inlined ];
    plugins = [ ];
  };
assert
  !accepts {
    compiled = [ plugin ];
    enable = [ "mcpp" ];
  };
# The settings follow the final payload's compiled set, through override and withPlugins.
assert sources chained.settings.packages == [ "${plugin}" ];
runCommand "pi-bolt-settings-check" { nativeBuildInputs = [ jq ]; } ''
  export HOME=$TMPDIR PI_OFFLINE=1
  : ${builtinIds} # the renderer's built-in list matches Pi's source
  # Pi's own answer to get_commands, for an agent directory whose settings are the file given.
  ask() {
    mkdir -p agent
    cp --no-preserve=mode "$1" agent/settings.json
    printf '{"id":"1","type":"get_commands"}\n' \
      | PI_CODING_AGENT_DIR=$PWD/agent timeout 120 ${payload}/bin/pi --mode rpc --no-session > "$2"
  }
  check() {
    jq -e --slurp --arg plugin "${plugin}" --arg runtime "${runtime}" "[.[] | select(.command == \"get_commands\") | .data.commands[]] as \$c | $1" "$2" > /dev/null || {
      echo "$3" >&2
      cat "$2" >&2
      exit 1
    }
  }

  # Every plugin selected: the compiled copy answers once, and its skill, prompt and the run-time plugin come from the store.
  ask ${allFile} all.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
    and ([$c[] | select(.name == "skill:settings-skill") | .sourceInfo.source] == [$plugin])
    and ([$c[] | select(.name == "settings-prompt") | .sourceInfo.source] == [$plugin])
    and ([$c[] | select(.name == "settings-runtime") | .sourceInfo.source] == [$runtime])
  ' all.json "the compiled plugin, its resources, or the run-time plugin did not load as selected"

  # The compiled plugin left out: nothing of it loads, and the run-time plugin still does.
  ask ${leftOutFile} left-out.json
  check '
    ([$c[] | select(.name == "settings-compiled" or .name == "skill:settings-skill" or .name == "settings-prompt")] | length == 0)
    and ([$c[] | select(.name == "settings-runtime") | .sourceInfo.source] == [$runtime])
  ' left-out.json "a left-out plugin still loaded"

  # Closed, with mcp enabled: the selected compiled plugin and mcp answer; llama, which is not enabled, does not.
  ask ${closedFile} closed.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
    and ([$c[] | select(.name == "mcp") | .sourceInfo.path] == ["builtin:mcp"])
    and ([$c[] | select(.name == "llama")] | length == 0)
    and ([$c[] | select(.name == "settings-runtime")] | length == 0)
  ' closed.json "the closed selection did not admit exactly what it names"

  # Closed, with a listed path: the path loads although its plugin is not selected.
  ask ${closedPathFile} closed-path.json
  check '
    ([$c[] | select(.name == "settings-runtime") | .sourceInfo.path] == [$runtime + "/index.ts"])
    and ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
  ' closed-path.json "a listed path did not load under the closed selection"
  touch $out
''
