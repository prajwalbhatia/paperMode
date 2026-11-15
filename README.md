# PaperMode

A macOS menu bar utility for watching courses while taking handwritten notes on a notebook resting over your laptop keyboard.

The native input lock and reminder now connect to the Electron menu bar app. Milestone 3 integration is implemented and has automated coverage; real Electron lock/permission QA is still pending. See [app QA instructions](docs/MILESTONE-3-QA.md), [native QA results](docs/MILESTONE-2-QA.md), and [PLAN.md](PLAN.md).

## Development

Requirements: macOS, Node.js 22.13.0 or newer within Node 22 (tested and pinned in `.nvmrc` to 22.22.2), npm, and a working Xcode or Command Line Tools installation with Swift. The deployment target is macOS 13; currently tested only on this Apple Silicon Mac running macOS 27.2.1.

```sh
npm ci
npm run check:native
npm start
```

A paper icon appears in the menu bar. Use **Enable Accessibility…** to request permission for the identity macOS shows, then **Check permission and layout**. The app also refreshes permission while idle. Press **Control + Option + Command + P** to start, with five seconds to position your notebook. Hold **Control + Option + Command + L** for two seconds to unlock. Normal sessions have no automatic timeout. The menu shows the current state and any errors; starting a lock uses the shortcut only.

For first app-level QA, use `npm run start:test` instead: sessions have a thirty-second development safety limit. Quit the running instance before changing modes. Permission granted to VS Code may not cover Electron or a packaged app; follow the identity in the macOS prompt.

```sh
npm run check:app
npm run package
```

`check:app` creates the actual menu bar item, registers the start shortcut, checks the native helper and permission state, prints the result, and exits without locking input. Quit a running development instance before running this check. `package` requires native ARM64 Node.js on macOS, verifies the helper architecture, and builds an Apple Silicon app in `out/`; it is a local development artifact, not a signed/notarized public release.

See [docs/SETUP.md](docs/SETUP.md) for build details and troubleshooting.
