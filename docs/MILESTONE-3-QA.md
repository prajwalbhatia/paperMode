# Milestone 3: Electron/native integration QA

Status: implemented; automated verification and agent-run real Electron runtime checks passed on the development Mac. User-reported core manual checks and the normal-session duration check passed; assisted app-level permission revocation passed. Normal-session shortcut unlock is now corroborated by the native event log; core development-Mac QA passed, with hardware and release gates deferred below. Milestone 2 native results do not establish Electron's or the packaged app's permission identity.

## Automated checks — 2026-11-15

- Native build and diagnostic passed.
- 125 native assertions passed.
- 25 JavaScript tests passed: packaging guards, duplicate starts, permission/layout preflight, stale async responses, quit/sleep cancellation, correlated/fragmented protocol frames, invalid events, startup timeout, unexpected exit, and connection-loss cleanup.
- Nine native IPC integration tests passed, covering status/correlation, invalid JSON/version/oversized frames, duplicate request IDs/start, cancellation before delayed start, real nonblocking preview start/shutdown, and EOF during preview.
- Electron smoke check passed: `menuBarCreated:true`, `shortcutRegistered:true`, `state:permission-required` for the agent execution context. No input was blocked. This does not imply VS Code's grant was revoked.

## Agent-run real app runtime QA — 2026-11-15

These checks loaded the production Electron entry point through a temporary harness in ignored `.build/qa-electron.cjs`. The harness called the real controller's start method, observed state/events, and scheduled termination; it used real native input locks with `--bounded-locks`, not mocks or previews. It did not exercise menu clicks or the global start shortcut. Production source was restored unchanged after instrumentation, and no Accessibility grants were changed.

| Check | Observed result |
| --- | --- |
| Three consecutive bounded sessions, with duplicate start calls | Passed: exactly one helper per session; Ready → Starting → Locked → Ready; all ended with `development-test-ended` after approximately thirty seconds and helper exit code 0. |
| Quit during preparation | Passed: helper exited with `app-quit`, code 0; no Locked event or delayed lock. |
| Quit while locked | Passed: helper exited with `app-quit`, code 0, approximately nine milliseconds after quit began. |
| Kill the helper while locked | Passed: controller reported `helper-connection-lost` and error state; helper exited with SIGKILL. |
| Kill Electron while locked | Passed for process cleanup: both Electron and its helper exited. The final native reason was unavailable because the output pipe closed. |
| Start without Accessibility permission | Passed: controller returned to `permission-required` with `accessibility-required`; no helper was created and no Locked event occurred. |

The granted runs were launched through VS Code. The denied run used the agent execution context, which had no Accessibility permission; it did not revoke VS Code's grant. Process inspection confirmed the tested app/helper processes had exited. These observations establish lifecycle and state handling, not physical input recovery or reminder appearance.

Local evidence: `.build/m3-repeat.jsonl`, `.build/m3-quit-starting.jsonl`, `.build/m3-quit-locked.jsonl`, `.build/m3-helper-crash.jsonl`, `.build/m3-parent-crash.jsonl`, and `.build/m3-permission-denied.jsonl`. These ignored artifacts are not part of the repository.

### Limits of the initial agent pass

- Computer-use automation timed out selecting the windowless Electron app, so tray labels and menu actions were not visually verified.
- Targeted synthetic start/unlock chords did not establish successful shortcut delivery. The unlock attempt ended at the development timeout (`.build/m3-shortcut.jsonl`); this is inconclusive, not a shortcut pass or a confirmed physical-key failure.
- Physical start/unlock shortcuts, short-hold reset, countdown appearance, keyboard/media/trackpad suppression, reminder cleanup, and full-screen playback still need app-level manual verification.
- Sleep/wake, revoking the actual app identity's permission during a session, and a normal session lasting beyond thirty seconds remain pending.

The regular development app was left running with `--bounded-locks`, with no active lock helper, for the remaining checks. No production behavior changed during this QA pass.

## Follow-up manual and runtime QA — 2026-11-15

User-reported passes after the preparation-countdown change (`4b9f4e2`):

- The visible preparation countdown changes to the unlock reminder; video continues without dimming.
- Keyboard, media keys, and trackpad remain blocked. Releasing the unlock chord early resets progress; holding for two seconds unlocks and the menu returns to Ready.
- Quitting during preparation removes the countdown, causes no delayed lock, and leaves input working.
- Closing/reopening the lid while locked removes the reminder, restores input, and returns to Ready without relocking.

Additional agent-run checks used the temporary harness with the real production entry point and helper:

- **Normal session duration passed:** launched without `--bounded-locks`; native event reported `testSession:false`. At 35 seconds after locking the controller still reported Locked. The harness requested app shutdown at 40 seconds, and the helper exited with `app-quit`, code 0. This verifies absence of the thirty-second development limit; it does not independently verify shortcut unlock in that normal session. Evidence: `.build/m3-untimed.jsonl`.
- **Permission revocation blocked:** while a bounded session was locked, attempted to disable Visual Studio Code's enabled control permission in System Settings. macOS requested Touch ID/password before changing it. Cancelled authentication and verified both Visual Studio Code and papermode-helper remained enabled. No permission was revoked, so attribution and revocation recovery are not established by this attempt. The session ended normally with `development-test-ended` and helper exit code 0. Evidence: `.build/m3-permission-revoked.jsonl`.

All QA app/helper processes from this follow-up exited. No production code or permission settings changed. The remaining permission-revocation check requires the user to authenticate in macOS. Tray wording in normal mode and deliberate shortcut unlock after a session exceeds thirty seconds have not been directly observed together; external devices, multiple monitors, and release gates below remain deferred.

## Assisted completion checks — 2026-11-15

- **Permission revocation passed:** the first authentication-assisted attempt reached its development timeout. On the repeat, disabling Visual Studio Code's permission during an active lock produced native `unlocked` with reason `permission-revoked` at 10,553 ms, helper exit code 0, and controller state `permission-required`. Re-enabling the same permission restored controller state Ready. The enabled setting was verified in System Settings. Evidence: `.build/m3-permission-assisted-repeat.jsonl`. This establishes the development launch context only, not packaged-app attribution.
- **Normal-session follow-up:** native reported `testSession:false` and the controller remained Locked after 35 seconds. The user subsequently confirmed input recovery, reminder dismissal, Ready in the menu, and absence of the development safety-limit label after the requested physical shortcut check.
- **Evidence discrepancy:** `.build/m3-untimed-assisted.jsonl` records harness shutdown at 90 seconds with `app-quit`, not a `shortcut` event. Record the user's observations as reported; do not count this run as independently verified shortcut unlock after thirty seconds. This discrepancy was resolved by the final repeat recorded below. Earlier bounded-session physical shortcut QA passed as reported above.

No production code changed during these assisted checks. The development permission was restored. External devices, multiple monitors, and release gates remain deferred.

## Final normal-session shortcut repeat — 2026-11-15

**Passed.** Removed the temporary harness's 90-second cleanup for this repeat (retained a ten-minute QA watchdog). Production code was unchanged. Launched the real app/helper without `--bounded-locks`; the native lock event reported `testSession:false`. The controller remained Locked after 35 seconds. After the user physically held the unlock chord, native emitted `unlocked` with `reason:shortcut` and `elapsedMilliseconds:57319`; helper exit code was 0, and the controller returned to Ready. The user confirmed the reminder disappeared and input worked.

Evidence: `.build/m3-final-shortcut.jsonl`, request ID `de24d8c3-9915-4994-ad27-cb0c8e991b5d`. This confirms deliberate shortcut unlock after the development timeout threshold and resolves the previous run's evidence discrepancy. The temporary QA app was closed after verification.

## Manual sequence

Use `npm run start:test` initially. Its menu explicitly identifies the thirty-second development safety limit. Quit an existing PaperMode instance first. The native standalone helper tests and app tests are separate.

1. Check the tray shows the permission state and start/unlock shortcut instructions. Use Enable Accessibility; grant the identity macOS actually shows. Confirm the menu becomes Ready after rechecking. Denied permission must never create a lock or claim Locked.
2. Play a disposable full-screen video. Press Control + Option + Command + P. Confirm the on-screen card immediately counts down “Locking in 5…” through 1, with input still usable during preparation, then changes to the unlock reminder and Locked after five seconds. Pressing start again while starting must not create another helper/reminder.
3. Test built-in keys/media/trackpad suppression and the countdown reset on a short unlock hold. Hold Control + Option + Command + L for two seconds; verify input returns, the reminder disappears, and the menu becomes Ready.
4. Repeat three sessions. Confirm no stale state or leftover helper/reminder. Check the start shortcut does not accidentally retrigger after unlocking.
5. Quit during preparation; ensure no delayed lock appears. In a bounded session, test parent exit/crash and sleep/wake; verify cleanup and no automatic relock. Schedule any forced termination before starting the lock so recovery does not depend on typing while locked.
6. Repeat permission revocation for the actual app identity (do not assume it is VS Code), and inspect the menu's permission-required state after recovery. Restore permission afterward.
7. After bounded checks pass, use normal `npm start`, confirm the menu no longer shows the development limit, and verify a session can continue beyond thirty seconds before deliberate shortcut unlock.

External keyboard/mouse and multiple-monitor checks remain deferred from milestone 2. Packaged-app identity, signing/notarization, and older OS/hardware validation remain release gates.

Protocol details: [HELPER-PROTOCOL.md](HELPER-PROTOCOL.md).

## Post-merge review fixes — 2026-11-15

- Native cancellation observers are installed before preparation starts (and idempotently for direct begin calls). Sleep or session deactivation now finishes the helper and invalidates its preparation timer without relying on Electron cancellation.
- Preserved the agreed shortcut-only start design. If registration fails, the menu explains that the conflicting binding must be released and offers Retry start shortcut; the app also retries every three seconds. Registration recovery never starts a session itself. This is recovery after the conflict is removed, not an alternative start path while another app still owns the shortcut.
- Validation: native build, 26 JavaScript tests, and ten native integration tests passed. New tests exercise both retry paths with a simulated registration conflict, and send local sleep/session-deactivation notifications through the real native preparation path in nonblocking preview mode. Both native cases exited before locking with the expected reason and zero locked duration.
- Actual OS shortcut contention and physical sleep during the countdown remain manual follow-up checks; the tests do not put the Mac to sleep or intercept input.
