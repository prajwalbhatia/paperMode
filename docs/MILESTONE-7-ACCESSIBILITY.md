# Milestone 7 — standalone Accessibility feasibility

Date: 2026-11-16. Isolated Swift probe only. No PaperMode production code or installed app changed; no extension used. Existing Accessibility approval was sufficient. User requested YouTube in Safari instead of signing into course player.

## Results

Evidence files are in `docs/evidence/milestone-7/accessibility/`. A confirmed cycle means AXPress returned success and the retained control changed its label and then returned to its original state. It does not independently measure media playback.

| Browser / player | Unlocked cycle | Isolated input filter enabled |
| --- | --- | --- |
| Chrome / course player TPStreams course | Passed on repeat with run-loop servicing | Unconfirmed: AXPress returned success but Pause label did not change; subsequent UI observation still showed Pause |
| Chrome / YouTube | Passed | Passed on repeat; first run did not confirm a transition |
| Safari / YouTube | Passed | Passed, returning to paused state |
| Safari / course player | Not tested: sign-in required; user chose YouTube instead | Not tested |

The first Chrome/course player run used Thread.sleep and reported an unchanged label even though subsequent browser observation showed playback started. Replacing the wait with run-loop servicing allowed a complete unlocked cycle. Later locked Chrome runs still produced unconfirmed results; do not attribute all failures to stale reads without further evidence. Failed attempts remain in the evidence inventory.

Both successful locked YouTube runs recorded an enabled event tap before and after the actions and before cleanup. Suppressed-event counts were zero: no physical typing/pointer test was performed in these short cycles. This establishes native-action feasibility with an enabled filter, not complete input-lock QA.

Safari’s initial unlocked test was followed by observation of a full-screen player. The later locked test was in a normal window. Attempts to enter full screen for another locked test did not establish a state change, so locked full-screen coverage remains pending.

## Interpretation

Native AXPress can control these YouTube instances without an extension. It is not yet reliable enough to promise course-targeted playback in PaperMode: the locked course player attempt did not confirm playback control, and Chrome/YouTube had an inconclusive run. AX button labels are a heuristic and success return values are insufficient confirmation.

The probe selects one eligible control in the current browser window and retains it for two actions. It does not implement durable selected-course binding. Background competitors existed during Chrome checks, but their states were not independently tracked through every action; exact-target contention acceptance remains unverified.

Before product implementation, investigate the Chrome failure, improve bounded state observation, and test target identity through tab switches, navigation, player replacement, multiple players, localization, and full screen. Three-minute paused resume and permission-loss recovery remain outside this AX probe’s coverage. There is no global-media fallback.

## Cleanup and validation

The isolated tap released after each completed process. The temporary Chrome YouTube tab was closed; the original course was left with its Play control visible. Safari YouTube returned to paused. No permission settings were changed. Raw logs omit document URLs, credentials, and page contents.

The Swift probe compiles against the existing InputPolicy. No production test results are claimed from this experiment.

## Follow-up investigation — 2026-11-16

Only the isolated probe changed: added available-action diagnostics, browser foreground context, suppressed event-type counts, and bounded state polling (about 100 ms intervals, three seconds per action). No automatic toggle retries, browser configuration changes, or production modifications.

### Observations

1. Two initial course attempts refused before enabling the filter because no eligible control was found. A diagnostic inspection explained why: the `Play Play` button existed inside a web area but exposed only `AXShowMenu` and `AXScrollToVisible`, without `AXPress`. Raising Chrome did not change this. This is action availability, not a missing button or input-filter failure.
2. Chrome/YouTube passed four consecutive locked cycles with polling. All observed transitions arrived on the first sample, about 100–101 ms after the action.
3. After an ordinary UI click started the course, its button exposed `AXPress`. The course then passed four consecutive locked pause/resume cycles, with transitions observed at about 100–102 ms.
4. A comparison executable using the original one-second, single-read wait also passed on the course. Therefore these results do not establish that polling fixed the original failure. Its source was generated from the diagnostic probe by replacing both polling calls with the earlier one-second RunLoop wait plus a label read; generated binary/source remain in ignored `.build/accessibility-probe/`.
5. Starting from paused, the course passed resume/return-to-pause under the filter. Another attempted background comparison also passed, but its context still reported `browserActive:true`; the filename `investigation-course-background.jsonl` is an attempted case, not background coverage.
6. Every successful filtered cycle recorded the tap enabled throughout, with zero intercepted events. No physical input was injected, so this is not physical input suppression QA. The results show AX actions can succeed without intercepted keyboard/pointer events; they do not prove every Chromium action takes the same route.

### What this explains—and what it does not

Confirmed: the course's Accessibility action availability changed across observations, and a Play-labelled button alone is insufficient. The missing action was present before any lock. Ordinary player interaction was followed by action availability and successful locked cycles. This is a correlation; the experiment did not identify whether player initialization, focus, event handlers, or Chrome’s AX cache caused that change.

Chromium's implementation only advertises AXPress for eligible default actions and excludes click-ancestor-only nodes. That supports treating action availability as distinct from button labels, but does not establish the exact cause in this TPStreams instance. Reference: [Chromium browser_accessibility_cocoa.mm](https://chromium.googlesource.com/chromium/src.git/+/HEAD/ui/accessibility/platform/browser_accessibility_cocoa.mm).

The earlier AXPress-success-without-confirmed-transition failure was not reproduced under the new foreground, initialized-player conditions. Root cause remains unresolved. Neither polling nor a preparatory click should be shipped as a proven fix. No fallback click or global media command was added.

### Next isolated experiment

Use a controlled local player fixture to distinguish default-action exposure, delayed handler installation, and stale AX state, then repeat on a newly loaded course with synchronized action lists, focus state, and independent playback-progress observations. Preserve the first action result and never blindly retry a toggle. Actual background, full-screen, idle-resume, and player replacement remain separate gates.

### Cleanup and validation

Closed the temporary Chrome YouTube tab and verified the course's Play control at the end. Course position advanced during testing; it was not reset. The native filter exited after every cycle. The probe compiles; no production source was changed. Investigation JSONL files retain control labels/action names and timing, but no page URLs or signed media tokens.

## Controlled fixture comparison — 2026-11-16

Added only `scripts/accessibility-probe/fixture/`, a loopback server and a local canvas-stream video page. The page independently records delivered clicks, actual `video.paused`/`currentTime`, media events, and displayed labels. No extension, external media, browser scripting permission, or PaperMode change. The existing diagnostic probe was used unchanged for this comparison.

| Case | Native probe result | Independent fixture evidence |
| --- | --- | --- |
| Normal, unlocked | Complete cycle, restored | Two clicks; playing then paused; time advanced to about 0.101 s |
| Normal, locked | Complete cycle, restored | Two further clicks; playing then paused; time advanced to about 0.206 s total |
| Label deliberately delayed, locked | AXPress success, unconfirmed; no retry | One click delivered; playing with advancing time while label remained Play; label became Pause at about 4.505 s |
| Handler deliberately ignores click, locked | AXPress success, unconfirmed; no retry | One click delivered; remained paused at time zero |
| Label deliberately delayed, unlocked | AXPress success, unconfirmed; no retry | One click delivered; playing with advancing time while label remained Play; label became Pause at about 5.449 s (timer scheduled for 4.5 s) |

All locked cases logged the filter enabled through cleanup, with zero intercepted input events. The normal cases confirm actual playback rather than relying solely on AX labels. This does not test physical input suppression.

**Conclusion:** the same AX success plus unchanged label can represent successful playback with delayed UI or a delivered click with no playback effect. The false-negative label result also occurs unlocked. This proves the probe's label-only observation cannot diagnose the original failure; it does not prove course player used either of these mechanisms. No blind retry was introduced. Increasing the wait alone cannot distinguish an ignored action from an arbitrarily delayed label.

Evidence is in `docs/evidence/milestone-7/accessibility/controlled/`: five native logs plus fixture events. Assertions checked the two restored cycles, three unconfirmed outcomes without second actions, delayed playback advancing beyond three seconds with the old label, and ignored playback staying at zero. All passed.

The fixture tab was closed and the loopback server stopped. Original course content was not interacted with during this controlled run. Next: reproduce the real-player failure while independently observing its progress/time and native control action availability; retain the uncertain outcome if independent evidence is unavailable. Durable player identity and full-screen/background testing remain separate requirements.
