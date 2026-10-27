#!/usr/bin/env bash
# Guarded commit entry point. Raw `git commit` is blocked by project rules.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: scripts/commit.sh [--verified] [--release] -m "type(scope): message"

  --verified   Confirmed that the user completed docs/manual-test.md
  --release    Release commit; verified by reviewing the release PR instead
  -m, --message  Conventional commit message (required)

Runtime changes (.qml, .js, manifest.json, icon.svg) require --verified.
Docs, CI, and tooling changes do not.
EOF
}

fail() { printf '\n✖ commit: %s\n' "$*" >&2; exit 1; }

verified=0
release=0
message=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verified) verified=1; shift ;;
    --release) release=1; shift ;;
    -m|--message)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      message="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
[[ -n "$branch" ]] || fail "detached HEAD; create a branch first"
[[ "$branch" != "main" ]] || fail "commits to main are forbidden.
  Create a branch first: git switch -c feat/<slug>"

[[ -n "$message" ]] || { usage; fail "commit message is required (-m)"; }

pattern='^(feat|fix|refactor|docs|test|chore|perf|ci|build|style)(\([a-z0-9._/-]+\))?!?: .+$'
[[ "$message" =~ $pattern ]] || fail "message is not a conventional commit:
  feat|fix|refactor|docs|test|chore|perf|ci|build|style(scope): summary"

if git diff --cached --quiet; then
  fail "nothing is staged. Stage the intended files with: git add <paths>"
fi

runtime=0
while IFS= read -r file; do
  case "$file" in
    *.qml|*.js|manifest.json|icon.svg) runtime=1 ;;
  esac
done < <(git diff --cached --name-only --diff-filter=ACMRD)

if (( runtime && ! verified && ! release )); then
  fail "runtime files are staged, but manual verification was not confirmed.
  1. Run scripts/check.sh
  2. Run scripts/dev-install.sh
  3. Ask the user to test docs/manual-test.md
  4. Rerun with --verified only after an explicit confirmation"
fi

"$ROOT/scripts/check.sh"

if (( release )); then
  export OMNEZIA_RELEASE=1
else
  export OMNEZIA_VERIFIED=1
fi

git commit -m "$message"

printf '\n✔ committed on %s: %s\n' "$branch" "$message"
printf 'Next: scripts/mr.sh\n'
