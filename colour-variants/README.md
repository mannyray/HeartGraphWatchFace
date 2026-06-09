# colour-variants

Generates a simulator screenshot for every combination of the three "look"
settings (BackgroundColor × GraphNumberColor × TimeColor = 12 images) on top
of the synthetic test-ramp HR data, so a glance at `output/` shows the
full visual matrix for QA, palette tweaks, or store-page comparison shots.

Output filenames are the shareable settings code for each combination
(`v1.0-01480-D.png` etc.) so you can paste a code into the watch's Preset
"+ Enter code" picker to load the exact look on a real device.

## Prereqs

- macOS — uses `screencapture -l <windowID>` and AppleScript to drive the sim
- Terminal has **Screen Recording** permission (System Settings → Privacy &
  Security → Screen Recording → Terminal/iTerm)
- Terminal has **Accessibility** permission (same place → Accessibility) —
  needed for AppleScript to click sim menu items
- Pillow: `pip3 install Pillow`
- The Connect IQ simulator **freshly launched**, with no device loaded
  (i.e. just the empty sim window). The script will auto-load fr955.

## Run

```bash
python3 generate.py            # all 12 scenarios
python3 generate.py 01490      # only scenarios whose code matches '01490'
```

Each scenario takes ~25-30 s (Delete All Apps → build → deploy →
20 s render wait → screenshot → crop). Full run is ~6 minutes.

## How it works

For each scenario:

1. **Restore + patch `resources/settings/properties.xml`** with the
   scenario's overrides (3 color properties + `TestMode=true`). Backup at
   `properties.xml.backup`.
2. **Build** via `./build.sh fr955`.
3. **Kill running app + Delete All Apps** in the sim via AppleScript menu
   clicks — this is the critical step (see Gotchas).
4. **`monkeydo`** deploys the fresh .prg; sim performs a clean install
   that re-reads `properties.xml` defaults.
5. **Wait 20 s** for the GARMIN splash to clear and the watch face to
   render its first frame.
6. **`screencapture -l <windowID>`** of the sim's main window.
7. **Crop** to the round watch face using a hardcoded bbox per device
   (`WATCH_FACE_CROP` in `generate.py`).
8. **Save** as `output/<settings-code>.png`. Raw uncropped screenshot
   kept alongside as `<code>.raw.png` for debugging.

On exit `properties.xml` is restored from backup. The script self-recovers
from crashes by restoring on next start if a backup exists.

## Gotchas (in priority order — read these before changing the script)

### 1. `Reset All App Data` does NOT clear `Application.Properties`

Only `Storage` is cleared. The user-tunable properties
(`BackgroundColor` etc.) survive across redeploys, which means setting a
new default in `properties.xml` has no effect until the app is fully
uninstalled. **Use `Delete All Apps` instead** — the next `monkeydo` then
performs a fresh install and reads `properties.xml` defaults.

### 2. The sim can get into a "stuck on splash" state that no menu action recovers

If `monkeydo` is `terminate()`d mid-deploy, or a watch face crashes
during init, the sim may end up displaying just the blue GARMIN triangle
for all subsequent deploys — no app loads, no `monkeydo` output. **Fix:
fully quit and relaunch the sim app** (Cmd+Q → re-open ConnectIQ.app).
The window ID changes when you do this, which is a useful health check:

```bash
swift find_window.swift   # before and after relaunch should differ
```

### 3. 20-second post-deploy wait is non-negotiable

The fresh-install path (Delete All Apps → install → first `onLayout` →
first `onUpdate`) takes much longer than a hot reload. 8 s catches the
splash. 20 s is empirical headroom. If you see splash screens in
`output/`, the watch face hasn't finished its first paint yet — bump
the sleep in `deploy()`.

### 4. Window ID must be the main face window, not a sub-window

`find_window.swift` prefers the window whose title starts with
"CIQ Simulator" (e.g. "CIQ Simulator - Forerunner® 955 / Solar (5.2.0)")
over largest-by-area. Sub-windows (Watchface Diagnostics, Persistence
Editor) can otherwise win the largest-area tiebreaker and the
screenshot will be of the wrong panel.

### 5. Crop bbox is per-device and pixel-perfect

`WATCH_FACE_CROP["fr955"] = (126, 351, 666, 891)` was probed by
inspecting black/white transitions in the raw 792×1208 retina capture.
If you add a new device, eyeball the `.raw.png` and adjust. The cropped
output is a 540×540 RGB PNG that includes the bezel ring for context.

### 6. The settings code in the filename uses `DEFAULTS` in `generate.py`, not properties.xml

The encoder reads the settings being VARIED from the scenario dict, but
the un-varied fields (HRMin/HRMax/HRStep/PaletteIndex etc.) come from
`DEFAULTS` at the top of `generate.py`. If you change defaults in
`properties.xml` without updating `DEFAULTS`, the filename code won't
round-trip correctly on a real watch. Keep them in sync.

## Files

- `generate.py` — the pipeline (build → deploy → capture → crop)
- `settings_code.py` — pure-Python mirror of `source/SettingsCode.mc`'s
  encoder, used only for naming files
- `find_window.swift` — Quartz `CGWindowListCopyWindowInfo` helper
- `output/` — generated PNGs (gitignored)
- `logs/` — per-scenario `monkeydo` stdout/stderr (gitignored, mostly
  empty since `monkeydo` is quiet but useful for diagnosing failures)
- `properties.xml.backup` — created during a run, deleted on clean exit

## Adding a new scenario dimension

To also vary, say, `PaletteIndex`:

1. Add it to `build_scenarios()` in `generate.py` — nest another loop or
   compute a Cartesian product.
2. Include the property name in the `write_props` overrides dict.
3. Move it OUT of `DEFAULTS` (so it doesn't double-feed the encoder).
4. Reconsider total run count: 12 × N palettes × 25-30 s each = `N × 6 min`.
