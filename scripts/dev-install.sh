#!/usr/bin/env bash
# Copy the plugin into the local Omarchy plugin directories and rescan.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf '\n✖ dev-install: %s\n' "$*" >&2; exit 1; }
ok() { printf '✔ %s\n' "$*"; }

restart=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart) restart=1; shift ;;
    -h|--help)
      printf 'Usage: scripts/dev-install.sh [--restart]\n'
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

files=(manifest.json BarWidget.qml Panel.qml Service.qml AmneziaIcon.qml Model.js icon.svg)
targets=(
  "${HOME}/.config/omarchy/plugins/io.github.BroFrank.omnezia"
  "${HOME}/.config/omarchy/plugins/bro.amneziawg"
)

for file in "${files[@]}"; do
  [[ -f "$file" ]] || fail "missing runtime file: $file"
done

"$ROOT/scripts/check.sh"

for target in "${targets[@]}"; do
  mkdir -p "$target"
  cp "${files[@]}" "$target/"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$target" >/dev/null || fail "validation failed: $target"
  fi
  ok "copied to ${target}"
done

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell -q shell rescanPlugins || true
  ok "plugin registry rescanned"
fi

if (( restart )); then
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell
    ok "Omarchy shell restarted"
  else
    fail "--restart requested, but omarchy is not available"
  fi
else
  printf '\nRestart the shell to load QML changes: omarchy restart shell\n'
fi

printf '\nNow test manually: docs/manual-test.md\n'
