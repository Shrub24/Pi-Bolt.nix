{
  pkgs,
  agentDir ? "/home/me/.pi/roles/greeting",
}:
let
  greeting = pkgs.piBoltPlugins.buildPiBoltPlugin {
    pname = "greeting";
    version = "1.0.0";
    src = ./greeting;
    entry = "index.ts";
    runtimeInputs = [ pkgs.git ];
  };
  payload = (pkgs.pi-bolt.withPlugins (_: [ greeting ])).override {
    pluginLock = ./plugins.lock.json;
  };
  selection = payload.select { };
in
{
  plugin = greeting;
  package = payload.override {
    launchers.pi-bolt-greeting = {
      env.PI_CODING_AGENT_DIR = agentDir;
      path = selection.runtimeInputs;
    };
  };
  inherit (selection) settings runtimeInputs;
}
