# Isolated playback feasibility probe

Development only. Not linked into PaperMode or bundled by Forge. Run from the repository root with PaperMode **unlocked**. Uses existing Accessibility authorization; never grants permission itself.

```sh
mkdir -p .build/playback-probe .build/playback-web
xcrun swiftc -module-cache-path .build/module-cache native/PaperMode/InputPolicy.swift scripts/playback-probe/main.swift -o .build/playback-probe/playback-probe
cp scripts/playback-probe/index.html scripts/playback-probe/server.py .build/playback-web/
# Copy a short local MP4 you may use into .build/playback-web/sample.mp4.
python3 .build/playback-web/server.py
```

Open `http://127.0.0.1:8769/?id=chrome` in Chrome and `http://127.0.0.1:8769/?id=safari` in Safari. Start playback with the player controls. The localhost-only server records Media Session actions and video state in `.build/playback-web/events.jsonl`; it serves only that disposable directory. Stop with Ctrl+C after testing and close the fixture tabs.

In another terminal:

```sh
.build/playback-probe/playback-probe --toggle
.build/playback-probe/playback-probe --lock-probe
.build/playback-probe/playback-probe --lock-probe-forward
```

Run one command at a time. `--toggle` posts a system play/pause command; it does not know which app will receive it or whether playback changed. Confirm against the browser log, not the dispatch log.

Both lock probes block keyboard/pointer input for ten seconds. A process alarm terminates the utility after fifteen seconds if its main loop stalls. Emergency exit is **Control + Option + Command + physical L (US key position)**, immediately, without a hold. This differs deliberately from PaperMode's two-second unlock. The probe is not suitable for unattended use or production.

At two seconds both modes send an ordinary HID media command as a negative control. At four and six seconds:

- `--lock-probe` posts at the annotated-session location downstream of its tap.
- `--lock-probe-forward` posts a randomly tagged HID down/up pair and permits at most two matching play/pause events through its callback per dispatch. The tap remains enabled. This experiment is not a security boundary; production authorization/validation is still to be designed.

Reports contain event counts, tap status, and frontmost bundle ID when available; no typed text is recorded. The fixture records only its own playback metadata. Physical input suppression, layout-specific emergency escape, full-screen behavior, and production recovery require separate tests.

See `docs/MILESTONE-7-FEASIBILITY.md` for results and unresolved acceptance gates. Do not run a lock probe while PaperMode or another input-locking tool is active.
