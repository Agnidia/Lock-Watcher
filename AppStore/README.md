# App Store listing

The App Store listing for Lock-Watcher, in the layout the
[App Store Connect CLI (`asc`)](https://github.com/rorkai/App-Store-Connect-CLI) reads and writes.
Credentials and the private publishing guide are outside this repo, in
`/Users/korich/Projects/igrsoft/AppStore/` (see its `README.md`).

| Path | Content | Managed with |
|---|---|---|
| `metadata/app-info/<locale>.json` | Name, subtitle, privacy policy URL | `asc metadata` |
| `metadata/version/<version>/<locale>.json` | Description, keywords, promotional text, What's New, support and marketing URLs | `asc metadata` |
| `screenshots/<locale>/APP_DESKTOP/` | Mac screenshots (2880×1800 PNG, no alpha), one set per locale, uploaded in file-name order | `asc screenshots` |
| `screenshots/<locale>/raw/` | Plain window captures the slides are built from; never uploaded | `screenshots/tools/capture.sh` |
| `screenshots/tools/` | Scripts that capture the app and compose the slides | see [Screenshots](#screenshots) |
| `changelog.md` | Release history | by hand |

Locales: `en-US`, `uk`. App ID: `1583462846`. Platform: `MAC_OS`.

## Character limits

| Field | Limit |
|---|---|
| Name, subtitle | 30 |
| Promotional text | 170 |
| Keywords | 100, comma-separated |
| Description, What's New | 4000 |

Run `asc metadata validate --dir AppStore/metadata` after every edit; it checks limits, required fields and URLs.

## Screenshots

Each slide is a real window capture of the app, placed on a branded background with a headline. Build both locale
sets in one pass so they stay identical apart from the language.

### Slides

| # | Raw capture | en-US headline / subline | uk headline / subline |
|---|---|---|---|
| 01 | `menu-popover` | Catch Whoever Touches Your Mac / A photo or short video, taken silently | Побачте, хто чіпав ваш Mac / Фото або коротке відео — тихо й миттєво |
| 02 | `settings-snapshot` | Triggers That Work While Locked / Display, location, keyboard and mouse | Працює, поки Mac заблоковано / Дисплей, переміщення, клавіатура та миша |
| 03 | `settings-options` | Photo or Short Video / Choose quality, size and how long to keep files | Фото або коротке відео / Якість, розмір і термін зберігання — на ваш вибір |
| 04 | `settings-sync` | Straight to Your Own Cloud / iCloud, Dropbox and notifications | Одразу у вашу хмару / iCloud, Dropbox і сповіщення |
| 05 | `settings-options` above `settings-sync` | Set It and Forget It / One toggle per trigger, all in one window | Налаштуйте й забудьте / Один перемикач на тригер, усе в одному вікні |

### Tools

The scripts in `screenshots/tools/` make the whole set. Run them from the repo root:

```
AppStore/screenshots/tools/build.sh         # screenshot-only app build, into $TMPDIR/lockwatcher-shots
AppStore/screenshots/tools/capture.sh       # raw captures, en-US and uk, into screenshots/<locale>/raw/
python3 AppStore/screenshots/tools/compose.py   # slides into screenshots/<locale>/APP_DESKTOP/
rm -rf ~/Library/Containers/com.igrsoft.lockwatcher.shots   # remove the screenshot app's data afterwards
```

| File | Role |
|---|---|
| `build.sh` | Builds the MAS Debug scheme with `PRODUCT_BUNDLE_IDENTIFIER=com.igrsoft.lockwatcher.shots` and `shots.entitlements` (empty), and compiles `wins.swift` |
| `capture.sh` | Seeds demo-safe settings and history, launches each language, opens the popover and Settings, removes the focus ring and captures each window with `screencapture -l <id> -o -x` |
| `compose.py` | Builds the slides from `raw/` to the spec below; edit headlines and slide order in its `SLIDES` table |
| `seed.py` | Writes four synthetic captures (emoji faces, no real person, location or IP) as the app's history file |
| `prefs.py` | Writes the settings shown: all triggers on except battery, input delay 5 s, one Settings section expanded |
| `wins.swift` | Lists the app's on-screen windows with their IDs and bounds |
| `shots.entitlements` | Empty entitlements; the iCloud entitlement does not apply to the screenshot bundle ID, so iCloud is only a stored setting there |

Requirements:

- **Mac unlocked:** keep the Mac unlocked with the display on while `capture.sh` runs. macOS cannot capture a window
  behind the lock screen, so the script stops if the screen is locked.
- **Permissions:** the terminal needs Accessibility and Screen Recording access.
- **Settings domain:** `capture.sh` reads the app's settings domain from `userDefaultsId` in the generated
  `Source/Application/Secrets.swift`.
- **Python:** `compose.py` needs Pillow (`pip3 install pillow`) and uses the system SF Pro font.
- **Locales without a raw capture:** for a locale with no raw captures, add them by hand to
  `screenshots/<locale>/raw/` with the names in the table above, then run `compose.py`.

### Capture notes

- The screenshot app has its own bundle ID, so its sandbox container is separate. The real app's settings and
  capture history are never read or changed.
- The focus ring is removed twice: `NSUseKeyboardFocusRing = NO` in the screenshot app's preferences, and the key
  window's first responder is cleared through `lldb` before each capture. Still check every raw capture for a blue
  ring around the first header or checkbox.
- `capture.sh` clicks the popover's Settings button at a fixed offset (183, 512) pt from the popover's top-left
  corner. Update that offset if the popover layout changes.

### Slide spec

| Element | Spec |
|---|---|
| Canvas | 2880×1800, RGB, no alpha, sRGB profile embedded |
| Background | Navy diagonal gradient from `#1B2233` (top left) to `#0B1019` (bottom right), with a faint warm glow behind the window |
| Flag ribbon | Bottom-left corner, two bands at 45°: blue `#0057B7` between the lines x − y = −1340 and −1490, yellow `#FFD700` between −1490 and −1640 (in pixels from the top-left corner). Drawn under the text and the window |
| Text column | Left edge at x = 170 px, block centred vertically. Yellow accent bar `#FFD60A` 130×14 px with radius 7, then the headline, then the subline |
| Headline | SF Pro Bold, 124 pt (step down to 116 or 108 pt to fit), white, line height 1.19 |
| Subline | SF Pro Regular, 60 pt (56 or 52 pt to fit), `#BEC6D6`, line height 1.4 |
| Text wrapping | At most 3 headline lines and 2 subline lines. No line holds a single word on its own; a dash ends a line and never starts one |
| Window | Right-aligned to x = 2820 px, between y = 50 and 1750 px, up to 1700 px wide, with a soft drop shadow. Enlarge with LANCZOS and no sharpening. Tall windows (popover, Options, the stacked pair) are limited by the height |

### Check before upload

- `sips -g pixelWidth -g pixelHeight -g hasAlpha` on every slide: 2880, 1800, `no`.
- Look at every slide at full size: no focus ring, no clipped UI, no single-word line, the newest strings shown.
- Compare pixels, not file hashes, when you check whether a slide changed: `compose.py` embeds a freshly generated
  sRGB profile, so the file hash changes on every run even when the image is identical. For a dry run, write to a
  temporary folder (`python3 AppStore/screenshots/tools/compose.py "$TMPDIR/slides"`) and compare with
  `PIL.ImageChops.difference`.
- Run the `asc screenshots validate` commands in [Publish a new version](#publish-a-new-version), step 5.

The Settings window is fixed at 420 pt wide (840 px at 2x), so slides 02 and 04 enlarge it about 2x. The text is
slightly soft under close zoom and reads cleanly at App Store size.

## Publish a new version

From the repo root, with `<v>` the marketing version (for example `1.7.0`):

1. Create the version in App Store Connect if it does not exist:
   `asc versions create --app 1583462846 --version <v> --platform MAC_OS`
2. Start the local files from the live listing, then edit them:
   `asc metadata pull --app 1583462846 --version <v> --platform MAC_OS --dir AppStore/metadata`
3. Validate, then review what would change:
   ```
   asc metadata validate --dir AppStore/metadata
   asc metadata plan --app 1583462846 --version <v> --platform MAC_OS --dir AppStore/metadata
   ```
4. Apply after review:
   `asc metadata apply --app 1583462846 --version <v> --platform MAC_OS --dir AppStore/metadata --confirm`
5. Screenshots, when they change. Upload one locale at a time, with `--path` on that locale's `APP_DESKTOP` folder.
   Never fan out over `AppStore/screenshots`: in that mode `asc` needs every folder directly under `--path` to be a
   locale, and it would scan `raw/` too. `tools/` is not a locale, so a fan-out upload fails.
   ```
   asc screenshots validate --path AppStore/screenshots/en-US/APP_DESKTOP --device-type APP_DESKTOP
   asc screenshots validate --path AppStore/screenshots/uk/APP_DESKTOP --device-type APP_DESKTOP
   asc screenshots upload --app 1583462846 --version <v> --platform MAC_OS --locale en-US --path AppStore/screenshots/en-US/APP_DESKTOP --device-type APP_DESKTOP --replace --confirm
   asc screenshots upload --app 1583462846 --version <v> --platform MAC_OS --locale uk --path AppStore/screenshots/uk/APP_DESKTOP --device-type APP_DESKTOP --replace --confirm
   ```
6. Check readiness, attach the build and submit:
   ```
   asc status --app 1583462846
   asc validate --app 1583462846 --version-id <VERSION_ID>
   asc review submit --app 1583462846 --version <v> --build-number <build> --confirm
   ```

The build number on the attached build must match `CURRENT_PROJECT_VERSION` in `Configurations/base.xcconfig`.

## Privacy label

The published label is **Data Not Collected**: captures go only to the user's own iCloud or Dropbox, and
Agnidia receives nothing. `Resources/PrivacyInfo.xcprivacy` declares no collected data types to match. Keep the two
in step; read the live label with `asc web privacy pull --app 1583462846`.
