#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
selector="${repo_root}/scripts/select-foundry-cli-asset.sh"

expect_rejected() {
  local release_json="$1"
  if "${selector}" 1.2.3 <<<"${release_json}" >/dev/null 2>&1; then
    echo "Expected release assets to be rejected: ${release_json}" >&2
    exit 1
  fi
}

selected="$("${selector}" 1.2.3 <<'JSON'
{"assets":[{"name":"foundry-cli_1.2.3_linux_amd64.tar.gz","digest":"sha256:good"}]}
JSON
)"
[[ "$(jq -r '.name' <<<"${selected}")" == "foundry-cli_1.2.3_linux_amd64.tar.gz" ]]

expect_rejected '{"assets":[]}'
expect_rejected '{"assets":[{"name":"foundry-cli_9.9.9_linux_amd64.tar.gz","digest":"sha256:wrong"}]}'
expect_rejected '{"assets":[{"name":"foundry-cli_1.2.3_linux_amd64.tar.gz","digest":"sha256:one"},{"name":"foundry-cli_9.9.9_linux_amd64.tar.gz","digest":"sha256:two"}]}'
