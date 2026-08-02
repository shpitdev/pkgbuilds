#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for package_dir in "${repo_root}"/*; do
  [[ -d "${package_dir}" ]] || continue
  [[ -f "${package_dir}/PKGBUILD" ]] || continue
  "${repo_root}/scripts/validate-package.sh" "${package_dir}"
done

"${repo_root}/scripts/validate-foundry-cli-archive.test.sh"
"${repo_root}/scripts/select-foundry-cli-asset.test.sh"

meshix_pkg="${repo_root}/meshix-cli-bin"
if [[ -f "${meshix_pkg}/PKGBUILD" ]]; then
  grep -q "depends=('nodejs')" "${meshix_pkg}/PKGBUILD"
  grep -q '_release_version="${pkgver//_/-}"' "${meshix_pkg}/PKGBUILD"
  grep -q 'gh release download "meshix-cli-v${_release_version}"' "${meshix_pkg}/PKGBUILD"
  grep -q 'install="${pkgname}\.install"' "${meshix_pkg}/PKGBUILD"
  grep -q 'meshix-cli-dev' "${meshix_pkg}/meshix-cli-bin.install"
fi

tabex_pkg="${repo_root}/tabex-bin"
if [[ -f "${tabex_pkg}/PKGBUILD" ]]; then
  grep -q 'install="${pkgname}\.install"' "${tabex_pkg}/PKGBUILD"
  grep -q 'tabex setup' "${tabex_pkg}/tabex-bin.install"
fi

bash -n "${repo_root}/scripts/publish-tabex-release.sh"
"${repo_root}/scripts/publish-tabex-release.test.sh"
"${repo_root}/scripts/update-tabex-bin.test.sh"
