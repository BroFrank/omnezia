#!/usr/bin/env bash
# Prepare and publish releases. Tagging is only allowed through this script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh <version|patch|minor|major>   Prepare a release PR
  scripts/release.sh --publish <version>           Tag and publish a merged release

Options:
  --dry-run   Show what would happen without committing, tagging, or publishing

Prepare:
  - requires a clean, up-to-date main
  - creates release/vX.Y.Z
  - bumps manifest.json and prepends a CHANGELOG.md section
  - commits with scripts/commit.sh --release and opens a PR

Publish (after the release PR is merged):
  - requires a clean, up-to-date main whose manifest matches <version>
  - creates and pushes the annotated vX.Y.Z tag
  - creates a GitHub release with generated notes and a plugin archive

Examples:
  scripts/release.sh minor
  scripts/release.sh 0.2.0
  scripts/release.sh --publish 0.2.0
EOF
}

fail() { printf '\n✖ release: %s\n' "$*" >&2; exit 1; }
ok() { printf '✔ %s\n' "$*"; }

resolve_version() {
  local requested="$1"
  local major minor patch

  if [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s' "$requested"
    return
  fi

  IFS=. read -r major minor patch <<<"$current"
  case "$requested" in
    major) printf '%s.0.0' "$((major + 1))" ;;
    minor) printf '%s.%s.0' "$major" "$((minor + 1))" ;;
    patch) printf '%s.%s.%s' "$major" "$minor" "$((patch + 1))" ;;
    *) fail "invalid version '$requested'; use X.Y.Z, patch, minor, or major" ;;
  esac
}

generate_changelog_section() {
  local version="$1"
  local range last_tag commits added fixed changed docs maintenance section

  if last_tag="$(git describe --tags --abbrev=0 2>/dev/null)"; then
    range="${last_tag}..HEAD"
  else
    range="HEAD"
  fi

  commits="$(git log "$range" --no-merges --pretty=format:'%s' | grep -vE '^chore\(release\):' || true)"

  added="$(grep -E '^feat(\([^)]*\))?!?: ' <<<"$commits" | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"
  fixed="$(grep -E '^fix(\([^)]*\))?!?: ' <<<"$commits" | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"
  changed="$(grep -E '^(refactor|perf)(\([^)]*\))?!?: ' <<<"$commits" | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"
  docs="$(grep -E '^docs(\([^)]*\))?!?: ' <<<"$commits" | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"
  maintenance="$(grep -E '^(chore|ci|build|test|style)(\([^)]*\))?!?: ' <<<"$commits" | sed -E 's/^[a-z]+(\([^)]*\))?!?: /- /' || true)"

  section="## [$version] - $(date +%F)"
  if [[ -n "$added" ]]; then
    section+=$'\n\n### Added\n'"$added"
  fi
  if [[ -n "$fixed" ]]; then
    section+=$'\n\n### Fixed\n'"$fixed"
  fi
  if [[ -n "$changed" ]]; then
    section+=$'\n\n### Changed\n'"$changed"
  fi
  if [[ -n "$docs" ]]; then
    section+=$'\n\n### Documentation\n'"$docs"
  fi
  if [[ -n "$maintenance" ]]; then
    section+=$'\n\n### Maintenance\n'"$maintenance"
  fi
  if [[ -z "$added$fixed$changed$docs$maintenance" ]]; then
    section+=$'\n\n### Changed\n- No user-facing changes.'
  fi

  printf '%s' "$section"
}

publish=0
dry_run=0
requested=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish) publish=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'Unknown argument: %s\n' "$1" >&2; usage; exit 2 ;;
    *)
      [[ -z "$requested" ]] || { usage; fail "only one version argument is allowed"; }
      requested="$1"
      shift
      ;;
  esac
done

[[ -n "$requested" ]] || { usage; exit 2; }

command -v jq >/dev/null 2>&1 || fail "jq is required"
[[ -f manifest.json ]] || fail "manifest.json is missing"

current="$(jq -r '.version // empty' manifest.json)"
[[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "current manifest version is not SemVer: '$current'"

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
[[ -n "$branch" ]] || fail "detached HEAD; switch to main first"
[[ "$branch" == "main" ]] || fail "releases must start from main (current: $branch)"

if [[ -n "$(git status --porcelain)" ]]; then
  fail "working tree is not clean"
fi

git fetch origin main --quiet
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main is not up to date with origin/main"

if (( publish )); then
  [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--publish requires an explicit X.Y.Z version"
  version="$requested"
else
  version="$(resolve_version "$requested")"
fi

tag="v${version}"

if (( publish )); then
  [[ "$current" == "$version" ]] || fail "manifest version is $current, not $version.
  Merge the release/v${tag} pull request first, then rerun --publish."
else
  [[ "$current" != "$version" ]] || fail "version $version is already the current manifest version"
  newest="$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -n1)"
  [[ "$newest" == "$version" ]] || fail "requested version $version is lower than current $current"
fi

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1; then
  fail "tag ${tag} already exists locally"
fi
if git ls-remote --tags origin "refs/tags/${tag}" | grep -q .; then
  fail "tag ${tag} already exists on origin"
fi

if (( publish )); then
  command -v gh >/dev/null 2>&1 || fail "gh is required to publish"
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; run: gh auth login"
  command -v zip >/dev/null 2>&1 || fail "zip is required to build the release archive"

  if (( dry_run )); then
    printf 'Dry run: would create and push tag %s, then create a GitHub release with omnezia-%s.zip\n' "$tag" "$version"
    exit 0
  fi

  git tag -a "$tag" -m "Omnezia ${tag}"
  git push origin "$tag"
  ok "tag ${tag} pushed"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  pkg="${tmpdir}/omnezia-${version}"
  mkdir -p "$pkg"
  cp manifest.json BarWidget.qml Panel.qml Service.qml AmneziaIcon.qml Model.js icon.svg README.md LICENSE "$pkg/"
  (cd "$tmpdir" && zip -qr "omnezia-${version}.zip" "omnezia-${version}")

  url="$(gh release create "$tag" \
    --title "Omnezia ${tag}" \
    --generate-notes \
    --verify-tag \
    "${tmpdir}/omnezia-${version}.zip#Omnezia ${version} plugin archive")"

  ok "release created: ${url}"
  printf '\nDone. The plugin archive is attached to the release.\n'
  exit 0
fi

git switch -c "release/${tag}"

tmp="$(mktemp)"
jq --arg v "$version" '.version = $v' manifest.json > "$tmp"
mv "$tmp" manifest.json

grep -qE '^## \[Unreleased\]$' CHANGELOG.md || fail "CHANGELOG.md has no '## [Unreleased]' section"

section="$(generate_changelog_section "$version")"
tmp="$(mktemp)"
awk -v section="$section" '
  { print }
  /^## \[Unreleased\]$/ && !inserted {
    print ""
    print section
    inserted = 1
  }
' CHANGELOG.md > "$tmp"
mv "$tmp" CHANGELOG.md

git add manifest.json CHANGELOG.md

if (( dry_run )); then
  printf '\nDry run: no commit, push, or pull request was created.\n'
  printf 'The branch release/%s and staged changes were left in place.\n' "$tag"
  printf 'Discard them with: git reset --hard && git switch main\n\n'
  git diff --cached
  exit 0
fi

scripts/commit.sh --release -m "chore(release): ${tag}"
scripts/mr.sh --release

ok "release PR prepared for ${version}"
printf '\nNext:\n'
printf '  1. Review and merge the release PR (the user merges, not the agent).\n'
printf '  2. git switch main && git pull --ff-only\n'
printf '  3. scripts/release.sh --publish %s\n' "$version"
