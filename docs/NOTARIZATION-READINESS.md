# Developer ID and notarization readiness

Status: prepared locally on 2026-11-18; no Apple account, certificate, credential or submission has been used.

## What is ready

- `npm run package:hardened-local` builds a local, ad-hoc-signed test bundle using Hardened Runtime on all Electron and native helper executables. Its main process has a local-only library validation exception because ad-hoc signatures have no shared Apple Team ID.
- The Swift helper is re-signed with the stable `papermode-helper` identifier, so a release signature does not silently replace it with a path-derived identifier.
- Electron receives only its required runtime exceptions. PaperMode does not request camera, microphone, location, USB, Bluetooth or Photos entitlements.
- `npm run package:developer-id` requires an explicit `Developer ID Application` identity, re-signs the helper and nested Electron code, and runs `check:developer-id` after structural package verification.
- `npm run check:developer-id` strictly verifies every bundled Mach-O signature and requires a Developer ID authority, matching signing team, secure timestamp, Hardened Runtime, no enabled `get-task-allow` entitlement, and the expected helper identifier.
- `npm run notarize:developer-id` creates a pending archive with the app, license notices and the Developer ID installation guide. It requires Apple's `Accepted` status, staples and validates the ticket, checks Gatekeeper, verifies the extracted final ZIP and then publishes it without replacing an existing version. It does nothing unless explicitly run with a Keychain profile.

The local hardened build is not Apple trust. Its signature is ad-hoc and has no Team Identifier. Its library validation exception means this mode cannot fully predict Developer ID runtime behavior.

## Verified locally

The hardened local bundle passed strict package verification on this development Mac:

- 15 ARM64 Mach-O files;
- Hardened Runtime on the PaperMode executable and native helper;
- `app.papermode.desktop` app identifier;
- `papermode-helper` helper identifier;
- empty helper entitlement set.

The hardened local bundle did **not** launch on macOS 27.2.1. The non-locking smoke test exited before Electron startup; the crash report records a dyld rejection of the Electron Framework because the ad-hoc main process and framework have different Team IDs. The local-only library validation exception did not resolve this. Structural verification passes, but hardened runtime behavior remains unverified until a real Developer ID signed build exists. Full physical lock/playback QA and Apple acceptance remain open.

## After enrolling

1. Enroll in the Apple Developer Program and create/install a **Developer ID Application** certificate in the login Keychain. Do not add its private key or certificate export to this repository.
2. Confirm the exact certificate name with:

   ```sh
   security find-identity -v -p codesigning
   ```

3. Build and verify the signed bundle. Substitute your exact certificate display name; keep this value in your shell or CI secret, never a tracked file:

   ```sh
   PAPERMODE_DEVELOPER_ID_IDENTITY='Developer ID Application: Your Name (TEAMID)' npm run package:developer-id
   ```

4. Create a `notarytool` Keychain profile using an Apple app-specific password or an App Store Connect API key. Apple prompts for the sensitive value; do not send it in chat or store it in the repo. For example:

   ```sh
   xcrun notarytool store-credentials papermode-notary
   ```

5. Submit, staple, assess and create the final archive:

   ```sh
   PAPERMODE_NOTARY_PROFILE=papermode-notary npm run notarize:developer-id
   ```

6. Test that exact final ZIP as a quarantined browser download on a fresh test account or Mac: open, grant Accessibility, start, lock, play/pause, unlock, quit and restart. Publish only that checksum and archive.

## Notes

- The current `v0.1.0-preview.1` asset remains unchanged and unnotarized.
- Notarization is an automated Apple decision. These checks reduce configuration risk but cannot promise an Apple acceptance before a real submission.
- This is direct-download signing, not Mac App Store packaging. It intentionally does not enable App Sandbox or include a provisioning profile.
