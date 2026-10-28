# Design

## Context

See `proposal.md` — Why. The repository is a small QML/JS plugin (five runtime files) that Omarchy installs as a git checkout and updates with a fast-forward pull. The repository is currently private on a free GitHub plan, which does not allow branch protection. There is one maintainer and no CI.

The workflow must work in two environments: inside OpenCode (where the agent runs commands) and in a plain terminal (where hooks still apply). Hooks are not cloned, so activation needs an explicit setup step.

## Goals / Non-Goals

**Goals**

- Make direct work on `main` impossible through every normal entry point: OpenCode shell, plain terminal, and GitHub.
- Keep the manual verification requirement cheap for docs and tooling changes.
- Keep releases reviewable without adding a release branch that diverges from `main`.
- Give every future behavior change a single planning path (OpenSpec).

**Non-Goals**

- Protecting against a determined human who edits `.git/config`, runs `git commit --no-verify`, or edits the ruleset. This is a solo-project guardrail, not a sandbox.
- Automating manual UI verification. It remains a human step.
- Adding a package manager, Node build step, or release framework.

## Decisions

### 1. Trunk-based development with short-lived branches

`main` is always releasable. Branches use `feat/`, `fix/`, `refactor/`, `docs/`, `chore/`, `release/`. Pull requests are squash-merged and the branch is deleted.

**Alternative:** Git Flow (`develop`, `release/*`, `hotfix/*`) adds long-lived branches and merge overhead without adding value for a single-maintainer plugin.

### 2. Layered enforcement

Each layer covers a different entry point:

| Layer | Covers | Bypass |
|---|---|---|
| `opencode.json` permissions | agent shell commands | edit config, restart |
| `.githooks/pre-commit` | any local commit | `--no-verify` |
| `.githooks/pre-push` | any local push | `--no-verify` |
| GitHub ruleset | any push/merge to `main` | admin changes ruleset |
| CI `validate` job | merge gate | ruleset decides |

No single layer is sufficient. The ruleset is the final authority once the repository is public.

### 3. `manifest.json` is the version source of truth

The manifest already declares `version` and is validated by Omarchy. Adding a second version file creates drift. `scripts/check.sh` verifies the SemVer shape and that `CHANGELOG.md` has an entry for the current version.

**Alternative:** `release-please` or `semantic-release` would automate bumps and notes, but adds Node/CI machinery and removes control over when a plugin release happens.

### 4. Two-phase release: prepare, then publish

`scripts/release.sh X.Y.Z` creates `release/vX.Y.Z` with the version bump and changelog, then opens a PR. After the user merges it, `scripts/release.sh --publish X.Y.Z` tags that exact merge commit and creates the GitHub release.

This preserves the "`main` only through PRs" rule. A single direct release commit to `main` would be simpler but would create a permanent exception to the main rule.

**Alternative:** a tag-triggered workflow that creates the release. Rejected because the release would silently happen on any tag push, and debugging Actions is slower than running a local script.

### 5. Changelog from conventional commits at release time

The release script groups commits since the last tag into Added / Fixed / Changed / Documentation / Maintenance sections. The maintainer can edit the generated section in the release PR before merging.

### 6. Manual gate is scoped by staged paths

`scripts/commit.sh` checks the staged file list:

- `.qml`, `.js`, `manifest.json`, `icon.svg` → runtime change, `--verified` required.
- Anything else → no UI test required, checks still run.

Release commits use `--release`, which bypasses `--verified` because the release PR review is the verification step.

### 7. OpenSpec for behavior changes only

Runtime changes need proposal + specs + design + tasks. Tooling, CI, and documentation changes set `skip_specs: true`. This keeps the full workflow for product behavior without generating four markdown files for a typo fix.

### 8. Public repository to enable free rulesets

GitHub branch protection/rulesets require GitHub Pro for private repositories. A public repository enables rulesets on the free plan, which is the only hard, non-local protection available.

### 9. Hooks activated through `core.hooksPath`

`scripts/setup.sh` sets `core.hooksPath=.githooks` and makes the scripts executable. Hooks stay versioned in the repository and are not overwritten by `git init`.

## Risks / Trade-offs

- **`--no-verify` bypasses hooks** → The ruleset still blocks pushes to `main`; OpenCode permissions remove the obvious path.
- **OpenCode permissions are configuration, not a sandbox** → Hooks and the ruleset remain the real gates; the permissions only prevent accidental agent commands.
- **0 required approvals** → A solo maintainer cannot approve their own PR without a second account. The PR still provides a diff, CI, and the manual checklist.
- **Ruleset requires a check named `validate`** → If the CI job is renamed, merges block. The job name is documented in `AGENTS.md` and the workflow.
- **First release has no previous tag** → `git log` falls back to the full history and `gh release create --generate-notes` handles the first release.
- **Changelog generated from commit subjects** → The release PR is the place to correct wording before the tag is created.
- **`release/*` branch can go stale** → The publish step requires an up-to-date `main` and a matching manifest, so a stale branch cannot publish.

## Migration Plan

1. Merge the workflow PR into `main` through the new PR flow.
2. Run `scripts/setup.sh` in every clone (already run in this one).
3. Publish the baseline release with `scripts/release.sh --publish 0.1.0`; the manifest and changelog already contain `0.1.0`.
4. Future work starts on a branch and follows `AGENTS.md`.

**Rollback:** revert the workflow PR; remove the ruleset with `gh api -X DELETE repos/BroFrank/omnezia/rulesets/<id>`; unset hooks with `git config --unset core.hooksPath`.

## Open Questions

None.
