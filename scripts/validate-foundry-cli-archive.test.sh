#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validator="${repo_root}/scripts/validate-foundry-cli-archive.sh"
mkdir -p "${repo_root}/.memory"
test_root="$(mktemp -d "${repo_root}/.memory/validate-foundry-cli-archive.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

make_base_fixture() {
  local root="$1" layout="$2"
  mkdir -p "${root}/bin" "${root}/libexec/cli-ts/1.0.0" "${root}/libexec/superrepo/1.0.0"
  printf '#!/usr/bin/env bash\nprintf "fixture-cli\\n"\n' > "${root}/foundry-cli"
  printf '#!/usr/bin/env bash\nprintf "fixture-ts\\n"\n' > "${root}/bin/foundry-cli-ts"
  chmod +x "${root}/foundry-cli" "${root}/bin/foundry-cli-ts"
  printf 'TS payload\n' > "${root}/libexec/cli-ts/1.0.0/launch.cjs"
  printf 'SuperRepo payload\n' > "${root}/libexec/superrepo/1.0.0/main.mjs"
  printf 'Fixture license\n' > "${root}/LICENSE"
  printf '# Foundry CLI fixture\n' > "${root}/README.md"
  if [[ "${layout}" != core-only ]]; then
    mkdir -p "${root}/templates/${layout}"
    printf '{"name":"fixture-template"}\n' > "${root}/templates/${layout}/package.json"
  fi
}

expect_rejected() {
  local archive="$1"
  if "${validator}" "${archive}" >/dev/null 2>&1; then
    echo "Expected archive to be rejected: ${archive}" >&2
    exit 1
  fi
}

for layout in core-only compute-module-ts compute-modules/typescript; do
  fixture="${test_root}/${layout}"
  make_base_fixture "${fixture}" "${layout}"
  members=(foundry-cli LICENSE README.md bin libexec)
  [[ "${layout}" == core-only ]] || members+=(templates)
  tar -C "${fixture}" -czf "${test_root}/good.tar.gz" "${members[@]}"
  "${validator}" "${test_root}/good.tar.gz"

  for required in foundry-cli LICENSE README.md bin/foundry-cli-ts libexec/cli-ts/1.0.0/launch.cjs libexec/superrepo/1.0.0/main.mjs; do
    tar -C "${fixture}" -czf "${test_root}/missing.tar.gz" \
      --exclude="${required}" "${members[@]}"
    expect_rejected "${test_root}/missing.tar.gz"
  done

  tar -C "${fixture}" -czf "${test_root}/absolute.tar.gz" \
    --transform='s#^#/absolute/#' "${members[@]}"
  expect_rejected "${test_root}/absolute.tar.gz"

  tar -C "${fixture}" -czf "${test_root}/traversal.tar.gz" \
    --transform='s#^#../#' "${members[@]}"
  expect_rejected "${test_root}/traversal.tar.gz"

  ln -s ../../outside "${fixture}/symlink"
  tar -C "${fixture}" -czf "${test_root}/symlink.tar.gz" "${members[@]}" symlink
  expect_rejected "${test_root}/symlink.tar.gz"

  ln "${fixture}/foundry-cli" "${fixture}/hardlink"
  tar -C "${fixture}" -czf "${test_root}/hardlink.tar.gz" "${members[@]}" hardlink
  expect_rejected "${test_root}/hardlink.tar.gz"

  mkfifo "${fixture}/unsafe"
  tar -C "${fixture}" -czf "${test_root}/fifo.tar.gz" "${members[@]}" unsafe
  expect_rejected "${test_root}/fifo.tar.gz"
  echo "Validated archive layout and safety guards: ${layout}"
done

mkdir -p "${test_root}/core-only/templates"
printf '# Incomplete template bundle\n' > "${test_root}/core-only/templates/README.md"
tar -C "${test_root}/core-only" -czf "${test_root}/incomplete.tar.gz" \
  foundry-cli LICENSE README.md bin libexec templates
expect_rejected "${test_root}/incomplete.tar.gz"
