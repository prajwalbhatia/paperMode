# Milestone 2: native prototype and manual QA

Status: implemented, automated checks passed; physical input and full-screen QA pending. This is a native test harness. Electron session controls belong to milestone 3.

## Commands

- `npm run test:native`: tests the two-second chord timer, early releases, repeats, and incomplete chords without intercepting input.
- `npm run preview:native`: show the reminder for ten seconds; keyboard and pointer remain active.
- `.build/native/papermode-helper --request-permission`: ask macOS for Accessibility permission. Follow the OS prompt for the process it identifies, then run `--diagnose` again. Packaged-app permission identity is not validated yet.
- `npm run test:lock`: after permission is granted, wait five seconds, then block input for at most thirty seconds. Lift the notebook and hold Control + Option + Command + L for two seconds to end early.
- `.build/native/papermode-helper --lock`: same five-second preparation period, with no session timeout. Reserve this for after the bounded test passes. The thirty-second development limit is not a product session timer.

The shortcut currently uses the physical L key position on an Apple US/ABC keyboard. Other layouts must be tested before claiming support. A held chord can be detected with either side's modifier keys.

## Results on the development Mac

2026-11-14, Apple Silicon, macOS 27.2.1:

- Native build and diagnostic passed.
- Ten chord timing assertions passed; three existing packaging guard tests passed.
- Missing Accessibility permission: helper exited with code 2 and `accessibility-required`, without starting a lock.
- Reminder preview reported visible and exited after ten seconds with `development-test-ended`.
- SIGTERM during preview released the reminder and exited with `process-signal`.
- Preview window geometry was not visually inspected over full-screen video.
- Actual input suppression, locked-session recovery, parent-exit recovery, sleep, permission revocation, multiple monitors, and other keyboard layouts are not yet verified.

## Manual acceptance sequence

1. Play a disposable course video in a browser. Run the reminder preview and check that text fits, contrast is readable, and the video remains bright and audible. Repeat in Safari, Chrome, and a local player's full-screen mode.
2. Grant Accessibility, then run the bounded lock test. During the five-second preparation period, bring the course to the front.
3. Press normal keys, modifier shortcuts, volume/brightness/playback keys, click, scroll, and try multi-finger gestures. Record every input that still reaches the system. Repeat with an external keyboard and mouse.
4. Hold the unlock chord for less than two seconds and release: input should remain blocked. Then hold for two full seconds: normal input must return.
5. Repeat with the notebook resting on the keyboard. Verify video/audio playback and the persistent reminder throughout.
6. Test cleanup after helper/parent exit, sleep/wake, and permission revocation. Test connecting/disconnecting a monitor while active. Use a bounded session and a separate recovery process during these development experiments.

## Known boundaries

Core Graphics event filtering does not establish control over every macOS gesture or secure system action. Media events are filtered using recognized consumer-key identifiers; hardware power/Touch ID and unrecognized system-defined events pass through. Multi-finger gestures and system shortcuts are explicit feasibility tests, not guaranteed features yet. Any escape that interrupts studying must be investigated before milestone 2 is marked complete.

The helper logs only lifecycle state/reason and diagnostic metadata. Raw keystrokes are neither emitted nor stored. Input filtering, reminder ownership, and display-awake assertion live in the helper. Parent exit, tap failure, lost reminder, session deactivation, and permission loss are designed to end the session. Actual locked-session recovery remains a manual test gate.
