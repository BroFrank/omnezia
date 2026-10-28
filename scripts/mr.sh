#!/usr/bin/env bash
# Push the current branch and open (or reuse) a pull request. Never merges.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: scripts/mr.sh [--release] [--draft]

Pushes the current branch and creates a pull request against main.
If a pull request already exists for the branch, prints its URL and exits.

  --release  Use the release checklist instead of the manual UI checklist
  --draft    Create the pull request as a draft
  --dry-run  Print the title, label, and body without pushing or creating a PR
EOF
}

fail() { printf '\n✖ mr: %s\n' "$*" >&2; exit 1; }

release=0
draft=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) release=1; shift ;;
    --draft) draft=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

command -v gh >/dev/null 2>&1 || fail "gh is required"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; run: gh auth login"

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
[[ -n "$branch" ]] || fail "detached HEAD; create a branch first"
[[ "$branch" != "main" ]] || fail "cannot open a pull request from main"

if [[ -n "$(git status --porcelain)" ]]; then
  fail "working tree is not clean. Commit or stash changes first."
fi

base="main"
git fetch origin "$base" --quiet

count="$(git rev-list --count "origin/${base}..HEAD")"
(( count > 0 )) || fail "no commits ahead of origin/${base}"

"$ROOT/scripts/check.sh"

title="$(git log --reverse --pretty=format:'%s' "origin/${base}..HEAD" | head -n1)"
[[ -n "$title" ]] || title="$branch"

label=""
color=""
case "$branch" in
  feat/*) label="feat"; color="0e8a16" ;;
  fix/*) label="fix"; color="d73a4a" ;;
  docs/*) label="docs"; color="0075ca" ;;
  refactor/*) label="refactor"; color="5319e7" ;;
  chore/*) label="chore"; color="cfd3d7" ;;
  release/*) label="release"; color="fbca04" ;;
esac

if [[ -n "$label" ]]; then
  gh label create "$label" --color "$color" --force >/dev/null 2>&1 || true
fi

commits="$(git log --reverse --pretty=format:'- %s' "origin/${base}..HEAD")"

if (( release )); then
  test_plan=$'- [ ] Manifest version and `CHANGELOG.md` match\n- [ ] `scripts/check.sh` passes\n- [ ] After merge: `scripts/release.sh --publish <version>`'
else
  test_plan=$'- [ ] `scripts/check.sh` passes\n- [ ] Runtime changes manually verified with [`docs/manual-test.md`](docs/manual-test.md)\n- [ ] No secrets, VPN profiles, or unrelated files are included'
fi

body="$(cat <<EOF
## Summary

${commits}

## Test plan

${test_plan}

## Notes

Created with \`scripts/mr.sh\`. The maintainer reviews and merges this pull request; the agent does not merge.
EOF
)"

args=(pr create --base "$base" --head "$branch" --title "$title" --body "$body")
[[ -n "$label" ]] && args+=(--label "$label")
(( draft )) && args+=(--draft)

if (( dry_run )); then
  printf 'Dry run: would push %s and open a pull request\n\n' "$branch"
  printf 'Title: %s\nLabel: %s\n\n%s\n' "$title" "${label:-none}" "$body"
  exit 0
fi

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push origin "HEAD:${branch}"
else
  git push -u origin "HEAD:${branch}"
fi

if url="$(gh pr view "$branch" --json url --jq '.url' 2>/dev/null)"; then
  printf '✔ pull request already exists: %s\n' "$url"
  exit 0
fi

url="$(gh "${args[@]}")"

printf '\n✔ pull request created: %s\n' "$url"
printf 'The maintainer must review and merge it. The agent must not run gh pr merge.\n'
