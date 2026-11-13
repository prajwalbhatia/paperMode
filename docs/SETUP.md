# Local setup

Use Node.js >=22.13.0 and <23, matching Forge’s minimum requirement. `.nvmrc` pins the tested version 22.22.2. Dependencies are pinned in `package.json` and `package-lock.json`. Use `npm ci` for subsequent clean installs.

Verify the native tools with `xcrun swift --version` and `xcrun --show-sdk-path`. PaperMode invokes the selected toolchain through `xcrun`; it does not replace developer tools or change the system's selected developer directory.

The native build uses `.build/module-cache` explicitly. During initial investigation the compiler's default cache path was not writable, and Swift also reported a misleading SDK/compiler mismatch. A local AppKit probe compiled and ran when given a writable module cache. The project build preserves that setting.

Generated native executables and npm caches are under `.build/` and ignored by Git. The development launch scripts set `electron_config_cache=.build/electron-cache` to keep Electron runtime downloads local as well. Electron may download its runtime on the first launch.

## Commands

- `npm run build:native`: compile the diagnostic Swift helper for the host architecture, targeting macOS 13.
- `npm run check:native`: build, execute, and validate the helper's JSON response.
- `npm start`: build the helper and launch the development menu bar app.
- `npm run check:app`: create a menu bar item, execute the helper, report the result, then quit.
- `npm run package`: require native ARM64 Node on macOS, rebuild and inspect the helper architecture, then assemble an Apple Silicon development app. x64 Node under Rosetta is rejected before any build starts.
- `npm test`: run packaging architecture guard regression tests.

The native helper now also supports explicit permission, preview, and lock commands. See `docs/MILESTONE-2-QA.md` before running a lock test. The diagnostic command never intercepts input. The JavaScript process executes the helper with an argument array and a five-second diagnostic timeout. This timeout is for the setup check, not a PaperMode session timer.

Public signing, notarization, Intel packaging, older macOS validation, and packaged lock validation are later milestones. A project license has not yet been selected.

## Milestone 1 verification — 2026-11-14

- Node 22.22.2 and npm 10.9.7.
- Electron 45.3.2 and Electron Forge 8.0.1 installed; npm audit reported zero vulnerabilities at setup time.
- Swift 6.1 compiled the AppKit probe and the diagnostic helper with the project-local module cache.
- `npm run check:native` passed on Apple Silicon / macOS 27.2.1.
- `npm run check:app` passed: `menuBarCreated: true`, helper protocol version 1, input locking unimplemented.
- GUI launch inside the restricted automation shell aborted; running the same smoke check with native desktop access succeeded.
- Electron's downloader stalled in this environment. The official v45.3.2 Darwin ARM64 ZIP was downloaded directly and verified against the SHA-256 shipped in Electron's npm package before extraction. Normal development startup attempts the standard download automatically if the runtime is missing.
- Packager configuration is scaffolded; packaged-app behavior will be verified in milestone 5.
