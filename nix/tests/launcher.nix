# The launcher contract, in two parts.
#
# The generator: the environment and PATH it sets, its arguments passed through one by one, and that it still finds `pi` after
# the whole tree is moved (it resolves `pi` relative to itself, not by store path, so a consumer's copy works).
#
# The package: every launcher is installed beside the executable and linked from bin/, which is the folder rule `pi-bolt doctor`
# applies when it decides whether a launcher is this installation.
{
  runCommand,
  writeShellScript,
  writeShellScriptBin,
  callPackage,
  pi-bolt,
}:
let
  mkLauncher = callPackage ../launcher.nix { };
  probe = writeShellScriptBin "probe-tool" "echo tool";
  launcher = mkLauncher {
    name = "pi-bolt-test";
    env.PI_TEST_ROLE = "role 'quoted' \$dollar";
    path = [ probe ];
  };
  stub = writeShellScript "pi" ''
    echo "role=$PI_TEST_ROLE"
    echo "tool=$(probe-tool)"
    for arg in "$@"; do echo "arg=$arg"; done
  '';
  withRole = pi-bolt.override {
    launchers.pi-bolt-role.env.PI_TEST_ROLE = "role";
  };
in
runCommand "pi-bolt-launcher-check" { } ''
  mkdir -p $out/lib/pi-bolt $out/bin
  cp ${stub} $out/lib/pi-bolt/pi
  cp ${launcher} $out/lib/pi-bolt/pi-bolt-test
  ln -s ../lib/pi-bolt/pi-bolt-test $out/bin/pi-bolt-test

  expected=$(printf '%s\n' "role=role 'quoted' \$dollar" "tool=tool" "arg=one" "arg=two words")
  actual=$($out/bin/pi-bolt-test one "two words")
  [ "$actual" = "$expected" ] || { echo "launcher output differs:"; echo "$actual"; exit 1; }

  cp -r $out moved
  [ "$(./moved/bin/pi-bolt-test one "two words")" = "$expected" ] || { echo "moved launcher does not find pi"; exit 1; }
  rm -rf moved

  role=${withRole}
  executable=$(dirname "$(readlink -f "$role/lib/pi-bolt/pi")")
  for name in pi-bolt pi-bolt-role; do
    [ -f "$role/lib/pi-bolt/$name" ] || { echo "$name is not beside the executable"; exit 1; }
    [ "$(readlink -f "$role/bin/$name")" = "$role/lib/pi-bolt/$name" ] || { echo "bin/$name is not its launcher"; exit 1; }
    [ "$(dirname "$(readlink -f "$role/bin/$name")")" = "$executable" ] ||
      { echo "bin/$name is not in the executable's folder"; exit 1; }
  done
  [ "$(readlink -f "$role/bin/pi")" = "$role/lib/pi-bolt/pi-bolt" ] || { echo "bin/pi is not the default launcher"; exit 1; }

  said=$(HOME=$TMPDIR $role/bin/pi-bolt-role --version 2>&1)
  grep -q 'Pi-Bolt' <<< "$said" || { echo "the role launcher did not run Pi:"$'\n'"$said" >&2; exit 1; }

  touch $out/done
''
