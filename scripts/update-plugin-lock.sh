# Writes the npm lock for a set of compiled plugins: Pi's own lock with the plugins' dependencies added (docs/PLUGINS.md,
# "Dependencies"). Usage: update-plugin-lock OUT PLUGIN_DIR... — each folder holds a plugin's package.json (a published npm
# package unpacked, or a checkout). PI_SOURCE is the Pi-Bolt source the lock extends. The only networked step: it asks the
# registry to resolve the declared ranges; the result is committed, and nothing resolves at build time.
[ "$#" -ge 2 ] || {
  echo "usage: update-plugin-lock OUT PLUGIN_DIR..." >&2
  exit 1
}
out=$1
shift

manifests=()
for dir in "$@"; do
  [ -f "$dir/package.json" ] || {
    echo "update-plugin-lock: $dir has no package.json" >&2
    exit 1
  }
  manifests+=("$dir/package.json")
done

# One lock is one resolution, so each package has one range across the set.
conflicts=$(jq -sr '
  [.[] | (.dependencies // {}) | to_entries[]] | group_by(.key)
  | map(select((map(.value) | unique | length) > 1) | .[0].key + ": " + (map(.value) | unique | join(", ")))
  | .[]' "${manifests[@]}")
[ -z "$conflicts" ] || {
  echo "update-plugin-lock: the plugins declare different ranges for one package:" >&2
  echo "$conflicts" >&2
  exit 1
}
dependencies=$(jq -s '[.[] | (.dependencies // {}) | to_entries[]] | unique_by(.key) | from_entries' "${manifests[@]}")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# npm resolves from the package.json files of Pi's workspace and its lock, which is all it needs of the source.
(cd "$PI_SOURCE" && find . -name package.json -not -path '*/node_modules/*') | while read -r file; do
  mkdir -p "$work/$(dirname "$file")"
  cp "$PI_SOURCE/$file" "$work/$file"
done
cp "$PI_SOURCE/package-lock.json" "$work/"
chmod -R u+w "$work"

jq --argjson dependencies "$dependencies" '.dependencies = $dependencies' "$work/package.json" >"$work/package.json.new"
mv "$work/package.json.new" "$work/package.json"
# --legacy-peer-deps: npm would otherwise install the plugins' peers, and a second Pi with them.
(cd "$work" && npm install --package-lock-only --ignore-scripts --legacy-peer-deps --no-audit --no-fund >/dev/null)
cp "$work/package-lock.json" "$out"
echo "wrote $out"
