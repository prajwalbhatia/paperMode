# Install PaperMode (Developer ID release)

This guide applies to a future Developer ID signed and Apple notarized PaperMode ZIP. Use it only with a release explicitly identified as notarized on the [official GitHub Releases page](https://github.com/prajwalbhatia/paperMode/releases). The current preview has a separate installation guide.

PaperMode currently ships for Apple Silicon (ARM64). The build targets macOS 13 or newer, but physical compatibility has not been confirmed across every supported macOS version and Mac model.

## Install

1. Download the `PaperMode-<version>-macos-arm64.zip` asset from the release. Extract it and move **PaperMode.app** into **Applications**. Quit an older PaperMode first and run only one copy.
2. Open **Applications → PaperMode**. macOS may show a normal first-open confirmation identifying the developer. If it reports malware, a damaged app, or an unverified developer, stop and report the exact warning rather than bypassing it.
3. PaperMode appears as a paper icon in the menu bar. In its guide, choose **Enable Accessibility…** if needed. Enable **PaperMode** in **System Settings → Privacy & Security → Accessibility** and authenticate locally if prompted.
4. Close the guide, then choose **Check permission and layout** from PaperMode's menu. Wait for **Ready**. If permission still appears missing while PaperMode is enabled in Settings, use the recovery steps below.

Accessibility is required to filter input during a session. Developer ID signing and notarization do not remove this permission step.

## Use

Bring the intended video to the foreground and close the guide. Press **Control + Option + Command + P** or choose **Start PaperMode** in the menu. The five-second countdown gives you time to position your notebook. PaperMode then filters keyboard, pointer, and recognized media/control input while the screen and video remain visible.

Hold **Control + Option + Command + L** for two seconds to unlock. The reminder shows the shortcut and hold progress. Normal sessions have no automatic timeout. Sleep ends a session and waking does not restart it.

When available, press **Control + Option + Command + Space** once to pause or resume the selected video; release before pressing again. Compatible YouTube and TPStreams players in Chrome and Safari are supported. If PaperMode says playback is unavailable, unlock to control the video normally.

External keyboard and mouse coverage remains unverified. Power and unknown system events are intentionally passed through.

## Update or remove

PaperMode checks the official GitHub releases shortly after launch and about once a day while idle. It shows a newer release's notes and link once, after any lock or guide closes. Choose **Check for Updates…** from the menu for an immediate check. PaperMode does not download or install updates automatically. Quit it before replacing it with a newer release.

If Accessibility remains unavailable while PaperMode's switch is enabled, quit the app, remove only its stale entry in **System Settings → Privacy & Security → Accessibility**, then reopen **Applications → PaperMode**. Add it with **+** if needed, enable it, and choose **Check permission and layout**. Leave other apps' permissions alone.

To remove PaperMode, unlock, choose **Quit PaperMode**, move the app from Applications to Trash, and remove its Accessibility entry.
