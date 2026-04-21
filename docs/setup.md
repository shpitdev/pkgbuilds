# Setup

## Temporary, No-Publish Mode

Use this first.

1. Push the repo to GitHub as `shpitdev/pkgbuilds`.
2. Enable GitHub Actions for the repo.
3. In `Settings -> Actions -> General`:
   - set workflow permissions to `Read and write`
   - enable `Allow GitHub Actions to create and approve pull requests`
4. Do not add any AUR secrets yet.
5. Attach `SHPIT_GH_TOKEN` if you want Actions to bump the private SHPIT packages.
6. Run the `version-bumps` workflow manually.

Result:

- branch and PR creation use the repo `GITHUB_TOKEN`
- `meshix-cli-bin`, `tabex-bin`, and `osyrra-bin` update only if the repo has access to `SHPIT_GH_TOKEN`
- AUR publishing is skipped without failing
- upstream `meshix-observability`, `tabex`, and `osyrra` release workflows can also trigger this workflow automatically with `gh workflow run version-bumps.yml`, but that depends on `SHPIT_WORKFLOW_DISPATCH_TOKEN` being available in their producer-repo Depot CI secrets

## GitHub UI Links

- create PAT: <https://github.com/settings/personal-access-tokens>
- review active org PATs: <https://github.com/organizations/shpitdev/settings/personal-access-tokens/active>
- manage org Actions secrets: <https://github.com/organizations/shpitdev/settings/secrets/actions>

## SHPIT_GH_TOKEN

Create the secret (org-level or repo-level) with access to read private releases on `shpitdev/meshix-observability`, `shpitdev/tabex`, and `shpitdev/osyrra`. An org-level secret with `selected` visibility is the cleanest option if you have multiple consuming repos.

Attach it to this repo with:

```bash
gh secret set SHPIT_GH_TOKEN \
  --org shpitdev \
  --repos pkgbuilds \
  --body "$(gh auth token)"
```

If you later want to narrow or broaden repo access without changing the secret value, rerun the same command with a different repo list.

## SHPIT_WORKFLOW_DISPATCH_TOKEN

Create a fine-grained PAT that can trigger workflow dispatches in:

- `shpitdev/homebrew-tap`
- `shpitdev/pkgbuilds`

Store that PAT as the GitHub org secret `SHPIT_WORKFLOW_DISPATCH_TOKEN` with `selected` visibility for these producer repos:

- `shpitdev/meshix-observability`
- `shpitdev/tabex`
- `shpitdev/osyrra`

Those producer release workflows run in Depot CI, so GitHub org secrets are not enough on their own. Mirror the same secret into Depot for each producer repo with one of these paths:

```bash
cd /home/anandpant/Development/shpitdev/meshix/meshix-observability
depot ci migrate secrets-and-vars -y

cd /home/anandpant/Development/shpitdev/tabex
depot ci migrate secrets-and-vars -y

cd /home/anandpant/Development/shpitdev/osyrra
depot ci migrate secrets-and-vars -y
```

Or add the Depot secrets directly:

```bash
depot ci secrets add SHPIT_WORKFLOW_DISPATCH_TOKEN --repo shpitdev/meshix-observability
depot ci secrets add SHPIT_WORKFLOW_DISPATCH_TOKEN --repo shpitdev/tabex
depot ci secrets add SHPIT_WORKFLOW_DISPATCH_TOKEN --repo shpitdev/osyrra
```

## Local Operator Flow

If you are logged into GitHub locally with `gh auth login`, you can run:

```bash
./scripts/update-packages.sh all
./scripts/validate-packages.sh
```

That uses your local GitHub CLI session for private release access.

For `tabex-bin`, the package install hook now points users at:

```bash
tabex setup
```

That is safe because `v0.0.4` is the first stable release that ships the source-repo-side setup flow.

## Full Publish Setup

When you are ready to publish to AUR:

1. Create the target AUR package repos (`meshix-cli-bin`, `tabex-bin`, `osyrra-bin`).
2. Generate an SSH key that can push to those AUR repos.
3. Add these repo secrets:
   - `AUR_USERNAME`
   - `AUR_EMAIL`
   - `AUR_SSH_PRIVATE_KEY`
4. Merge a PR that changes `PKGBUILD` or `.SRCINFO` on `main`.
5. `publish.yml` will detect each changed package directory and push it to the matching AUR repo.

## Token Model

- Same-repo automation uses the built-in `GITHUB_TOKEN`.
- Cross-repo private release access for `meshix-cli-bin`, `tabex-bin`, and `osyrra-bin` needs a separate credential in Actions, because the workflow token is scoped to the repository that contains the workflow.
- Local runs can use your normal `gh auth login` session instead of any exported token.

## Recommended Follow-Up

Replace the org-level token with a narrower machine credential when practical:

1. Create a dedicated machine user token with only the repo access needed for private release reads on `shpitdev/meshix-observability`, `shpitdev/tabex`, and `shpitdev/osyrra`.
2. Or use a GitHub App installation token flow for the cleanest long-term setup.
