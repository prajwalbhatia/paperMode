# Contributing to PaperMode

Use an Apple Silicon Mac with native ARM64 Node 22.13.0 or newer within Node 22 (`.nvmrc` pins the tested version), npm, and working Xcode Command Line Tools with Swift.

```sh
npm ci
npm test
npm run test:native
npm run test:ipc
npm run package
```

Create a branch for a focused change. Explain the behavior changed, checks run, and any untested hardware/browser cases in the pull request. Keep test evidence separate from assumptions; structural package checks do not establish runtime behavior.

For input-lock changes, begin with `npm run start:test`, which has a 30-second development session limit. Packaged apps ignore that flag and have no timeout. Review the recovery and physical-input cases in `docs/MILESTONE-2-QA.md`, `docs/MILESTONE-5-QA.md`, and `docs/MILESTONE-7-QA.md`. Do not silently weaken unlocking, permission checks, or fail-open recovery. Browser Accessibility queries must stay off the event-tap thread and within bounded deadlines.

Report issues with macOS version, chip architecture, PaperMode version, browser/site, reproduction steps, and expected/actual behavior. Remove private URLs, account information, and unrelated screen content from logs or screenshots. Never include signing keys or passwords.

## Issues and community

Use the bug-report or feature-request form from the repository's **Issues → New issue** page. Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems through [SECURITY.md](SECURITY.md), not public issues.

Pull requests use a template for behavior, validation and remaining limits. CI runs JavaScript tests, native policy assertions and ARM64 package verification on macOS 15 with the Node version in `.nvmrc`. CI does not activate an input lock, grant permissions or publish a release. GUI preview/IPC and physical hardware checks remain local; a green build is not proof of runtime compatibility with every Mac or browser.

Use GitHub's noreply email for commits if you want to keep your address private. Do not copy private backup, audit or old PR refs into the public repository.

Contributions are under the project's MIT license. Third-party code must retain its applicable notices.
