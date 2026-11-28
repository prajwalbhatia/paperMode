# Install and use PaperMode

## Current availability

PaperMode previews are ad-hoc signed and **not Developer ID signed or notarized by Apple**. They are intended for early testing, not as stable releases. Download only from the [official GitHub Releases page](https://github.com/prajwalbhatia/paperMode/releases). Draft releases are visible only to repository collaborators until published.

Current artifact: Apple Silicon (ARM64) only. Development and owner QA were performed on macOS 27.2.1. macOS 13 is the build deployment target, not a tested compatibility claim. Intel and older macOS runtime support are unverified.

## Install the GitHub preview

1. Download `PaperMode-0.1.3-macos-arm64-unnotarized-preview.zip` from the official release's **Assets** section. Optionally download `SHA256SUMS.txt` to compare the archive checksum; a matching checksum checks consistency with the published asset, not independent trust in the publisher.
2. Quit an existing PaperMode instance. Keep the previous build until replacement testing passes. Extract the ZIP and drag **PaperMode.app** into **Applications**, replacing the old copy if applicable. Run only one copy.
3. Open **Applications → PaperMode** once. macOS may say it cannot verify PaperMode is free of malware, or that the developer cannot be verified. Dismiss that warning without moving the app to Trash.
4. If you trust the official download, open **System Settings → Privacy & Security**, scroll to **Security**, and choose **Open Anyway** beside the PaperMode notice. Confirm opening and authenticate locally if prompted. The notice appears after an attempted launch; wording varies by macOS version. Managed Macs may prohibit this override.
5. PaperMode appears as a paper icon in the menu bar, not a normal main window. Open **How to use PaperMode** and choose **Enable Accessibility…** if needed. In **Privacy & Security → Accessibility**, enable **PaperMode** and authenticate locally if prompted. On the tested macOS 27 host, this list is named **Device Control and Data Access**; enable **PaperMode** and **papermode-helper** if both appear.
6. Close the guide, then choose **Check permission and layout** in PaperMode's menu. Wait for **Ready**. Start is disabled while Help is open. If permission still appears missing even though PaperMode is enabled in Settings, follow the recovery steps below.

This is Apple's per-app exception flow: [Safely open apps on your Mac](https://support.apple.com/102445). Do not disable Gatekeeper globally or remove quarantine attributes to bypass the check. If macOS reports actual malware or a damaged app, stop and report the exact warning rather than treating it as the expected unidentified-developer notice.

## Updating and permission identity

Quit before replacing PaperMode. Development-host grants such as VS Code do not necessarily cover the installed app. Always reopen the copy in Applications after an update so an old development build does not remain active.

If PaperMode says **Permission required** while its Accessibility switch is already enabled: quit PaperMode, open **System Settings → Privacy & Security → Accessibility** (or **Device Control and Data Access** on the tested macOS 27 host), select and remove only PaperMode's entry, then reopen **Applications → PaperMode**. Add PaperMode with **+** if it is missing, enable its switch, and choose **Check permission and layout** from PaperMode's menu. Do not reset permissions for unrelated apps.

Starting with v0.1.1-preview.1, PaperMode checks the official GitHub releases shortly after launch and about once a day while idle. If it finds a newer release, it shows its notes and a link once; it waits until the lock and guide are closed. Choose **Check for Updates…** from the menu for an immediate check. The earlier v0.1.0-preview.1 does not have update alerts. PaperMode does not download or install updates automatically. Quit it before replacing it with a downloaded version.

## Use

Bring the intended course to the foreground. Close Help before starting. Press **Control + Option + Command + P**, or choose **Start PaperMode** in the menu. After the five-second countdown, PaperMode filters keyboard, pointer, and recognized media/control input while the video and screen remain visible. Built-in keyboard, trackpad and tested media-key blocking passed on the development Mac; external keyboard/mouse coverage remains unverified. Power and unknown system events deliberately pass through, so not every system action is prevented.

Hold **Control + Option + Command + L** together for two seconds to unlock. The reminder displays the shortcut and hold progress; releasing early resets it. Normal packaged sessions have **no automatic timeout**. The `--bounded-locks` option applies only to development runs, not packaged apps. Sleep ends a session and waking does not restart it.

The keyboard and trackpad lock works over any browser. Play/pause while locked requires a compatible video in Chrome, Safari, or Firefox. When available, press **Control + Option + Command + Space** once to pause/resume the bound video; release before another press. Tested targets include YouTube in all three browsers, TPStreams in Chrome/Safari, Udemy lectures in Firefox, and Vimeo in Firefox. PaperMode can detect other players with a unique Play/Pause control, timeline, and nearby media controls exposed through macOS Accessibility. English labels and a recognizable structure are required; an unsupported or changed player can show unavailable. Unlock to control it normally. The action acknowledgement is not confirmation of playback state.

On a compatible player, press **Control + Option + Command + Left Arrow** to seek back about five seconds or **Right Arrow** to seek forward. Release the arrow before pressing again. Some course players need you to click the video before locking so it has focus. PaperMode reports a request, not a confirmed new playback position. If seeking is unavailable, unlock and use the player normally.

## Remove

Unlock and choose **Quit PaperMode**, then move PaperMode.app from Applications to Trash. Remove its entry in System Settings → Privacy & Security → Accessibility. To reset the welcome acknowledgement too, use Finder → Go → Go to Folder → `~/Library/Application Support/PaperMode` and remove PaperMode's `welcome.json` if present. Keep other applications' data untouched.
