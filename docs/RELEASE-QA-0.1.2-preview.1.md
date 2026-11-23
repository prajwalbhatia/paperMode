# PaperMode 0.1.2 Preview 1 release QA

Published prerelease: [v0.1.2-preview.1](https://github.com/prajwalbhatia/paperMode/releases/tag/v0.1.2-preview.1). Source: clean merged commit `5fead36cd44734be867baec98f43c4de31f0af59` from [PR #7](https://github.com/prajwalbhatia/paperMode/pull/7). ZIP SHA-256: `8a1416a0d72f8ab40120b29b2c66a9998ecb7bc7518d5230ffa28651e56798c0`.

- [x] [Hosted ARM64 CI](https://github.com/prajwalbhatia/paperMode/actions/runs/45189118241) passed JavaScript tests, native policy assertions, and package verification on the PR.
- [x] The release script packaged from the clean merged commit, extracted the ZIP, and verified app structure, ARM64 binaries, ad-hoc signing, runtime source inventory, notices, and installation instructions.
- [x] The local ZIP checksum, GitHub asset digest, authenticated CLI download, and Firefox browser download all matched. The Firefox download carried quarantine metadata.
- [x] Earlier local builds passed owner physical checks for locked playback, seeking, and deliberate unlock in the recorded Chrome, Safari, and Firefox players; see [seek QA](SEEK-QA.md).
- [ ] A fresh installation, permission acceptance, lock/playback/unlock, and restart of this exact downloaded ZIP have not been physically retested. The public prerelease notes disclose this limit.
- [ ] Clean-machine installation, external devices, Intel Macs, and older macOS versions remain unverified.

The published asset is an unnotarized Apple Silicon preview. Do not replace it silently; any changed archive needs a new version, checksum, and release record.
