# Milestone 4: user experience QA

Status: first-use guidance and recovery messaging implemented. First-time-user acceptance and display/hardware checks remain pending; this milestone is not yet marked complete.

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
