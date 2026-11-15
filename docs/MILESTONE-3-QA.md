# Milestone 3: Electron/native integration QA

Status: implemented; automated verification passed on the development Mac. Real Electron lock/permission tests are pending. Milestone 2 native results do not establish Electron's or the packaged app's permission identity.

## Automated checks — 2026-11-15

- Native build and diagnostic passed.
- 125 native assertions passed.
- 25 JavaScript tests passed: packaging guards, duplicate starts, permission/layout preflight, stale async responses, quit/sleep cancellation, correlated/fragmented protocol frames, invalid events, startup timeout, unexpected exit, and connection-loss cleanup.
- Nine native IPC integration tests passed, covering status/correlation, invalid JSON/version/oversized frames, duplicate request IDs/start, cancellation before delayed start, real nonblocking preview start/shutdown, and EOF during preview.
- Electron smoke check passed: `menuBarCreated:true`, `shortcutRegistered:true`, `state:permission-required` for the agent execution context. No input was blocked. This does not imply VS Code's grant was revoked.

## Manual sequence

Use `npm run start:test` initially. Its menu explicitly identifies the thirty-second development safety limit. Quit an existing PaperMode instance first. The native standalone helper tests and app tests are separate.

1. Check the tray shows the permission state and start/unlock shortcut instructions. Use Enable Accessibility; grant the identity macOS actually shows. Confirm the menu becomes Ready after rechecking. Denied permission must never create a lock or claim Locked.
2. Play a disposable full-screen video. Press Control + Option + Command + P. Confirm Starting appears, then the reminder and Locked after five seconds. Pressing start again while starting must not create another helper/reminder.
3. Test built-in keys/media/trackpad suppression and the countdown reset on a short unlock hold. Hold Control + Option + Command + L for two seconds; verify input returns, the reminder disappears, and the menu becomes Ready.
4. Repeat three sessions. Confirm no stale state or leftover helper/reminder. Check the start shortcut does not accidentally retrigger after unlocking.
5. Quit during preparation; ensure no delayed lock appears. In a bounded session, test parent exit/crash and sleep/wake; verify cleanup and no automatic relock. Schedule any forced termination before starting the lock so recovery does not depend on typing while locked.
6. Repeat permission revocation for the actual app identity (do not assume it is VS Code), and inspect the menu's permission-required state after recovery. Restore permission afterward.
7. After bounded checks pass, use normal `npm start`, confirm the menu no longer shows the development limit, and verify a session can continue beyond thirty seconds before deliberate shortcut unlock.

External keyboard/mouse and multiple-monitor checks remain deferred from milestone 2. Packaged-app identity, signing/notarization, and older OS/hardware validation remain release gates.

Protocol details: [HELPER-PROTOCOL.md](HELPER-PROTOCOL.md).
