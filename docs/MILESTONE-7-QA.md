# Milestone 7 implementation QA

2026-11-16. Native Accessibility playback implemented on the existing milestone-7 branch following owner authorization. Public release has not been made.

## Current merge-gate status

The owner explicitly confirmed testing the rebuilt app containing `c6753d20c12c44c62c3a985d73ab1a2d7a5caa9f` after the review fixes:

| Browser / player | Pause | Resume | Two-second shortcut unlock |
| --- | --- | --- | --- |
| Chrome / YouTube | Passed | Passed | Passed |
| Safari / YouTube | Passed | Passed | Passed |
| Chrome / course player (TPStreams) | Passed | Passed | Passed |

These are owner-reported physical results, not automated observations. They satisfy the targeted retest requested by the follow-up reviewer. The follow-up review of that commit found both P2 findings addressed and no new actionable defect; it reported 39 JavaScript tests, native assertions, package verification, and diff checks passing. The subsequent QA-record commit changes documentation only.

Historical pending statements below describe earlier builds. The basic three-player retest is now complete. A hung AX call has not been induced, and this confirmation does not establish every full-screen, long-pause, target-change, or recovery scenario on the final code. Earlier full-screen and held-key results remain scoped to their recorded builds. Public-release/signing gates remain open; see `LOCAL-RELEASE-CHECKLIST.md`.


## Implemented

- Control + Option + Command + Space requests one toggle per fresh press; autorepeat and modifier additions to held Space do not toggle.
- At session start, bind only a unique supported English-labelled AXPress button in foreground Chrome/Safari. Retain window, document, button, and in-memory document URL. Rescan and require those identities before each command; refuse changed/ambiguous/unsupported targets. No URL or page contents logged by production code.
- No extension or global media fallback. No temporary disabling of the input tap.
- AX scans/actions run on a serial background queue with per-call timeouts and scan bounds. Unlock detection stays on the native event loop. Cleanup cancels pending playback work; an already dispatched browser action cannot be recalled.
- Reminder and guide explain the experimental shortcut. Feedback says “Playback requested,” not “Paused” or “Playing.” No automatic toggle retries.

## Passed

- Native build on ARM64, Node 22.22.2.
- 39 JavaScript tests.
- Native unlock, input policy, permission probe, playback label policy, and playback key-repeat tests.
- 10 real native IPC/preview/preparation-recovery tests.
- Direct production PlaybackTarget harness on the controlled Chrome player: binding succeeded and two requests delivered two actual clicks; media advanced approximately 1.075 seconds then returned to paused. This was an unlocked test of the production class, not shortcut acceptance.
- Actual rebuilt helper entered bounded locks and released at the 30-second development deadline without a stuck lock.
- Local app packaging and structural verification: ARM64, 15 Mach-O binaries, helper signature/identity and source inventory.

## Not passed / still required

- Automated Control+Option+Command+Space attempts during lock did not produce fixture clicks. Initial attempts also had the wrong foreground app/tab. A physical-key test was requested; the bounded session expired with no new fixture click and no confirmation received yet. Do not infer shortcut success from unit tests or the direct targeting harness.
- Physical play/pause twice, held-key repeat, ordinary-input suppression, and two-second unlock in the rebuilt packaged app.
- Chrome/course player and Chrome/Safari YouTube integrated playback, including full screen, long pause, multiple tabs, changed document/player, and unavailable player feedback.
- Recovery while a browser AX request is slow/unresponsive; physical unlock and sleep/permission revocation on the final build.
- Visual reminder layout and help scrolling on the packaged build.
- Review the implementation before merge/release.

The prior isolated probe evidence establishes feasibility but does not replace these integrated checks. Only the current development Mac (Apple Silicon, macOS reporting 27.2.1) is tested; no Intel or macOS 13 runtime claim.

## Local candidate

`out/PaperMode-darwin-arm64/PaperMode.app` is ad-hoc signed for local QA, not Developer ID signed or notarized. Keep the existing installed app until replacement/permission behavior is explicitly tested. Owner deferred license and signing decisions until local work is complete.

## Packaged smoke attempt and cleanup

The direct packaged `--smoke-test` invocation exited 1 without output; runtime smoke is not marked passed. The app enforces a single-instance lock, so another running instance is one possible cause, not a confirmed diagnosis. A computer-use attempt to inspect the existing PaperMode instance timed out. No installed app was replaced or permission changed.

All bounded lock sessions ended with `development-test-ended`. The temporary fixture tab was closed and its loopback server stopped. Physical-key confirmation remains pending and needs a fresh session; the earlier test window has ended.

## Follow-up packaged smoke — 2026-11-16

Confirmed the older `/Applications/PaperMode.app` was running with no active lock helper. Terminated that idle instance, then ran the new bundle with `--smoke-test`: exit 0, menuBarCreated true, shortcutRegistered true, state ready, Accessibility trusted, layout supported. This resolves the prior packaged smoke gate and confirms the single-instance conflict diagnosis. Opened the new bundle with `--bounded-locks` for physical QA; launch alone does not start a lock. Each user-started session in this mode has a 30-second safety limit. Physical playback/unlock results remain pending.

## Physical shortcut attempt — player unavailable

Owner reported “player unavailable” during the packaged Chrome/YouTube physical test. Playback/unlock acceptance is not passed; shortcut-unlock outcome was not reported. Subsequent process inspection found no active lock helper.

Read-only inspection of Chrome then found an enabled `Play (k)` button exposing only AXShowMenu and AXScrollToVisible, without AXPress (797 nodes). After ordinary UI interaction, the same labelled control advertised AXPress (809 nodes). A subsequent normal click produced Pause (k), with displayed progress advancing from 4:21 to 4:23; video was left playing. No production code or permissions changed.

This confirms variable action availability after the failed test, not the exact bind/request failure cause during that session. The product currently refuses controls without AXPress, so it cannot guarantee playback for every YouTube state. A fresh physical retry is needed with the action available; do not treat the interaction workaround as a release-quality fix.

## Startup binding follow-up and change

Owner confirmed the unavailable message appeared before pressing Space and that holding the unlock shortcut for two seconds released input. Mark that physical unlock case passed; playback remains unconfirmed.

Opt-in diagnostics in a subsequent real packaged start showed foreground Chrome, a complete 808-node scan, and one actionable candidate. Thus the failure is intermittent, not an always-wrong browser or consistently incomplete traversal. Separate read-only scans reproduced the missing AXPress on a unique candidate. A Chrome AXEnhancedUserInterface initialization experiment returned attribute-unsupported and did not restore the action. A direct unadvertised AXPress returned success without a confirmed label transition; that bypass is not included in production.

Changed binding to anchor one unique English-labelled player/window/document first, then rescan that same identity during a bounded readiness window. It never binds a replacement target or retries a toggle. Pending readiness now says “Checking play/pause availability…” instead of prematurely showing unavailable. Background AX work and unlock independence are preserved. Persistent unsupported players still fail closed; this change is not yet a demonstrated cure for every Chrome failure.

Native regression checks cover transient readiness, completion, cancellation, changed-target rejection, and timeout; JavaScript tests still pass (39). Diagnostics are opt-in with PAPERMODE_PLAYBACK_DIAGNOSTICS=1 and record only browser bundle, candidate/action counts, scan completeness, and binding outcome. They do not record page URLs/content or keys. Final physical playback retest remains required.

Chromium reference consulted: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/chrome_browser_application_mac.mm (on-demand Accessibility initialization; no initialization attribute change shipped).

Readiness-window candidate validation: native build and tests passed, 39 JavaScript tests passed, 10 IPC/recovery tests passed, package structure verified, packaged smoke exited 0 with Ready/Accessibility trusted/start shortcut registered. Reopened in bounded mode with opt-in diagnostics for owner retest. These automated results do not mark the intermittent physical binding issue resolved.


Owner retest result: **All three passed** — Chrome/YouTube paused, resumed, and the two-second L shortcut unlocked before the development timeout. Diagnostic evidence records a complete scan with one actionable player and `binding-ready`. This is the first confirmed packaged physical playback/unlock pass for this readiness build. Repeat/full-screen/long-pause, target-change, Safari and remaining recovery acceptance are still open; one successful run does not establish universal Chrome reliability.

## Chrome full-screen pass and reminder refinement

Owner confirmed Chrome/YouTube video full screen passed: pause, resume, remaining in full screen, visible reminder, and two-second shortcut unlock. This pass applies to the pre-refinement reminder.

Updated the reminder to a 360×222 card with separate permanent keycap rows for Unlock (L, hold two seconds) and Play / Pause (Space, press once). Playback feedback is now a separate line and cannot replace the shortcut. Countdown still hides both shortcut rows. Native build passed; an offscreen render was visually inspected with the playback-requested status. New layout still requires a physical full-screen readability check; held-Space repeat and long-pause resume remain pending.

Countdown layout correction: owner screenshot exposed unused space from the locked-state card. Preparation now uses a shared 136-point height for both panel and content; locked/preview remains 222 points. Header positions derive from height, with countdown and instruction placed inside the compact card. The top edge remains 16 points below the visible screen top in both states. Native build passed; the countdown was rendered offscreen and visually verified. This does not constitute a held-Space QA pass, which remains pending.

## Review fixes — media evidence and AX deadlines

Owner reported the compact countdown, held-Space single-toggle, subsequent resume, and unlock all passed before these review fixes. Owner also reported Safari working; exact Safari scenarios were not individually enumerated.

Addressed review finding P2 (target selection): count all Play/Pause-like controls in web areas before filtering by URL, enabled state or AXPress. A unique candidate additionally needs a recognized player ancestor, a seek timeline in that same player context, and a supported HTTPS document (YouTube video page/embed or app.tpstreams.com embed). Retain player-container identity alongside window/document/button. An unrelated Play button or a second non-actionable/URL-less candidate cannot qualify. Compatibility is intentionally narrowed and reflected in Help/README. These are structural/site checks, not a guarantee about arbitrary page JavaScript or every player variant.

Addressed review finding P2 (timeouts): all attribute/action-list calls and the final AXPress configure the timeout on the actual queried object. Timeouts are capped at 150 ms and shortened to the remaining monotonic budget. Check expiry after queries and immediately before action dispatch. Binding/readiness and playback-request budgets begin at enqueue time, include scans, and cannot authorize work after expiry. Errors/incomplete scans fail closed. AX work stays off the event-tap queue. No claim of hard real-time scheduling or cancellation of an action already dispatched.

Regression coverage includes unrelated buttons, missing player context, ambiguous candidates, unsupported/spoofed origins, deadline boundary, remaining-budget timeout, and late readiness rejection. Native and JavaScript tests pass. A read-only scan using the production scanner recognized the current Chrome YouTube player with one candidate and complete traversal (804 nodes); it did not press, lock input, or change browser focus. A hung browser has not been induced. Physical Chrome/Safari/TPStreams and full-screen playback need a targeted retest because discovery rules changed.
