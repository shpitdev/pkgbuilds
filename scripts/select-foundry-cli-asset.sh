#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-version>" >&2
  exit 1
fi

pkgver="$1"
expected_asset="foundry-cli_${pkgver}_linux_amd64.tar.gz"
candidate_assets="$(jq -c '
  .assets
  | map(select(.name | test("^foundry-cli_.*_linux_amd64\\.tar\\.gz$")))
')"
candidate_count="$(jq 'length' <<<"${candidate_assets}")"
asset_name="$(jq -r '.[0].name // empty' <<<"${candidate_assets}")"

if [[ "${candidate_count}" -ne 1 || "${asset_name}" != "${expected_asset}" ]]; then
  echo "foundry-cli release must contain exactly ${expected_asset}; found ${candidate_count} matching candidates" >&2
  exit 1
fi

jq -c '.[0]' <<<"${candidate_assets}"
