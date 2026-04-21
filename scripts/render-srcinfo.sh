#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"

if [[ "$(id -u)" -eq 0 ]]; then
  parent_dir="$(dirname "${package_dir}")"
  package_name="$(basename "${package_dir}")"
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' EXIT

  cp -a "${package_dir}" "${workdir}/${package_name}"
  mkdir -p "${workdir}/home"
  chown -R 65534:65534 "${workdir}"

  env HOME="${workdir}/home" \
    setpriv --reuid 65534 --regid 65534 --clear-groups \
    bash -c "
      set -euo pipefail
      cd '${workdir}/${package_name}'
      makepkg --printsrcinfo > .SRCINFO
    "

  cat "${workdir}/${package_name}/.SRCINFO" > "${package_dir}/.SRCINFO"
else
  (
    cd "${package_dir}"
    makepkg --printsrcinfo > .SRCINFO
  )
fi
