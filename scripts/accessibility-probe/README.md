# Isolated native Accessibility probe

Not linked into PaperMode. Requires existing Accessibility approval for the launching process; does not request or reset permission. Uses AXPress on a single Play/Pause-labelled web button in the browser’s focused/main window, retaining that element for a short two-action cycle. No extension, browser scripting, or global media command.

Build from the repository root:

```sh
mkdir -p .build/accessibility-probe
xcrun swiftc -module-cache-path .build/module-cache native/PaperMode/InputPolicy.swift scripts/accessibility-probe/main.swift -o .build/accessibility-probe/accessibility-probe
.build/accessibility-probe/accessibility-probe --inspect chrome
.build/accessibility-probe/accessibility-probe --cycle safari
.build/accessibility-probe/accessibility-probe --locked-cycle chrome
```

Select the intended player first. `--cycle` attempts one toggle, confirms a changed accessibility label, then attempts to restore the initial state. An unconfirmed action stops without retrying; playback may have changed, so check it manually. Labels are evidence of UI state, not direct video state. English labels only; this heuristic is not a product-grade player selector.

`--locked-cycle` temporarily enables its own event tap and reminder. Immediate emergency exit: Control + Option + Command + L (physical US L position). A ten-second process alarm bounds the lock; ordinary completion releases it. This does not launch or modify PaperMode. Do not run while PaperMode is locked. Inspecting the tree precedes the watchdog and can take longer than ten seconds.

The probe preserves unknown system-defined lifecycle events using the existing InputPolicy. It logs tap status and suppressed event count; zero events does not prove physical input suppression. The investigation version polls labels every approximately 100 ms for up to three seconds per action without retrying the action. This improves diagnostic visibility; it is not a demonstrated fix for earlier failures. Retained element and URL checks do not establish robust identity across navigation, same-URL replacements, tab switches, or player rebuilding. AXPress success alone is not a pass.

See `docs/MILESTONE-7-ACCESSIBILITY.md` for actual outcomes and limitations.
