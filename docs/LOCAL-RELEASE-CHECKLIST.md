# Local candidate before public release

The owner requested finishing local work before Apple distribution setup. Do not publish this artifact as a finished release.

- [x] Implement experimental native play/pause and expose its shortcut/limitations.
- [x] Build native helper; pass JavaScript, native policy/recovery, and IPC tests.
- [x] Exercise production target binding and two playback requests on the controlled Chrome player.
- [x] Package the Apple Silicon app and verify its structure/signatures/architecture.
- [x] Complete initial physical playback/unlock test on the rebuilt app (Chrome/YouTube, owner-confirmed; broader matrix below remains).
- [x] Targeted post-review physical retest: Chrome/YouTube, Safari/YouTube, Chrome/course player pause/resume/unlock (owner confirmed).
- [ ] Complete the broader final-build matrix: full screen, long pause and target changes.
- [ ] Complete packaged runtime smoke and recovery checks on this final artifact.
- [x] Follow-up code review: no new actionable defects at c6753d2; both P2 findings addressed.
- [x] Merge milestone 7 (PR #6; main at 9108527).
- [x] Choose license: MIT, explicitly approved by the owner on 2026-11-17.
- [x] Document Developer ID signing/notarization process in RELEASE.md.
- [ ] Owner selects public signing/distribution approach; complete its verification.
- [x] Draft installation/uninstallation instructions, contribution guide, versioned release notes and accurate tested-platform claims.
- [ ] Record and review the demo (DEMO.md).
- [x] Build and verify local ZIP, checksum and manifest (2026-11-17; see MILESTONE-6-QA.md).
- [ ] Review milestone 6 changes.
- [ ] Publish only after review and explicit release authorization.

Current local bundle: `out/PaperMode-darwin-arm64/PaperMode.app`. It is ad-hoc signed, not Developer ID signed/notarized. Keep the prior installed build until replacement/permission behavior is tested. Follow `MILESTONE-7-QA.md` for the remaining acceptance checks.
