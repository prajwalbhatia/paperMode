# PaperMode 0.1.3 Preview 1

This preview improves playback control in an embedded course player and makes the unlock hold easier to see.

- Fixed a player that could show **Player unavailable** after pausing because it exposed two nested Play controls. PaperMode selects the inner control only when both belong to the same recognized player.
- Fixed a deeper Accessibility layout that made the player appear ready but prevented playback actions.
- On a supported Chrome course player, the locked seek shortcuts now use the focused video's arrow controls. This avoids a synthetic timeline click that moved the lesson but left it paused. Click the video before locking so it has focus; if focus moves to another control, seeking is unavailable.
- The two-second unlock progress now traces the reminder's rounded perimeter.

The owner tested pause, resume, forward and backward seeking without stopping playback, and the two-second unlock in the local Chrome course player. The unlock outline was also checked in the rebuilt local app. Other player layouts and browsers may differ. PaperMode's keyboard and trackpad lock still works without a compatible player.

This Apple Silicon preview is ad-hoc signed and **not notarized by Apple**. macOS may require **Open Anyway** in Privacy & Security. Quit an older PaperMode copy before replacing it, then follow the bundled `INSTALL.md`. This is an early test build, not a stable release. External input devices, Intel Macs, older macOS versions, and clean-machine installation remain unverified.
