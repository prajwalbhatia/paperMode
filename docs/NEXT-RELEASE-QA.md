# Next release: update check and permission recovery QA

Candidate: `v0.1.1-preview.1`. The release ZIP must be rebuilt from the merged, clean commit and tested after download before publication.

## Automated and package checks

- [x] JavaScript tests passed on the development Mac, including release ordering, published-release filtering, the menu action, and A → B → A withdrawal without repeating A's alert.
- [x] The live check of PaperMode's GitHub releases found no release newer than the local `0.1.0` build baseline.
- [x] The rebuilt local app launched and completed its first automatic background check after the startup delay; it recorded `local-0.1.0` without announcing an older release.
- [x] The 0.1.1 ARM64 package passed structural verification (15 Mach-O binaries, 11 source files). Its nonlocking smoke launch reached Ready, registered the start shortcut and reported an Accessibility-trusted 0.1.1 helper on the development Mac. This is not the final downloaded ZIP.
- [x] An isolated native Electron QA session displayed an automatic alert for a simulated newer release. Choosing **Later** saved the highest announced tag in its isolated profile; no public release or normal app update history changed.
- [ ] Repeat the nonlocking smoke and physical checks on the final downloaded ZIP after the release commit is merged.

## Physical checks before the next public release

- [ ] From Ready, choose **Check for Updates…**. Confirm the app shows that no newer release exists and does not start a lock.
- [ ] Disconnect the network and retry. Confirm an error message appears, the menu returns to Ready, and locking still works afterward.
- [ ] Confirm the update action is unavailable while locked or while the guide is open.
- [ ] With Accessibility off, open the guide and confirm the recovery instructions name the correct macOS path and installed copy in Applications.
- [ ] If a stale PaperMode permission entry occurs after replacing the app, follow the guide's steps and confirm **Check permission and layout** returns Ready. Do not reset another app's permission to simulate this.

## Checks for a future newer release

The current public v0.1.0-preview.1 has no updater, and v0.1.1-preview.1 cannot announce itself as newer. The isolated alert QA and automated tests cover this behavior before publication. Once a later version is published, check these paths with a real GitHub release:

- [ ] Launch v0.1.1-preview.1 and leave it idle. Confirm one automatic alert appears, choose **Later**, restart, and confirm the same release is not announced again.
- [ ] If a release check completes during a lock or while the guide is open, confirm the alert waits until the session or guide ends.
- [ ] Confirm the newer release's notes appear and **View release** opens its official GitHub page. Choosing **Later** must open nothing.

The current public preview asset remains unchanged. The candidate sets `paperModeReleaseTag` to `v0.1.1-preview.1`; repeat all prepublication checks on its exact downloaded ZIP.
