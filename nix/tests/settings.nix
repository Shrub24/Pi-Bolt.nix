# The settings renderer (nix/settings.nix): the rules it keeps, and what Pi does with the settings it renders.
#
# Evaluation checks the rules that are ours: a plugin loads once, a compiled plugin's extension is switched off where its
# entry is, a left-out plugin has no entry, invalid selections are refused. The built check asks Pi which commands it has,
# with each rendered file as the agent directory's settings: which copy answered, and whether the resources came along.
{
  lib,
  runCommand,
  jq,
  writeShellScriptBin,
  pi-bolt,
  piBoltPlugins,
}:
let
  inherit (piBoltPlugins) buildPiBoltPlugin;
  inherit (import ../settings.nix { inherit lib; }) render;

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
  allFile = payload.mkSettingsFile {
    plugins = [
      plugin
      runtime
    ];
  };
  leftOutFile = payload.mkSettingsFile { plugins = [ runtime ]; };
  closedFile = payload.mkSettingsFile {
    plugins = [ plugin ];
    closed = true;
    enable = [ "mcp" ];
  };
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
# A run-time plugin's tools reach the launcher's PATH with the package's own.
assert lib.elem tool (pi-bolt.runtimeInputsFor [ runtime ]);
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
assert
  sources (((pi-bolt.override { jit = true; }).withPlugins (_: [ plugin ])).mkSettings { }).packages
  == [
    "${plugin}"
  ];
runCommand "pi-bolt-settings-check" { nativeBuildInputs = [ jq ]; } ''
  export HOME=$TMPDIR PI_OFFLINE=1
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
  touch $out
''
