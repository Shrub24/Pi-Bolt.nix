# Writes the npm lock for a set of compiled plugins (docs/PLUGINS.md, "npm dependencies"): a standalone npm project with each
# plugin as a workspace. A package two plugins share is one copy there; one that needs another version than a sibling gets it
# nested under that plugin. The compile copies the tree into plugins/node_modules, where a plugin resolves it before Pi's own, so
# Pi is not part of the lock and a Pi-Bolt bump does not invalidate it.
#
# Usage: update-plugin-lock OUT NAME=MANIFEST...
# MANIFEST is the plugin's package.json, and the only input shape: whoever owns the plugin's version owns writing its manifest,
# and this combines manifests into a lock. It resolves nothing about sources, so it is not told where a plugin came from.
# The one networked step: it asks the registry to resolve the declared ranges. The result is committed, and nothing resolves at
# build time.
[ "$#" -ge 2 ] || {
  echo "usage: update-plugin-lock OUT NAME=MANIFEST..." >&2
  exit 1
}
out=$1
shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '{ "name": "pi-bolt-plugins", "version": "0.0.0", "private": true, "workspaces": ["pbplugins/*"] }' >"$work/package.json"

for spec in "$@"; do
  name=${spec%%=*}
  manifest=${spec#*=}
  [ "$name" != "$spec" ] && [ -n "$name" ] || {
    echo "update-plugin-lock: $spec is not NAME=MANIFEST" >&2
    exit 1
  }
  [ ! -e "$work/pbplugins/$name" ] || {
    echo "update-plugin-lock: $name is given twice" >&2
    exit 1
  }
  [ -f "$manifest" ] || {
    echo "update-plugin-lock: $manifest is not a file (pass the plugin's package.json)" >&2
    exit 1
  }
  # The fields npm installs a workspace member from, and what Pi installs a package with (--omit=dev): a plugin's dev
  # dependencies and scripts are not installed. The manifest is read as committed, not derived from anything else.
  jq -e 'type == "object" and (.name | type == "string") and (.version | type == "string")' "$manifest" >/dev/null 2>&1 || {
    echo "update-plugin-lock: $manifest is not a package.json with a name and a version" >&2
    exit 1
  }
  mkdir -p "$work/pbplugins/$name"
  jq '{ name, version, dependencies, optionalDependencies } | with_entries(select(.value != null))' "$manifest" \
    >"$work/pbplugins/$name/package.json"
done

# --legacy-peer-deps, as Pi's own package installer passes it (package-manager.ts): npm would otherwise install the peers of a
# plugin's dependencies, which for Pi's packages under their old names (@mariozechner/pi-*) is a second Pi. A plugin declares what
# it imports in `dependencies`. nix/plugin-set.nix installs the lock with the same flag.
(cd "$work" && npm install --package-lock-only --ignore-scripts --legacy-peer-deps --no-audit --no-fund >/dev/null)
cp "$work/package-lock.json" "$out"
echo "wrote $out"
