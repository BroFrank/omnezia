# Omnezia — AmneziaWG VPN Plugin for Omarchy

A bar-widget plugin for [Omarchy](https://omarchy.org/) that provides AmneziaWG VPN connectivity in the status bar.

## Features

- **Multiple profiles**: Store and switch between different VPN server configurations
- **Quick toggle**: Right-click the bar icon to connect/disconnect instantly
- **Panel UI**: Left-click for full profile management with 4 sections:
  - Header with SVG icon, plugin name, and connection toggle
  - AmneziaWG status (install check, version display)
  - Profile list with select/delete actions
  - vpn:// key import form (auto-extracts server name from key)
- **AmneziaWG protocol**: Full support for AmneziaWG-specific parameters (obfuscation, padding, header protection)
- **vpn:// key import**: Paste Amnezia client-generated keys to auto-create profiles

## Installation

### From git (recommended)

```bash
omarchy plugin add https://github.com/BroFrank/omnezia.git --enable
mkdir -p ~/.config/omnezia/profiles
```

Update later with:

```bash
omarchy plugin update io.github.BroFrank.omnezia
```

### Manual install

```bash
git clone https://github.com/BroFrank/omnezia.git \
  ~/.config/omarchy/plugins/io.github.BroFrank.omnezia
mkdir -p ~/.config/omnezia/profiles
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.BroFrank.omnezia
```

### Add to bar layout (optional)

The widget defaults to the right section. To add it manually:

```jsonc
// ~/.config/omarchy/shell.json → bar.layout.right
{ "id": "io.github.BroFrank.omnezia" }
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
    "S1": 80, "S2": 80, "S3": null, "S4": 0,
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

## Development

Requirements: `omarchy`, `amneziawg-go`, `jq`, `node`, `gh`, and `openspec`.
Install OpenSpec with the official installer or npm:

```bash
curl -fsSL https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary/install.sh | sh
# or: npm install -g @fission-ai/openspec@latest
```

```bash
git clone https://github.com/BroFrank/omnezia.git
cd omnezia
scripts/setup.sh          # activate hooks
scripts/check.sh          # manifest, SemVer, changelog, JS syntax, OpenSpec
scripts/dev-install.sh --restart
```

Workflow:

1. Create a branch (`feat/`, `fix/`, `docs/`, `chore/`, `refactor/`).
2. Create an OpenSpec change for behavior changes (`/opsx-propose`).
3. Implement and run `scripts/check.sh`.
4. Deploy with `scripts/dev-install.sh` and complete
   [`docs/manual-test.md`](docs/manual-test.md).
5. Commit with `scripts/commit.sh --verified -m "feat: ..."`.
6. Open a pull request with `scripts/mr.sh`; the maintainer merges.

Direct commits and pushes to `main` are blocked by git hooks and a GitHub
ruleset. Full rules are in [AGENTS.md](AGENTS.md).

## Versioning and Releases

Versions follow [Semantic Versioning](https://semver.org/) and come from
`manifest.json`. `CHANGELOG.md` tracks every release, and tags use `vX.Y.Z`.

```bash
# Prepare a reviewed release PR
scripts/release.sh minor

# After the PR is merged
scripts/release.sh --publish 0.2.0
```

Publishing creates the annotated tag, a plugin archive, and a GitHub release.

## License

MIT
