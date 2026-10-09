#!/usr/bin/env bash
# Exercise real local git pushes; never connect to AUR.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export REAL_GIT
REAL_GIT="$(command -v git)"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == clone ]]; then
  [[ "$2" == ssh://aur@aur.archlinux.org/foundry-cli-bin.git ]]
  exec "$REAL_GIT" clone "$FAKE_AUR" "$3"
fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH" AUR_USERNAME=test AUR_EMAIL=test@example.com
write_package() {
  local directory="$1" version="$2" revision="$3"
  mkdir -p "$directory"
  printf 'pkgver=%s\npkgrel=%s\n' "$version" "$revision" > "$directory/PKGBUILD"
  printf 'pkgbase = foundry-cli-bin\n\tpkgver = %s\n\tpkgrel = %s\n' "$version" "$revision" > "$directory/.SRCINFO"
}
run_case() {
  local name="$1" version="$2" revision="$3" expected="$4"
  local work="$tmp/$name"
  export FAKE_AUR="$work/aur.git"
  mkdir -p "$work/source/scripts"
  git init -q --bare --initial-branch=master "$FAKE_AUR"
  git init -q -b master "$work/seed"
  write_package "$work/seed" 0.0.56 2
  git -C "$work/seed" add .
  git -C "$work/seed" -c user.name=test -c user.email=test@example.com commit -qm initial
  git -C "$work/seed" push -q "$FAKE_AUR" master
  local before
  before="$(git --git-dir="$FAKE_AUR" rev-parse HEAD)"
  git init -q -b main "$work/source"
  write_package "$work/source/foundry-cli-bin" "$version" "$revision"
  git -C "$work/source" add .
  cp "${PUBLISHER_UNDER_TEST:-$repo_root/scripts/publish-package.sh}" "$work/source/scripts/publish-package.sh"
  "$work/source/scripts/publish-package.sh" foundry-cli-bin > "$work/output" 2>&1
  if [[ "$expected" == noop ]]; then
    [[ "$(git --git-dir="$FAKE_AUR" rev-parse HEAD)" == "$before" ]] || {
      echo "Publisher changed AUR for $name; expected a no-op" >&2
      exit 1
    }
  else
    [[ "$(git --git-dir="$FAKE_AUR" rev-parse HEAD)" != "$before" ]]
    git --git-dir="$FAKE_AUR" show HEAD:.SRCINFO > "$work/published"
    diff -u "$work/source/foundry-cli-bin/.SRCINFO" "$work/published"
  fi
  echo "Passed publish guard: $name"
}
run_case older-version 0.0.55 99 noop
run_case older-revision 0.0.56 1 noop
run_case equal 0.0.56 2 noop
run_case forward-version 0.0.57 1 publish
run_case forward-revision 0.0.56 3 publish
