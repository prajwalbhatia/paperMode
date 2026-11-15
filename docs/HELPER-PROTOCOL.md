# Native helper protocol v1

Electron launches one fresh helper per lock using an argument array, never a shell. `--ipc` is the production mode. Development-only `--ipc-test` adds a thirty-second lock limit; `--ipc-preview` runs the reminder without intercepting input. The app accepts `--bounded-locks` only when unpackaged.

## Framing and correlation

Stdin/stdout carry newline-delimited UTF-8 JSON, capped at 16 KiB per buffered frame. Requests contain integer `protocolVersion: 1`, a nonempty unique `requestID` (up to 128 UTF-8 bytes), and a command. Each process accepts at most 64 request IDs. Invalid framing, version, duplicate IDs, unknown commands, and repeated start commands fail closed. Stderr is drained separately and never interpreted as protocol data.

The helper first emits `ready` with a null request ID and explicit `preview` and `testSession` booleans. This means the connection is ready, not that input is locked. Every subsequent response includes the protocol version and preview mode. Session lifecycle events use the start request ID. Raw keys and pointer events never leave the native process.

## Commands

| Command | Response / behavior |
| --- | --- |
| `status` | Correlated `status` with permission, current input-source ID, and unlock-layout support. |
| `request-permission` | Before a session only: asks macOS for Accessibility and returns correlated `status`. |
| `start` | One per process: `starting` with five-second delay, then `locked` only after reminder and input tap setup. Preview mode emits `preview` instead. Startup failures emit `error`. |
| `shutdown` | Releases resources and emits `unlocked` (`app-quit`) associated with the active start ID, or null if no start occurred, then exits. |

Normal ending emits `unlocked` with a reason and elapsed session milliseconds, then exits. Permission denial, unsupported layout, and event-tap creation failures can emit an error and exit without a locked event. Stdin EOF ends the session with `connection-lost`; parent exit, sleep, permission/layout changes, and event-tap failures also release input. The delayed start checks cancellation before beginning.

## JavaScript lifecycle

`SessionController` owns checking, ready, permission-required, starting, locked, and error states. It uses fresh one-shot `--diagnose` / `--request-permission` processes for idle checks and permission requests, avoiding stale permission state across sessions. `HelperSession` owns the stdio transport. The app refuses duplicate starts while preflight or a helper is active, validates the handshake and event order, and waits for process close before allowing another session. Old async results cannot overwrite a newer session or start a helper after quit/sleep.

Handshake/startup must complete within twelve seconds (including the native five-second preparation). After a protocol failure or shutdown, JavaScript closes stdin and requests shutdown, then sends SIGKILL after one second if necessary. An unlocked helper that does not exit is also stopped. Electron waits for cleanup on quit, with a 2.5-second outer exit deadline; native EOF/parent-exit handling remains independent. These are startup/cleanup limits, not normal lock-session timers.

Control + Option + Command + P starts from Electron. The native two-second L chord remains the normal unlock path. Separate start/unlock keys avoid reactivation while releasing the unlock chord. Sleep or session deactivation never automatically relocks the app.
