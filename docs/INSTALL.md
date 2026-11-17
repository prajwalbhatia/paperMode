# Install and use PaperMode

## Current availability

This is a local QA candidate, not an approved public release. It is ad-hoc signed, without Developer ID signing or Apple notarization. A downloaded copy may be blocked by Gatekeeper; a successful local launch does not prove downloaded-install acceptance. Do not disable Gatekeeper globally. Public distribution instructions will be finalized after the signing decision and downloaded-copy tests.

Current artifact: Apple Silicon (ARM64) only. Development and owner QA were performed on macOS 27.2.1. macOS 13 is the build deployment target, not a tested compatibility claim. Intel and older macOS runtime support are unverified.

## Install a locally built candidate

1. Quit PaperMode before replacing an existing copy. Keep the previous build available until replacement testing passes.
2. Unzip the local QA archive and drag PaperMode.app into Applications. Keep only one running copy.
3. Open PaperMode. Its paper icon appears in the menu bar; it does not have a normal main window.
4. In the guide, choose **Enable Accessibility…**. In System Settings → Privacy & Security → Accessibility, enable PaperMode and authenticate locally if requested.
5. Close the guide, then use **Check permission and layout** in the menu. Wait for **Ready**. If it remains Permission required, quit and reopen the installed copy and check its permission again. Development-host grants such as VS Code do not necessarily cover the packaged app.

If replacing an ad-hoc build invalidates its permission identity, remove the stale PaperMode entry using Accessibility settings, reopen the intended installed copy, and grant that copy permission. Do not reset permissions for unrelated apps.

## Use

Bring the intended course to the foreground. Close Help before starting. Press **Control + Option + Command + P**, or choose **Start PaperMode** in the menu. After the five-second countdown, PaperMode filters keyboard, pointer, and recognized media/control input while the video and screen remain visible. Built-in keyboard, trackpad and tested media-key blocking passed on the development Mac; external keyboard/mouse coverage remains unverified. Power and unknown system events deliberately pass through, so not every system action is prevented.

Hold **Control + Option + Command + L** together for two seconds to unlock. The reminder displays the shortcut and hold progress; releasing early resets it. Normal packaged sessions have **no automatic timeout**. The `--bounded-locks` option applies only to development runs, not packaged apps. Sleep ends a session and waking does not restart it.

When available, press **Control + Option + Command + Space** once to pause/resume the bound video; release before another press. Experimental support covers YouTube video pages/embeds and TPStreams embeds used by course player in Chrome/Safari, with English Accessibility labels and a unique recognized player. Unsupported or changed players can show unavailable. Unlock to control these normally. The action acknowledgement is not confirmation of playback state.

## Remove

Unlock and choose **Quit PaperMode**, then move PaperMode.app from Applications to Trash. Remove its entry in System Settings → Privacy & Security → Accessibility. To reset the welcome acknowledgement too, use Finder → Go → Go to Folder → `~/Library/Application Support/PaperMode` and remove PaperMode's `welcome.json` if present. Keep other applications' data untouched.
