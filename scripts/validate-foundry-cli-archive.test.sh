#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validator="${repo_root}/scripts/validate-foundry-cli-archive.sh"
mkdir -p "${repo_root}/.memory"
test_root="$(mktemp -d "${repo_root}/.memory/validate-foundry-cli-archive.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

make_base_fixture() {
  local root="$1"
  mkdir -p "${root}/templates/compute-modules/typescript"
  touch "${root}/foundry-cli" "${root}/LICENSE" "${root}/README.md"
  touch "${root}/templates/compute-modules/typescript/package.json"
}

expect_rejected() {
  local archive="$1"
  if "${validator}" "${archive}" >/dev/null 2>&1; then
    echo "Expected archive to be rejected: ${archive}" >&2
    exit 1
  fi
}

mkdir -p "${test_root}/good"
make_base_fixture "${test_root}/good"
tar -C "${test_root}/good" -czf "${test_root}/good.tar.gz" \
  foundry-cli LICENSE README.md templates
"${validator}" "${test_root}/good.tar.gz"

tar -C "${test_root}/good" -czf "${test_root}/absolute.tar.gz" \
  --transform='s#^#/absolute/#' foundry-cli LICENSE README.md templates
expect_rejected "${test_root}/absolute.tar.gz"

tar -C "${test_root}/good" -czf "${test_root}/traversal.tar.gz" \
  --transform='s#^#../#' foundry-cli LICENSE README.md templates
expect_rejected "${test_root}/traversal.tar.gz"

mkdir -p "${test_root}/symlink"
make_base_fixture "${test_root}/symlink"
ln -s ../../outside "${test_root}/symlink/escape"
tar -C "${test_root}/symlink" -czf "${test_root}/symlink.tar.gz" \
  foundry-cli LICENSE README.md templates escape
expect_rejected "${test_root}/symlink.tar.gz"

mkdir -p "${test_root}/hardlink"
make_base_fixture "${test_root}/hardlink"
ln "${test_root}/hardlink/foundry-cli" "${test_root}/hardlink/escape"
tar -C "${test_root}/hardlink" -czf "${test_root}/hardlink.tar.gz" \
  foundry-cli LICENSE README.md templates escape
expect_rejected "${test_root}/hardlink.tar.gz"

mkdir -p "${test_root}/fifo"
make_base_fixture "${test_root}/fifo"
mkfifo "${test_root}/fifo/unsafe"
tar -C "${test_root}/fifo" -czf "${test_root}/fifo.tar.gz" \
  foundry-cli LICENSE README.md templates unsafe
expect_rejected "${test_root}/fifo.tar.gz"
