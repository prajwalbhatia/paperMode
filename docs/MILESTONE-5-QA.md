# Milestone 5: local packaged release

Status: started. Package structure and non-locking startup passed on the development Mac. Installed-app permission identity and interactive acceptance remain pending. This is not a public release.

## Repeatable checks

Run `npm run package` with native ARM64 Node on macOS. It builds the helper, packages Electron, and runs `npm run check:package` automatically. The checker can also inspect a copied bundle:

```sh
node scripts/check-package.js /path/to/PaperMode.app
```

The checker verifies bundle ID/version/menu-bar mode, deployment target, executable permissions, ARM64 architecture, exact native helper and icon bytes, and current application sources inside app.asar. It also requires strict deep code-signature verification and the app signing identifier `app.papermode.desktop`. It never launches the app or changes permissions. Run against the same checkout/build that produced the bundle; mismatched sources deliberately fail.

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

### Installed-app permission failure and signing correction

- Installed in `/Applications/PaperMode.app`, verified copied contents, and launched through Finder. Process inspection confirmed the installed path. The existing development welcome acknowledgement was retained; this was not a fresh-profile onboarding test.
- Visually inspected the packaged Help guide and artwork. It offered Enable Accessibility / Not now. The user confirmed Not now produced neither a prompt nor a lock, and Enable Accessibility opened Settings with PaperMode identified.
- Settings showed PaperMode enabled, but the app remained Permission required even after the user quit, toggled permission off/on, relaunched through Finder, and refreshed. Packaged permission acceptance **failed**; no lock was attempted.
- Investigation found `codesign --verify --deep --strict` failed on the installed bundle. TCC attribution logs identified the responsible app as `Electron`, with the bundled native helper as accessor. The existing linker signatures did not correctly seal the renamed Electron app/helper bundles. This is a verified packaging defect and a suspected cause of the permission failure, not yet a verified end-to-end fix.
- Added Forge ad-hoc signing of the app and nested Electron code, preserving the Swift helper's valid build signature. Full strict deep verification now passes and the main signing identifier is `app.papermode.desktop`. The new package checker rejects the old invalid app. This does not provide Developer ID trust, notarization, or a stable upgrade permission guarantee.
- Rebuilt and installed the corrected artifact, preserving the old copy at ignored `.build/m5-before-signing.app`. Installed structural/signature checks passed. Finder automation could not reconnect; corrected Finder launch and permission reapproval remain user-assisted pending checks.

### Continue acceptance

1. Quit development instances. Install the bundle in Applications without overwriting an unrelated or unverified existing app. Launch through Finder and verify the guide, icon, menu, and helper resources.
2. Verify denied permission, Not now, and Enable Accessibility through the guide. Record the exact identity macOS requests. Authenticate personally if prompted. Confirm Ready after grant, without relying on VS Code's grant.
3. Start from menu and shortcut; verify the preparation countdown, uninterrupted full-screen playback, all input suppressed, early-release reset, and two-second unlock. Normal packaged sessions have no automatic timeout.
4. Quit/relaunch, then repeat lock/unlock. Welcome acknowledgement persists; lock state never persists. Check recovery after quit, helper/parent failure, sleep during preparation and lock, and permission revocation.
5. Move/relaunch the app and replace it with a newly built version while stopped. Record permission persistence or reapproval, icon/assets, helper startup, and no orphaned lock. Do not assume ad-hoc signing preserves trust.
6. Complete a study session. Carry forward outstanding real shortcut-contention, external-device, multiple-display/notch/hot-plug checks. Record unavailable hardware explicitly.

Milestone 4's new-guide button flow is still pending; its successful real permission off/on check is supporting evidence only. Signing/notarization and public ZIP/DMG publishing decisions belong to milestone 6. Playback control remains deferred to milestone 7.
