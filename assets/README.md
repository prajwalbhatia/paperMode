# PaperMode artwork

The app icon combines warm paper, a folded corner, and an amber lock on a dark teal macOS tile. The menu bar uses a simplified monochrome paper/lock silhouette that macOS can tint in light and dark appearances.

- `PaperMode.png`: 1024-pixel transparent PNG used by the welcome/help dialog, native lock/countdown reminder, and development app icon. The native build copies it beside the helper; packaging includes it in Contents/Resources.
- `PaperMode.icns`: multi-resolution icon used by the packaged macOS app.
- `paperTemplate.png` / `paperTemplate@2x.png`: 18/36-pixel menu bar template images.

The vector source is `scripts/build-icons.swift`. Regenerate all assets on macOS with `npm run build:icons`. AppKit renders the artwork locally; `iconutil` builds the ICNS file. Generated iconset intermediates stay in ignored `.build/`. Committed assets allow normal builds without regenerating artwork.
