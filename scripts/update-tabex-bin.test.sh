#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

cp -a "${repo_root}/." "${workdir}/repo"
mkdir -p "${workdir}/bin"

cat > "${workdir}/release.json" <<'EOF'
[
  [
    {
      "tag_name": "tabex-v9.8.6",
      "draft": false,
      "prerelease": false,
      "assets": []
    },
    {
      "tag_name": "tabex-v9.8.7",
      "draft": false,
      "prerelease": false,
      "assets": [
        {
          "name": "tabex_v9.8.7_linux_amd64.tar.gz",
          "digest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }
      ]
    }
  ]
]
EOF

cat > "${workdir}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat "${TABEX_RELEASE_FIXTURE}"
EOF

cat > "${workdir}/bin/makepkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'SRCINFO'
pkgbase = tabex-bin
	pkgver = 9.8.7
	source = https://github.com/shpitdev/pkgbuilds/releases/download/tabex-v9.8.7/tabex_v9.8.7_linux_amd64.tar.gz
	sha256sums = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

pkgname = tabex-bin
SRCINFO
EOF

chmod +x "${workdir}/bin/gh" "${workdir}/bin/makepkg"

PATH="${workdir}/bin:${PATH}" \
  TABEX_RELEASE_FIXTURE="${workdir}/release.json" \
  "${workdir}/repo/scripts/update-tabex-bin.sh"

pkgbuild="${workdir}/repo/tabex-bin/PKGBUILD"
grep -Fq 'pkgver=9.8.7' "${pkgbuild}"
grep -Fq 'source=("https://github.com/shpitdev/pkgbuilds/releases/download/tabex-v${pkgver}/${_asset}")' "${pkgbuild}"
grep -Fq "sha256sums=('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')" "${pkgbuild}"
if grep -Eq 'github-cli|gh release download|shpitdev/tabex/releases' "${pkgbuild}"; then
  echo "Generated Tabex PKGBUILD still requires private GitHub access." >&2
  exit 1
fi
