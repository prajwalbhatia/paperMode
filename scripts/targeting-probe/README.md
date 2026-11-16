# Explicit player targeting — isolated QA

Not a PaperMode feature or production integration. Everything here is excluded from packaging by the existing `/scripts` exclusion. No host, extension, permissions, or browser settings are installed by these files.

## Reviewable browser permissions

The unpacked extension requests `scripting`, `storage`, and access only to:

- `https://example.invalid/*`
- `https://app.tpstreams.com/*` (the embedded course player)
- `https://www.youtube.com/*`

These permissions allow reading/modifying pages on those hosts, including logged-in pages. The code operates only on videos when its popup is used; it has no content scripts, network uploads, native messaging, debugger permission, remote code, or media-key fallback. No cookies, account data, page text, or media URLs are read/exported. The isolated frame context retains a media source string only to reject source replacement. Stored bindings contain IDs/tokens and origin, not full page/embed URLs or titles. Removing the extension removes its local binding storage.

## Run after permission approval

Load `scripts/targeting-probe/extension` through Chrome's developer extension UI. Do not install or enable site access without the owner's approval.

1. Start a course using its normal controls. Open the probe popup and choose **Inspect selected tab**.
2. Select the intended video from the origin/frame candidates. No automatic choice is made, including on pages with several videos.
3. Read state; pause; verify paused state and the actual player; resume; verify the player's progress. `play()` may be denied or time out. A state report does not independently establish audible playback.
4. Start a competing video in another tab or browser. Reopen the popup without inspecting/rebinding; commands must continue to address the bound video. Verify the competitor stays unaffected.
5. Navigate/reload the bound page, replace its player, or close the tab. The old binding must fail without touching another video. An empty target must fail without a global fallback.
6. Repeat for course player and YouTube in each browser, normal/full screen and after a three-minute pause. Record actual results, including inaccessible frames or multiple candidates.

The popup cannot be clicked during a native input lock. This first experiment tests explicit binding and browser control only. Delivery during the lock needs a separately reviewed test bridge or timed runner; do not claim it from popup tests. Existing PaperMode remains unchanged.

## Safari prerequisite

This Mac currently selects `/Library/Developer/CommandLineTools`; neither `safari-web-extension-packager` nor the older `safari-web-extension-converter` is available, and no Xcode app was found in `/Applications`. Safari execution is blocked pending a suitable Xcode toolchain or another reviewed Safari test route. Shared browser code is a candidate for conversion, not a tested Safari extension.

Apple's current packaging guide: https://developer.apple.com/documentation/safariservices/packaging-a-web-extension-for-safari

## Local checks

`node --test scripts/targeting-probe/player.test.cjs`

These tests use a simulated DOM and verify stale-target rejection and error reporting; they are not browser compatibility evidence.
