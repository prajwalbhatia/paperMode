# PaperMode 0.1.3 Preview 1 release QA

Published prerelease: [v0.1.3-preview.1](https://github.com/prajwalbhatia/paperMode/releases/tag/v0.1.3-preview.1). Source: clean merged main commit `0716fcfe5c0e4824b54f0588156167d2a164946b` from [release PR #11](https://github.com/prajwalbhatia/paperMode/pull/11). ZIP SHA-256: `f6829b0207ef42d64e0738894c61eddf5a7c64e534ebec99f8bd090c5e3c886e`.

- [x] Release PR CI passed JavaScript tests, native policy tests, and ARM64 package verification.
- [x] The preview script packaged from the clean merge commit, extracted the ZIP, and verified app structure, ARM64 binaries, ad-hoc signing, source inventory, notices, and installation instructions.
- [x] A GitHub CLI download matched the local archive checksum and GitHub's asset digest. The public direct ZIP URL returned HTTP 200.
- [x] On the earlier local build with the same runtime code, the owner confirmed Chrome course pause/resume, forward/back seeking without pausing, and two-second unlock with the perimeter progress.
- [ ] Firefox browser download and a physical install/lock/restart of this exact published ZIP were not completed. Firefox changed tabs during the draft download attempt. Earlier versions passed those flows, but they do not establish this artifact's runtime behavior.
- [ ] Clean-machine installation, external devices, Intel Macs, and older macOS versions remain unverified.

This preview is unnotarized. Do not replace its published assets silently; changes require a new version, checksum, and release record.
