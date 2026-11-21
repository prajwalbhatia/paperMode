# PaperMode 0.1.1 Preview 1

This preview adds update checks and clearer Accessibility permission recovery.

- PaperMode now checks GitHub Releases after launch and about once a day while idle. A newer release prompts once after any lock session or guide closes. **Check for Updates…** in the menu runs an immediate check. PaperMode does not download or install updates.
- If Accessibility remains unavailable after replacing the app, the guide now explains how to remove PaperMode's stale permission entry and grant access to the installed copy.
- Update alerts remember the highest version already announced, so a withdrawn newer release does not make an older one appear again.

The existing v0.1.0-preview.1 does not have update alerts; install this preview manually from the official GitHub release. Quit PaperMode before replacing it, then check **Ready** in the menu. If permission is missing, follow the included INSTALL.md.

This Apple Silicon preview is ad-hoc signed and not notarized by Apple. macOS may require **Open Anyway** in Privacy & Security. It is an early test build, not a stable release. See INSTALL.md for the installation steps, supported playback, and current testing limits.
