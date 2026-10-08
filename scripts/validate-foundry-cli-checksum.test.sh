#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/foundry-cli-bin" "$tmp/bin"
cp "$repo_root/scripts/validate-foundry-cli-checksum.sh" "$tmp/scripts/"
printf "pkgver=1.2.3\n_sha256='%064d'\n" 0 > "$tmp/foundry-cli-bin/PKGBUILD"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
while (($#)); do
  if [[ "$1" == --dir ]]; then cp "$MANIFEST" "$2/foundry-cli_1.2.3_checksums.txt"; exit; fi
  shift
done
exit 1
GH
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" MANIFEST="$tmp/manifest"
printf '%064d  foundry-cli_1.2.3_linux_amd64.tar.gz\n' 0 > "$MANIFEST"
"$tmp/scripts/validate-foundry-cli-checksum.sh"
for defect in mismatch missing duplicate; do
  case "$defect" in
    mismatch) printf '%064d  foundry-cli_1.2.3_linux_amd64.tar.gz\n' 1 > "$MANIFEST" ;;
    missing) printf '%064d  foundry-cli_1.2.3_darwin_amd64.tar.gz\n' 0 > "$MANIFEST" ;;
    duplicate) printf '%064d  foundry-cli_1.2.3_linux_amd64.tar.gz\n' 0 0 > "$MANIFEST" ;;
  esac
  if "$tmp/scripts/validate-foundry-cli-checksum.sh" > /dev/null 2>&1; then
    echo "Expected checksum validation to reject $defect" >&2
    exit 1
  fi
  echo "Rejected: $defect"
done
