# Milestone 2: native prototype and manual QA

Status: implemented, automated checks passed; Chrome built-in input and full-screen checks passed by user report; recovery and broader hardware QA pending. This is a native test harness. Electron session controls belong to milestone 3.

## Commands

- `npm run test:native`: tests the two-second chord timer, early releases, repeats, and incomplete chords without intercepting input.
- `npm run preview:native`: show the reminder for ten seconds; keyboard and pointer remain active.
- `.build/native/papermode-helper --request-permission`: ask macOS for Accessibility permission. Follow the OS prompt for the process it identifies, then run `--diagnose` again. Packaged-app permission identity is not validated yet.
- `npm run test:lock`: after permission is granted, wait five seconds, then block input for at most thirty seconds. Lift the notebook and hold Control + Option + Command + L for two seconds to end early.
- `.build/native/papermode-helper --lock`: same five-second preparation period, with no session timeout. Reserve this for after the bounded test passes. The thirty-second development limit is not a product session timer.

The shortcut uses physical keycode 37. Before enabling input filtering, the helper translates that key in the active input source and requires it to produce L. Layouts with L elsewhere, or without readable layout data, are refused. A layout change or loss of a supported mapping during a session releases input. ABC–India on the development Mac passed the mapping check; other layouts still need physical testing. A held chord can be detected with either side's modifier keys.

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

Core Graphics event filtering does not establish control over every macOS gesture or secure system action. Auxiliary mouse-button and eject/menu subtypes are suppressed, and media events are filtered using recognized consumer-key identifiers (including contrast and launch-panel keys); hardware power/Touch ID and unrecognized system-defined events pass through. Multi-finger gestures and system shortcuts are explicit feasibility tests, not guaranteed features yet. Any escape that interrupts studying must be investigated before milestone 2 is marked complete.

The helper logs only lifecycle state/reason and diagnostic metadata. Raw keystrokes are neither emitted nor stored. Input filtering, reminder ownership, and display-awake assertion live in the helper. Parent exit, tap failure, lost reminder, session deactivation, and permission loss are designed to end the session. Actual locked-session recovery remains a manual test gate.

## Review fixes

All 105 native assertions passed after adding system-event and layout-policy cases; the three packaging tests and native diagnostic also passed. Tests exercise the policy used by the callback with mouse state masks, media down/up/repeat encodings, eject and menu subtypes, and preserved power/lifecycle/unknown events. They do not synthesize hardware events or prove actual delivery suppression. Physical side buttons, contrast/launch/eject keys, and layout changes remain manual QA cases.

## User-guided Chrome preview and UI refinement

The user reported that the original reminder preview worked correctly over a full-screen Google Chrome course video: readable top-right placement, unchanged brightness, continuous video/audio, and no exit from full screen. This is a user-observed pass for the original reminder in Chrome only.

The reminder was then restyled with a compact dark card, paper icon, lock-status label, separate shortcut keycaps, and a two-second hold instruction. Native compilation/diagnostics passed and a static AppKit render was visually inspected for text fit and spacing. Repeat the Chrome preview with the updated design before proceeding to the bounded lock test. Actual input suppression and recovery remain unverified. Normal sessions still use shortcut unlocking; the ten-second preview and thirty-second lock limit are development test modes only.

## First physical lock attempt

The user enabled Accessibility for Visual Studio Code, then reported that `--test-lock` emitted starting, locked, and immediately unlocked with `event-tap-disabled`. No reminder or input suppression was observed. This test failed; the old reason did not distinguish timeout, user-input disable, or the health check observing a disabled tap.

Startup now finishes reminder/power/observer setup before creating the event tap and avoids the initial disable/re-enable cycle. Layout polling is reduced to twice per second. Failure output distinguishes timeout, user-input disable, and observed disabled state, and records elapsed session milliseconds. Compilation, native diagnostics, 105 native assertions, and three packaging tests passed. A repeat physical test is required to establish whether this fixes the failure; its cause is not yet confirmed.

## Subsequent physical tests — user-reported results

After commit `4a58733`, using the bounded test from VS Code with the course in Chrome:

- Lock started successfully and the two-second shortcut restored input.
- User reported keyboard, media keys, and trackpad remained locked during the requested input checks. Individual hardware key/gesture coverage was not logged separately.
- Writing in a notebook resting over the laptop caused no course interruptions; lifting it and using the shortcut restored input correctly.
- User approved retaining the two-second hold and the revised reminder UI.

These results supersede the earlier unverified status for this Chrome/built-in-device workflow. The user also confirmed that a short shortcut press kept input locked and a full two-second hold unlocked it. Recovery scenarios, external devices, other players, and additional displays remain pending.

## Unlock hold countdown

The reminder now displays remaining hold time and a progress bar while the complete unlock shortcut is held. Releasing early clears the indicator; a new hold starts again from two seconds. The indicator uses the same chord timing state as unlocking. All 112 native assertions and three packaging tests passed. The user verified that the live countdown and progress bar worked correctly, releasing early reset the indicator while input remained locked, and holding for two seconds unlocked successfully. The user also confirmed automatic recovery after thirty seconds, with `development-test-ended` in the terminal. The user confirmed that scheduled SIGTERM during a locked session removed the reminder and restored keyboard/trackpad input, with `process-signal` in the terminal. The user confirmed that scheduled SIGKILL removed the reminder, restored keyboard/trackpad input, and left video playback uninterrupted; the terminal reported `killed`, as expected without a cleanup event. The user confirmed that parent-process exit removed the reminder, restored keyboard/trackpad input, and left video playback uninterrupted, with `parent-exited` in the terminal. Sleep/wake recovery passed by user report: closing the lid ended the session with `system-sleep` after 2395 ms, and keyboard/trackpad worked normally after reopening. The user then completed three fresh lock/unlock sessions after waking: all ended with `shortcut`, with no leftover reminders or stuck keys. External keyboard/mouse input suppression is pending, explicitly deferred by the user on 2026-11-15. No external-device test result is claimed.

## Safari full-screen QA — 2026-11-15

User reported a pass: the reminder stayed visible over full-screen Safari video, video/audio continued, input stayed locked, and the two-second shortcut unlocked correctly. The user also reported QuickTime passed: the reminder stayed visible and the shortcut unlocked correctly. Individual playback/input checks were not separately described in that report.

## Permission revocation QA

First revocation test failed on 2026-11-15. Resetting Accessibility for `com.microsoft.VSCode` succeeded, but the session ended only at 29980 ms with `development-test-ended`; a subsequent fresh diagnostic reported `accessibilityTrusted:false`. This proves the running-session permission check did not recover promptly. Whether input remained suppressed after reset was not separately reported.

The result is consistent with a stale in-process AX verdict; the exact macOS caching behavior is not established by this test. The helper now also launches a fresh, non-prompting `--check-accessibility` process, off the input-handling thread, one second after each completed check. A denied result ends the session with `permission-revoked`. Launch errors, unexpected exits, or a three-second probe timeout end it with `permission-check-failed`. Probes do not intercept input or request permission; each has its own three-second lifetime limit even if its parent dies. Session cleanup cancels outstanding probes and ignores late callbacks.

Native build/diagnostics, 125 native assertions (including real subprocess denial, failure, timeout, cancellation, and repeated checks), three packaging tests, and a real probe/diagnostic consistency check passed. On retest after `fdbd0cf`, the user supplied a successful reset followed by `permission-revoked` at 10573 ms and a fresh diagnostic with `accessibilityTrusted:false`. This verifies timely detection and session termination in the VS Code workflow, before the thirty-second deadline. The user subsequently confirmed the reminder disappeared and keyboard/trackpad worked immediately: physical revocation recovery passed. Packaged-app identity remains unverified. The user confirmed VS Code’s Accessibility permission has been re-enabled. This does not add a normal-session timeout.

## Keyboard layout QA

Agent-executed on 2026-11-15 through the existing, authorized VS Code terminal:

- Temporarily added and selected standard Dvorak using macOS settings and the input-source shortcut.
- Diagnostic reported `accessibilityTrusted:true`, `keyboardSourceID:com.apple.keylayout.Dvorak`, and `unlockLayoutSupported:false`.
- `--test-lock` emitted `starting` then `unsupported-keyboard-layout`, with no `locked` event. Unsupported-layout startup refusal passed.
- Removed temporary Dvorak and restored ABC–India, the original hidden input menu, Globe-key action, and English (India)-only dictation language list. Final diagnostic confirmed ABC–India and `unlockLayoutSupported:true`.
- The desktop automation could not access the macOS input-menu agent (timeout), so changing layouts during an already active lock was not tested. No active input lock was started in this agent-run QA sequence.

At that point, remaining manual gates were active-session layout-change recovery, external keyboard/mouse checks (user-deferred), and multiple monitors/physical display connection/disconnection. The active-layout retest below supersedes its pending status. No hardware-dependent pass is claimed. Shell execution from the agent has a different Accessibility identity than VS Code, so its `accessibilityTrusted:false` does not establish a loss of VS Code’s grant.

## Active-session layout-change recovery — 2026-11-15

Agent-executed retest passed using System Settings accessibility actions rather than the unavailable input-menu agent:

- Added temporary standard ABC and selected it. A diagnostic from VS Code confirmed `com.apple.keylayout.ABC`, `unlockLayoutSupported:true`, and `accessibilityTrusted:true`.
- Started `--test-lock` from VS Code and verified the `locked` event before changing the source.
- Removed only the temporary active ABC source through Keyboard settings, causing macOS to return to the original ABC–India source.
- The helper emitted `unlocked` with `keyboard-layout-changed` at 3182 ms into the lock, before the thirty-second development deadline. This is elapsed session time, not measured detection latency.
- The command following the helper ran, verifying process exit, and reported ABC–India with permission still granted. A subsequent terminal command entered via desktop automation succeeded, confirming automated input worked after recovery. Physical keyboard/trackpad gestures were not independently exercised by the agent.
- Restored the original single ABC–India source, hidden input menu, Globe action (Show Emoji & Symbols), and English (India)-only dictation language list.

This covers an actual active-source change caused by source removal, between two supported layouts. It does not claim every IME or layout transition has been tested. Remaining manual hardware gates: external keyboard/mouse and multiple-monitor connection/disconnection.
