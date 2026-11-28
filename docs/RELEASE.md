# Release preparation

## Local candidate workflow

Unreleased development builds leave `paperModeReleaseTag` as `null`. Public preview builds set it to the matching `v<version>-preview.<number>` tag; stable Developer ID builds use `v<version>`. The menu's update checks use that tag to compare the installed build with GitHub releases.

Use native ARM64 Node on macOS. From the repository root:

```sh
npm ci
npm test
npm run release:local
```

The command rebuilds the helper and app, verifies the packaged bundle, creates a versioned ZIP, extracts it into a temporary verification directory, and repeats package checks on the extracted app. Successful output is printed under a unique `out/release-local-*` directory:

- `PaperMode-<version>-macos-arm64-local-qa.zip` (version comes from package.json)
- `SHA256SUMS.txt`
- `manifest.json`, including source commit, dirty-tree status, architecture and actual signing status

The ZIP includes PaperMode.app, installation instructions, the MIT license, Electron's license, Chromium notices and a local-QA warning. A failed run is not an accepted artifact. Successful runs remove staging/extraction directories. Check the checksum from the printed output directory with `shasum -a 256 -c SHA256SUMS.txt`.

This workflow expects ad-hoc signing and does not upload, tag, notarize, launch, or lock input. A dirty-tree manifest identifies uncommitted inputs; public candidates must be rebuilt from a clean reviewed commit. Checks establish structure and archive integrity, not Gatekeeper acceptance or runtime QA. The separate Developer ID workflow is documented in [NOTARIZATION-READINESS.md](NOTARIZATION-READINESS.md).

## Public signing decision

On 2026-11-17 the owner selected an unnotarized GitHub preview without paid Apple membership for now. Developer ID signing remains a future option, not a prerequisite for this explicitly labelled preview.

GitHub can host the download, but that does not sign or notarize it. Apple's [Developer ID distribution overview](https://developer.apple.com/developer-id/) describes signing apps distributed outside the App Store. [Apple Developer Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment) is the owner step for obtaining Developer ID access; enrollment is generally US$99 per membership year, with local pricing where available.

If the owner chooses Developer ID distribution:

1. Enroll and create a Developer ID Application certificate; keep its private key in the owner's Keychain or a secured build system, never in the repository or chat.
2. Configure signing for the native helper, nested Electron code and app, with hardened runtime and the appropriate Electron entitlements. The current ad-hoc Forge configuration is not this setup.
3. Submit using Apple's notarization tooling, wait for acceptance, staple the ticket, and verify signatures and Gatekeeper assessment. Follow [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
4. Build the final archive after signing/stapling. Recompute checksums and test an actual quarantined download on a clean test environment, including permission identity and replacement behavior.

Source publication under MIT does not require enrolling in Apple's program. No enrollment, certificate creation, or public publication is performed by the local workflow.

## Before publishing

Complete `LOCAL-RELEASE-CHECKLIST.md`, record final-artifact QA against its checksum, record the demo, review release notes, settle signing, and obtain explicit publication authorization. Do not infer successful clean-install, older-macOS, or Intel support from build metadata.

## Unnotarized preview workflow

From a clean committed tree, run `npm run release:preview`. This uses the same archive verification but names the ZIP `PaperMode-<version>-macos-arm64-unnotarized-preview.zip` and bundles `UNNOTARIZED-PREVIEW.txt`. For this preview, the app version is `0.1.3` and the GitHub tag is `v0.1.3-preview.1`. The manifest describes build-time state and does not itself authorize publication.

Upload the ZIP, SHA256SUMS.txt, manifest.json and INSTALL.md to a **draft prerelease** targeting the exact build commit. Download its asset through a browser while signed into GitHub to exercise quarantine, extraction, per-app Open Anyway, Applications installation and Accessibility permission. CLI downloads alone do not establish this flow. Record checksum and observations before publishing the draft. This existing development Mac cannot establish clean-machine behavior because earlier permissions/approvals may persist.

Keep the website's existing download link pointed at the published preview until the new prerelease is public. After publishing and verifying the new asset URL, update both website download buttons and displayed version in a follow-up change.
