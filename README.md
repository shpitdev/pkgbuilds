# SHPIT Arch Packages

Arch Linux package definitions for SHPIT-maintained command-line tools.

## Packages

| Package | Upstream | Notes |
|---|---|---|
| `meshix-cli-bin` | `shpitdev/meshix-observability` GitHub Releases | Private release assets. Same auth model as `tabex-bin` and `osyrra-bin`. |
| `tabex-bin` | `shpitdev/tabex` GitHub Releases | Private release assets. The PKGBUILD is public, but `makepkg` needs GitHub access to the `shpitdev` org to download the release tarball. |
| `osyrra-bin` | `shpitdev/osyrra` GitHub Releases | Private release assets. Same auth model as `tabex-bin`. |

## Automation

- `.github/workflows/version-bumps.yml` runs on a schedule or manual dispatch, updates package versions/checksums via repo-owned scripts, regenerates `.SRCINFO`, and opens or updates a PR.
- `.github/workflows/validate.yml` is non-mutating PR validation. It checks PKGBUILD syntax and confirms `.SRCINFO` is in sync.
- `.github/workflows/publish.yml` publishes every changed package directory to the AUR after changes land on `main`, but cleanly skips publishing until AUR secrets exist.

## Local Usage

Update all packages:

```bash
./scripts/update-packages.sh auto
```

Validate package metadata:

```bash
./scripts/validate-packages.sh
```

Build a package locally:

```bash
cd <package-dir>
makepkg -si
```

`gh auth login` must be configured with access to the `shpitdev` org before `makepkg` can download the private `meshix-cli-bin`, `tabex-bin`, or `osyrra-bin` release assets.

After installing `tabex-bin`, start with:

```bash
tabex setup
```

The package includes an install hook that prints the same guidance after install or upgrade.

## Temporary Mode

- You can use this repo immediately without creating the AUR repositories or AUR secrets.
- The scheduled/manual bump workflow uses the repository `GITHUB_TOKEN` for branch and PR operations in this repo.
- Without `SHPIT_GH_TOKEN`, the workflow skips the private package updates (`meshix-cli-bin`, `tabex-bin`, and `osyrra-bin`).
- Without AUR secrets, the publish workflow exits successfully without pushing anywhere.

## Secrets

- `SHPIT_GH_TOKEN` — optional; required for GitHub Actions to refresh the private SHPIT packages (`meshix-cli-bin`, `tabex-bin`, and `osyrra-bin`) from their GitHub releases.
- `AUR_USERNAME`, `AUR_EMAIL`, `AUR_SSH_PRIVATE_KEY` — optional until you actually want to publish to AUR.

## Local Auth

- Local scripts use your normal `gh auth login` session when you run them from your machine.
- GitHub-hosted Actions cannot reuse your personal interactive `gh` login session. They only get the repository `GITHUB_TOKEN` plus any secrets you explicitly configure.

## Adding a New Package

1. Create a directory with the package name and add a `PKGBUILD`.
2. Add a dedicated updater script in `scripts/` if the package needs live version discovery.
3. Regenerate `.SRCINFO` with `./scripts/render-srcinfo.sh <package-dir>`.
4. Extend `./scripts/update-packages.sh` if the package should be included in automated bump PRs.

## Ultimate Setup

1. Create the GitHub repository and enable Actions.
2. In `Settings -> Actions -> General`, set workflow permissions to read and write, and enable GitHub Actions to create pull requests.
3. Attach the `SHPIT_GH_TOKEN` secret (org-level or repo-level) to this repo so the bump workflow can read the private release assets.
4. When the AUR repos exist, add `AUR_USERNAME`, `AUR_EMAIL`, and `AUR_SSH_PRIVATE_KEY`.
5. Run `version-bumps` manually once, confirm the PR output, then merge.
6. After the first merge, `publish.yml` will start pushing package updates to AUR only if those AUR secrets are present.
