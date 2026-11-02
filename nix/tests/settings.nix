# The settings renderer (nix/settings.nix): the rules it keeps, and what Pi does with the settings it renders.
#
# Evaluation checks the rules that are ours: a plugin loads once, a compiled plugin's extension is switched off where its
# entry is, a left-out plugin has no entry, a raw entry and a listed path pass through, a duplicate name or an inlined plugin
# left out is refused. The built checks ask Pi which commands it has, with each rendered file as the agent directory's
# settings — including the shared case under stock Pi, which is the claim `shared = true` exists to make.
{
  lib,
  runCommand,
  jq,
  writeShellScriptBin,
  writeText,
  pi-bolt,
  piBoltPlugins,
  # Stock Pi, for the half of the shared claim Pi-Bolt cannot answer for itself.
  pi-coding-agent,
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
  shared = render {
    compiled = [ plugin ];
    shared = true;
  };
  sharedNothingSelected = render {
    compiled = [ plugin ];
    plugins = [ runtime ];
    shared = true;
  };

  # A plugin whose dependency is installed only by the set's lock: its own store path has no node_modules.
  locked = buildPiBoltPlugin {
    pname = "settings-locked";
    src = ./settings/locked;
    entry = "index.ts";
    pluginName = "settings-locked";
  };
  lockedLock = {
    name = "pi-bolt-plugins";
    version = "0.0.0";
    lockfileVersion = 3;
    requires = true;
    packages = {
      "" = {
        name = "pi-bolt-plugins";
        version = "0.0.0";
        workspaces = [ "pbplugins/*" ];
      };
      "node_modules/@babel/runtime" = {
        version = "7.29.10";
        resolved = "https://registry.npmjs.org/@babel/runtime/-/runtime-7.29.10.tgz";
        integrity = "sha512-NpugTzbKgGrNe45Ui32cN8vCFFMxVtP/9rtfwv0nP5FRDAjvYBxJcLVpYA9mr1jxP6cnIT7x9LUzuDTbWYYNRA==";
      };
      "node_modules/date-fns" = {
        version = "2.30.0";
        resolved = "https://registry.npmjs.org/date-fns/-/date-fns-2.30.0.tgz";
        integrity = "sha512-fnULvOpxnC5/Vg3NCiWelDsLiUc9bRwAPs/+LfTLNvetFCtCTN+yQz15C/fs4AwX1R9K5GLtLfn8QW+dWisaAw==";
        dependencies."@babel/runtime" = "^7.21.0";
      };
      "node_modules/settings-locked" = {
        resolved = "pbplugins/settings-locked";
        link = true;
      };
      "pbplugins/settings-locked" = {
        version = "0.0.0";
        dependencies.date-fns = "2.30.0";
      };
    };
  };
  lockedPayload = (pi-bolt.withPlugins (_: [ locked ])).override { pluginLock = lockedLock; };
  lockedShared = (lockedPayload.select { shared = true; }).settings;

  payload = pi-bolt.withPlugins (_: [ plugin ]);
  # The file for a directory stock Pi reads too.
  sharedFile = writeText "settings-shared.json" (
    builtins.toJSON (payload.select { shared = true; }).settings
  );
  lockedFile = writeText "settings-locked.json" (builtins.toJSON lockedShared);
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
# Shared with stock Pi, the plugin's store entry stays loadable for stock Pi, and Pi-Bolt's overlay replaces that same source
# with a resources-only entry, so only the compiled copy runs there and the store is not read twice.
assert
  shared.packages == [
    {
      source = "${plugin}";
    }
  ];
assert shared.piBolt.packagesOverlay;
assert
  shared.piBolt.packages == [
    {
      source = "${plugin}";
      extensions = [ ];
    }
  ];
# A shared file whose selection is empty has nothing to overlay.
assert !(sharedNothingSelected ? piBolt);
# A plugin whose dependencies come from the lock cannot be read from its own store path: the shared entry names the payload's
# runtime view instead, and the overlay names the same source so the replacement is in place.
assert lib.hasInfix "/pbplugins/settings-locked" (lib.head lockedShared.packages).source;
assert (lib.head lockedShared.piBolt.packages).source == (lib.head lockedShared.packages).source;
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
# A launcher already carries the payload's tools, so a selection of what it compiled adds nothing.
assert (pi-bolt.select { }).runtimeInputs == [ ];
assert
  (pi-bolt.select {
    plugins = [
      runtime
      rawEntry
    ];
  }).runtimeInputs == (pi-bolt.select { plugins = [ runtime ]; }).runtimeInputs;
# Refused: two plugins of one name, and a builtin = false plugin that the selection leaves out. The positive control shows the
# renderer accepts a valid selection, so the refusals are its own.
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
assert
  !accepts {
    compiled = [ inlined ];
    plugins = [ ];
  };
# The settings follow the final payload's compiled set, through override and withPlugins.
assert sources chained.settings.packages == [ "${plugin}" ];
runCommand "pi-bolt-settings-check" { nativeBuildInputs = [ jq ]; } ''
  export HOME=$TMPDIR PI_OFFLINE=1
  # Pi's own answer to get_commands, for an agent directory whose settings are the file given.
  ask() {
    mkdir -p agent
    cp --no-preserve=mode "$2" agent/settings.json
    printf '{"id":"1","type":"get_commands"}\n' \
      | PI_CODING_AGENT_DIR=$PWD/agent timeout 120 "$1"/bin/pi --mode rpc --no-session > "$3"
  }
  check() {
    jq -e --slurp --arg plugin "${plugin}" --arg runtime "${runtime}" "[.[] | select(.command == \"get_commands\") | .data.commands[]] as \$c | $1" "$2" > /dev/null || {
      echo "$3" >&2
      cat "$2" >&2
      exit 1
    }
  }

  # Every plugin selected: the compiled copy answers once, and its skill, prompt and the run-time plugin come from the store.
  ask ${payload} ${allFile} all.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
    and ([$c[] | select(.name == "skill:settings-skill") | .sourceInfo.source] == [$plugin])
    and ([$c[] | select(.name == "settings-prompt") | .sourceInfo.source] == [$plugin])
    and ([$c[] | select(.name == "settings-runtime") | .sourceInfo.source] == [$runtime])
  ' all.json "the compiled plugin, its resources, or the run-time plugin did not load as selected"

  # The compiled plugin left out: nothing of it loads, and the run-time plugin still does.
  ask ${payload} ${leftOutFile} left-out.json
  check '
    ([$c[] | select(.name == "settings-compiled" or .name == "skill:settings-skill" or .name == "settings-prompt")] | length == 0)
    and ([$c[] | select(.name == "settings-runtime") | .sourceInfo.source] == [$runtime])
  ' left-out.json "a left-out plugin still loaded"

  # Closed, with mcp enabled: the selected compiled plugin and mcp answer; llama, which is not enabled, does not.
  ask ${payload} ${closedFile} closed.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
    and ([$c[] | select(.name == "mcp") | .sourceInfo.path] == ["builtin:mcp"])
    and ([$c[] | select(.name == "llama")] | length == 0)
    and ([$c[] | select(.name == "settings-runtime")] | length == 0)
  ' closed.json "the closed selection did not admit exactly what it names"

  # Closed, with a listed path: the path loads although its plugin is not selected.
  ask ${payload} ${closedPathFile} closed-path.json
  check '
    ([$c[] | select(.name == "settings-runtime") | .sourceInfo.path] == [$runtime + "/index.ts"])
    and ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
  ' closed-path.json "a listed path did not load under the closed selection"

  # A shared file: Pi-Bolt matches the store entry stock Pi would load and replaces it with its resources-only entry, so the
  # compiled copy answers and nothing is loaded a second time.
  ask ${payload} ${sharedFile} shared.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["builtin:settings-compiled"])
    and ([$c[] | select(.name == "skill:settings-skill") | .sourceInfo.source] == ["${plugin}"])
  ' shared.json "a shared settings file did not give Pi-Bolt the compiled copy and its store resources"

  # A lock-backed plugin: its dependency exists only in the set's tree, so the shared file has to give stock Pi a copy that
  # reaches it. Pi-Bolt answers with the compiled copy from the same file.
  ask ${pi-coding-agent} ${lockedFile} stock-locked.json
  check '
    ([$c[] | select(.name == "settings-locked") | .sourceInfo.path | endswith("/pbplugins/settings-locked/index.ts")] == [true])
  ' stock-locked.json "stock Pi could not load a lock-backed plugin from the shared file"
  ask ${lockedPayload} ${lockedFile} pibolt-locked.json
  check '
    ([$c[] | select(.name == "settings-locked") | .sourceInfo.path] == ["builtin:settings-locked"])
  ' pibolt-locked.json "Pi-Bolt did not run its compiled copy from the shared file"

  # The same file under stock Pi: it loads the plugin from the store, which is what makes the file shared rather than
  # Pi-Bolt-only. Pinned against nixpkgs' pi-coding-agent, so a change in how Pi resolves package entries surfaces here.
  ask ${pi-coding-agent} ${sharedFile} stock-shared.json
  check '
    ([$c[] | select(.name == "settings-compiled") | .sourceInfo.path] == ["${plugin}/index.ts"])
    and ([$c[] | select(.name == "skill:settings-skill") | .sourceInfo.source] == ["${plugin}"])
  ' stock-shared.json "stock Pi did not load the shared file's plugin from the store"
  # Without `shared`, the same plugin entry switches the extension off for stock Pi too, leaving only its resources.
  ask ${pi-coding-agent} ${allFile} stock-plain.json
  check '
    ([$c[] | select(.name == "settings-compiled")] | length == 0)
    and ([$c[] | select(.name == "skill:settings-skill") | .sourceInfo.source] == ["${plugin}"])
  ' stock-plain.json "stock Pi loaded an extension the plain rendering switches off"
  touch $out
''
