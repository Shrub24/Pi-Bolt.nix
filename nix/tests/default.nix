# The flake's plugin contract check: compiled in and loaded from the store.
#
# consumer imports helper by its package name, `ms` from its lockfile and data.txt through an explicit store-path patch.
# helper is also registered, so it must be staged once and shared. Its declared runtime tool must reach consumer's PATH.
# The model consumer registers is named after what it saw, and `--list-models` prints it.
{
  lib,
  runCommand,
  writeShellScriptBin,
  makeBinaryWrapper,
  pi-bolt,
  piBoltPlugins,
}:
let
  inherit (piBoltPlugins) buildPiBoltPlugin;
  tool = writeShellScriptBin "pi-bolt-check-tool" "printf 'tool' ";
  helper = buildPiBoltPlugin {
    pname = "pi-bolt-check-helper";
    src = ./helper;
    entry = "index.ts";
    packageName = "@pi-bolt-check/helper";
    pluginName = "check-helper";
    runtimeInputs = [ tool ];
  };

  consumer = buildPiBoltPlugin {
    pname = "pi-bolt-check-consumer";
    src = ./consumer;
    entry = "index.ts";
    dependencies = [ helper ];
    # Distinct names that used to produce the same JavaScript import binding.
    pluginName = "check_helper";
    packageLock = ./consumer/package-lock.json;
    postPatch = ''
      substituteInPlace index.ts \
        --replace-fail 'new URL("./data.txt", import.meta.url)' "\"$out/data.txt\""
    '';
  };

  # No node_modules of its own: date-fns comes from the set's lock.
  lockdep = buildPiBoltPlugin {
    pname = "pi-bolt-check-lockdep";
    src = ./lockdep;
    entry = "index.ts";
  };
  # What update-plugin-lock writes for lockdep: a standalone project with the plugin as a workspace. yaml is one Pi has at
  # another version, and the set's tree is resolved before Pi's, so the plugin gets the lock's.
  member = "pi-bolt-check-lockdep";
  pluginLock = {
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
        engines.node = ">=6.9.0";
      };
      "node_modules/date-fns" = {
        version = "2.30.0";
        resolved = "https://registry.npmjs.org/date-fns/-/date-fns-2.30.0.tgz";
        integrity = "sha512-fnULvOpxnC5/Vg3NCiWelDsLiUc9bRwAPs/+LfTLNvetFCtCTN+yQz15C/fs4AwX1R9K5GLtLfn8QW+dWisaAw==";
        dependencies."@babel/runtime" = "^7.21.0";
        engines.node = ">=0.11";
      };
      "node_modules/${member}" = {
        resolved = "pbplugins/${member}";
        link = true;
      };
      "node_modules/yaml" = {
        version = "1.10.2";
        resolved = "https://registry.npmjs.org/yaml/-/yaml-1.10.2.tgz";
        integrity = "sha512-r3vXyErRCYJ7wg28yvBY5VSoAF8ZvlcW9/BwUzEtUsjvX/DKs24dIkuwjtuprwJJHsbyUbLApepYTR1BN4uHrg==";
        engines.node = ">= 6";
      };
      "pbplugins/${member}" = {
        version = "0.0.0";
        dependencies = {
          date-fns = "2.30.0";
          yaml = "1.10.2";
        };
      };
    };
  };
  # A lock that lists a plugin this package does not compile.
  unknownPluginLock = lib.recursiveUpdate pluginLock {
    packages."pbplugins/ghost".version = "0.0.0";
  };

  built =
    (pi-bolt.withPlugins (ps: [
      ps.word-count
      helper
      consumer
      helper
      lockdep
    ])).override
      { inherit pluginLock; };
  # What a consumer that wants a plugin at run time owns: its own launcher, the plugin's store path and its tools.
  runtime = runCommand "pi-bolt-runtime-check" { nativeBuildInputs = [ makeBinaryWrapper ]; } ''
    mkdir -p $out/bin
    makeBinaryWrapper ${lib.getExe pi-bolt} $out/bin/pi-bolt \
      ${
        lib.optionalString (
          consumer.piBolt.runtimeInputs != [ ]
        ) "--prefix PATH : ${lib.makeBinPath consumer.piBolt.runtimeInputs}"
      } \
      --add-flag -e --add-flag ${consumer.extensionPath}
  '';
  conflicting = pi-bolt.withPlugins (_: [
    helper
    (helper.overrideAttrs (old: {
      version = "1";
      src = old.src;
    }))
  ]);
  expected = "hello-fromdisk-3600000-loads1-tool";
in
# Two plugins of one name are refused when the executable's derivation is evaluated.
assert !(builtins.tryEval conflicting.unwrapped.drvPath).success;
assert (builtins.tryEval built.unwrapped.drvPath).success;
# A lock listing a plugin this package does not compile is refused, naming it.
assert
  !(builtins.tryEval (built.override { pluginLock = unknownPluginLock; }).unwrapped.drvPath).success;
# A plugin's own lock and a ready node_modules folder are two ways to say one thing: both is refused.
assert
  !(builtins.tryEval
    (buildPiBoltPlugin {
      pname = "pi-bolt-check-both";
      src = ./helper;
      entry = "index.ts";
      packageLock = ./consumer/package-lock.json;
      nodeModules = "/nonexistent";
    }).drvPath
  ).success;
# A plugin given no version still has a name (its default is "0").
assert
  (buildPiBoltPlugin {
    pname = "pi-bolt-check-versionless";
    src = ./helper;
    entry = "index.ts";
  }).name == "pi-bolt-check-versionless-0";
assert lib.elem tool built.unwrapped.runtimeInputs;
assert lib.elem tool built.runtimeInputs;
# A launcher-only change leaves the compiled payload alone.
assert
  pi-bolt.unwrapped.drvPath == (pi-bolt.overrideAttrs (_: {
    postInstall = "touch $out/launcher-only";
  })).unwrapped.drvPath;
runCommand "pi-bolt-plugins-check" { } ''
  export HOME=$TMPDIR PI_OFFLINE=1
  test -x ${built.unwrapped}/lib/pi-bolt/pi
  # Compiled in: every plugin is a built-in extension, and the consumer's model reports what it saw.
  ${lib.getExe built} --list-models pi-bolt-check > models.txt 2>&1 || { cat models.txt; exit 1; }
  cat models.txt
  grep -q -- '${expected}' models.txt || {
    echo "expected the compiled-in consumer's model ${expected}" >&2
    exit 1
  }
  # What the lock installed is staged for the plugin that has no node_modules of its own, and the set's tree is resolved
  # before Pi's: yaml is the lock's 1.10.2, not the version Pi carries.
  ${lib.getExe built} --list-models pi-bolt-lock > lock.txt 2>&1 || { cat lock.txt; exit 1; }
  grep -q -- 'lock-2000-yaml-1.10.2' lock.txt || {
    echo "expected lockdep's model: date-fns from the lock, and its own yaml, not Pi's" >&2
    exit 1
  }
  # Turned off as any built-in is: no model.
  ${lib.getExe built} --no-extensions --list-models pi-bolt-check > off.txt 2>&1 || true
  ! grep -q -- '${expected}' off.txt
  # The same patched plugin and its transitive runtime tool, loaded from the store instead of compiled in.
  ${lib.getExe' runtime "pi-bolt"} --list-models pi-bolt-check > runtime.txt 2>&1 || { cat runtime.txt; exit 1; }
  cat runtime.txt
  grep -q -- '${expected}' runtime.txt
  touch $out
''
