# mkLauncher: a script that sets the environment and PATH it is given, then runs the `pi` beside it. The package's own launcher
# is one of these, and a consumer's role launchers are the same function, so the two cannot drift.
#
# It finds `pi` relative to itself, not by store path, so it works in any copy of lib/pi-bolt. It passes its arguments through
# unchanged: flags belong to the caller, who places them outside this function, since a flag before the user's arguments changes
# which subcommand Pi takes (docs/PLUGINS.md, "Launchers").
{
  lib,
  coreutils,
  runtimeShell,
  writeTextFile,
}:
{
  name ? "pi-bolt",
  env ? { },
  path ? [ ],
}:
writeTextFile {
  inherit name;
  executable = true;
  text = ''
    #!${runtimeShell}
    ${
      lib.concatStrings (
        lib.mapAttrsToList (key: value: "export ${key}=${lib.escapeShellArg value}\n") env
      )
    }${
      lib.optionalString (
        path != [ ]
      ) "export PATH=${lib.escapeShellArg (lib.makeBinPath path)}:\"$PATH\"\n"
    }exec "$(${coreutils}/bin/dirname "$(${coreutils}/bin/readlink -f "$0")")/pi" "$@"
  '';
}
