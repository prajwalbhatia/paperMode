# PaperMode 0.1.1 Preview 1 release QA

Published prerelease: `v0.1.1-preview.1`. The ZIP was built from clean merged commit `774f5586d960950417f2cadf7e9e17b1ffe74e8f`. SHA-256: `ebea8a4ba88f5b0684fd907a79764dad0a562030ce5ef4c0bed7abe9a767e90e`.

## Automated and package checks

- [x] JavaScript tests passed on the development Mac, including release ordering, published-release filtering, the menu action, and A → B → A withdrawal without repeating A's alert.
- [x] The live check of PaperMode's GitHub releases found no release newer than the local `0.1.0` build baseline.
- [x] The rebuilt local app launched and completed its first automatic background check after the startup delay; it recorded `local-0.1.0` without announcing an older release.
- [x] The 0.1.1 ARM64 package passed structural verification (15 Mach-O binaries, 11 source files). Its nonlocking smoke launch reached Ready, registered the start shortcut and reported an Accessibility-trusted 0.1.1 helper on the development Mac. This is not the final downloaded ZIP.
- [x] An isolated native Electron QA session displayed an automatic alert for a simulated newer release. Choosing **Later** saved the highest announced tag in its isolated profile; no public release or normal app update history changed.
- [x] The final ZIP was downloaded in Firefox from the draft release. Its SHA-256 matched the build manifest and GitHub asset digest; quarantine named Firefox. The extracted and installed app passed signature, ARM64 architecture and source-inventory checks. The installed app's nonlocking smoke launch reached Ready with the 0.1.1 helper.

## Downloaded-app physical checks

- [x] macOS showed the expected unnotarized-app first-open warning. The owner used **Open Anyway** for this app and approved the local prompt.
- [x] The first normal launch showed **Permission required** with a stale PaperMode Accessibility entry enabled. Removing only PaperMode's old grant, enabling its switch again and choosing **Check permission and layout** restored Ready; the separate helper entry stayed enabled.
- [x] In Chrome YouTube, the downloaded app blocked input while the video remained visible, paused and resumed via the Space chord, and unlocked with the two-second L chord.
- [x] From Ready, **Check for Updates…** reported no newer release without starting a lock.
- [x] After restarting the downloaded app, no new macOS warning appeared; the menu still showed Ready with Start enabled.
- [ ] Disconnect the network and retry. Confirm an error message appears, the menu returns to Ready, and locking still works afterward.
- [ ] Confirm the update action is unavailable while locked or while the guide is open.
- [ ] With Accessibility off, open the guide and confirm the recovery instructions name the correct macOS path and installed copy in Applications.

The same development Mac has prior PaperMode approvals, so this does not establish a clean-machine first install. The quarantined app ran from an App Translocation path during these checks, including after Finder replacement; permission recovery and the restart test passed in that state. The remaining unchecked items above are covered by automated checks or documentation review, but were not physically repeated on the downloaded ZIP.

## Checks for a future newer release

The earlier v0.1.0-preview.1 has no updater, and v0.1.1-preview.1 cannot announce itself as newer. The isolated alert QA and automated tests cover this behavior until a later version is published. With a real newer GitHub release, check:

- [ ] Launch v0.1.1-preview.1 and leave it idle. Confirm one automatic alert appears, choose **Later**, restart, and confirm the same release is not announced again.
- [ ] If a release check completes during a lock or while the guide is open, confirm the alert waits until the session or guide ends.
- [ ] Confirm the newer release's notes appear and **View release** opens its official GitHub page. Choosing **Later** must open nothing.

The published v0.1.1-preview.1 asset remains unchanged after QA. The website download link was updated separately after publication.
