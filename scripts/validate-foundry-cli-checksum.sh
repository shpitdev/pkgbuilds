#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(sed -n 's/^pkgver=//p' foundry-cli-bin/PKGBUILD)"
actual="$(sed -n "s/^_sha256='\([0-9a-f]*\)'$/\1/p" foundry-cli-bin/PKGBUILD)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$actual" =~ ^[0-9a-f]{64}$ ]]
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
GH_TOKEN="${SHPIT_GH_TOKEN:-${GH_TOKEN:-}}" gh release download "v${version}" \
  --repo shpitdev/foundry-cli --pattern "foundry-cli_${version}_checksums.txt" --dir "$tmpdir"
expected="$(awk -v asset="foundry-cli_${version}_linux_amd64.tar.gz" '$2 == asset {print $1}' "$tmpdir/foundry-cli_${version}_checksums.txt")"
[[ "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" ]] || {
  echo 'PKGBUILD SHA-256 does not match the release checksum manifest.' >&2
  exit 1
}
echo "Validated linux_amd64 checksum against v${version} release manifest."
