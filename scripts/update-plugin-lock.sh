# Writes the npm lock for a set of compiled plugins (docs/guides/dependencies.md, "npm dependencies"): a standalone npm project
# with each plugin as a workspace. A package two plugins share is one copy there; one that needs another version than a sibling
# gets it nested under that plugin. The compile copies the tree into plugins/node_modules, where a plugin resolves it before Pi's
# own, so Pi is not part of the lock and a Pi-Bolt bump does not invalidate it.
#
# Usage: update-plugin-lock -o OUT [NAME=]MANIFEST...
# MANIFEST is the plugin's package.json, and the only input shape: whoever owns the plugin's version owns writing its manifest,
# and this combines manifests into a lock. It resolves nothing about sources, so it is not told where a plugin came from.
# NAME is the plugin's pluginName, used as its folder in the lock. Omit it when the manifest's folder already holds that name;
# give it when they differ, as `radar=./checkouts/pi-extensions/pi-radar/package.json`.
# The one networked step: it asks the registry to resolve the declared ranges. The result is committed, and nothing resolves at
# build time.

usage() {
	echo "usage: update-plugin-lock -o OUT [NAME=]MANIFEST..." >&2
	exit 1
}

out=
specs=()
while [ "$#" -gt 0 ]; do
	case $1 in
	-o | --output)
		[ "$#" -ge 2 ] || usage
		out=$2
		shift 2
		;;
	-h | --help) usage ;;
	*) specs+=("$1") && shift ;;
	esac
done
[ -n "$out" ] || usage
[ "${#specs[@]}" -ge 1 ] || usage

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '{ "name": "pi-bolt-plugins", "version": "0.0.0", "private": true, "workspaces": ["pbplugins/*"] }' >"$work/package.json"

for spec in "${specs[@]}"; do
	# `NAME=MANIFEST` when the folder does not name the plugin, otherwise the manifest alone.
	if [ "${spec%%=*}" != "$spec" ]; then
		name=${spec%%=*}
		manifest=${spec#*=}
		explicit_name=1
	else
		manifest=$spec
		name=$(basename -- "$(dirname -- "$spec")")
		case $name in . | /) name= ;; esac
		explicit_name=
	fi
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
	if [ -n "$explicit_name" ] && [ -z "${spec%%=*}" ]; then
		echo "update-plugin-lock: $spec needs a name before =" >&2
		exit 1
	fi
	if [ -z "$name" ]; then
		echo "update-plugin-lock: $manifest needs NAME=MANIFEST: its folder does not name the plugin" >&2
		exit 1
	fi
	case $name in
	*/*)
		echo "update-plugin-lock: the name in $spec cannot contain /" >&2
		exit 1
		;;
	esac
	[ ! -e "$work/pbplugins/$name" ] || {
		echo "update-plugin-lock: $name is given twice" >&2
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
