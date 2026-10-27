# Tasks

## 1. Repository rules and permissions

- [ ] 1.1 Add `opencode.json` that denies raw `git commit`, `git push`, `git tag`, `git merge`, `gh pr merge`, and `gh release`, and verify the JSON parses with `jq empty opencode.json`
- [ ] 1.2 Rewrite `AGENTS.md` with the hard rules, branch naming, manual gate, MR flow, release flow, and OpenSpec workflow; verify every command referenced in it exists in `scripts/`
- [ ] 1.3 Add `.githooks/pre-commit` and `.githooks/pre-push`; verify `scripts/setup.sh` activates them with `git config --get core.hooksPath` returning `.githooks`

## 2. Validation and manual testing

- [ ] 2.1 Add `scripts/check.sh` for manifest JSON, SemVer, required files, `node --check Model.js`, changelog version, and optional `omarchy plugin validate`; verify it exits zero on the current tree
- [ ] 2.2 Add `docs/manual-test.md` with the full UI checklist; verify every checklist item maps to an observable panel or bar behavior
- [ ] 2.3 Add `scripts/dev-install.sh` that copies runtime files to both plugin directories, validates them, and rescans plugins; verify it runs without errors

## 3. Commit and MR gates

- [ ] 3.1 Add `scripts/commit.sh` with branch guard, conventional commit validation, runtime-file detection, `--verified` enforcement, and `--release` exception; verify a runtime change without `--verified` is rejected
- [ ] 3.2 Add `scripts/mr.sh` that runs checks, pushes the branch, creates or reuses a PR, and adds labels; verify it never merges and prints the PR URL
- [ ] 3.3 Add secret/profile scanning to the pre-commit hook; verify a fake `PrivateKey` and a `*.conf` file are rejected while documentation placeholders pass

## 4. Versioning and releases

- [ ] 4.1 Add `CHANGELOG.md` with the `0.1.0` baseline and verify `scripts/check.sh` accepts the version match
- [ ] 4.2 Add `scripts/release.sh` with `prepare` and `--publish` modes, changelog generation, tag creation, and archive creation; verify `--help` and invalid versions fail cleanly
- [ ] 4.3 Add `.github/workflows/ci.yml` with a `validate` job and `.github/workflows/release.yml` that verifies the tag matches the manifest; verify the YAML is valid and the job name matches the ruleset context

## 5. OpenSpec and documentation

- [ ] 5.1 Configure `openspec/config.yaml` with project context and artifact rules; verify `openspec validate --strict` passes
- [ ] 5.2 Archive this change into `openspec/specs/project-workflow/spec.md`; verify `openspec list --specs` shows the capability
- [ ] 5.3 Update `README.md` with git-based installation, development commands, versioning, and release instructions; verify the documented commands are executable
- [ ] 5.4 Add `LICENSE` and `.gitignore`; verify `git check-ignore` matches `*.conf` and `profiles/`

## 6. GitHub protection and integration

- [ ] 6.1 Make the repository public and enable squash-only merges with automatic branch deletion; verify with `gh repo view --json visibility,deleteBranchOnMerge,squashMergeAllowed`
- [ ] 6.2 Create the `Protect main` ruleset with PR required, linear history, no deletion/force-push, and required `validate` check; verify `gh api repos/BroFrank/omnezia/rulesets` lists it
- [ ] 6.3 Open the workflow PR with `scripts/mr.sh`; verify the PR exists, CI runs, and a direct push to `main` is rejected
