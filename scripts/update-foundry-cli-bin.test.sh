#!/usr/bin/env bash
# Offline release fixtures exercise the real updater, prepare(), and makepkg.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
# The CI container runs makepkg as nobody, which must traverse this directory.
chmod 755 "${test_root}"
mkdir -p "${test_root}/bin"
cat > "${test_root}/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" == 2 && "$1" == api && "$2" == repos/shpitdev/foundry-cli/releases/tags/v1.2.3 ]]; then
  cat "${RELEASE_FIXTURE}"
elif [[ "$#" == 10 && "$1 $2 $3" == 'release download v1.2.3' &&
  "$4 $5 $6 $7 $8" == '--repo shpitdev/foundry-cli --pattern foundry-cli_1.2.3_linux_amd64.tar.gz --dir' &&
  "${10}" == --clobber ]]; then
  cp "${ARCHIVE_FIXTURE}" "${9}/foundry-cli_1.2.3_linux_amd64.tar.gz"
else
  echo 'Unexpected fixture gh invocation; no network access is allowed.' >&2
  exit 1
fi
GH
chmod +x "${test_root}/bin/gh"
export PATH="${test_root}/bin:${PATH}" FOUNDRY_CLI_RELEASE_TAG=v1.2.3
export SHPIT_GH_TOKEN= GH_TOKEN=

make_workspace() {
  local work="$1" layout="$2"
  mkdir -p "${work}/repo/scripts" "${work}/repo/foundry-cli-bin" "${work}/archive"
  for script in update-foundry-cli-bin render-srcinfo select-foundry-cli-asset validate-foundry-cli-archive; do
    cp "${repo_root}/scripts/${script}.sh" "${work}/repo/scripts/"
  done
  cp "${repo_root}/foundry-cli-bin/"{PKGBUILD,.SRCINFO,foundry-cli-bin.install} "${work}/repo/foundry-cli-bin/"
  printf '#!/usr/bin/env bash\nprintf "fixture-cli\\n"\n' > "${work}/archive/foundry-cli"
  chmod +x "${work}/archive/foundry-cli"
  printf 'Fixture license\n' > "${work}/archive/LICENSE"
  printf '# Foundry CLI fixture\n' > "${work}/archive/README.md"
  local members=(foundry-cli LICENSE README.md)
  if [[ "${layout}" != core-only ]]; then
    mkdir -p "${work}/archive/templates/${layout}"
    printf '{"name":"fixture-template"}\n' > "${work}/archive/templates/${layout}/package.json"
    members+=(templates)
    if [[ "${layout}" == compute-modules/typescript ]]; then
      printf '# Original template documentation\n' > "${work}/archive/templates/README.md"
      printf 'Fixture notice\n' > "${work}/archive/NOTICE"
      members+=(NOTICE)
    fi
  fi
  export ARCHIVE_FIXTURE="${work}/release.tar.gz" RELEASE_FIXTURE="${work}/release.json"
  tar -C "${work}/archive" -czf "${ARCHIVE_FIXTURE}" "${members[@]}"
  write_release
}

write_release() {
  local digest
  digest="$(sha256sum "${ARCHIVE_FIXTURE}")"
  digest="${digest%% *}"
  jq -n --arg digest "sha256:${1:-${digest}}" \
    '{tag_name:"v1.2.3",assets:[{name:"foundry-cli_1.2.3_linux_amd64.tar.gz",digest:$digest}]}' > "${RELEASE_FIXTURE}"
}

run_makepkg() {
  local work="$1"
  if [[ "$(id -u)" -eq 0 ]]; then
    mkdir -p "${work}/home"
    chown -R 65534:65534 "${work}"
    env HOME="${work}/home" setpriv --reuid 65534 --regid 65534 --clear-groups \
      bash -c 'cd "$1" && makepkg --force --cleanbuild --nodeps --nocheck --noconfirm --nosign --nocolor' \
      bash "${work}/repo/foundry-cli-bin"
  else
    (
      cd "${work}/repo/foundry-cli-bin"
      makepkg --force --cleanbuild --nodeps --nocheck --noconfirm --nosign --nocolor
    )
  fi
}

for layout in core-only compute-module-ts compute-modules/typescript; do
  work="${test_root}/${layout}"
  make_workspace "${work}" "${layout}"
  "${work}/repo/scripts/update-foundry-cli-bin.sh"
  (
    source "${work}/repo/foundry-cli-bin/PKGBUILD"
    digest="$(sha256sum "${ARCHIVE_FIXTURE}")"
    [[ "${pkgver}" == 1.2.3 && "${_sha256}" == "${digest%% *}" ]]
  )
  "${repo_root}/scripts/validate-package.sh" "${work}/repo/foundry-cli-bin"
  if ! run_makepkg "${work}" > "${work}/makepkg.log" 2>&1; then
    cat "${work}/makepkg.log" >&2
    exit 1
  fi
  packages=("${work}/repo/foundry-cli-bin/"*.pkg.tar.*)
  [[ "${#packages[@]}" == 1 && -f "${packages[0]}" ]]
  mkdir "${work}/installed"
  tar -xf "${packages[0]}" -C "${work}/installed"
  installed="${work}/installed/usr"
  [[ -L "${installed}/bin/foundry-cli" && -x "${installed}/bin/foundry-cli" ]]
  [[ "$("${installed}/bin/foundry-cli")" == fixture-cli ]]
  cmp "${work}/archive/foundry-cli" "${installed}/lib/foundry-cli/foundry-cli"
  cmp "${work}/archive/LICENSE" "${installed}/share/licenses/foundry-cli-bin/LICENSE"
  cmp "${work}/archive/README.md" "${installed}/share/doc/foundry-cli-bin/README.md"
  if [[ "${layout}" == core-only ]]; then
    [[ ! -e "${installed}/lib/foundry-cli/templates" ]]
    [[ ! -e "${installed}/share/licenses/foundry-cli-bin/NOTICE" ]]
  else
    cmp "${work}/archive/templates/${layout}/package.json" \
      "${installed}/lib/foundry-cli/templates/${layout}/package.json"
    if [[ -f "${work}/archive/templates/README.md" ]]; then
      diff -r "${work}/archive/templates" "${installed}/lib/foundry-cli/templates"
      cmp "${work}/archive/NOTICE" "${installed}/share/licenses/foundry-cli-bin/NOTICE"
    else
      [[ -s "${installed}/lib/foundry-cli/templates/README.md" ]]
    fi
  fi
  echo "Updated and built package: ${layout}"
done

for defect in checksum missing-core; do
  work="${test_root}/${defect}"
  make_workspace "${work}" core-only
  if [[ "${defect}" == checksum ]]; then
    write_release "$(printf '%064d' 0)"
  else
    tar -C "${work}/archive" -czf "${ARCHIVE_FIXTURE}" foundry-cli LICENSE
    write_release
  fi
  cp "${work}/repo/foundry-cli-bin/PKGBUILD" "${work}/before.PKGBUILD"
  cp "${work}/repo/foundry-cli-bin/.SRCINFO" "${work}/before.SRCINFO"
  if "${work}/repo/scripts/update-foundry-cli-bin.sh" > "${work}/updater.log" 2>&1; then
    echo "Expected updater to reject ${defect}" >&2
    exit 1
  fi
  cmp "${work}/before.PKGBUILD" "${work}/repo/foundry-cli-bin/PKGBUILD"
  cmp "${work}/before.SRCINFO" "${work}/repo/foundry-cli-bin/.SRCINFO"
  echo "Updater rejected ${defect} without changing package metadata"
done

work="${test_root}/prepare-checksum"
make_workspace "${work}" core-only
"${work}/repo/scripts/update-foundry-cli-bin.sh"
printf 'Corrupted download\n' > "${ARCHIVE_FIXTURE}"
if run_makepkg "${work}" > "${work}/makepkg.log" 2>&1; then
  echo 'Expected prepare() to reject a corrupted download' >&2
  exit 1
fi
grep -q 'FAILED' "${work}/makepkg.log"
[[ ! -e "${work}/repo/foundry-cli-bin/src/foundry-cli" ]]
echo 'prepare() rejected the checksum mismatch before extraction'
