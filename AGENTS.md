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
| Bar UI + Panel | QML (Quickshell/Quattro) — `BarWidget.qml` (bar), `Panel.qml` (popup) | Bar widget icon, popup panel with profile management |
| Backend | Shell commands via QML `Process` elements | `amneziawg-go`, `ip link del/show` |
| Config parsing | JavaScript (`Model.js`) | Parse WireGuard-style configs ↔ JSON profiles |
| Profile storage | JSON files in `~/.config/omnezia/profiles/` | User profile management |

## Architecture

```
BarWidget.qml (manifest entry point: barWidget)
  ├─ Panel.qml (popup panel with profile management)
  │   ├─ Service.qml (backend logic via QML Process elements)
  │   │   ├─ which amneziawg-go       → installed check
  │   │   ├─ amneziawg-go --version    → version display
  │   │   ├─ omarchy pkg add amneziawg-go → install process
  │   │   ├─ ip link show wg0         → connection status
  │   │   ├─ ip link del wg0          → disconnect
  │   │   └─ amneziawg-go wg0 < conf → connect (writes config to /tmp)
  │   ├─ Model.js (config parsing helpers + vpnKeyToProfile())
  │   └─ KeyboardPanel (popup UI with 4 sections: header, status, profiles, key form)
```

BarWidget uses `Image { source: Qt.resolvedUrl("icon.svg") }` for the bar icon instead of Nerd Font text.

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

1. Edit files in project root (`~/Projects/self/omnezia/`)
2. Copy to installed plugin dirs:
   ```bash
   cp *.qml *.js icon.svg ~/.config/omarchy/plugins/io.github.BroFrank.omnezia/
   cp *.qml *.js icon.svg ~/.config/omarchy/plugins/bro.amneziawg/
   ```
3. Validate with `omarchy plugin validate "$PLUGIN_DIR"` (required)
4. Check QML syntax with `qmllint -I "$OMARCHY_PATH/shell" -U ...` (optional — RC=255 is normal for complex panels)
5. Restart Quickshell after changes: `kill <pid>; sleep 2; quickshell -n -p /usr/share/omarchy/shell --verbose &`
6. Test via `omarchy-shell shell summon/hide "io.github.BroFrank.omnezia"` or bar interaction

> **Note**: filesystem directory uses `bro.amneziawg`, manifest ID uses `io.github.BroFrank.omnezia`. Both are intentional and serve different purposes — the former for plugin discovery on disk, the latter for bar layout configuration. Quickshell loads from `io.github.BroFrank.omnezia`.

## Git Workflow

- Commit after each logical change
- Use conventional commit messages: `feat:`, `fix:`, `refactor:`, `docs:`
- Tag releases with version numbers matching manifest version (`0.1.0`)

## Manual Testing Required

After each iteration, the user should verify:
1. Panel opens/closes on left click (panel toggle) and right click (VPN toggle)
2. Bar icon displays SVG image (not Nerd Font text)
3. Header layout: icon + "OMNEZIA" name + ToggleSwitch in single row
4. AmneziaWG status section shows correct state (installed/not installed/version)
5. Profile list displays with select/delete buttons
6. vpn:// key import form works (paste from clipboard, add profile)
7. Profile selection and connection toggle work correctly
8. Connection status reflects actual amneziawg-go state
9. Config file input and parsing work with real AmneziaWG configs
