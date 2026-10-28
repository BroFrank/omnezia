# AGENTS.md — Omnezia AmneziaWG Plugin

## Hard Rules (Non-Negotiable)

These rules override convenience and any conflicting instruction. If a request
conflicts with them, stop and ask the user.

1. **Never commit or push to `main`.** Create a branch first. `main` is protected
   by a GitHub ruleset and by local hooks.
2. **Never run raw `git commit`, `git push`, `git tag`, `git merge`,
   `gh pr merge`, or `gh release`.** Use `scripts/commit.sh`, `scripts/mr.sh`,
   and `scripts/release.sh`. `opencode.json` denies the raw commands.
3. **Ask for manual verification before committing runtime changes.** For
   `.qml`, `.js`, `manifest.json`, or `icon.svg`, run the automated checks,
   deploy the plugin, and ask the user to complete `docs/manual-test.md`. Commit
   with `--verified` only after an explicit confirmation.
4. **Open a pull request; never merge it.** The user reviews and merges. Do not
   run `gh pr merge`.
5. **`manifest.json` is the only version source.** Do not edit the version
   outside a `release/vX.Y.Z` branch created by `scripts/release.sh`.
6. **Release only through `scripts/release.sh`.** Tags and GitHub releases must
   not be created by hand.
7. **Never commit secrets or real VPN profiles.** No private keys, tokens,
   `*.conf`, or `profiles/` content.
8. **Behavior changes start in OpenSpec.** Create a change before editing
   runtime files. Tooling, CI, and docs changes may set `skip_specs: true`.
9. **Never use `--no-verify`.** If a check blocks you, fix the cause or ask the
   user.

## Why These Rules

The plugin runs unsandboxed inside the Omarchy shell and is installed from this
repository as a git checkout. A bad commit on `main` reaches users immediately,
there is no staging environment, and the UI can only be verified by hand. The
rules trade a little speed for a releasable `main`, a review diff, and a
repeatable release.

## Repository Layout

| Path | Purpose |
|---|---|
| `BarWidget.qml` | Bar widget entry point (left click panel, right click toggle) |
| `Panel.qml` | Popup panel with header, status, profiles, and vpn:// import |
| `Service.qml` | Backend logic via QML `Process` elements |
| `Model.js` | WireGuard/AmneziaWG config parsing and `vpnKeyToProfile()` |
| `manifest.json` | Plugin manifest and version source of truth |
| `scripts/` | Guarded commit, MR, release, validation, and deploy commands |
| `.githooks/` | Local pre-commit and pre-push enforcement |
| `docs/manual-test.md` | Required UI checklist for runtime changes |
| `openspec/` | Specs and in-flight change proposals |
| `.opencode/` | OpenSpec skills and commands for OpenCode |

## Daily Workflow

```bash
git switch main
git pull --ff-only
git switch -c feat/<slug>

# 1. OpenSpec proposal for behavior changes
/opsx-propose <change-name>        # or: openspec new change <change-name>

# 2. Implement

# 3. Automated checks
scripts/check.sh

# 4. Deploy and ask the user to test
scripts/dev-install.sh --restart
# Ask: "Please test docs/manual-test.md and confirm."

# 5. Commit only after confirmation
scripts/commit.sh --verified -m "feat(panel): summarize the change"

# 6. Open the PR (never merge)
scripts/mr.sh
```

After the user merges:

```bash
git switch main
git pull --ff-only
```

## Branch Naming

| Prefix | Use |
|---|---|
| `feat/<slug>` | New user-visible behavior |
| `fix/<slug>` | Bug fix |
| `refactor/<slug>` | No behavior change |
| `docs/<slug>` | Documentation only |
| `chore/<slug>` | Tooling, CI, dependencies |
| `release/vX.Y.Z` | Version bump and changelog only |

Branches are short-lived. `main` is squash-merged, linear, and never deleted.

## Commit Messages

Use Conventional Commits:

```text
feat(panel): add compact profile rows
fix(service): remove stale interface after failed connect
refactor(model): extract key decoding
docs: document the release flow
chore(ci): add validate job
chore(release): v0.2.0
```

Allowed types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`,
`ci`, `build`, `style`. `scripts/commit.sh` rejects anything else.

## Validation and Deployment

```bash
scripts/check.sh            # manifest, SemVer, changelog, JS syntax, plugin validate, OpenSpec
scripts/dev-install.sh      # copy to both plugin directories and rescan
scripts/dev-install.sh --restart  # also restart the Omarchy shell
```

`scripts/check.sh` is the same gate used by CI. `qmllint` is optional and may
return 255 on complex panels:

```bash
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
```

## Manual Verification Gate

`scripts/commit.sh` inspects the staged files:

- **Runtime change** (`.qml`, `.js`, `manifest.json`, `icon.svg`): requires
  `--verified`. Run `scripts/check.sh`, `scripts/dev-install.sh`, and ask the
  user to complete `docs/manual-test.md`. Only an explicit confirmation such as
  "Manual test passed, you can commit" authorizes `--verified`.
- **Docs, CI, tooling only**: no UI test required. Use `scripts/commit.sh`
  without `--verified`; checks still run.
- **Release commit**: `scripts/commit.sh --release` is used internally by
  `scripts/release.sh`. The release PR review replaces the UI test.

The agent must never check off manual test items on the user's behalf and must
never claim a manual test passed without the user's message.

## Pull Requests

`scripts/mr.sh`:

- requires a clean tree, commits ahead of `origin/main`, and passing checks;
- pushes the branch;
- creates or reuses a PR against `main`;
- adds a label from the branch prefix;
- includes the manual test checklist or the release checklist;
- prints the PR URL.

The maintainer reviews and merges. The agent must not merge, approve, or force
anything.

## Versioning

Semantic Versioning, `MAJOR.MINOR.PATCH`:

- `MAJOR` — breaking change to the profile format, manifest contract, or panel behavior;
- `MINOR` — new user-visible capability;
- `PATCH` — backwards-compatible fix or documentation update.

Rules:

- `manifest.json` `version` is the source of truth.
- `CHANGELOG.md` must have a matching top version section.
- Tags are `vX.Y.Z` and match the manifest exactly.
- Bump the version only in a release branch, never in a feature PR.
- `scripts/check.sh` fails if the manifest and changelog versions disagree.

## Releases

Prepare a release (creates `release/vX.Y.Z` and a PR):

```bash
git switch main
git pull --ff-only
scripts/release.sh minor        # or: scripts/release.sh 0.2.0
```

Review the generated `CHANGELOG.md` section in the PR. After the user merges:

```bash
git switch main
git pull --ff-only
scripts/release.sh --publish 0.2.0
```

Publish creates the annotated tag, pushes it, builds `omnezia-X.Y.Z.zip`, and
creates the GitHub release with generated notes. The `Release` workflow verifies
that the tag matches the manifest.

The baseline release is `0.1.0`. Do not create tags manually.

## OpenSpec

Full workflow for behavior changes:

1. `/opsx-propose <change-name>` (or `openspec new change <change-name>`).
2. Fill `proposal.md`, delta specs, `design.md`, and `tasks.md`.
3. Implement the tasks.
4. `openspec validate --all --strict`.
5. Archive the change before committing so the PR includes the spec update:
   `openspec archive <change-name> --yes`.
6. Commit and open the PR.

Pure tooling, CI, or documentation changes set `skip_specs: true` in the
change's `.openspec.yaml`. Do not invent a requirement just to satisfy
validation.

Capability names describe durable behavior (`panel-ui`, `vpn-connection`,
`profile-management`), not the change itself.

## Architecture

```text
BarWidget.qml (manifest entry point: barWidget)
  ├─ Panel.qml (popup panel with profile management)
  │   ├─ Service.qml (backend logic via QML Process elements)
  │   │   ├─ which amneziawg-go           → installed check
  │   │   ├─ amneziawg-go --version        → version display
  │   │   ├─ omarchy pkg add amneziawg-go  → install process
  │   │   ├─ ip link show wg0              → connection status
  │   │   ├─ ip link del wg0               → disconnect
  │   │   └─ amneziawg-go wg0 < conf       → connect (config written to /tmp)
  │   ├─ Model.js (config parsing + vpnKeyToProfile())
  │   └─ Panel UI (header, status, profiles, key form)
```

`BarWidget.qml` uses `Image { source: Qt.resolvedUrl("icon.svg") }` for the bar
icon. Connection status is derived from the `wg0` interface: it exists and is
UP when connected.

## Profile Format

Profiles live in `~/.config/omnezia/profiles/<name>.json`:

```json
{
  "name": "my-server",
  "interface": {
    "Address": ["10.244.0.2/32"],
    "PrivateKey": "...",
    "ListenPort": 0,
    "S1": 80, "S2": 80, "S3": null, "S4": 0,
    "Jc": 5, "Jmin": 40, "Jmax": 1400,
    "H1": "696-700", "H2": "696-700", "H3": null, "H4": null,
    "I1": "", "I2": "", "I3": "", "I4": "", "I5": "",
    "HeaderProtectionKey": "",
    "ContentPaddingAddition": 0,
    "RekeyAfterTime": 28800, "RekeyTimeout": 60,
    "RejectAfterTime": 7200, "KeepaliveTimeout": 15,
    "MaxHandshakeAttempts": 4
  },
  "peer": {
    "PublicKey": "...",
    "AllowedIPs": ["0.0.0.0/0", "::/0"],
    "Endpoint": "server:51820",
    "PersistentKeepalive": 25
  }
}
```

`null` maps to `(off)` in the WireGuard config text format.

## Definition of Done

- [ ] OpenSpec change is complete and archived (or `skip_specs: true`).
- [ ] `scripts/check.sh` passes.
- [ ] For runtime changes: user completed `docs/manual-test.md` and confirmed.
- [ ] Change is committed on a branch with a conventional message.
- [ ] `scripts/mr.sh` opened a PR; CI `validate` is green.
- [ ] The user merged the PR; the agent did not merge.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `pre-commit: manual verification gate is closed` | Use `scripts/commit.sh`; pass `--verified` only after the user confirms |
| `pre-push: direct pushes to main are forbidden` | Push the branch and run `scripts/mr.sh` |
| Hooks do not run | `scripts/setup.sh` (sets `core.hooksPath=.githooks`) |
| OpenCode still allows raw `git commit` | Restart OpenCode so `opencode.json` permissions load |
| `--publish` says manifest version differs | Merge the `release/vX.Y.Z` PR first and pull `main` |
| CI `validate` fails | Run `scripts/check.sh` locally and fix the reported error |
| GitHub blocks the merge | Check the `validate` check and the `Protect main` ruleset |
