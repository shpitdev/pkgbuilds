#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <stable-release-tag>" >&2
  exit 1
fi

release_tag="$1"
source_repo="shpitdev/tabex"
target_repo="${TARGET_REPOSITORY:-shpitdev/pkgbuilds}"

if [[ ! "${release_tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing to publish a non-stable Tabex release tag: ${release_tag}" >&2
  exit 1
fi
if [[ -z "${SOURCE_GITHUB_TOKEN:-}" ]]; then
  echo "SOURCE_GITHUB_TOKEN is required to read the private Tabex release." >&2
  exit 1
fi
if [[ -z "${TARGET_GITHUB_TOKEN:-}" ]]; then
  echo "TARGET_GITHUB_TOKEN is required to publish the public binary release." >&2
  exit 1
fi

version="${release_tag#v}"
public_tag="tabex-${release_tag}"
assets=(
  "tabex_${release_tag}_darwin_arm64.tar.gz"
  "tabex_${release_tag}_linux_amd64.tar.gz"
)
expected_names_json="$(printf '%s\n' "${assets[@]}" | jq -R . | jq -s .)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

verify_public_release() {
  local public_release_file="$1"
  local asset
  local public_digest
  local source_digest

  if ! jq -e --arg public_tag "${public_tag}" --argjson expected_names "${expected_names_json}" '
    .tag_name == $public_tag
      and .draft == false
      and .prerelease == false
      and ([.assets[].name] | sort) == ($expected_names | sort)
      and all(.assets[]; (.digest // "") | test("^sha256:[0-9a-f]{64}$"))
  ' "${public_release_file}" >/dev/null; then
    echo "Public release ${public_tag} is incomplete or contains unexpected assets." >&2
    return 1
  fi

  for asset in "${assets[@]}"; do
    source_digest="$(jq -r --arg name "${asset}" '.assets[] | select(.name == $name) | .digest' "${source_release}")"
    public_digest="$(jq -r --arg name "${asset}" '.assets[] | select(.name == $name) | .digest' "${public_release_file}")"
    if [[ "${public_digest}" != "${source_digest}" ]]; then
      echo "Public release ${public_tag} differs from the private source asset ${asset}." >&2
      return 1
    fi
  done
}

source_release="${workdir}/source-release.json"
GH_TOKEN="${SOURCE_GITHUB_TOKEN}" gh api \
  "repos/${source_repo}/releases/tags/${release_tag}" > "${source_release}"

if ! jq -e --arg tag "${release_tag}" '
  .tag_name == $tag and .draft == false and .prerelease == false
' "${source_release}" >/dev/null; then
  echo "The source must be an exact, published, stable Tabex release: ${release_tag}" >&2
  exit 1
fi

for asset in "${assets[@]}"; do
  digest="$(jq -r --arg name "${asset}" '
    [.assets[] | select(.name == $name)] as $matches
    | if ($matches | length) == 1 then $matches[0].digest // empty else empty end
  ' "${source_release}")"
  if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "The source release must contain one digested asset named ${asset}." >&2
    exit 1
  fi

  GH_TOKEN="${SOURCE_GITHUB_TOKEN}" gh release download "${release_tag}" \
    --repo "${source_repo}" \
    --pattern "${asset}" \
    --dir "${workdir}" >/dev/null

  actual_digest="$(sha256sum "${workdir}/${asset}" | awk '{print $1}')"
  if [[ "sha256:${actual_digest}" != "${digest}" ]]; then
    echo "SHA-256 mismatch for private release asset ${asset}." >&2
    exit 1
  fi

  archive_root="${asset%.tar.gz}"
  archive_entries="$(tar -tzf "${workdir}/${asset}")"
  expected_entries="${archive_root}/
${archive_root}/tabex"
  if [[ "${archive_entries}" != "${expected_entries}" ]]; then
    echo "Unexpected archive contents in ${asset}; refusing to publish." >&2
    exit 1
  fi

  binary_entry_type="$(tar -tvzf "${workdir}/${asset}" | awk -v path="${archive_root}/tabex" '$NF == path { print substr($1, 1, 1) }')"
  if [[ "${binary_entry_type}" != "-" ]]; then
    echo "The Tabex entry in ${asset} is not a regular file; refusing to publish." >&2
    exit 1
  fi

  extract_dir="${workdir}/extract-${asset}"
  mkdir -p "${extract_dir}"
  tar -xzf "${workdir}/${asset}" -C "${extract_dir}"
  if [[ ! -f "${extract_dir}/${archive_root}/tabex" || ! -x "${extract_dir}/${archive_root}/tabex" ]]; then
    echo "The Tabex binary in ${asset} is not executable; refusing to publish." >&2
    exit 1
  fi
done

public_release="${workdir}/public-release.json"
public_release_error="${workdir}/public-release.error"
if GH_TOKEN="${TARGET_GITHUB_TOKEN}" gh api \
  "repos/${target_repo}/releases/tags/${public_tag}" \
  > "${public_release}" 2> "${public_release_error}"; then
  verify_public_release "${public_release}"
  echo "Public Tabex binaries already match ${release_tag}; nothing to publish."
  exit 0
fi

if ! grep -q 'HTTP 404' "${public_release_error}"; then
  cat "${public_release_error}" >&2
  exit 1
fi

notes_file="${workdir}/release-notes.md"
cat > "${notes_file}" <<EOF
Public Tabex ${version} native-host binaries for package-manager installation.

These archives are copied byte-for-byte from the authenticated Tabex ${release_tag} release after GitHub's SHA-256 digests and archive layout are verified. This release contains binaries only; the Tabex source repository remains private.
EOF

release_files=()
for asset in "${assets[@]}"; do
  release_files+=("${workdir}/${asset}")
done

GH_TOKEN="${TARGET_GITHUB_TOKEN}" gh release create "${public_tag}" \
  "${release_files[@]}" \
  --repo "${target_repo}" \
  --target main \
  --title "Tabex ${release_tag} public binaries" \
  --notes-file "${notes_file}" \
  --latest=false

GH_TOKEN="${TARGET_GITHUB_TOKEN}" gh api \
  "repos/${target_repo}/releases/tags/${public_tag}" > "${public_release}"
verify_public_release "${public_release}"

echo "Published ${target_repo} release ${public_tag}."
