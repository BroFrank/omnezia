# AGENTS.md — Omnezia AmneziaWG Plugin

## Project Overview

Omnezia is a bar-widget plugin for the [Omarchy](https://omarchy.org/) Linux distribution. It provides an AmneziaWG VPN client integrated into the status bar, allowing users to:

- Store multiple VPN profiles (WireGuard-style config files with AmneziaWG params)
- Connect/disconnect from VPN servers via a toggle button
- Switch between stored profiles
- View connection status in the bar and panel

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Bar UI + Panel | QML (Quickshell/Quattro) — single `Panel.qml` entry point | Bar widget icon, popup panel with profile management |
| Backend | Shell commands via QML `Process` elements | `amneziawg-go`, `ip link del/show` |
| Config parsing | JavaScript (`Model.js`) | Parse WireGuard-style configs ↔ JSON profiles |
| Profile storage | JSON files in `~/.config/omnezia/profiles/` | User profile management |

## Architecture

```
Panel.qml (manifest entry point: barWidget)
  ├─ Service.qml (backend logic via QML Process elements)
  │   ├─ which amneziawg-go       → installed check
  │   ├─ ip link show wg0         → connection status
  │   ├─ ip link del wg0          → disconnect
  │   └─ amneziawg-go wg0 < conf → connect (writes config to /tmp)
  ├─ Model.js (config parsing helpers)
  ├─ AmneziaIcon.qml (VPN icon component)
  └─ BarIconButton + KeyboardPanel (bar button + popup UI)
```

Unlike Tailscale which calls `tailscale status --json`, AmneziaWG status is determined by:
1. Checking if the interface exists (`ip link show wg0`) — type 65534 = WireGuard/AWG
2. The interface being in UP state indicates connected

## Profile Format (JSON)

Profiles stored in `~/.config/omnezia/profiles/<name>.json`:

```json
{
  "name": "my-server",
  "interface": {
    "Address": ["10.244.0.2/32"],
    "PrivateKey": "...",
    "ListenPort": 0,
    // AmneziaWG params:
    "S1": 80, "S2": 80, "S3": null, "S4": 0,
    "Jc": 5, "Jmin": 40, "Jmax": 1400,
    "H1": "696-700", "H2": "696-700", "H3": null, "H4": null,
    "I1": "", "I2": "", "I3": "", "I4": "", "I5": "",
    "HeaderProtectionKey": "",
    "ContentPaddingAddition": 0,
    "RekeyAfterTime": 28800, "RekeyTimeout": 60,
    "RejectAfterTime": 7200, "KeepaliveTimeout": 15,
    "MaxHandshakeAttempts": 4
  },
  "peer": {
    "PublicKey": "...",
    "AllowedIPs": ["0.0.0.0/0", "::/0"],
    "Endpoint": "server:51820",
    "PersistentKeepalive": 25
  }
}
```

null = "(off)" in WireGuard config text format.

## Development Workflow

1. Edit files under `~/.config/omarchy/plugins/bro.amneziawg/`
2. Validate with `omarchy plugin validate "$PLUGIN_DIR"` (required)
3. Check QML syntax with `qmllint -I "$OMARCHY_PATH/shell" -U ...` (optional — RC=255 is normal for complex panels)
4. Test via `omarchy-shell shell summon/hide "bro.amneziawg"` or bar interaction

## Validation Checklist

- [x] Manifest parses as valid JSON with required fields
- [x] Kind and entry point agree (bar-widget → Panel.qml)
- [x] Every referenced file exists on disk
- [x] No forbidden ID (`bro.amneziawg` is OK, not `omarchy.*`)
- [x] Git initialized with first commit (582eb8b)
- [ ] Plugin folder has no symlinks
- [ ] Manual testing: panel opens/closes, toggle works, profile management

## Git Workflow

- Commit after each logical change
- Use conventional commit messages: `feat:`, `fix:`, `refactor:`, `docs:`
- Tag releases with version numbers matching manifest version
- First commit (582eb8b): initial plugin with all core files

## Manual Testing Required

After each iteration, the user should verify:
1. Panel opens/closes on left click (panel toggle) and right click (VPN toggle)
2. Profile selection works correctly
3. Connection status reflects actual amneziawg-go state
4. Config file input and parsing work with real AmneziaWG configs
