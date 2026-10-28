# project-workflow Specification

## Purpose
Defines the development workflow that keeps `main` releasable and requires human verification before changes are committed, merged, and released.

## Requirements

### Requirement: Branch-only development

The repository SHALL keep `main` releasable and SHALL reject commits and pushes that target `main` directly. All work MUST happen on a branch whose name starts with `feat/`, `fix/`, `refactor/`, `docs/`, `chore/`, or `release/`.

#### Scenario: Commit on main is rejected

- **WHEN** a developer or agent attempts to commit while `main` is checked out
- **THEN** the pre-commit hook exits non-zero and prints the branch workflow

#### Scenario: Push to main is rejected

- **WHEN** a developer or agent attempts to push `refs/heads/main`
- **THEN** the pre-push hook exits non-zero and points to `scripts/mr.sh`

#### Scenario: Feature branch commit is accepted

- **WHEN** the current branch matches an allowed prefix and all other gates pass
- **THEN** the commit is created

### Requirement: Manual verification gate

A commit that changes runtime behavior (`.qml`, `.js`, `manifest.json`, or runtime assets such as `icon.svg`) SHALL require explicit human confirmation recorded by passing `--verified` to `scripts/commit.sh`. Before requesting confirmation, the agent MUST run automated checks and deploy the plugin for manual testing.

#### Scenario: Runtime change without confirmation is rejected

- **WHEN** `scripts/commit.sh` is invoked for a runtime change without `--verified`
- **THEN** the script exits non-zero and lists the manual test document

#### Scenario: Runtime change after confirmation is accepted

- **WHEN** the user explicitly confirms the manual test and the agent passes `--verified`
- **THEN** the script runs checks and creates the commit

#### Scenario: Docs-only change skips UI testing

- **WHEN** the staged files contain no runtime files
- **THEN** `scripts/commit.sh` creates the commit without requiring `--verified`

### Requirement: Merge request flow

Completed branch work SHALL reach `main` only through a pull request created by `scripts/mr.sh`. Direct pushes to `main` and agent-initiated merges are forbidden.

#### Scenario: MR script creates a pull request

- **WHEN** the branch is clean, checks pass, and `scripts/mr.sh` runs
- **THEN** the branch is pushed and a pull request targeting `main` is created or reused

#### Scenario: Agent merge is blocked

- **WHEN** the agent attempts `gh pr merge` or a direct push to `main`
- **THEN** the OpenCode permission rule and the pre-push hook deny the operation

#### Scenario: Pull request carries the manual test checklist

- **WHEN** `scripts/mr.sh` creates a pull request
- **THEN** the body links to `docs/manual-test.md` and includes a checklist for runtime changes

### Requirement: Semantic versioning

`manifest.json` `version` SHALL be the single source of truth for the plugin version and MUST be valid SemVer. Release tags MUST use `vX.Y.Z` and match the manifest version. `CHANGELOG.md` MUST contain an entry for the current version.

#### Scenario: Version checks pass

- **WHEN** `scripts/check.sh` runs with a valid manifest and matching changelog entry
- **THEN** the check exits zero

#### Scenario: Invalid manifest version fails

- **WHEN** the manifest version is not `MAJOR.MINOR.PATCH`
- **THEN** `scripts/check.sh` exits non-zero with a SemVer error

#### Scenario: Tag mismatch fails

- **WHEN** a tag `vX.Y.Z` does not match the manifest version
- **THEN** the release verification workflow fails

### Requirement: Release preparation

`scripts/release.sh X.Y.Z` SHALL create a `release/vX.Y.Z` branch that bumps the manifest, adds a changelog entry, commits the result, pushes the branch, and opens a pull request. It MUST NOT create a tag or a GitHub release.

#### Scenario: Prepare creates a release PR

- **WHEN** the working tree is clean, `main` is up to date, and the requested version is greater than the current version
- **THEN** a `release/vX.Y.Z` branch and pull request are created

#### Scenario: Invalid or non-increasing version is rejected

- **WHEN** the requested version is invalid, equal to, or lower than the current manifest version
- **THEN** the script exits non-zero without changing files

### Requirement: Release publication

`scripts/release.sh --publish X.Y.Z` SHALL run only from a clean, up-to-date `main` whose manifest version equals `X.Y.Z`. It SHALL create an annotated `vX.Y.Z` tag, push the tag, build a plugin archive, and create a GitHub release with generated notes.

#### Scenario: Publish succeeds

- **WHEN** the release PR is merged, `main` is clean and current, and the manifest matches the requested version
- **THEN** the annotated tag is pushed and the GitHub release is created with a plugin archive

#### Scenario: Publish from dirty or stale main fails

- **WHEN** `main` has uncommitted changes or is behind `origin/main`
- **THEN** the script exits non-zero before tagging

#### Scenario: Publish before merge fails

- **WHEN** the manifest version does not equal the requested version
- **THEN** the script exits non-zero and asks the user to merge the release PR first

### Requirement: Secret and profile protection

Commits SHALL be rejected when staged content contains private keys, access tokens, real VPN profiles (`*.conf`, `profiles/*`), or files larger than 2 MB.

#### Scenario: Private key is rejected

- **WHEN** a staged file contains a WireGuard private key value or a PEM private key block
- **THEN** the pre-commit hook exits non-zero and names the file

#### Scenario: VPN profile is rejected

- **WHEN** a staged path matches `*.conf` or `profiles/*` and is not an `*.example.conf`
- **THEN** the pre-commit hook exits non-zero

#### Scenario: Documentation placeholder is allowed

- **WHEN** a staged file contains only placeholders such as `your-private-key-here` or `...`
- **THEN** the pre-commit hook allows the commit

### Requirement: OpenSpec planning

Every change that alters runtime behavior SHALL have an OpenSpec change with `proposal.md`, delta specs, `design.md`, and `tasks.md` before implementation. Purely tooling or documentation changes MAY set `skip_specs: true`.

#### Scenario: Behavior change starts with a proposal

- **WHEN** the agent starts a feature or behavior fix
- **THEN** it creates or updates an OpenSpec change before editing runtime files

#### Scenario: Tooling change opts out of specs

- **WHEN** a change touches only scripts, CI, or documentation and sets `skip_specs: true`
- **THEN** `openspec validate` accepts the change without delta specs
