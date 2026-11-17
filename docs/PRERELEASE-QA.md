# Unnotarized preview download QA — 2026-11-17

Candidate: `v0.1.0-preview.1`, app version 0.1.0, source commit `1ecc12c078295635ca016f4e5c83da3cf55ab2fd` (clean tree).
Artifact: `PaperMode-0.1.0-macos-arm64-unnotarized-preview.zip`.
SHA-256: `f0671f3b3779c031830d00828b57e4acbeab62eaabc2f19e2e66f39ecf2d6db1`.
Draft: https://github.com/prajwalbhatia/paperMode/releases/tag/untagged-0dc6036b9f0e12cf98ae

- 42 JavaScript tests passed; diff whitespace check passed.
- Original and archive-extracted packages passed structural verification (15 ARM64 binaries, 9 source files, strict app/helper signatures and identities).
- GitHub draft prerelease created with ZIP, checksum, manifest and installation instructions; remote ZIP digest matches the local artifact. Repository remains private; no public release or visibility change was performed.
- Downloaded the ZIP through signed-in Firefox using the draft's Assets link. Local SHA-256 matched. Firefox quarantine was present on the archive.
- Opened the ZIP with macOS Archive Utility. Extracted app retained quarantine and passed package checks.
- Backed up the existing installed app to `out/release-local-34K6sT/PaperMode-before-download-test.app`. Closed the idle development instance. Used Finder to copy the download to Applications and accepted Replace.
- Installed app retained quarantine and passed package verification. Finder launch produced a process but this did not establish completed startup. A subsequent no-lock startup diagnostic waited on CoreServicesUIAgent showing the expected “PaperMode Not Opened / Apple could not verify…” warning. Dismissed Done and opened Privacy & Security, which showed “PaperMode was blocked to protect your Mac” and Open Anyway. The owner subsequently confirmed completing Open Anyway and authentication. The PaperMode blocked notice disappeared from Privacy & Security. The system also displays that its Allow applications setting is profile-managed; no global setting was changed.

After owner approval, the installed app smoke test exited 0: menuBarCreated true, shortcutRegistered true, state Ready, Accessibility trusted, ABC-India layout supported. Reopened /Applications/PaperMode.app for physical QA. The per-app Gatekeeper approval flow passed on this existing development Mac; the later normal-launch permission mismatch and recovery are recorded below.

At this point physical QA was pending; subsequent results follow below. No quarantine removal or global Gatekeeper disable was performed. The later explicitly approved PaperMode-only permission reset is documented below.

## Permission mismatch after approval

Owner reported that the installed normal app showed Permission required although its Settings switch was on. Process inspection confirmed /Applications/PaperMode.app with no active lock. The earlier agent-launched smoke diagnostic's trusted result did not establish permission in the normal launch context; physical acceptance was still pending at that point. A stale grant is suspected, not proven.

After explicit owner approval, closed the idle installed app and ran `tccutil reset Accessibility app.papermode.desktop` successfully. Reopened the installed app. Settings showed PaperMode off; the separate papermode-helper and other app entries were unchanged. Owner re-enabled PaperMode and confirmed the normal app shows Ready with Start PaperMode enabled. This establishes permission recovery after the targeted reset; the precise cause of the original mismatch is not proven. Subsequent physical results follow below.

## Downloaded installed app — owner Chrome physical pass

Owner confirmed all six requested steps passed in Chrome: countdown/start, ordinary keyboard and trackpad input suppression while video continued, playback shortcut pause/resume, two-second shortcut unlock, reminder cleanup and restored input, and menu returning to Ready. This applies to the Firefox-downloaded preview installed in Applications after its per-app Gatekeeper approval and PaperMode-only permission reset/re-enable. Restart and permission-persistence results follow below.

## Downloaded installed app — owner restart pass

Owner quit PaperMode, reopened it from Applications, and confirmed all five steps passed: no verification warning on restart, no automatic countdown or lock, permission persisted, menu showed Ready with Start enabled, and another session started and unlocked with the two-second shortcut.

## Current acceptance scope

The browser-download, Archive Utility extraction, Applications replacement, per-app Gatekeeper approval, targeted permission recovery, Chrome physical playback/lock/unlock and installed restart flow passed on this development Mac. This is not a clean-machine install or a claim about every macOS/browser/device combination. Previously documented broader playback/recovery/hardware gates remain open. The prerelease remains a draft in a private repository; review, merge and public visibility/publication steps are still required.

## Public launch verification — 2026-11-17

- Owner explicitly approved publishing the privacy-cleaned final ZIP with the unperformed physical retest disclosed. This does not mark that retest passed.
- GitHub CLI download SHA-256: `afbc72e34891c735cae6831a0edc30689c4ce6e18ba0f48cc3e2952dfbfa935b`. Extracted app passed strict app/helper signatures, 15 Mach-O ARM64 architecture checks, and exact runtime source inventory.
- 42 JavaScript tests and hosted native/package CI passed. Website workflow passed actionlint.
- Prerelease published with ZIP, checksum, manifest and installation instructions. Anonymous ZIP request followed the release redirect to HTTP 200, with expected 120392535-byte content length.
- GitHub Pages deployment succeeded; anonymous HTTP reads of all six website resources matched repository bytes. Browser confirmed the public site loads without ChatGPT authentication.
- Physical acceptance, clean-machine and other documented coverage limits remain unchanged. Demo, paid signing/notarization and private archive deletion remain deferred.
