#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <release-archive>" >&2
  exit 1
fi

archive="$1"
listing="$(tar -tzf "${archive}")"

while IFS= read -r member; do
  normalized="${member%/}"
  if [[ -z "${normalized}" || "${normalized}" == /* || "${normalized}" == *\\* ]]; then
    echo "Release archive ${archive} contains an absolute or invalid member path: ${member}" >&2
    exit 1
  fi

  IFS='/' read -r -a segments <<<"${normalized}"
  for segment in "${segments[@]}"; do
    if [[ -z "${segment}" || "${segment}" == "." || "${segment}" == ".." ]]; then
      echo "Release archive ${archive} contains a non-normal member path: ${member}" >&2
      exit 1
    fi
  done
done <<<"${listing}"

while IFS= read -r mode _; do
  case "${mode:0:1}" in
    -|d) ;;
    l|h)
      echo "Release archive ${archive} contains a link; symlink and hardlink targets are not trusted." >&2
      exit 1
      ;;
    *)
      echo "Release archive ${archive} contains an unsafe member type: ${mode:0:1}" >&2
      exit 1
      ;;
  esac
done < <(tar -tvzf "${archive}")

grep -Fxq "foundry-cli" <<<"${listing}"
grep -Fxq "LICENSE" <<<"${listing}"
grep -Fxq "README.md" <<<"${listing}"

if ! grep -Eq '^templates/(compute-module-ts|compute-modules/typescript)/package\.json$' <<<"${listing}"; then
  echo "Release archive ${archive} is missing a recognized compute module template package.json." >&2
  exit 1
fi
