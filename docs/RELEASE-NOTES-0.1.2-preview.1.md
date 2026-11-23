# PaperMode 0.1.2 Preview 1

This preview adds five-second rewind and forward controls while input is locked, and broadens video-player detection.

- Press **Control + Option + Command + Left Arrow** to request a five-second rewind, or **Right Arrow** to request a five-second skip forward. Release the arrow before pressing again. The existing Space shortcut still requests play/pause, and holding **Control + Option + Command + L** for two seconds still unlocks.
- A unique player with a Play/Pause button, timeline, and nearby media controls can work without a site-specific rule. Owner tests passed on YouTube in Chrome, Safari, and Firefox; a Chrome course player; a Firefox Udemy lecture; and Vimeo and an InterviewReady free lesson in Firefox. Video full-screen tests passed in Chrome and Safari YouTube, and Firefox Vimeo and InterviewReady.
- Seeking checks the bound browser window and player before acting. Firefox arrow seeking requires focus on the selected player surface or timeline. A request acknowledgement does not confirm that the video moved; if unavailable or unresponsive, unlock and use the player normally.
- The lock reminder is smaller, and the two-second unlock progress runs along the top border.

Playback controls depend on English macOS Accessibility labels and a unique recognizable player. Other sites and browser combinations may not work. The keyboard and trackpad lock still works without a compatible player. External input devices, Intel Macs, and older macOS versions remain unverified.

This Apple Silicon preview is ad-hoc signed and **not notarized by Apple**. macOS may require **Open Anyway** in Privacy & Security. Quit an older PaperMode copy before replacing it, then follow the bundled `INSTALL.md`. This is an early test build, not a stable release.
