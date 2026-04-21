#!/usr/bin/env bash
set -euo pipefail

optional=false
if (($# > 1)); then
  echo "usage: $0 [--optional]" >&2
  exit 1
fi
if (($# == 1)); then
  if [[ "$1" != "--optional" ]]; then
    echo "usage: $0 [--optional]" >&2
    exit 1
  fi
  optional=true
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pkgbuild="${repo_root}/meshix-cli-bin/PKGBUILD"
repo="shpitdev/meshix-observability"
requested_version="${MESHIX_CLI_VERSION:-latest}"

resolve_release_json() {
  local version="$1"
  local endpoint

  if [[ -z "${version}" || "${version}" == "latest" ]]; then
    endpoint="repos/${repo}/releases/latest"
  else
    if [[ "${version}" != v* ]]; then
      version="v${version}"
    fi
    endpoint="repos/${repo}/releases/tags/${version}"
  fi

  if [[ -n "${SHPIT_GH_TOKEN:-}" ]]; then
    GH_TOKEN="${SHPIT_GH_TOKEN}" gh api "${endpoint}"
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    if [[ "${optional}" == "true" ]]; then
      echo "Skipping meshix-cli-bin: SHPIT_GH_TOKEN is not configured in GitHub Actions." >&2
      exit 0
    fi
    echo "SHPIT_GH_TOKEN is required in GitHub Actions to read the private meshix-cli release." >&2
    exit 1
  else
    gh api "${endpoint}"
  fi
}

release_json="$(resolve_release_json "${requested_version}")"
pkgver="$(jq -r '.tag_name | ltrimstr("v")' <<<"${release_json}")"
asset_json="$(jq -c '
  .assets
  | map(select(.name | test("_linux_amd64\\.tar\\.gz$")))
  | first
' <<<"${release_json}")"
release_asset="$(jq -r '.name // empty' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${release_asset}" || "${release_asset}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping meshix-cli-bin: release is missing a linux amd64 archive." >&2
    exit 0
  fi
  echo "meshix-cli release is missing a linux amd64 archive" >&2
  exit 1
fi

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping meshix-cli-bin: release is missing an asset digest." >&2
    exit 0
  fi
  echo "meshix-cli release is missing an asset digest" >&2
  exit 1
fi

sha256="${sha256#sha256:}"

perl -0pi -e "s/^pkgver=.*/pkgver=${pkgver}/m" "${pkgbuild}"
perl -0pi -e "s/^_sha256=.*/_sha256='${sha256}'/m" "${pkgbuild}"

"${repo_root}/scripts/render-srcinfo.sh" "${repo_root}/meshix-cli-bin"
