#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"
package_name="$(basename "${package_dir}")"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${repo_root}/${package_dir}/PKGBUILD" || ! -f "${repo_root}/${package_dir}/.SRCINFO" ]]; then
  echo "package directory is missing PKGBUILD or .SRCINFO: ${package_dir}" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

git clone "ssh://aur@aur.archlinux.org/${package_name}.git" "${workdir}/${package_name}"

find "${workdir}/${package_name}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

while IFS= read -r tracked_file; do
  relative_path="${tracked_file#${package_dir}/}"
  install -d "${workdir}/${package_name}/$(dirname "${relative_path}")"
  cp -a "${repo_root}/${tracked_file}" "${workdir}/${package_name}/${relative_path}"
done < <(git -C "${repo_root}" ls-files -- "${package_dir}")

(
  cd "${workdir}/${package_name}"

  git config user.name "${AUR_USERNAME}"
  git config user.email "${AUR_EMAIL}"
  git add -A

  if git diff --cached --quiet; then
    echo "No AUR changes for ${package_name}"
    exit 0
  fi

  git commit -m "Update ${package_name}"
  git push origin HEAD
)
