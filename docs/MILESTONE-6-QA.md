# Milestone 6 release preparation QA

## 2026-11-17 local workflow verification

- `npm test`: 41 tests passed, including safe artifact naming.
- `npm run release:local`: rebuilt the helper and Electron app, verified the original bundle, created a ZIP, extracted it and verified the extracted bundle. Both package checks passed: 15 ARM64 Mach-O files and 9 current source files, strict app/helper signatures and expected identifiers.
- `shasum -a 256 -c SHA256SUMS.txt`: passed.
- Archive inspection: PaperMode MIT license, Electron license, Chromium notices, installation instructions and local-QA warning all present and nonempty.
- `git diff --check`: passed.

Local output: `out/release-local-6py4YG/PaperMode-0.1.0-macos-arm64-local-qa.zip`.
SHA-256: `8673dea9a8ed902597c68eaca8978a8d91a385aa76a0e15f3fbb9145672ecfe7`.

This workflow test was built from main commit `9108527d0469984e89792a973275a2c5ae162021` plus the uncommitted milestone 6 changes. Its manifest correctly records `sourceTreeDirty: true`. Rebuild from a clean reviewed commit for any public candidate. The first sandboxed packaging attempt could not fetch Electron; the permitted network-enabled retry succeeded.

## Limits and remaining gates

The initial workflow checks above did not launch the app or activate an input lock. Subsequent runtime and owner physical results are recorded below. Download quarantine/Gatekeeper acceptance, a clean-machine install, final-artifact runtime/recovery and broader playback acceptance are not established. The candidate is ad-hoc signed and not notarized. Owner-approved MIT licensing is complete; public signing decision, demo recording, milestone 6 review and explicit publication approval remain open. See LOCAL-RELEASE-CHECKLIST.md.

## Clean-commit candidate and runtime checks — 2026-11-17

Built from clean commit `1537b9dfe4ff924b93505bed9ac4572b78c10499`; manifest records `sourceTreeDirty: false`.
Artifact: `out/release-local-cY1RbK/PaperMode-0.1.0-macos-arm64-local-qa.zip`.
SHA-256: `f3b3b6b6e3f68b3be98c5fd73efd652f6d6fabe265fa2b8e852b66eca7aa7046`.
Runtime copy extracted from that ZIP: `out/release-local-cY1RbK/runtime-qa/PaperMode.app`.

- Local release workflow and SHA-256 verification passed; original and extracted package checks passed.
- Native policy assertions passed (unlock timing, input filtering, playback selection/repeat/readiness/deadline rules).
- Closed the prior idle app before testing. Extracted app `--smoke-test` exited 0: menu created, start shortcut registered, Ready, Accessibility trusted and ABC-India layout supported.
- All 10 IPC/preview/preparation integration tests passed. Protocol and preview cases used the extracted helper via PAPERMODE_TEST_HELPER; the preparation notification test compiled its separate source harness. These did not activate an input lock.
- Opened the extracted candidate for owner physical QA; results and remaining cases are recorded below.

This is a local extracted-copy check, not an Applications replacement, fresh-machine install or quarantined-download acceptance. No permission was reset. No public signing/notarization claim.

### Owner physical QA — Chrome full screen

Owner confirmed all steps passed on the clean-commit candidate above: input remained blocked, play/pause shortcut paused and resumed the video, Chrome stayed full screen, reminder stayed visible, and the two-second unlock shortcut restored input. Initial session-start difficulty cleared after restarting the idle app; startup diagnostic reported Ready, permission granted and shortcut registered. Root cause of that initial difficulty was not established. Safari results follow below.

### Owner physical QA — Safari full screen

Owner confirmed all steps passed on the same candidate: input stayed blocked, Safari stayed full screen, play/pause paused and resumed the video, the reminder remained visible, and the two-second unlock shortcut restored input. Long-pause results follow below.

### Owner physical QA — Safari three-minute pause

Owner confirmed the candidate remained locked for three minutes while paused, the same Safari video resumed using the playback shortcut, and holding the unlock shortcut restored input.

### Local QA round closed at owner request

The owner requested finalizing this local QA round after the Safari long-pause pass. This is not a claim that all release gates passed. Chrome long-pause, target-change/ambiguity, hung-browser behavior, final-candidate physical recovery and permission-revocation cases remain untested in this round. Earlier milestone evidence remains scoped to its original builds. Demo, clean-install/replacement/download acceptance, signing decision, milestone 6 code review and publication approval remain open.
