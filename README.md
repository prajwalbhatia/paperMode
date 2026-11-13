# PaperMode

A macOS menu bar utility for watching courses while taking handwritten notes on a notebook resting over your laptop keyboard.

Milestone 1 provides the Electron menu bar shell and a diagnostic Swift helper. Input blocking and the unlock reminder are planned for later milestones. See [PLAN.md](PLAN.md).

## Development

Requirements: macOS, Node.js 22 (tested with 22.22.2), npm, and a working Xcode or Command Line Tools installation with Swift. The deployment target is macOS 13; currently tested only on this Apple Silicon Mac running macOS 27.2.1.

```sh
npm ci
npm run check:native
npm start
```

A paper icon appears in the menu bar. Choose **Check native helper** to verify the native executable, or **Quit PaperMode** to close the app. No Accessibility permission is requested at this stage.

```sh
npm run check:app
npm run package
```

`check:app` creates the actual menu bar item, checks the native helper, prints the result, and exits. Quit a running development instance before running this check. `package` builds an Apple Silicon app in `out/`; it is a local development artifact, not a signed/notarized public release.

See [docs/SETUP.md](docs/SETUP.md) for build details and troubleshooting.
