# Preview release checklist

Updated 2026-11-17. The public source repository is live; the unnotarized preview download is still a draft. These results are scoped to their recorded builds. A published preview must retain its known limitations and must not be presented as a fully validated stable release.

## Completed

- [x] Implement input locking, deliberate unlock, reminders, permission guidance and experimental targeted playback.
- [x] JavaScript, native policy and package checks passed for the recorded candidates.
- [x] Owner-confirmed Chrome/Safari full-screen playback and unlock, plus Safari three-minute pause/resume on the milestone 6 candidate.
- [x] Milestone 6 code review completed; the reported input-blocking documentation claim was narrowed. Milestone 6 and prerelease-preparation PRs were merged before migration.
- [x] MIT license approved and included, with installation/removal and contribution instructions.
- [x] Owner selected ad-hoc-signed, unnotarized GitHub preview distribution without paid Apple membership for now.
- [x] Firefox download, quarantine, per-app Open Anyway approval, Applications replacement, permission recovery, Chrome physical lock/playback/unlock and restart passed on the earlier downloaded candidate (PRERELEASE-QA.md).
- [x] Privacy-cleaned public repository created with 39 original commit dates preserved; previous repository retained privately. Old PR refs were not copied.
- [x] Rebuilt the privacy-cleaned archive; package, ZIP round-trip and checksum checks passed. Draft assets are attached to source commit `b3d78154c8290f8170b0b2184761ed6f3781b83a`.
- [x] Draft preview prepared in the public repository with ZIP, checksum, manifest, installation instructions and known limitations.
- [x] Bug and feature issue forms, PR template, security policy and Code of Conduct added; private vulnerability reporting enabled.
- [x] CI workflow added for JavaScript tests, native policy assertions and ARM64 package verification.

## Before publishing the draft

- [x] Community/CI PR merged; its first hosted CI run passed.
- [ ] Repeat browser download/install acceptance on the privacy-cleaned final ZIP; prior physical tests used its earlier candidate. Record its exact checksum.
- [x] Final draft assets downloaded via GitHub CLI on 2026-11-17; ZIP checksum matches the recorded value. Extracted app passed signature, 15-binary ARM64 architecture and 9-file runtime source verification. Release remains unnotarized.
- [ ] Confirm the known limits below are acceptable for the preview and publish only with explicit owner authorization.

## Remaining validation limits

- [ ] Clean-machine installation and first-time permission acceptance.
- [ ] Chrome long-pause, target changes/ambiguity and hung-browser behavior on the final candidate.
- [ ] Final-candidate physical recovery and permission-revocation checks.
- [ ] External-device and multiple-monitor coverage; Intel and older macOS runtime compatibility remain unverified.

## Deferred by owner

- [ ] Record and review the demo (DEMO.md); deferred until after this community/CI work.
- [ ] Developer ID signing/notarization, if chosen later.
- [ ] Delete the original private repository only after migration is verified and the owner explicitly requests that deletion.

Current draft: [GitHub Releases](https://github.com/prajwalbhatia/paperMode/releases). Archive SHA-256: `afbc72e34891c735cae6831a0edc30689c4ce6e18ba0f48cc3e2952dfbfa935b`. The new community files are repository-only changes and are not included in that already-built archive. Do not regenerate or replace the draft silently; a new artifact needs a new provenance/checksum record.

## Public website

- [x] Approved static landing page, transparent 3D hero, native interface images, shortcuts and installation FAQ prepared under `website/`.
- [x] GitHub Pages workflow validated with actionlint; local asset links checked. No ChatGPT authentication is part of the static website.
- [ ] Public deployment and release download links verified after publication.
