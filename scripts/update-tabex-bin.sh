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
pkgbuild="${repo_root}/tabex-bin/PKGBUILD"
repo="shpitdev/pkgbuilds"

releases_json="$(gh api --paginate "repos/${repo}/releases?per_page=100" --slurp)"
release_json="$(jq -c '
  [
    .[][]
    | select(.draft == false and .prerelease == false)
    | select(.tag_name | test("^tabex-v[0-9]+\\.[0-9]+\\.[0-9]+$"))
  ]
  | sort_by(.tag_name | sub("^tabex-v"; "") | split(".") | map(tonumber))
  | last // empty
' <<<"${releases_json}")"

if [[ -z "${release_json}" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping tabex-bin: no public stable Tabex binary release exists yet." >&2
    exit 0
  fi
  echo "No public stable Tabex binary release exists in ${repo}." >&2
  exit 1
fi

public_tag="$(jq -r '.tag_name' <<<"${release_json}")"
pkgver="${public_tag#tabex-v}"
asset_json="$(jq -c '
  .assets
  | map(select(.name == "tabex_v'"${pkgver}"'_linux_amd64.tar.gz"))
  | first
' <<<"${release_json}")"
release_asset="$(jq -r '.name // empty' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${release_asset}" || "${release_asset}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping tabex-bin: latest release is missing a linux amd64 archive." >&2
    exit 0
  fi
  echo "tabex latest release is missing a linux amd64 archive" >&2
  exit 1
fi

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping tabex-bin: latest release is missing an asset digest." >&2
    exit 0
  fi
  echo "tabex latest release is missing an asset digest" >&2
  exit 1
fi

sha256="${sha256#sha256:}"

cat > "${pkgbuild}" <<EOF
# Maintainer: Anand Pant

pkgname=tabex-bin
pkgver=${pkgver}
pkgrel=1
pkgdesc="Tabex CLI for browser session, capture, and page inspection"
arch=('x86_64')
url="https://tabex.dev"
license=('LicenseRef-proprietary')
install="\${pkgname}.install"
provides=('tabex')
conflicts=('tabex')

_asset="tabex_v\${pkgver}_linux_amd64.tar.gz"
source=("https://github.com/shpitdev/pkgbuilds/releases/download/tabex-v\${pkgver}/\${_asset}")
sha256sums=('${sha256}')

package() {
  install -Dm755 "tabex_v\${pkgver}_linux_amd64/tabex" \
    "\${pkgdir}/usr/bin/tabex"
}
EOF

"${repo_root}/scripts/render-srcinfo.sh" "${repo_root}/tabex-bin"
