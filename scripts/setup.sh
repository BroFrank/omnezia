#!/usr/bin/env bash
# Install the repository hooks and make the workflow scripts executable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push scripts/*.sh

printf '✔ git hooks activated (core.hooksPath=%s)\n' "$(git config --get core.hooksPath)"
printf '✔ scripts are executable\n'

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    printf '✔ gh is authenticated\n'
  else
    printf '… gh is installed but not authenticated; scripts/mr.sh will fail until you run: gh auth login\n'
  fi
else
  printf '… gh is not installed; scripts/mr.sh and release publishing will not work\n'
fi

printf '\nNext: create a branch and follow AGENTS.md.\n'
