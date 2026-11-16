# Milestone 7 — explicit targeting experiment

Date: 2026-11-16. Isolated browser probe only; no PaperMode production code, installed app, or native input filtering changed.

## Scope and approval

Owner approved temporarily loading the Chrome test extension and access to `example.invalid`, `app.tpstreams.com`, and `www.youtube.com`. Loaded `scripts/targeting-probe/extension` through Chrome's existing developer-mode UI. Extension ID observed: `mehlloflaimpbjccahjalcdfoafalgca`.

No native bridge, global media command, Apple Events scripting, or browser debugger was used. The extension explicitly binds a video reference in a specific tab/frame. Commands use that reference even from another selected tab. A new document, changed source, disconnected element, or expired binding requires rebinding; there is no global fallback. This probe does not automatically identify the watched course.

## Results

| Case | Evidence | Result |
| --- | --- | --- |
| Chrome / course player embedded TPStreams | Scan returned one video in `https://app.tpstreams.com`, frame 182, 1149×646. Resume returned `ok:true`, `paused:false`, time 5098.410582; pause returned `paused:true`, time 5105.311914. | Direct element control passed for this lesson. |
| Chrome / course player binding while YouTube selected and playing | Popup retained the course's tab/frame. Resume reported `visibleDocument:false`, `paused:false`; subsequent pause reported ended at 5105.666666. YouTube still exposed Pause afterward. | Binding stayed on the intended course. Near-end playback limits this particular contention observation. |
| Chrome / YouTube | Explicitly selected its sole video in frame 0, 1185×667. Pause reported time 60.66772 and `paused:true`; resume reported 60.757333 and `paused:false`; later pause reached 79.314356. | Pause/resume and advancing playback passed. |
| Chrome / YouTube bound, course player selected and playing | Restarted the completed course. With the course selected, the saved YouTube target resumed at 79.403972 and paused at 86.187642; both replies reported `visibleDocument:false`. Course UI still showed Pause and progress 0:00:16. | Explicit background target passed; foreground competitor remained playing. |
| Target tab navigated to about:blank | Old binding's Resume returned `ok:false` and page-access error. | No fallback command issued. |
| Same tab returned to a newly loaded YouTube document | Old binding's Resume returned `ok:false`, `Page changed; bind again. No playback command sent.` | Stale-document rejection passed on a real browser. |
| Initial toolbar/keyboard reload attempts | Old binding remained valid; actual document replacement was not established by UI automation. | Not counted as reload rejection coverage. Confirmed navigation case above supersedes this ambiguous attempt. |
| Safari / course player | No extension packager/converter available; no Xcode found. | Blocked, not tested. |
| Safari / YouTube | Same build-tool prerequisite. | Blocked, not tested. |

Results above are transcribed from the extension's returned state and browser accessibility observations, not raw event logs. No signed embed URLs, credentials, or account data are retained. Five simulated-DOM tests passed: explicit token required, navigation rejection, source-replacement rejection, disconnected-element rejection, rejected play handling. JS syntax and `git diff --check` passed. Simulated tests do not establish browser compatibility.

## Cleanup

Forgot the saved binding, closed the temporary YouTube tab, removed the temporary extension through Chrome, and closed the extension manager tab. Original course and AI Resume tabs remain. The course was restarted for the competitor check and left paused around 0:25; its original pre-test position was near the end (1:24:58). No course content or media file was edited. Existing developer mode was already on and was not changed.

## What remains

- Safari requires a suitable Xcode toolchain and separately reviewed temporary extension packaging/enabling. `xcode-select -p` returned `/Library/Developer/CommandLineTools`; `xcrun --find` failed for both `safari-web-extension-packager` and `safari-web-extension-converter`; no Xcode app was found in `/Applications` or the bundle-ID Spotlight search.
- App-to-extension/native-shortcut delivery during an enabled input lock has not been built or tested. Popup actions alone do not prove that integration.
- Explicit targeting in full screen, three-minute paused resume, permission revocation, browser/profile restarts, duplicate commands, and player replacement on actual sites remain acceptance work.
- Automatic selection of the visible course is not solved by manual binding. Multiple players, full-screen iframe discovery, and navigation policy need design and tests.
- Start with platform-specific compatibility claims. DOM video access worked for the tested TPStreams embed; this is not a guarantee for all DRM players, ads, closed shadow roots, or courses.

Conclusion: Chrome exact-video binding is feasible for these course player/YouTube instances and avoids the demonstrated global-media routing problem. Safari and locked-session integration remain unverified. No product implementation is authorized by these results alone.

Reference: [Apple Safari extension packaging](https://developer.apple.com/documentation/safariservices/packaging-a-web-extension-for-safari), [Chrome scripting targets](https://developer.chrome.com/docs/extensions/reference/api/scripting).
