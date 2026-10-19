#!/usr/bin/env bash
# Adds a Pi-Bolt release's runtime to nix/runtime.json: its engine stamp and the hash of each platform's runtime archive, as
# the release's signed SHA256SUMS gives them. The signature is checked against keys/release.pub, this repository's pinned copy
# of the release key, not the copy in the release.
#
# Usage, from the repository root: nix run .#update-runtime -- <version>      e.g. ... -- 0.9.5
# Needs (the flake app provides them): curl, OpenSSL 3, python3, sha256sum. Re-running for a recorded version checks it and
# changes nothing.
set -euo pipefail
[ -f nix/runtime.json ] && [ -f keys/release.pub ] || {
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

# The runtime archive each Nix system uses (the release's asset names).
declare -A assets=(
	[x86_64-linux]=pi-bolt-runtime-linux-x64.tar.gz
	[aarch64-linux]=pi-bolt-runtime-linux-arm64.tar.gz
)

openssl version | grep -q '^OpenSSL 3' || die "OpenSSL 3 is needed to check the release's signature"
base="https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for file in SHA256SUMS SHA256SUMS.sig RUNTIME_STAMP "${assets[@]}"; do
	curl -fsSL -o "$tmp/$file" "$base/$file" || die "cannot fetch $base/$file"
done

openssl pkeyutl -verify -pubin -inkey keys/release.pub -rawin -in "$tmp/SHA256SUMS" -sigfile "$tmp/SHA256SUMS.sig" >/dev/null 2>&1 ||
	die "the signature of SHA256SUMS does not verify against keys/release.pub"

# The release's checksum for a file: exactly one line names it.
sum_of() {
	local hashes
	hashes="$(awk -v file="$1" '$2 == file { print $1 }' "$tmp/SHA256SUMS")"
	[ "$(printf '%s' "$hashes" | grep -c .)" -eq 1 ] || die "SHA256SUMS does not list $1 exactly once"
	printf '%s\n' "$hashes"
}

check_file() {
	local expected
	expected="$(sum_of "$1")"
	[ "$(sha256sum "$tmp/$1" | cut -d' ' -f1)" = "$expected" ] || die "checksum mismatch for $1"
}

check_file RUNTIME_STAMP
stamp="$(tr -d '\n' <"$tmp/RUNTIME_STAMP")"
[[ "$stamp" =~ ^[0-9a-f]{16}$ ]] || die "RUNTIME_STAMP is not a 16-digit hex stamp: $stamp"

platforms=()
for system in "${!assets[@]}"; do
	name="${assets[$system]}"
	check_file "$name"
	hash="$(sum_of "$name")"
	platforms+=("$system=$name=$hash")
done

python3 - nix/runtime.json "$version" "$stamp" "${platforms[@]}" <<'EOF'
import json, os, sys

path, version, stamp, *platforms = sys.argv[1:]
entry = {"stamp": stamp, "platforms": {}}
for platform in platforms:
    system, name, sha256 = platform.split("=")
    entry["platforms"][system] = {"name": name, "sha256": sha256}

runtimes = json.load(open(path)) if os.path.exists(path) else {}
if version in runtimes:
    if runtimes[version] != entry:
        sys.exit(f"update-runtime: {version} is recorded with different values; not overwriting it")
    print(f"{version} is already recorded in {path}")
    sys.exit(0)

runtimes[version] = entry
ordered = dict(sorted(runtimes.items(), key=lambda item: tuple(map(int, item[0].split(".")))))
with open(path, "w") as out:
    json.dump(ordered, out, indent=2)
    out.write("\n")
print(f"recorded {version} (stamp {stamp}) in {path}")
EOF
