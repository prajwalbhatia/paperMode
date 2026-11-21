# Next release: update check and permission recovery QA

## Automated and package checks

- [x] JavaScript tests passed on the development Mac, including release ordering, published-release filtering, and the menu action.
- [x] The live check of PaperMode's GitHub releases reported no newer release than `v0.1.0-preview.1`.
- [x] The ARM64 package passed structural verification. This does not establish first-launch or permission behavior.
- [ ] Packaged smoke launch was blocked by the already-running downloaded PaperMode instance's single-instance lock. Retry after quitting that instance during physical QA.

## Physical checks before the next public release

- [ ] From Ready, choose **Check for Updates…**. Confirm the app shows that no newer release exists and does not start a lock.
- [ ] Disconnect the network and retry. Confirm an error message appears, the menu returns to Ready, and locking still works afterward.
- [ ] Confirm the update action is unavailable while locked or while the guide is open.
- [ ] When a newer draft candidate is published as a GitHub prerelease, check that its notes appear and **View release** opens the matching official GitHub page. Choosing **Later** must open nothing.
- [ ] With Accessibility off, open the guide and confirm the recovery instructions name the correct macOS path and installed copy in Applications.
- [ ] If a stale PaperMode permission entry occurs after replacing the app, follow the guide's steps and confirm **Check permission and layout** returns Ready. Do not reset another app's permission to simulate this.

The current preview asset is unchanged. Update `version` and `paperModeReleaseTag` together when preparing the next public build, then repeat these checks on its exact downloaded ZIP.
