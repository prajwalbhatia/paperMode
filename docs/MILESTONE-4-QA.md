# Milestone 4: user experience QA

Status: first-use guidance and recovery messaging implemented. Agent-assisted welcome dismissal, acknowledgement/relaunch, guide reopening, Settings navigation, and already-granted guidance checks passed with the limits below. Visual, hardware, and remaining end-to-end checks are pending; this milestone is not yet marked complete.

## Changes

- First normal launch shows a native guide explaining permission, both start paths, the preparation countdown, and the two-second unlock hold.
- The guide offers Enable Accessibility only when the latest diagnostic does not confirm permission; permission is requested only after that explicit choice. Not now leaves the app available through its menu.
- A local, versioned acknowledgement prevents repeated welcome dialogs. How to use PaperMode always reopens the guide. No lock state or input is persisted.
- Both start paths are blocked while the guide is open; repeated Help requests do not create multiple dialogs. A late dialog response after quit cannot request permission.
- Smoke and bounded development modes skip automatic onboarding. The existing reminder appearance and fixed shortcuts are retained.
- Menu messages now explain reminder loss, input-filter failures, helper connection loss, and permission-request failures.

## Verification — 2026-11-15

- 32 JavaScript tests passed, covering first-use acknowledgement, Not now, explicit permission choice, already-granted permission, duplicate dialogs, late responses, corrupt preferences, dialog failure, and start protection while guidance is open, in addition to existing tests.
- Native build passed. No native implementation changed for this milestone.
- Electron smoke passed with macOS UI access after closing an older idle bounded instance: `menuBarCreated:true`, `shortcutRegistered:true`, `state:permission-required` in the agent launch context. Earlier attempts were blocked by the sandbox or single-instance lock; no permission was revoked.
- Attempted an isolated-profile preview, but computer-use automation could not select the Electron app by its full path. The bundle ID is also shared with another local Electron project, and an older bounded instance was present. Dialog appearance and readability were not verified; the preview was closed without changing permissions or activating a lock.

## Remaining manual sequence

1. Launch normally with a fresh app profile. Confirm the welcome is readable and find both the start and unlock instructions. Choose Not now; no OS permission prompt or lock should occur.
2. Relaunch: welcome should not reappear. Open How to use PaperMode; close it and reopen it. While it is open, press the start shortcut: no countdown or lock should begin.
3. With permission missing, choose Enable Accessibility in the guide. Verify Settings opens, grant only the identity macOS identifies, then return to the menu. Confirm Ready appears after permission refresh. Repeat with denial and confirm the app stays unlocked.
4. With permission already granted, verify the guide offers Got it, with no unnecessary permission request. Start through the menu, then unlock using the visible two-second shortcut reminder.
5. Verify the compact reminder stays readable in full screen, near the notch, and on each connected display. Connect/disconnect a display during preparation and during a bounded session. If the reminder cannot remain visible, input must be released.
6. Validate actual shortcut contention and physical sleep during preparation from the post-merge review fixes.

Packaged permission identity and first-time installation belong to milestone 5. Multiple-display and external-device checks require the relevant hardware; do not infer those passes from single-display testing.

## App artwork update

Added a locally rendered paper-and-lock app icon, an explicit welcome/help dialog icon, and matching monochrome menu bar templates. The deterministic vector source is `scripts/build-icons.swift`; regenerate with `npm run build:icons` on macOS. The PNG was visually inspected. All 32 JavaScript tests passed, and an ARM64 local package built successfully; its Info.plist icon entry resolves to an ICNS file whose SHA-256 matches `assets/PaperMode.icns`. This validates bundled artwork, not packaged input/permission behavior. Actual welcome-dialog and light/dark menu-bar appearance remain manual checks.

Reminder icon correction: replaced the native panel’s old SF Symbol with the same PaperMode artwork, loaded beside the helper independently of the working directory. The native build copies the PNG and the packager includes it beside the bundled helper. Rebuilt the helper, checked its diagnostic, verified the copied asset matches the source, and rendered/visually inspected the updated card without blocking input. The revised packaged resource layout has not yet been rebuilt for runtime QA.

## Agent-run UX checks — 2026-11-15

Used an ignored `.build/qa-m4-manual.cjs` harness with the production entry point, a separate `.build/m4-manual-profile`, and no mocked permission result. The harness kept the Dock entry visible so computer-use could select Electron, logged dialog results and menu templates, and invoked the real guide for the reopen check. This does not establish direct tray-menu clicking. The user's saved welcome preference was not reset.

| Check | Result and evidence |
| --- | --- |
| Fresh welcome | Accessibility tree contained the welcome title, permission/start/unlock instructions, and Enable Accessibility / Not now buttons. Screenshot capture returned white, so visual readability/icon appearance was not established. |
| Not now | Clicked through computer-use; app logged response 1 and saved only `welcomeVersion:1`. No permission request or lock was triggered by dismissal. Evidence: `.build/m4-manual.jsonl`. |
| Acknowledged relaunch | The same profile reported `firstUse:true, alreadySeen:true` without opening welcome. Evidence: `.build/m4-help.jsonl`. |
| Reopen guide | Harness invoked the real guide after relaunch; accessibility tree showed the help title and instructions. This tests reopening, not the tray click path. |
| Enable Accessibility | Clicked the actual guide button; app logged response 0 and System Settings opened Device Control and Data Access under Privacy & Security. PaperMode was listed disabled at inspection. No grants or revocations were performed by the agent. |
| Already-granted context | Launched through VS Code. Menu template reported Ready and guide offered only Got it. Clicking Got it logged response 0, and the menu template returned to Ready with Start enabled. Evidence: `.build/m4-granted.jsonl`. |
| Start protection while guide open | Menu template disabled Start and the permission/help controls. A targeted synthetic start chord left the guide unchanged and no lock was started. Global delivery of synthetic input is not proven; automated gate tests remain the stronger evidence. |
| Real shortcut contention attempt | Separate Electron and Carbon test owners both reported successful reservation, but PaperMode also reported successful registration. No failing registration was induced; contention/recovery remains inconclusive rather than passed. Evidence: `.build/m4-shortcut-owner.jsonl`, `.build/m4-native-shortcut-owner.log`, `.build/m4-native-conflict.jsonl`. |

Computer-use often timed out after closing the last native dialog; app logs and persisted state confirmed those actions completed. All isolated QA apps and temporary shortcut owners were closed afterward. The previously running idle development instance was closed before testing and was not relaunched. Production code and permission toggles were unchanged.

Still pending: direct tray-menu start/help interaction in this milestone, visual welcome layout, physical shortcut testing with the guide open, fresh grant/denial and resulting Ready state in one launch context, display hot-plug/notch/multiple-display behavior, actual shortcut-conflict recovery, and physical sleep during preparation. Authentication and physical device changes require user participation; earlier milestone checks remain supporting evidence, not new passes for these cases.

## Inline start feedback update

Replaced the native alert with a local guide window so it can respond while open. The guide always says to close it before starting. Pressing the start chord while it is open highlights “Close this guide to start PaperMode. Then press Control + Option + Command + P again.” Both global and focused-window handlers provide feedback without starting a session. The message remains in the guide; no second dialog or automatic start is used.

The window uses a sandboxed preload, no Node integration in the page, a local-only CSP, validated sender/button choices, and blocked external navigation. Existing permission choice and welcome acknowledgement behavior is retained. Closing the window is equivalent to cancellation; renderer/load failure rejects rather than granting permission.

Validation: 34 JavaScript tests passed, including notice routing, protection against starting, pending notice delivery, sender/button validation, listener cleanup, cancellation, and renderer failure. Computer-use inspected the rendered window: icon, complete instructions, baseline hint, and Got it were visible and readable; Got it closed the window. Synthetic chord delivery did not show the highlighted notice, so physical shortcut-to-notice verification remains pending. Prior native-dialog QA does not substitute for the new window's remaining permission and relaunch checks.
