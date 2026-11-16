# PaperMode — build plan

## Progress

- Milestone 5 started on `milestone-5-local-release` after milestone 4 merged. Added automatic packaged-content verification; fresh ARM64 build and non-locking packaged startup passed. Finder-launched permission identity, installation/replacement, and interactive packaged acceptance remain pending in `docs/MILESTONE-5-QA.md`.

- Milestone 1 complete: Electron menu bar and diagnostic Swift helper build/run checks passed on Apple Silicon, macOS 27.2.1. See `docs/SETUP.md` for results.
- Milestone 2 merged: native input filtering, deliberate unlock, reminder, and core manual recovery/full-screen QA passed. External devices and multiple displays remain pending (see `docs/MILESTONE-2-QA.md`).
- Milestone 3 merged, including post-merge review fixes: versioned stdio commands/events, Electron session state, permission controls, start shortcut, and connection cleanup. Automated and real Electron runtime checks passed; core user-reported manual checks and normal-session duration passed; assisted permission revocation and logged normal-session shortcut unlock passed; core development-Mac QA passed, with hardware and release gates deferred (see `docs/MILESTONE-3-QA.md`).

- Milestone 4 implementation started on `milestone-4-user-experience`: first-use permission/use guide, start protection while guidance is open, clearer recovery messages, and current usage docs. Automated and agent-assisted welcome/help/Settings checks passed; the user verified inline shortcut feedback, direct menu start/unlock, Help/relaunch, and sleep during preparation. Fresh permission transitions, actual OS shortcut conflict, and hardware acceptance remain pending in `docs/MILESTONE-4-QA.md`.

## Goal

Milestone 7 feasibility is active on `milestone-7-playback-feasibility`, after milestone 5 merged. The agreed sequence is milestone 5 → milestone 7 → milestone 6. Product implementation awaits the feasibility review; release preparation will follow playback work. See `docs/MILESTONE-7-FEASIBILITY.md`.

The isolated native probe delivered pause/resume to Chrome and Safari fixtures while its input tap remained enabled. User physical F8 tests passed in both browsers, including full screen and a three-minute pause. Intended-course routing, broader contention, and product integration remain open; this is not a full milestone acceptance pass.

Let someone place a notebook over a MacBook's keyboard and trackpad while watching a course. The video and sound continue without dimming or blur. A small unlock reminder is the only content PaperMode places above the course.

## First release

- A menu bar app with one clear action to start PaperMode and a visible ready/locked state in the menu.
- Block accidental keyboard, trackpad, mouse, scroll, and media-key input while active, subject to verified macOS limits.
- Keep the current video/app visible and prevent the display from sleeping during a session.
- Lock **all** attached keyboard and pointer devices in the first release.
- Unlock only by holding **Control + Option + Command + L** for two seconds. There is no session timer.
- Show a small, click-through reminder reading “Hold ⌃⌥⌘L to unlock” in the top-right corner for the entire locked session, including full-screen video. It must not dim or blur the rest of the display.
- Release input if the native helper exits or crashes. Never save a locked state across relaunches.
- Treat loss of the JavaScript parent process as a failure and release input, rather than leaving an orphaned helper active.
- Run locally with no account, network connection, or keystroke logging.

## Proposed architecture

- **JavaScript/Electron main process:** menu bar icon, settings, session status, and packaging. No full-screen window during a session.
- **Small Swift helper:** macOS Accessibility permission, a Core Graphics event tap that filters input, display-awake assertion, deliberate unlock shortcut, and a small click-through reminder window.
- **IPC:** Electron starts the bundled helper and communicates through a small versioned JSON protocol over standard input/output. The helper releases input if the parent process disappears.
- **Distribution:** start with a local build; package a downloadable Mac app after behavior is validated. GitHub Releases is the initial publishing target. Signing and notarization are a separate release decision.

## Build milestones

### 1. Establish a reproducible development setup

Inspect Node/npm, Xcode, Swift, the selected SDK, and the Mac's architecture. Resolve the compiler/SDK mismatch seen during the discarded prototype before implementation depends on it. Use JavaScript with Electron, a Swift helper, npm, and Electron Forge for packaging. Pin dependency versions and commit the lockfile once chosen.

Done when a minimal Swift executable and an empty Electron menu bar app both run, with setup instructions another contributor can follow. Any required system-tool installation is a distinct setup step.

### 2. Prove the native behavior

Build the helper with Accessibility checks, an active event tap, the two-second unlock chord, and the native reminder panel. Detect the chord inside the helper so unlocking does not depend on the JavaScript process or a global shortcut registration. Releasing a required key before two seconds cancels the hold; repeated key-down events must not shorten it.

Test ordinary keys, modifiers, media keys, mouse buttons, scrolling, and trackpad gestures while a course runs full screen. Verify both built-in and attached devices. Test the reminder over Safari, Chrome, and a local video player without taking focus. Use a bounded development test session during initial experiments; this is not a timer in the shipped product.

Done when the central experience works on the development Mac and limitations are recorded. Investigate any input that escapes before proceeding. Hardware power/Touch ID behavior and OS-controlled security actions cannot be promised to be blocked; the public feature description must reflect actual results.

### 3. Connect the JavaScript app and helper

Define a small versioned protocol with request IDs and explicit commands/events for permission status, starting a session, locked, unlocked, and errors. Keep raw input events inside the helper; do not send keys to JavaScript or logs.

Use the states ready, permission-required, starting, locked, and error. Show locked only after the helper confirms both input filtering and reminder visibility. Handle duplicate requests and helper launch failures. Keep unlock detection independent of the UI, release input on parent exit/connection loss, and clean up display-awake assertions and reminder windows on every exit path. Sleep, wake, permission revocation, and event-tap failure should return the app to an unlocked state.

Done when repeated lock/unlock cycles and process-failure tests restore normal input reliably.

### 4. Finish the user experience

Add the PaperMode icon and a compact menu with Start PaperMode, permission/help information, and Quit. On first use, explain the shortcut and guide the user through the required macOS permission. Keep the shortcut fixed for version one.

Render a readable reminder such as “Hold Control + Option + Command + L for 2 seconds to unlock.” Use a compact top-right panel that ignores clicks, never activates the app, and stays visible in full-screen spaces. Provide the reminder on each connected display; verify placement around the notch and after monitor changes. If the reminder cannot be maintained, release input and report the error after unlocking.

Done when a first-time user can grant permission, start a session, read the reminder, and unlock without Terminal commands.

### 5. Package and test a local release

Bundle the native executable with Electron and test its actual permission identity and process lifecycle from the packaged app. Verify relaunches, moving the app to Applications, and replacing it with a newer build. Start with Apple Silicon, the development machine's architecture. Add an Intel artifact only after a real Intel test is available.

Use automated tests for chord timing, IPC/state transitions, and cleanup on failures. Use manual hardware tests for actual input suppression, video playback, full-screen visibility, and Accessibility behavior. Run a complete study session with a notebook on the laptop. Target macOS 13+, but advertise only tested OS/architecture combinations.

Done when a packaged app passes the acceptance checks below, including recovery tests. Record any untested combinations explicitly.

### 6. Prepare the open-source release

Status: in progress on `codex/milestone-6-release-preparation`. MIT approved by the owner on 2026-11-17. Local archive tooling and release documentation are being prepared; demo, final-artifact acceptance, signing decision, and public release approval remain open.

Add a README with install/use/uninstall instructions, a short demo, supported versions, known limitations, and contribution instructions. Choose an open-source license with the owner. Prepare a versioned ZIP/DMG and checksums for GitHub Releases. Decide on Developer ID signing/notarization before a public download; document the actual signing status accurately.

Done when the release files and documentation are reviewable. Creating a public repository, choosing the final license, and publishing are separate release actions to settle with the owner.

### 7. Play/pause while locked — implementation and acceptance

Let the user briefly lift the notebook, deliberately pause or resume the course, and continue writing without unlocking and relocking. Keep the existing two-second unlock chord unchanged. Start with play/pause only; rewind, remote controls, and hands-free operation are outside this milestone.

**Phase A — feasibility and reliability:** compare system media commands with explicit browser/player targeting in Chrome and Safari. Browser media-key support is established by documentation, but reliable routing to the intended course and delivery through PaperMode's active input filter have not been verified. System commands may target a different media session. Investigate the simpler system-command approach first; consider browser integration only if targeting cannot meet the acceptance criteria, documenting the extra permissions and maintenance involved.

Test both browsers against the user's actual course platforms, recording browser/macOS versions and results for:

- Repeated pause/resume in windowed and full-screen playback.
- Resuming after several minutes paused for note-taking.
- Multiple video tabs, both browsers open, and a competing media app.
- Focus changes, unsupported players, and no eligible media session.
- Continuously blocked keyboard, pointer, and ordinary media-key input while the deliberate playback action is delivered.

**Decision gate:** review the evidence with the owner before selecting an approach or implementing the feature. Do not treat documentation support as an end-to-end reliability pass. If the intended player cannot be targeted reliably, document that limitation rather than silently controlling other media.

**Phase B — implementation, only after approval:** choose a deliberate chord distinct from unlock, show it in the reminder, and debounce it so one deliberate activation causes one action. Control + Option + Command + Space and a short hold are candidates, not settled decisions. Deliver playback control without temporarily disabling the input lock or allowing notebook-generated input through. Give accurate feedback: do not claim playback changed unless it can be confirmed. Preserve all existing unlock and failure-recovery behavior.

Done when the agreed Chrome/Safari compatibility matrix passes, the intended course is controlled consistently within the documented support scope, ordinary input remains blocked throughout, and regression tests confirm unlock and recovery still work. Owner authorized native Accessibility implementation on 2026-11-16. Implemented as experimental with no global fallback; acceptance gates remain before milestone 6.

Research references (feasibility review, 2026-11-15):

- [Chrome hardware media-key support](https://developer.chrome.com/blog/media-updates-in-chrome-73)
- [Media Session routing specification](https://www.w3.org/TR/mediasession/#routing)
- [WebKit Now Playing session selection](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/audio/cocoa/MediaSessionManagerCocoa.mm)

## Planned source layout

```text
src/main/           JavaScript menu bar, helper connection, session state
native/PaperMode/   Swift input filtering, unlock logic, reminder window
assets/            App and menu bar icons
scripts/           Native build and packaging steps
tests/             State/protocol/recovery tests
docs/              Setup instructions and manual test results
```

The first version has no backend, account system, remote playback control, device exclusions, automatic updater, or configurable shortcut. Deliberate playback control is reserved for deferred milestone 7; other additions can be considered after the core workflow passes testing.

## Acceptance checks

- The course remains bright, playing, and audible throughout a session; only the small unlock reminder covers part of the screen.
- Resting and writing on the notebook does not type, click, scroll, pause playback, switch apps, or change volume/brightness.
- The unlock shortcut works repeatedly, including after moving between apps and full-screen spaces.
- Quitting or crashing the helper immediately restores input.
- If the Electron process exits unexpectedly, the helper restores input.
- Permission denial produces a clear message before any lock begins.
- The packaged app behaves the same way as the development build.

## Decisions to settle

1. Confirm the reminder's size and top-right placement after testing it over real course videos.
2. Target **macOS 13 Ventura or later**, because the current Electron line supports macOS 13+. Verify on macOS 13 before claiming that minimum in a release; otherwise raise the minimum to the oldest version actually tested.

## Technical references

- Electron tray/menu bar API: https://www.electronjs.org/docs/latest/tutorial/tray
- Apple Core Graphics event taps: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
- Apple Accessibility input filtering guidance: https://developer.apple.com/videos/play/wwdc2019/701/
