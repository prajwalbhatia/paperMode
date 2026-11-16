# Milestone 7: playback while locked

Follow-up explicit-player experiment: see [MILESTONE-7-TARGETING.md](MILESTONE-7-TARGETING.md). Chrome course player/YouTube direct binding and a competing-player check passed; Safari is blocked by unavailable extension build tools. This remains isolated feasibility work.

Status: isolated native delivery established on 2026-11-16; intended-player routing and product acceptance are **not yet established**. No product behavior, input filtering, shortcuts, or permissions were changed. Branch: `milestone-7-playback-feasibility`, based on merged milestone 5.

## Observed baseline

Host: development Apple Silicon Mac, macOS 27.2.1. Installed browser versions read from bundle metadata: Chrome 157.0.8103.78, Safari 27.2.

| Case | Observation | What it establishes |
| --- | --- | --- |
| Chrome, existing course player lesson in embedded TPStreams player | Chrome Global Media Controls identified the lesson. Play changed to Pause and the tab reported audio playing; Pause changed back to Play. The course advanced from 6:29 to 6:34 and was left paused. | Browser-level media-session resume/pause works for this lesson; no system media key or PaperMode lock was exercised. |
| Safari, official Chrome Media Session video sample in a temporary tab | Started Sintel trailer. Elapsed time advanced; sample logged playback metadata and position updates. Native video controls paused and resumed. Closed the temporary tab afterward. | Basic playback and Media Session setup work in Safari. Clicking the player's own controls does not prove remote Media Session action delivery. |
| System play/pause key through computer-use | `XF86AudioPlay` returned keyNotFound. Selecting macOS Control Center timed out. | Automation limitation, not evidence that browser media keys fail. |

The first Chrome selection took over ten minutes despite a requested short timeout. Further native automation had intermittent stale-element/capture errors. Do not infer failed playback from those tool errors. The existing Safari tab was preserved; no course authentication data or embedded access-token URLs are saved here.

## Constraints verified in the current code

`LockSession.handle` suppresses ordinary keyboard input and delegates system-defined media events to `InputPolicy`. Play/pause is currently blocked. Merely forwarding a conventional media key from another process cannot be assumed to work through the active filter. A future deliberate dispatch path must preserve the input lock continuously, avoid duplicate/repeat actions, and retain the independent two-second unlock.

## Evidence and approach decision

- [Chrome's documented media-key behavior](https://developer.chrome.com/blog/media-updates-in-chrome-73) supports foreground/background play/pause of the active media element; custom page handlers may override defaults.
- [Media Session routing](https://www.w3.org/TR/mediasession/#routing) is selected by the user agent. This does not guarantee that a generic system command controls the visible course when several media sources exist.
- [Official sample](https://googlechrome.github.io/samples/media-session/video.html) explicitly registers play/pause action handlers; observing those handler log messages during a system-command test would distinguish remote control from player-button clicks.

## Physical media-key results (user reported)

PaperMode was unlocked for these checks. Initial F8 failures occurred while PaperMode was locked and are expected filtering behavior.

| Browser/player | Windowed | Full screen | Resume after three minutes |
| --- | --- | --- | --- |
| Chrome, course player lesson | Pass | Three cycles passed | Same lesson resumed |
| Safari, YouTube | Three cycles passed | Three cycles passed | Same video resumed |

## Isolated native experiment (agent executed)

The owner explicitly authorized this utility. `scripts/playback-probe/` is excluded from packaging by the existing scripts exclusion. It does not change or launch PaperMode, install a shortcut, or change permissions. The separate ten-second lock uses the existing system-event policy but is not a production LockSession test.

| Experiment | Observed result |
| --- | --- |
| Native system play/pause, unlocked real Chrome lesson | Paused; Chrome's media UI showed Play at 10:11. Native resume on this real lesson was not checked. |
| Native dispatch, instrumented local Chrome/Safari video | Both logged remote Media Session actions and corresponding playback transitions. An initial Safari dispatch produced no action until the player was activated again; do not claim universal delivery. |
| Ordinary HID media event during isolated lock | Suppressed; no corresponding browser playback action. |
| Posting at annotated-session location after the tap | Safari did not receive play/pause. Tap stayed enabled; probe ended normally. This approach failed on this host. |
| Tagged HID events allowed narrowly through the probe callback | Both browser fixtures logged exactly one remote pause and one remote play. Each run forwarded four probe events (down/up twice), suppressed three events, and ended with `test-ended`. Tap checks at 2/4/6 seconds were enabled; code never disables the tap between commands. |
| Background playback | Chrome fixture reported hidden/focus false during remote pause/play; Safari reported hidden. Some frontmost lookups returned unknown, so these runs do not establish exact foreground app or full-screen state. A later unlocked toggle logged Codex frontmost and paused Chrome. |
| Both browser fixtures playing | After starting Chrome most recently, the tagged probe paused/resumed Chrome; Safari received no new action. This is one routing observation, not an intended-course guarantee. |

Raw sanitized probe and local-fixture evidence is in `docs/evidence/milestone-7/`. Browser events identify only the local fixtures. The fixtures were closed afterward; original course/YouTube tabs remain and were paused. The temporary localhost server was stopped.

The final unlocked toggle runner waits 0.5 seconds after posting; an immediate-exit attempt produced no browser event. Do not treat a successful post/exit as confirmed playback. The utility always reports `playbackConfirmed: false`; confirmation comes separately from browser events/UI.

## Decision and remaining gates

Native delivery while maintaining an enabled input filter is feasible on this host. The tagged forwarding path is an experiment, **not a production trust boundary or finished feature**. Production integration needs bounded dispatch authorization, down/up validation, repeat protection, and regression coverage without widening ordinary input access.

The current experiment does not justify claiming that the visible course will always receive a global media command. No approach or new shortcut has been selected; review support scope before implementation.

Still pending, explicitly not passed:

- Broader competing-native-app coverage, unsupported players, and a clean no-eligible-session case. Existing user media sessions prevent treating an empty fixture as no eligible player. The Chrome two-tab test below exposed a targeting failure.
- Reliable foreground/visible-course targeting under contention. UI automation did not establish the intended foreground browser consistently.
- Native probe in full-screen real-course playback. User physical F8 full-screen results above are a separate test.
- Continuous physical keyboard/pointer/notebook checks during deliberate dispatch, repeated chord activation, emergency shortcut, and production unlock/recovery regressions. The probe sends timed commands, not the future product shortcut.
- Other macOS versions and hardware, and additional course platforms.

These remain scope/implementation acceptance gates; no product behavior was changed to bypass them.

## Follow-up QA — 2026-11-16

**Confirmed targeting failure, not an automation limitation:** started Chrome fixture A, then B, then selected A. Both were playing. Native `--toggle` reported Chrome frontmost but invoked `remote-pause` on hidden B. A received no remote action. The subsequent `--lock-probe-forward` resumed and paused hidden B again, with A still selected. All three tap checks were enabled; four tagged events passed and three ordinary events were suppressed. See `multiple-tabs.jsonl` and `multiple-tabs-browser-events.jsonl` in the evidence directory. Generic system commands do not meet a requirement to control the selected/visible course under this contention case.

**Real Safari YouTube delivery:** explicitly started playback, ran the bounded probe, observed Play at 0:48 during the pause phase and Pause after the resume phase. Probe exited normally. The full-screen button was invoked but automation did not verify entry; only playback delivery is passed. Video was paused afterward. Evidence filename `fullscreen-safari.jsonl` describes the attempted case, not a full-screen pass.

**Chrome full-screen attempt:** the real course exposed Exit Fullscreen, the probe forwarded four events and exited normally, but player/global-media state snapshots disagreed and the final state was paused. Time advanced from 10:33 to 10:36. This is inconclusive for the expected pause-then-resume sequence; a physical observation is needed. Do not mark full-screen acceptance passed from the log alone.

**QuickTime attempt:** opened the known local ten-second sample, started it, and sent native toggles with Codex frontmost. UI changed to paused near nine seconds; a later toggle advanced to the clip end. The short clip and unconfirmed loop state confound resume observation. Broad native-app contention remains pending. Closed the sample afterward; no user video file was edited.

Both temporary Chrome fixture tabs were closed and the localhost server stopped. No production code changed. Physical input suppression and emergency escape during the timed probe are the next assisted checks; product chord/recovery regression must wait for an approved implementation.

## Assisted Chrome full-screen physical-input check — 2026-11-16

User explicitly prepared PaperMode unlocked, other videos paused, and the Chrome lesson playing in full screen. Ran `--lock-probe-forward`; it ended with `test-ended`, four forwarded probe events, and enabled tap checks at 2/4/6 seconds. The user confirmed all four: keyboard/F8/pointer input stayed blocked; the lesson paused and resumed; full screen remained intact; the reminder disappeared and input returned. This passes the observed Chrome full-screen physical-input scenario, resolving the earlier inconclusive automated attempt for this scenario.

Evidence: `docs/evidence/milestone-7/physical-chrome.jsonl`. The log records only three suppressed events, the same count as the synthetic negative control; physical-input results are user-reported, not independently established by those counts. Multi-source routing remains a confirmed limitation. Safari physical input and probe emergency escape remain pending.

## Assisted Safari full-screen physical-input repeat — 2026-11-16

The first assisted Safari run did not establish full-screen coverage: the user clarified they had not tested full screen. Repeated after the user explicitly prepared Safari YouTube playing in full screen, Chrome paused, and PaperMode unlocked.

The repeated probe ended with `test-ended`, suppressed 97 events, forwarded four tagged events, and reported enabled tap checks at 2/4/6 seconds. The user confirmed keyboard/trackpad input stayed blocked, the video paused and resumed, Safari stayed full screen, and input returned after the reminder disappeared. This passes the assisted Safari full-screen scenario. Playback and visual results are user-reported; event counts and normal termination are independently logged.

Evidence: `docs/evidence/milestone-7/physical-safari-fullscreen-repeat.jsonl`. The earlier attempt is not counted as a full-screen pass. Probe emergency escape is the next assisted check; multi-source routing remains a confirmed limitation and production behavior remains unchanged.

## Assisted probe emergency exit — 2026-11-16

With PaperMode unlocked and Safari playing, the user pressed Control + Option + Command + L when the isolated probe reminder appeared. The process exited in under one second with `reason: emergency-shortcut`, zero forwarded playback events, and three suppressed events. The user confirmed the reminder disappeared and keyboard/trackpad input returned immediately. This passes the probe's immediate emergency escape, not PaperMode's separate two-second unlock behavior.

Evidence: `docs/evidence/milestone-7/emergency-exit.jsonl`. The next assisted case is Safari versus QuickTime routing with both sources active. Production integration and its regression gates remain pending.

## Quick remaining-case attempt — 2026-11-16

At the owner's request, retried QuickTime automation using the existing local sample. The movie opened, but the accessibility tree exposed only window controls and no transport state; an interaction returned `noWindowsAvailable`, and rebinding/raising the app still did not expose playback state. Closed the temporary movie. No new native-app routing pass is claimed.

The clean no-eligible-session case remains untested: paused existing user browser sessions remain potential targets, and an empty/new tab does not establish that the system has no eligible media. A specific real unsupported player has not been selected; a fabricated no-op Media Session handler would only test a simulation. Neither case is marked passed. The earlier estimate of three quick manual checks understated these setup requirements. Existing evidence already disproves guaranteed visible-course targeting for generic media commands; review that support decision before further product work.
