#!/usr/bin/env bash
# Moves the Pi-Bolt runtime in nix/runtime-data.nix to a release: the version, each platform's archive hash, and the engine stamp.
#
# Usage, from the repository root:
#   nix run .#update-runtime              the newest stable release (this is how nix-update runs it: passthru.updateScript)
#   nix run .#update-runtime -- 0.9.6     a chosen release
#
# The values come from the release's signed SHA256SUMS and RUNTIME_STAMP, checked against keys/release.pub, this repository's
# pinned copy of the release key. Nothing is built: the two platform hashes and the stamp move together, and each is compared
# with the signed sums by evaluation afterwards. The `pi-bolt` input's tag is a separate step (docs/RELEASES.md).
set -euo pipefail
[ -f nix/runtime-data.nix ] && [ -f keys/release.pub ] || {
	echo "update-runtime: run it from the repository root" >&2
	exit 1
}

die() {
	echo "update-runtime: $*" >&2
	exit 1
}

# The runtime archive each Nix system uses.
declare -A assets=(
	[x86_64-linux]=pi-bolt-runtime-linux-x64.tar.gz
	[aarch64-linux]=pi-bolt-runtime-linux-arm64.tar.gz
)

if [ $# -gt 1 ]; then
	die "usage: $0 [version]"
elif [ $# -eq 1 ]; then
	version="$1"
else
	# The newest stable release. The tag scheme is bolt-vX.Y.Z, and a prerelease is not a release.
	version="$(
		curl -fsSL "https://api.github.com/repos/opensec-git/Pi-Bolt/releases?per_page=100" |
			jq -r '[.[]
			        | select((.prerelease | not) and (.tag_name | test("^bolt-v[0-9]+\\.[0-9]+\\.[0-9]+$")))
			        | .tag_name | sub("^bolt-v"; "")]
			       | sort_by(split(".") | map(tonumber)) | last // empty'
	)" || die "cannot read the list of releases"
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the version is X.Y.Z, not '$version'"

openssl version | grep -q '^OpenSSL 3' || die "OpenSSL 3 is needed to check the release's signature"
base="https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for file in SHA256SUMS SHA256SUMS.sig RUNTIME_STAMP; do
	curl -fsSL -o "$tmp/$file" "$base/$file" || die "cannot fetch $base/$file"
done
openssl pkeyutl -verify -pubin -inkey keys/release.pub -rawin -in "$tmp/SHA256SUMS" -sigfile "$tmp/SHA256SUMS.sig" >/dev/null 2>&1 ||
	die "the signature of SHA256SUMS does not verify against keys/release.pub"

# The release's hex sha256 of a file: exactly one line names it.
sum_of() {
	local hashes
	hashes="$(awk -v file="$1" '$2 == file { print $1 }' "$tmp/SHA256SUMS")"
	[ "$(printf '%s' "$hashes" | grep -c .)" -eq 1 ] || die "SHA256SUMS does not list $1 exactly once"
	printf '%s\n' "$hashes"
}

stamp="$(tr -d '\n' <"$tmp/RUNTIME_STAMP")"
[[ "$stamp" =~ ^[0-9a-f]{16}$ ]] || die "RUNTIME_STAMP is not a 16-digit hex stamp: $stamp"
[ "$(sha256sum "$tmp/RUNTIME_STAMP" | cut -d' ' -f1)" = "$(sum_of RUNTIME_STAMP)" ] || die "checksum mismatch for RUNTIME_STAMP"

# One pass over the file: the version, the stamp, and each archive's hash, which is keyed by the asset name beside it.
awk -v version="$version" -v stamp="$stamp" \
	-v name_x86="${assets[x86_64-linux]}" -v hash_x86="$(nix hash convert --hash-algo sha256 --to sri "$(sum_of "${assets[x86_64-linux]}")")" \
	-v name_arm="${assets[aarch64-linux]}" -v hash_arm="$(nix hash convert --hash-algo sha256 --to sri "$(sum_of "${assets[aarch64-linux]}")")" '
	/^  version = "/ { sub(/"[^"]*"/, "\"" version "\""); print; next }
	/^  stamp = "/ { sub(/"[^"]*"/, "\"" stamp "\""); print; next }
	/^      name = "/ {
		name = $0
		sub(/^      name = "/, "", name)
		sub(/";$/, "", name)
		print
		next
	}
	/^      hash = "/ && name != "" {
		hash = (name == name_x86) ? hash_x86 : ((name == name_arm) ? hash_arm : "")
		if (hash == "") {
			print "update-runtime: there is no hash for " name > "/dev/stderr"
			exit 1
		}
		sub(/"[^"]*"/, "\"" hash "\"")
		name = ""
		print
		next
	}
	{ print }
' nix/runtime-data.nix >"$tmp/runtime-data.nix" || die "cannot rewrite nix/runtime-data.nix"
mv "$tmp/runtime-data.nix" nix/runtime-data.nix

# What the file now says, as the flake evaluates it, is what the release's signed sums say.
for system in "${!assets[@]}"; do
	attr="packages.$system.pi-bolt-runtime"
	[ "$(nix eval --raw ".#$attr.version")" = "$version" ] || die "$system: the version is not $version"
	[ "$(nix eval --raw ".#$attr.passthru.stamp")" = "$stamp" ] || die "$system: the stamp is not $stamp"
	sri="$(nix eval --raw ".#$attr.passthru.assets.$system.hash")" || die "$system: cannot read the runtime's hash"
	[ "$(nix hash convert --hash-algo sha256 --to base16 "$sri")" = "$(sum_of "${assets[$system]}")" ] ||
		die "$system: the hash is not the release's SHA256SUMS entry"
done

echo "runtime set to $version (stamp $stamp) in nix/runtime-data.nix"
