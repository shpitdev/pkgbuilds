#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for package_dir in "${repo_root}"/*; do
  [[ -d "${package_dir}" ]] || continue
  [[ -f "${package_dir}/PKGBUILD" ]] || continue
  "${repo_root}/scripts/validate-package.sh" "${package_dir}"
done

meshix_pkg="${repo_root}/meshix-cli-bin"
if [[ -f "${meshix_pkg}/PKGBUILD" ]]; then
  grep -q 'source=("${url}/releases/download/v${pkgver}/${_asset}")' "${meshix_pkg}/PKGBUILD"
  grep -q 'meshix-cli-dev' "${meshix_pkg}/meshix-cli-bin.install"
fi

tabex_pkg="${repo_root}/tabex-bin"
if [[ -f "${tabex_pkg}/PKGBUILD" ]]; then
  grep -q 'install="${pkgname}\.install"' "${tabex_pkg}/PKGBUILD"
  grep -q 'tabex setup' "${tabex_pkg}/tabex-bin.install"
fi
