# Proposal

## Why

All development currently happens directly on `main`: commits are never reviewed, there is no manual verification gate, no tags, and no releases. A bad commit can break the installed bar widget for every user, and there is no reliable way to roll back to a known-good version.

## What Changes

- Adopt trunk-based development: `main` stays releasable, all work happens on short-lived branches and lands through pull requests.
- Require a manual verification gate before committing changes that affect runtime behavior.
- Add guarded `commit`, MR, and release scripts; deny raw `git commit`, `git push`, `git tag`, `git merge`, `gh pr merge`, and `gh release` in OpenCode permissions.
- Add local git hooks (`pre-commit`, `pre-push`) activated by `scripts/setup.sh`.
- Establish SemVer versioning with `manifest.json` as the source of truth, `CHANGELOG.md`, and annotated `vX.Y.Z` tags.
- Split releases into a reviewed release PR and a publish step that creates the tag and GitHub release.
- Initialize OpenSpec and require a change proposal for behavior changes.
- Make the repository public and protect `main` with a GitHub ruleset.

## Capabilities

### New Capabilities

- `project-workflow`: branch, commit, review, versioning, and release rules enforced by scripts, git hooks, OpenCode permissions, and GitHub rulesets.

### Modified Capabilities

<!-- None: this change adds process tooling and does not alter plugin behavior. -->

## Impact

- New files: `opencode.json`, `.githooks/*`, `scripts/*`, `docs/manual-test.md`, `CHANGELOG.md`, `LICENSE`, `.github/*`, `openspec/*`, `.opencode/*`.
- `AGENTS.md` and `README.md` are updated to describe the new workflow.
- Repository visibility changes from private to public; `main` becomes protected.
- No runtime QML/JS behavior changes.
