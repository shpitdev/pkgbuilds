#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for package_dir in "${repo_root}"/*; do
  [[ -d "${package_dir}" ]] || continue
  [[ -f "${package_dir}/PKGBUILD" ]] || continue
  "${repo_root}/scripts/validate-package.sh" "${package_dir}"
done
