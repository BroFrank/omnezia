# Manual test checklist

Runtime changes (`.qml`, `.js`, `manifest.json`, `icon.svg`) must pass this
checklist before they are committed. The agent runs the automated checks and
deploys the plugin, then asks the user to complete this document. The agent
must not mark items as passed on the user's behalf.

## Prepare

```bash
scripts/check.sh
scripts/dev-install.sh --restart
```

Requirements:

- `amneziawg-go` is installed (`omarchy pkg add amneziawg-go` if missing).
- At least one valid profile exists, or a real `vpn://` key is available.
- The widget is enabled in the bar layout.

## 1. Bar icon

- [ ] The bar shows the Omnezia SVG icon, not a Nerd Font glyph or a missing-image box.
- [ ] The icon is dimmed when disconnected and fully opaque when connected.
- [ ] Hovering shows `AmneziaWG: disconnected`, `AmneziaWG: connected`, or `AmneziaWG: working…`.

## 2. Panel open and close

- [ ] Left click opens the panel.
- [ ] Left click again closes the panel.
- [ ] Clicking outside closes the panel.
- [ ] `Esc` closes the panel.
- [ ] Opening the panel does not move or resize the bar.

## 3. Quick toggle

- [ ] Right click starts connecting when disconnected.
- [ ] Right click disconnects when connected.
- [ ] The tooltip shows `AmneziaWG: working…` while the action runs.
- [ ] The bar icon state changes after the action completes.

## 4. Header

- [ ] The header is a single row with the icon, `OMNEZIA`, and the toggle switch.
- [ ] Hovering the toggle shows `Connect`, `Disconnect`, or `Add a profile first` as appropriate.
- [ ] The toggle reflects the real connection state.

## 5. AmneziaWG status section

- [ ] When `amneziawg-go` is installed, the section shows `amneziawg-go installed` and a version.
- [ ] When it is not installed, the section shows the install prompt and the `omarchy pkg add amneziawg-go` hint.
- [ ] The install action reports progress and the result.
- [ ] The section does not flicker or duplicate between refreshes.

## 6. Profile list

- [ ] The section title shows the correct profile count.
- [ ] All JSON profiles from `~/.config/omnezia/profiles/` are listed.
- [ ] The active profile is marked.
- [ ] Selecting a profile switches the active profile.
- [ ] Deleting a profile removes it from the list and from disk.
- [ ] Deleting the active profile leaves the UI in a consistent state.
- [ ] An empty profile directory shows the empty-state message.

## 7. vpn:// import

- [ ] Pasting a valid `vpn://` key and pressing `Add Profile` creates a profile.
- [ ] The profile name is extracted from the key.
- [ ] The new profile appears in the list immediately.
- [ ] Pasting from the clipboard fills the input.
- [ ] An invalid key shows a readable error and does not create a profile.
- [ ] Importing does not log the key or private key to the shell output.

## 8. Connection lifecycle

- [ ] Connecting creates the `wg0` interface and the toggle becomes active.
- [ ] `ip link show wg0` reports the interface as up while connected.
- [ ] Disconnecting removes the interface and the toggle becomes inactive.
- [ ] Switching profiles while connected reconnects with the new profile.
- [ ] A failed connection shows an error and leaves the previous state consistent.
- [ ] Repeated connect/disconnect cycles do not leave stale processes or interfaces.

## 9. Status accuracy

- [ ] The bar and panel report the same state.
- [ ] If the interface is removed outside the plugin (`ip link del wg0`), the UI returns to disconnected after a refresh.
- [ ] The refresh interval from the widget settings is respected.
- [ ] No QML warnings or errors appear in the shell log during the checks above.

## 10. Config parsing

- [ ] A real WireGuard/AmneziaWG config with `S1`, `S2`, `Jc`, `Jmin`, `Jmax`, `H1`–`H4`, and `I1`–`I5` parses without errors.
- [ ] `null` values round-trip as `(off)` in the generated config.
- [ ] Missing `PrivateKey`, `PublicKey`, or `Endpoint` produces a readable error.
- [ ] Comments and blank lines in the source config are ignored.

## Report

For each failure, report:

- the checklist item number;
- what you clicked or ran;
- the expected and actual result;
- the relevant shell log line, if any.

The agent may commit only after an explicit confirmation such as:
"Manual test passed, you can commit."
