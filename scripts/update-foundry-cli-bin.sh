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
package_dir="${repo_root}/foundry-cli-bin"
pkgbuild="${package_dir}/PKGBUILD"
repo="shpitdev/foundry-cli"
asset_prefix="foundry-cli"
release_tag="${FOUNDRY_CLI_RELEASE_TAG:-}"

fetch_release_by_tag() {
  local tag="$1"

  if [[ -n "${SHPIT_GH_TOKEN:-}" ]]; then
    GH_TOKEN="${SHPIT_GH_TOKEN}" gh api "repos/${repo}/releases/tags/${tag}"
  else
    gh api "repos/${repo}/releases/tags/${tag}"
  fi
}

fetch_release_with_assets() {
  local include_prereleases="$1"

  if [[ -n "${SHPIT_GH_TOKEN:-}" ]]; then
    GH_TOKEN="${SHPIT_GH_TOKEN}" gh api --paginate "repos/${repo}/releases"
  else
    gh api --paginate "repos/${repo}/releases"
  fi | jq -s -c --arg asset_prefix "${asset_prefix}" --argjson include_prereleases "${include_prereleases}" '
    add
    | map(select(.draft | not))
    | map(select($include_prereleases or (.prerelease | not)))
    | map(select(any(.assets[]?; (.name | test("^" + $asset_prefix + "_.*_linux_amd64\\.tar\\.gz$")))))
    | first // empty
  '
}

if [[ -n "${release_tag}" ]]; then
  release_json="$(fetch_release_by_tag "${release_tag}")"
elif [[ -n "${SHPIT_GH_TOKEN:-}" || -z "${GITHUB_ACTIONS:-}" ]]; then
  release_json="$(fetch_release_with_assets false)"
  if [[ -z "${release_json}" || "${release_json}" == "null" ]]; then
    release_json="$(fetch_release_with_assets true)"
  fi
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: SHPIT_GH_TOKEN is not configured in GitHub Actions." >&2
    exit 0
  fi
  echo "SHPIT_GH_TOKEN is required in GitHub Actions to read the private foundry-cli release." >&2
  exit 1
fi

if [[ -z "${release_json}" || "${release_json}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: no release contains foundry-cli linux amd64 archives." >&2
    exit 0
  fi
  echo "foundry-cli has no release with linux amd64 archives" >&2
  exit 1
fi

tag_name="$(jq -r '.tag_name' <<<"${release_json}")"
pkgver="${tag_name#v}"
if ! asset_json="$("${repo_root}/scripts/select-foundry-cli-asset.sh" "${pkgver}" <<<"${release_json}")"; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: selected release has invalid linux amd64 assets." >&2
    exit 0
  fi
  exit 1
fi
asset_name="$(jq -r '.name' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: selected release is missing an asset digest." >&2
    exit 0
  fi
  echo "foundry-cli selected release is missing an asset digest" >&2
  exit 1
fi

sha256="${sha256#sha256:}"
mkdir -p "${repo_root}/.memory"
tmpdir="$(mktemp -d "${repo_root}/.memory/update-foundry-cli-bin.XXXXXX")"
trap 'rm -rf "${tmpdir}"' EXIT

if [[ -n "${SHPIT_GH_TOKEN:-}" ]]; then
  GH_TOKEN="${SHPIT_GH_TOKEN}" gh release download "v${pkgver}" --repo "${repo}" --pattern "${asset_name}" --dir "${tmpdir}" --clobber >/dev/null
else
  gh release download "v${pkgver}" --repo "${repo}" --pattern "${asset_name}" --dir "${tmpdir}" --clobber >/dev/null
fi

(
  cd "${tmpdir}"
  echo "${sha256}  ${asset_name}" | sha256sum -c
  "${repo_root}/scripts/validate-foundry-cli-archive.sh" "${asset_name}"
)

perl -0pi -e "s/^pkgver=.*/pkgver=${pkgver}/m" "${pkgbuild}"
perl -0pi -e "s/^_sha256=.*/_sha256='${sha256}'/m" "${pkgbuild}"

"${repo_root}/scripts/render-srcinfo.sh" "${package_dir}"
