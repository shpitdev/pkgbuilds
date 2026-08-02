#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
mkdir -p "${workdir}/bin" "${workdir}/assets"

release_tag="v9.8.7"
for platform in darwin_arm64 linux_amd64; do
  archive_root="tabex_${release_tag}_${platform}"
  mkdir -p "${workdir}/stage/${archive_root}"
  printf '#!/usr/bin/env bash\n' > "${workdir}/stage/${archive_root}/tabex"
  chmod +x "${workdir}/stage/${archive_root}/tabex"
  tar -czf "${workdir}/assets/${archive_root}.tar.gz" -C "${workdir}/stage" "${archive_root}"
done

darwin_sha="$(sha256sum "${workdir}/assets/tabex_${release_tag}_darwin_arm64.tar.gz" | awk '{print $1}')"
linux_sha="$(sha256sum "${workdir}/assets/tabex_${release_tag}_linux_amd64.tar.gz" | awk '{print $1}')"
jq -n \
  --arg tag "${release_tag}" \
  --arg darwin_sha "${darwin_sha}" \
  --arg linux_sha "${linux_sha}" \
  '{
    tag_name: $tag,
    draft: false,
    prerelease: false,
    assets: [
      {name: ("tabex_" + $tag + "_darwin_arm64.tar.gz"), digest: ("sha256:" + $darwin_sha)},
      {name: ("tabex_" + $tag + "_linux_amd64.tar.gz"), digest: ("sha256:" + $linux_sha)}
    ]
  }' > "${workdir}/source-release.json"

cat > "${workdir}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "api" && "$2" == repos/shpitdev/tabex/releases/tags/* ]]; then
  cat "${TABEX_SOURCE_RELEASE_FIXTURE}"
  exit 0
fi
if [[ "$1" == "api" && "$2" == repos/shpitdev/pkgbuilds/releases/tags/* ]]; then
  if [[ -f "${TABEX_PUBLIC_RELEASE_MARKER}" ]]; then
    jq '.tag_name = "tabex-v9.8.7"' "${TABEX_SOURCE_RELEASE_FIXTURE}"
    exit 0
  fi
  echo 'gh: Not Found (HTTP 404)' >&2
  exit 1
fi
if [[ "$1" == "release" && "$2" == "download" ]]; then
  asset=""
  output_dir=""
  while (($#)); do
    case "$1" in
      --pattern)
        asset="$2"
        shift 2
        ;;
      --dir)
        output_dir="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  cp "${TABEX_SOURCE_ASSET_DIR}/${asset}" "${output_dir}/${asset}"
  exit 0
fi
if [[ "$1" == "release" && "$2" == "create" ]]; then
  printf '%q ' "$@" > "${TABEX_CREATE_LOG}"
  touch "${TABEX_PUBLIC_RELEASE_MARKER}"
  exit 0
fi

echo "Unexpected gh invocation: $*" >&2
exit 1
EOF
chmod +x "${workdir}/bin/gh"

if PATH="${workdir}/bin:${PATH}" \
  "${repo_root}/scripts/publish-tabex-release.sh" "v9.8.7-rc.1" >/dev/null 2>&1; then
  echo "Publisher accepted a prerelease tag." >&2
  exit 1
fi

PATH="${workdir}/bin:${PATH}" \
  SOURCE_GITHUB_TOKEN=source-token \
  TARGET_GITHUB_TOKEN=target-token \
  TARGET_REPOSITORY=shpitdev/pkgbuilds \
  TABEX_SOURCE_RELEASE_FIXTURE="${workdir}/source-release.json" \
  TABEX_SOURCE_ASSET_DIR="${workdir}/assets" \
  TABEX_CREATE_LOG="${workdir}/create.log" \
  TABEX_PUBLIC_RELEASE_MARKER="${workdir}/public-release-created" \
  "${repo_root}/scripts/publish-tabex-release.sh" "${release_tag}"

grep -Fq 'tabex-v9.8.7' "${workdir}/create.log"
grep -Fq -- '--latest=false' "${workdir}/create.log"
if grep -Fq -- '--clobber' "${workdir}/create.log"; then
  echo "Publisher must not overwrite existing public assets." >&2
  exit 1
fi
