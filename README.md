# Omnezia — AmneziaWG VPN Plugin for Omarchy

A bar-widget plugin for [Omarchy](https://omarchy.org/) that provides AmneziaWG VPN connectivity in the status bar.

## Features

- **Multiple profiles**: Store and switch between different VPN server configurations
- **Quick toggle**: Right-click the bar icon to connect/disconnect instantly
- **Panel UI**: Left-click for full profile management, connection details, and config editing
- **AmneziaWG protocol**: Full support for AmneziaWG-specific parameters (obfuscation, padding, header protection)

## Installation

### 1. Clone into Omarchy plugins directory

```bash
# Copy plugin files to your Omarchy config
mkdir -p ~/.config/omarchy/plugins/bro.amneziawg
cp -r ./* ~/.config/omarchy/plugins/bro.amneziawg/
```

### 2. Create profiles directory

```bash
mkdir -p ~/.config/omnezia/profiles
```

### 3. Discover the plugin

```bash
omarchy-shell shell rescanPlugins
```

### 4. Add to bar layout (optional)

The widget defaults to the right section. To add it manually:

```jsonc
// ~/.config/omarchy/shell.json → bar.layout.right
{ "id": "bro.amneziawg" }
```

## Profile Format

Profiles are stored as JSON files in `~/.config/omnezia/profiles/<name>.json`.

### Example profile (from Amnezia server)

```json
{
  "name": "Germany",
  "interface": {
    "Address": ["10.244.0.2/32"],
    "PrivateKey": "your-private-key-here",
    "ListenPort": 0,
    "S1": 80, "S2": 80, "S3": "(off)", "S4": 0,
    "Jc": 5, "Jmin": 40, "Jmax": 1400,
    "H1": "696-700", "H2": "696-700", "H3": "696-700", "H4": "(off)",
    "I1": "", "I2": "", "I3": "", "I4": "", "I5": "",
    "HeaderProtectionKey": "",
    "ContentPaddingAddition": 0,
    "RekeyAfterTime": 28800, "RekeyTimeout": 60,
    "RejectAfterTime": 7200, "KeepaliveTimeout": 15,
    "MaxHandshakeAttempts": 4
  },
  "peer": {
    "PublicKey": "server-public-key-here",
    "AllowedIPs": ["0.0.0.0/0", "::/0"],
    "Endpoint": "server.example.com:51820",
    "PersistentKeepalive": 25
  }
}
```

### AmneziaWG Parameters Reference

| Parameter | Type | Description |
|-----------|------|-------------|
| `S1`–`S4` | int | Handshake/transport message padding sizes |
| `Jc` | int | Number of junk packets before handshake (recommended: 4-12) |
| `Jmin`, `Jmax` | int | Junk packet size range |
| `H1`–`H4` | string | Message header value ranges (e.g. "696-700") or "(off)" |
| `I1`–`I5` | string | Custom signature packet templates |
| `HeaderProtectionKey` | string | Server-side key for header protection (AWG 3+) |
| `ContentPaddingAddition` | uint32 | Content padding range (AWG 3+) |
| `RekeyAfterTime` | int | Seconds before client tries rehandshake |
| `RekeyTimeout` | int | Handshake timeout in seconds |
| `RejectAfterTime` | int | Force handshake + reject data after this time |
| `KeepaliveTimeout` | int | Keepalive interval when no data sent |

## Dependencies

- `amneziawg-go` — AmneziaWG protocol implementation (WireGuard fork with obfuscation)
- `iproute2` (`ip`) — Interface management
- `amneziawg-tools` — Optional config inspection tools

Install:

```bash
# From AUR or build from source
omarchy pkg add amneziawg-go
# or
git clone https://github.com/amnezia-vpn/amneziawg-go && cd amneziawg-go && make install
```

## License

Private — all rights reserved.
