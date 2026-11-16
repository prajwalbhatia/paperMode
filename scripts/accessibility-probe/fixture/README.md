# Controlled local playback fixture

This is a diagnostic page, not a PaperMode component. Run from the repository root:

```sh
mkdir -p .build/accessibility-probe
python3 scripts/accessibility-probe/fixture/server.py
```

Open the printed loopback URL in Chrome. Add `?mode=normal&run=unique-name`, `?mode=delayed-label&run=unique-name`, or `?mode=noop&run=unique-name`. Use a unique run name for each new document. Run the existing native probe with `--cycle chrome` or `--locked-cycle chrome`. Close the fixture tab and stop the server with Ctrl+C afterward.

The muted video receives locally generated canvas frames; no media downloads, camera/microphone, extension, or browser scripting permission is needed. Its own JavaScript records click delivery, actual video.paused/currentTime, media events, and button labels to `.build/accessibility-probe/fixture-events.jsonl` through a loopback POST. It never reads other pages. Normal mode toggles and updates the label; delayed-label mode toggles but schedules the label update after 4.5 seconds; noop mode receives the click but deliberately does nothing.

The native probe's confirmation window is three seconds. A delayed-label result is intentionally unconfirmed even when playback succeeds. Do not retry the toggle blindly. Navigate away/close the test tab to stop playback after this case. Requests can arrive out of event order; use event contents and playback time rather than treating server receipt ordering as exact browser event ordering.

This synthetic stream does not simulate DRM, iframe boundaries, buffering, network errors, or course-player internals. It distinguishes diagnostic failure categories; it cannot establish the cause of a third-party player's failure.
