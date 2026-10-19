# pi-bolt.mkLauncher's contract, with a stub in place of Pi: the environment and PATH it sets, its arguments passed through one
# by one, and that it still finds `pi` after the whole tree is moved (a consumer copies lib/pi-bolt).
{
  runCommand,
  writeShellScript,
  writeShellScriptBin,
  pi-bolt,
}:
let
  probe = writeShellScriptBin "probe-tool" "echo tool";
  launcher = pi-bolt.mkLauncher {
    name = "pi-bolt-test";
    env.PI_TEST_ROLE = "role 'quoted' \$dollar";
    path = [ probe ];
  };
  stub = writeShellScript "pi" ''
    echo "role=$PI_TEST_ROLE"
    echo "tool=$(probe-tool)"
    for arg in "$@"; do echo "arg=$arg"; done
  '';
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

  touch $out/done
''
