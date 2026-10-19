#!/usr/bin/env bash
# Moves the Pi-Bolt runtime (nix/runtime.nix) to a release. nix-update sets the version and the hash of this system's archive,
# which it downloads and hashes. The other system's hash and the engine stamp come from the release's signed SHA256SUMS and
# RUNTIME_STAMP. Then every value is checked against those sums by evaluation, so nothing is built.
#
# The signature is checked against keys/release.pub, this repository's pinned copy of the release key, not the copy in the
# release.
#
# Usage, from the repository root: nix run .#update-runtime -- <version>      e.g. ... -- 0.9.6
# Needs (the flake app provides them): nix, nix-update, curl, OpenSSL 3, sed, awk. Re-running for the recorded version changes
# nothing.
set -euo pipefail
[ -f nix/runtime.nix ] && [ -f keys/release.pub ] || {
	echo "update-runtime: run it from the repository root" >&2
	exit 1
}

die() {
	echo "update-runtime: $*" >&2
	exit 1
}

[ $# -eq 1 ] || die "usage: $0 <version>"
version="$1"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the version is X.Y.Z, not $version"

# The release asset each Nix system uses.
declare -A assets=(
	[x86_64-linux]=pi-bolt-runtime-linux-x64.tar.gz
	[aarch64-linux]=pi-bolt-runtime-linux-arm64.tar.gz
)
native="$(nix eval --impure --raw --expr builtins.currentSystem)"
[ -n "${assets[$native]:-}" ] || die "there is no runtime asset for $native"
other=
for system in "${!assets[@]}"; do
	[ "$system" = "$native" ] || other="$system"
done

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

nix-update --flake --system "$native" --version "$version" "packages.$native.pi-bolt-runtime"

# The other system's hash, from the signed sums: nix-update would need a builder for that system to fetch it.
sri="$(nix hash convert --hash-algo sha256 --to sri "$(sum_of "${assets[$other]}")")"
awk -v name="${assets[$other]}" -v hash="$sri" '
	index($0, "name = \"" name "\";") { found = 1 }
	found && /hash = / { sub(/hash = "[^"]*"/, "hash = \"" hash "\""); found = 0 }
	{ print }
' nix/runtime.nix >"$tmp/runtime.nix"
mv "$tmp/runtime.nix" nix/runtime.nix

sed -i "s|passthru.stamp = \"[0-9a-f]*\";|passthru.stamp = \"$stamp\";|" nix/runtime.nix

# Every system's runtime, as the flake evaluates it, must be the release's.
for system in "${!assets[@]}"; do
	attr="packages.$system.pi-bolt-runtime"
	[ "$(nix eval --raw ".#$attr.version")" = "$version" ] || die "$system: the runtime's version is not $version"
	[ "$(nix eval --raw ".#$attr.passthru.stamp")" = "$stamp" ] || die "$system: the runtime's stamp is not $stamp"
	got="$(nix hash convert --hash-algo sha256 --to base16 "$(nix eval --raw ".#$attr.outputHash")")"
	[ "$got" = "$(sum_of "${assets[$system]}")" ] || die "$system: the runtime's hash is not the release's SHA256SUMS entry"
done

echo "runtime set to $version (stamp $stamp) in nix/runtime.nix"
