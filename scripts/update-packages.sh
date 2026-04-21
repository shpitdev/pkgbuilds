#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if (($# == 0)); then
  set -- auto
fi

if [[ "$1" == "auto" ]]; then
  packages=(meshix-cli-bin)
  if [[ -n "${SHPIT_GH_TOKEN:-}" || -z "${GITHUB_ACTIONS:-}" ]]; then
    packages+=(tabex-bin)
    packages+=(osyrra-bin)
  fi
elif [[ "$1" == "all" ]]; then
  packages=(
    meshix-cli-bin
    tabex-bin
    osyrra-bin
  )
else
  packages=("$@")
fi

for package in "${packages[@]}"; do
  case "${package}" in
    meshix-cli-bin)
      if [[ "$1" == "auto" ]]; then
        "${repo_root}/scripts/update-meshix-cli-bin.sh" --optional
      else
        "${repo_root}/scripts/update-meshix-cli-bin.sh"
      fi
      ;;
    tabex-bin)
      if [[ "$1" == "auto" ]]; then
        "${repo_root}/scripts/update-tabex-bin.sh" --optional
      else
        "${repo_root}/scripts/update-tabex-bin.sh"
      fi
      ;;
    osyrra-bin)
      if [[ "$1" == "auto" ]]; then
        "${repo_root}/scripts/update-osyrra-bin.sh" --optional
      else
        "${repo_root}/scripts/update-osyrra-bin.sh"
      fi
      ;;
    *)
      echo "unknown package: ${package}" >&2
      exit 1
      ;;
  esac
done
