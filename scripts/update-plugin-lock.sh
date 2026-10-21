# Writes the npm lock for a set of compiled plugins (docs/PLUGINS.md, "Dependencies"): Pi's own lock with each plugin added as
# an npm workspace. Pi's entries stay where they are, a plugin that needs another version of a package gets it nested under its
# own folder, and one that shares a version shares the copy. Usage: update-plugin-lock OUT NAME=SOURCE...
# NAME is the plugin's name (its pluginName); SOURCE is its package.json, a folder holding one, or an npm tarball. PI_SOURCE is
# the Pi-Bolt source the lock extends. The one networked step: it asks the registry to resolve the declared ranges. The result is
# committed, and nothing resolves at build time.
[ "$#" -ge 2 ] || {
  echo "usage: update-plugin-lock OUT NAME=SOURCE..." >&2
  exit 1
}
out=$1
shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# npm resolves from the package.json files of Pi's workspaces and its lock, which is all it needs of the source.
(cd "$PI_SOURCE" && find . -name package.json -not -path '*/node_modules/*') | while read -r file; do
  mkdir -p "$work/$(dirname "$file")"
  cp "$PI_SOURCE/$file" "$work/$file"
done
cp "$PI_SOURCE/package-lock.json" "$work/"
chmod -R u+w "$work"

for spec in "$@"; do
  name=${spec%%=*}
  source=${spec#*=}
  [ "$name" != "$spec" ] && [ -n "$name" ] || {
    echo "update-plugin-lock: $spec is not NAME=SOURCE" >&2
    exit 1
  }
  [ ! -e "$work/pbplugins/$name" ] || {
    echo "update-plugin-lock: $name is given twice" >&2
    exit 1
  }
  if [ -d "$source" ]; then
    manifest=$(cat "$source/package.json")
  elif [ -f "$source" ] && [[ $source == *.tgz || $source == *.tar.gz ]]; then
    # npm's tarballs hold the package under package/.
    manifest=$(tar -xzOf "$source" package/package.json)
  elif [ -f "$source" ]; then
    manifest=$(cat "$source")
  else
    echo "update-plugin-lock: $source is not a package.json, a folder or a tarball" >&2
    exit 1
  fi
  mkdir -p "$work/pbplugins/$name"
  # The same fields pi-bolt compiles from (nix/pi-bolt.nix): a plugin's dev dependencies and scripts are not installed.
  jq '{ name, version, dependencies } | with_entries(select(.value != null))' <<<"$manifest" >"$work/pbplugins/$name/package.json"
done

jq '.workspaces += ["pbplugins/*"]' "$work/package.json" >"$work/package.json.new"
mv "$work/package.json.new" "$work/package.json"
(cd "$work" && npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null)
cp "$work/package-lock.json" "$out"
echo "wrote $out"
