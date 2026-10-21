# check-dependencies.js: what a compiled plugin declares must be what is staged for it. The cases are the incident this guards
# (a pin older than the range the plugin declares) and the two places a package can be staged.
{
  runCommand,
  nodejs,
}:
runCommand "pi-bolt-plugin-dependencies-check" { nativeBuildInputs = [ nodejs ]; } ''
  semver=${nodejs}/lib/node_modules/npm/node_modules/semver
  package() { mkdir -p "$1"; printf '{ "name": "%s", "version": "%s", "dependencies": %s }' "$(basename "$1")" "$2" "''${3:-{\}}" > "$1/package.json"; }

  # The host stages foo 1.2.0.
  package host/foo 1.2.0

  # check <plugin's declared dependencies> [skipped package]: runs the check on one plugin, with foo staged in the host.
  check() {
    rm -rf plugins; package plugins/p 0.0.0 "$1"
    ''${stage:-:}
    echo "[{ \"name\": \"p\", \"dir\": \"plugins/p\", \"skip\": [\"''${2:-}\"] }]" > spec.json
    node ${../plugins/check-dependencies.js} $semver host spec.json
  }

  # refused <message>: the check must fail, and say that.
  refused() {
    if check "$2" 2> refused.txt; then
      echo "accepted: $2" >&2
      exit 1
    fi
    grep -qF "$1" refused.txt || {
      cat refused.txt >&2
      exit 1
    }
  }

  check '{ "foo": "^1.1.0" }'
  # A range the staged version does not satisfy is named, with both.
  refused 'foo ^1.3.0 is declared, 1.2.0 is staged' '{ "foo": "^1.3.0" }'
  # A package that is not staged is named.
  refused 'bar 1.0.0 is declared but not staged' '{ "bar": "1.0.0" }'
  # The plugin's own copy is what it resolves, before the host's.
  stage='package plugins/p/node_modules/foo 2.0.0' check '{ "foo": "2.0.0" }'
  # What Pi provides is routed to Pi's own copy whatever the plugin declares, so no range of it is checked.
  package host/typebox 1.3.0
  check '{ "typebox": "^1.4.0" }'
  check '{ "@earendil-works/pi-ai": "^9.0.0" }'
  # A staged sibling plugin is checked by its own build, and a git source names itself.
  check '{ "sibling": "9.0.0" }' sibling
  check '{ "foo": "github:owner/foo" }'

  # check-lock.js: a plugin's package.json must be what its entry in the lock was generated from.
  locked() {
    rm -rf members; mkdir -p members/p
    printf '{ "name": "p", "version": "0.0.0", "dependencies": %s }' "$1" > members/p/package.json
    echo '{ "packages": { "pbplugins/p": { "version": "0.0.0", "dependencies": { "foo": "^1.1.0" } } } }' > lock.json
    node ${../plugins/check-lock.js} lock.json members
  }
  locked '{ "foo": "^1.1.0" }'
  # A pin that moved after the lock was written is named, with both ranges.
  if locked '{ "foo": "^1.3.0" }' 2> moved.txt; then echo "accepted a moved pin" >&2; exit 1; fi
  grep -qF 'p: foo is ^1.3.0 in its package.json, ^1.1.0 in the lock' moved.txt || { cat moved.txt >&2; exit 1; }
  touch $out
''
