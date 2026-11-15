# Milestone 5: local packaged release

Status: started. Package structure and non-locking startup passed on the development Mac. Installed-app permission identity and interactive acceptance remain pending. This is not a public release.

## Repeatable checks

Run `npm run package` with native ARM64 Node on macOS. It builds the helper, packages Electron, and runs `npm run check:package` automatically. The checker can also inspect a copied bundle:

```sh
node scripts/check-package.js /path/to/PaperMode.app
```

The checker verifies bundle ID/version/menu-bar mode, deployment target, executable permissions, ARM64 architecture, exact native helper and icon bytes, and current application sources inside app.asar. It never launches the app or changes permissions. Run against the same checkout/build that produced the bundle; mismatched sources deliberately fail.

Default artifact: `out/PaperMode-darwin-arm64/PaperMode.app`.

With other PaperMode instances closed, non-locking startup can be checked using:

```sh
out/PaperMode-darwin-arm64/PaperMode.app/Contents/MacOS/PaperMode --smoke-test
```

This checks tray creation, shortcut registration, and bundled-helper diagnostics, then exits. Permission reported from a shell launch does not establish the permission identity of a Finder-launched installation.

## Verification — 2026-11-15

- All 35 JavaScript tests and 125 native assertions passed.
- Fresh ARM64 package built successfully. Initial sandboxed download failed; retry with network access succeeded.
- Structural verification passed, including all nine source files, guide/tray assets, external reminder artwork, native helper, bundle ID `app.papermode.desktop`, version `0.1.0`, and macOS deployment target `13.0`.
- Packaged smoke initially exited at the single-instance guard. Closed the verified idle development process (no lock helper), then reran successfully: `menuBarCreated:true`, `shortcutRegistered:true`, `state:ready`, helper protocol 1 and `accessibilityTrusted:true` in the agent shell launch context. No lock or permission request was performed.
- Signing inspection reports ad-hoc/linker signatures, no TeamIdentifier, and no sealed resources. The app executable's signing identifier remains Electron. These are local development artifacts, not Developer ID signed/notarized distribution builds; stable permission behavior across replacement is unverified.
- Actual test host: Apple Silicon, macOS 27.2.1. The deployment target does not establish older macOS compatibility.

## Remaining acceptance sequence

1. Quit development instances. Install the bundle in Applications without overwriting an unrelated or unverified existing app. Launch through Finder and verify the guide, icon, menu, and helper resources.
2. Verify denied permission, Not now, and Enable Accessibility through the guide. Record the exact identity macOS requests. Authenticate personally if prompted. Confirm Ready after grant, without relying on VS Code's grant.
3. Start from menu and shortcut; verify the preparation countdown, uninterrupted full-screen playback, all input suppressed, early-release reset, and two-second unlock. Normal packaged sessions have no automatic timeout.
4. Quit/relaunch, then repeat lock/unlock. Welcome acknowledgement persists; lock state never persists. Check recovery after quit, helper/parent failure, sleep during preparation and lock, and permission revocation.
5. Move/relaunch the app and replace it with a newly built version while stopped. Record permission persistence or reapproval, icon/assets, helper startup, and no orphaned lock. Do not assume ad-hoc signing preserves trust.
6. Complete a study session. Carry forward outstanding real shortcut-contention, external-device, multiple-display/notch/hot-plug checks. Record unavailable hardware explicitly.

Milestone 4's new-guide button flow is still pending; its successful real permission off/on check is supporting evidence only. Signing/notarization and public ZIP/DMG publishing decisions belong to milestone 6. Playback control remains deferred to milestone 7.
