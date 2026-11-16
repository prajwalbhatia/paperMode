# PaperMode

A macOS menu bar utility for watching courses while taking handwritten notes on a notebook resting over your laptop keyboard.

The Electron menu bar app and native input lock have passed core development-Mac QA. Experimental native play/pause is implemented; its integrated physical-shortcut and packaged runtime checks remain before release. See [packaged QA](docs/MILESTONE-5-QA.md), [UX QA](docs/MILESTONE-4-QA.md), [app QA results](docs/MILESTONE-3-QA.md), [native QA results](docs/MILESTONE-2-QA.md), and [PLAN.md](PLAN.md).

## Development

Requirements: macOS, Node.js 22.13.0 or newer within Node 22 (tested and pinned in `.nvmrc` to 22.22.2), npm, and a working Xcode or Command Line Tools installation with Swift. The deployment target is macOS 13; currently tested only on this Apple Silicon Mac running macOS 27.2.1.

```sh
npm ci
npm run check:native
npm start
```

A paper icon appears in the menu bar. On the first normal launch, a guide explains permission, starting, and deliberate unlocking. Dismiss it with Got it or Not now; reopen it anytime using How to use PaperMode. Use **Enable Accessibility…** to request permission for the identity macOS shows, then **Check permission and layout**. The app also refreshes permission while idle. Press **Control + Option + Command + P** or choose **Start PaperMode** to start, with five seconds to position your notebook. Hold **Control + Option + Command + L** for two seconds to unlock. Normal sessions have no automatic timeout. The menu shows the current state and any errors; the menu start action also works if another app owns the start shortcut. The guide never starts a lock. Pressing the start shortcut while it is open highlights a reminder to close the guide and press the shortcut again.

The welcome acknowledgement is stored locally in the app’s user-data directory; no lock state or keystrokes are saved.

For first app-level QA, use `npm run start:test` instead: sessions have a thirty-second development safety limit. This mode skips the automatic welcome; use How to use PaperMode to inspect it. Quit the running instance before changing modes. Permission granted to VS Code may not cover Electron or a packaged app; follow the identity in the macOS prompt.

```sh
npm run check:app
npm run package
npm run check:package
```

`check:app` creates the actual menu bar item, registers the start shortcut, checks the native helper and permission state, prints the result, and exits without locking input. Quit a running development instance before running this check. `package` requires native ARM64 Node.js on macOS, verifies the helper architecture, and builds an Apple Silicon app in `out/`; it is a local development artifact, not a signed/notarized public release.

See [docs/SETUP.md](docs/SETUP.md) for build details and troubleshooting.

Packaging automatically verifies the bundle identity, ARM64 binaries, artwork, and current application sources. `check:package` repeats those structural checks without launching or locking. Installation, permission identity, and recovery from the actual packaged app still require the [milestone 5 acceptance sequence](docs/MILESTONE-5-QA.md).

## Play/pause while locked (experimental)

Start PaperMode with the intended course selected in the foreground Chrome or Safari window. When the reminder offers it, press **Control + Option + Command + Space** once to request play/pause. Keep the existing two-second L chord for unlocking. Requests never temporarily disable the input filter, and held Space does not repeat toggles.

This uses a unique English-labelled native Accessibility player control and retains it for the session. Unsupported/ambiguous controls, changed windows/documents/buttons, or another foreground app cause refusal. There is no extension and no global media fallback. “Playback requested” means the browser accepted the action, **not** that playback was confirmed. If the video does not respond, unlock and control it normally; do not blindly repeat a toggle. Replaced controls require starting a new session.

The feature still needs packaged-app and physical-shortcut acceptance before a public release. See [milestone 7 QA](docs/MILESTONE-7-QA.md).
