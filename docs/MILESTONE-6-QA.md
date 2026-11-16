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

No app was launched and no input lock was activated by these checks. Download quarantine/Gatekeeper acceptance, a clean-machine install, final-artifact runtime/recovery and broader playback acceptance are not established. The candidate is ad-hoc signed and not notarized. Owner-approved MIT licensing is complete; public signing decision, demo recording, milestone 6 review and explicit publication approval remain open. See LOCAL-RELEASE-CHECKLIST.md.
