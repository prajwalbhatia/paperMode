# Local candidate before public release

The owner requested finishing local work before Apple distribution setup. Do not publish this artifact as a finished release.

- [x] Implement experimental native play/pause and expose its shortcut/limitations.
- [x] Build native helper; pass JavaScript, native policy/recovery, and IPC tests.
- [x] Exercise production target binding and two playback requests on the controlled Chrome player.
- [x] Package the Apple Silicon app and verify its structure/signatures/architecture.
- [x] Complete initial physical playback/unlock test on the rebuilt app (Chrome/YouTube, owner-confirmed; broader matrix below remains).
- [x] Targeted post-review physical retest: Chrome/YouTube, Safari/YouTube, Chrome/course player pause/resume/unlock (owner confirmed).
- [x] Final local candidate: owner-confirmed Chrome and Safari full-screen playback/unlock; Safari three-minute pause/resume.
- [ ] Remaining final-candidate playback matrix: Chrome long pause, target changes/ambiguity and hung-browser behavior.
- [x] Extracted final local candidate runtime smoke and IPC/preview/preparation tests (MILESTONE-6-QA.md).
- [ ] Final-candidate physical recovery and permission-revocation checks.
- [x] Follow-up code review: no new actionable defects at c6753d2; both P2 findings addressed.
- [x] Merge milestone 7 (PR #6; main at 9108527).
- [x] Choose license: MIT, explicitly approved by the owner on 2026-11-17.
- [x] Document Developer ID signing/notarization process in RELEASE.md.
- [x] Owner selected unnotarized GitHub preview distribution on 2026-11-17.
- [x] Verify Firefox download, quarantine, per-app approval, Applications replacement, permission recovery, Chrome lock/playback/unlock and restart on the development Mac (PRERELEASE-QA.md).
- [ ] Clean-machine install and first-time permission acceptance remain unverified.
- [x] Draft installation/uninstallation instructions, contribution guide, versioned release notes and accurate tested-platform claims.
- [ ] Record and review the demo (DEMO.md).
- [x] Build and verify local ZIP, checksum and manifest (2026-11-17; see MILESTONE-6-QA.md).
- [ ] Review milestone 6 changes.
- [ ] Publish only after review and explicit release authorization.

Current local bundle: `out/PaperMode-darwin-arm64/PaperMode.app`. It is ad-hoc signed, not Developer ID signed/notarized. Keep the prior installed build until replacement/permission behavior is tested. Follow `MILESTONE-7-QA.md` for the remaining acceptance checks.
