#!/usr/bin/env bash
# Validate the repository before committing, pushing, or releasing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf '✖ %s\n' "$*" >&2; exit 1; }
ok() { printf '✔ %s\n' "$*"; }
skip() { printf '… %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || fail "jq is required"

[[ -f manifest.json ]] || fail "manifest.json is missing"
jq empty manifest.json >/dev/null 2>&1 || fail "manifest.json is not valid JSON"

[[ -f opencode.json ]] || fail "opencode.json is missing"
jq empty opencode.json >/dev/null 2>&1 || fail "opencode.json is not valid JSON"

version="$(jq -r '.version // empty' manifest.json)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "manifest.json version '${version}' is not SemVer (MAJOR.MINOR.PATCH)"

plugin_id="$(jq -r '.id // empty' manifest.json)"
[[ "$plugin_id" == "io.github.BroFrank.omnezia" ]] || fail "unexpected plugin id: '${plugin_id}'"

entry="$(jq -r '.entryPoints.barWidget // empty' manifest.json)"
[[ -n "$entry" ]] || fail "manifest.json has no entryPoints.barWidget"
[[ -f "$entry" ]] || fail "barWidget entry point is missing: $entry"

for file in \
  AGENTS.md \
  README.md \
  CHANGELOG.md \
  LICENSE \
  docs/manual-test.md \
  BarWidget.qml \
  Panel.qml \
  Service.qml \
  AmneziaIcon.qml \
  Model.js \
  icon.svg; do
  [[ -f "$file" ]] || fail "required file is missing: $file"
done

if command -v node >/dev/null 2>&1; then
  for file in ./*.js; do
    [[ -e "$file" ]] || continue
    node --check "$file" >/dev/null 2>&1 || fail "JavaScript syntax error: $file"
  done
  ok "JavaScript syntax"
else
  skip "node not found; skipped JavaScript syntax check"
fi

if [[ -f CHANGELOG.md ]]; then
  changelog_version="$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | sed -E 's/^## \[(.*)\]$/\1/')"
  [[ -n "$changelog_version" ]] || fail "CHANGELOG.md has no version section"
  [[ "$changelog_version" == "$version" ]] || fail "CHANGELOG.md top version (${changelog_version}) does not match manifest.json (${version})"
  ok "changelog version ${version}"
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$ROOT" >/dev/null || fail "omarchy plugin validate failed"
  ok "omarchy plugin validate"
else
  skip "omarchy not found; skipped plugin validation"
fi

if [[ -d openspec ]] && command -v openspec >/dev/null 2>&1; then
  if ! output="$(openspec validate --all --strict --no-interactive 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "openspec validation failed"
  fi
  ok "openspec validation"
fi

ok "all checks passed"
