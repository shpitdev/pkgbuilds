# SHPIT Arch Packages

Arch Linux package definitions for SHPIT-maintained command-line tools.

## Packages

| Package | Upstream | Notes |
|---|---|---|
| `foundry-cli-bin` | `shpitdev/foundry-cli` GitHub Releases | Private release assets. Same auth model as the other SHPIT packages. |
| `meshix-cli-bin` | `shpitdev/meshix-observability` GitHub Releases | Private release assets. Same auth model as `osyrra-bin`. |
| `tabex-bin` | `shpitdev/pkgbuilds` GitHub Releases | Public binary release assets mirrored from the private Tabex release after digest and archive verification. No GitHub credentials are required to install a mirrored version. |
| `osyrra-bin` | `shpitdev/osyrra` GitHub Releases | Private release assets. Same auth model as `meshix-cli-bin`. |

## Automation

- `.github/workflows/version-bumps.yml` keeps non-Foundry packages in the scheduled rolling PR. Dispatching with `foundry_cli_release_tag=vX.Y.Z` updates only Foundry CLI on a dedicated branch, opens a PR, validates it in the job, and squash-merges it with `SHPIT_GH_TOKEN`. That token needs private release read access plus contents and pull-request write access in this repo.
- Equal or older versions are no-ops. `dry_run=true` creates and validates a draft PR, including for an older tag, but never merges or publishes. Do not merge dry-run PRs. Validation failures leave the candidate PR open and the job red.
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

`gh auth login` must be configured with access to the `shpitdev` org before `makepkg` can download the private `foundry-cli-bin`, `meshix-cli-bin`, or `osyrra-bin` release assets. Tabex versions published through the public binary channel need no GitHub credentials.

After installing `tabex-bin`, start with:

```bash
tabex setup
```

The package includes an install hook that prints the same guidance after install or upgrade.

## Temporary Mode

- You can use this repo immediately without creating the AUR repositories or AUR secrets.
- The scheduled/manual bump workflow uses the repository `GITHUB_TOKEN` for branch and PR operations in this repo.
- Without `SHPIT_GH_TOKEN`, the workflow skips the private package updates (`foundry-cli-bin`, `meshix-cli-bin`, and `osyrra-bin`). Public Tabex package updates remain available.
- Without AUR secrets, the publish workflow exits successfully without pushing anywhere.

## Secrets

- `SHPIT_GH_TOKEN` — optional for routine version bumps; required by the trusted `publish-tabex-release` workflow only to read an exact stable release from the private Tabex repository. The workflow uses its repository-scoped token to trigger the local package bump only after the public mirror verifies. The secret is also required to refresh the other private SHPIT packages.
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
3. Attach the `SHPIT_GH_TOKEN` secret (org-level or repo-level) to this repo so the Tabex publisher and private-package bump paths can read their private release assets.
4. When the AUR repos exist, add `AUR_USERNAME`, `AUR_EMAIL`, and `AUR_SSH_PRIVATE_KEY`.
5. Run `version-bumps` manually once, confirm the PR output, then merge.
6. After the first merge, `publish.yml` will start pushing package updates to AUR only if those AUR secrets are present.

### Foundry CLI AUR recovery

The real-actor package PR merge triggers `publish.yml` on main. Missing AUR
credentials fail the Foundry CLI publish job. To retry publishing an already
merged version without touching other packages:

```sh
gh workflow run publish.yml --repo shpitdev/pkgbuilds --ref main -f package=foundry-cli-bin
```
