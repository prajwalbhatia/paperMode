# PaperMode website

Static HTML/CSS, hosted by GitHub Pages at https://prajwalbhatia.github.io/paperMode/.

Edit `index.html`, `style.css`, or the assets here. The Pages workflow deploys only this directory after changes land on main. No build dependencies, app permissions, or ChatGPT login are required.

Download buttons target the explicit preview release asset (GitHub's latest-release redirect excludes prereleases). Update both buttons and version copy for future releases.

The hero is an AI-generated 3D illustration with a transparent background. The countdown and reminder images are renders of PaperMode's actual native ReminderCard interface, not generated UI or desktop screenshots. The product demo remains deferred. Fonts load from Google Fonts with local fallbacks.

To refresh the app images after changing `ReminderCard`, compile `scripts/render-website-cards.swift` with `native/PaperMode/Reminder.swift`, place `assets/PaperMode.png` beside the executable for the app icon, then run it with `website/assets` as its output directory. Update the versioned image filenames in `index.html` when publishing the new images so visitors do not see a cached older card.
