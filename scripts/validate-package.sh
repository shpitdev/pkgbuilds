#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cp -a "${package_dir}" "${tmpdir}/pkg"
bash -n "${package_dir}/PKGBUILD"
for install_script in "${package_dir}"/*.install; do
  [[ -f "${install_script}" ]] || continue
  bash -n "${install_script}"
done

run_makepkg_validation() {
  if [[ "$(id -u)" -eq 0 ]]; then
    mkdir -p "${tmpdir}/home"
    chown -R 65534:65534 "${tmpdir}"
    env HOME="${tmpdir}/home" \
      setpriv --reuid 65534 --regid 65534 --clear-groups \
      bash -c "
        set -euo pipefail
        cd '${tmpdir}/pkg'
        makepkg --packagelist >/dev/null
        makepkg --printsrcinfo > .SRCINFO.generated
      "
  else
    (
      cd "${tmpdir}/pkg"
      makepkg --packagelist >/dev/null
      makepkg --printsrcinfo > .SRCINFO.generated
    )
  fi
}

run_makepkg_validation

diff -u "${package_dir}/.SRCINFO" "${tmpdir}/pkg/.SRCINFO.generated"
