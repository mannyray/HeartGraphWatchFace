# CLAUDE.md

Build/dev reference for the HeartGraphWatchFace Connect IQ project. End-user install docs are in README.md.

## Supported devices

`manifest.xml` targets 16 Garmin watches sharing the same display tech: **round, MIP-display (reflective, not AMOLED), 8 bits/pixel (64-color palette), Connect IQ ≥ 4.2, watchFace memory ≥ 128KB.** Models span four resolution classes: 218×218 (FR 255S / 255S Music), 240×240 (Fenix 7S / 7S Pro), 260×260 (FR 255 / 255M / 955, Fenix 7 / 7 Pro / Pro Solar / Pro no-WiFi, Fenix 8 Solar 47mm), and 280×280 (Enduro 3, Fenix 7X / 7X Pro / 7X Pro no-WiFi / Enduro 2 / Tactix 7, Fenix 8 Solar 51mm).

Why those criteria: layout Y coordinates in `HeartGraphWatchFaceView.mc::onLayout` are ratios against a 260px reference, so any round screen between 218 and 280 px adapts automatically. **MIP** is required because the perimeter HR ring redraws every tick — wasteful on AMOLED's always-on power model, and the design assumes black-background = neutral (whereas AMOLED makes black = power saving and bright = power cost). **8bpp** is the lowest depth that renders the 64-color palette without dithering — fewer levels would visibly shift colors. **Square or rectangular** displays would break the perimeter ring (`drawCircle(width/2, height/2, width/2)` draws a circle inscribed in the rect, leaving corners untouched). Adding more devices in the future = update the products list in `manifest.xml` after re-running the filter against the SDK's `Devices/` directory.

On the smallest screens (218×218), a 10-minute graph (201 px wide) just barely fits and looks cramped; 3- and 5-minute durations render comfortably.

## Toolchain locations

- SDK: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/`
- Dev key: `~/Library/Application Support/Garmin/ConnectIQ/developer_key.der`
- Device specs: `~/Library/Application Support/Garmin/ConnectIQ/Devices/<deviceId>/compiler.json`

## Build

```bash
./build.sh                    # builds both fr955 + enduro3 (.prg per device)
./build.sh fr955              # single device .prg
./build.sh --export           # bin/HeartGraphWatchFace.iq for the PRODUCTION store listing
./build.sh --export-with-test # bin/HeartGraphWatchFace.iq for the BETA store listing (sideload)
```

`build.sh` runs `gen-palettes.py` (regenerates `source/PalettesGenerated.mc` from `palettes.json` if needed) and `gen-shipped.py` (regenerates `source/ShippedPresetsGenerated.mc`), then invokes `monkeyc`. Each build also emits `bin/HeartGraphWatchFace-<device>-settings.json` (used by the simulator's settings editor, ignored on real watches).

### Production vs beta app IDs

Garmin's policy: a beta-uploaded app ID can never be promoted to production. So we use two store listings + two IDs, both held as constants at the top of `build.sh`:
- `PROD_APP_ID` — the production store listing's ID. It's also what's checked into `manifest.xml` so casual `./build.sh fr955` and `./build.sh --export` builds use it by default.
- `DEV_APP_ID` — the beta store listing's ID. `--export-with-test` swaps `manifest.xml` to this ID for the duration of the build, with a `trap … EXIT` clause that restores `PROD_APP_ID` on success OR failure so the working tree never lingers with the dev ID. Beta sideloads (with all `:dev_only` test affordances intact) live under this ID; production exports live under the other.

Neither ID is a secret — they're the equivalent of an iOS bundle identifier and end up embedded in every installed binary. The developer key (`developer_key.der`) IS the secret; it's what signs the build.

To bypass the wrapper:
```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
python3 gen-palettes.py  # required if palettes.json changed
"$SDK/bin/monkeyc" -d fr955 -f monkey.jungle -o bin/HeartGraphWatchFace-fr955.prg -y "$KEY" -w
```

## Palettes

Heart-rate gradient colors are defined in `palettes/palettes.json`. Edit via `palettes/palette-editor.html` — open in a browser, pick from the 64-color watch palette, download the result back to `palettes/palettes.json`. `palettes/gen-palettes.py` converts it to `source/PalettesGenerated.mc` (a `getPalettes()` function returning the palettes array, gitignored). The on-device **Customize → Settings → Colours → Palette** menu lets you pick which palette is active. HR range (Min/Step/Max) is a separate setting from palette selection.

## QC test suite

`qc/` contains a Python harness that drives the simulator through a list of property combinations (`qc/scenarios.json`), captures one screenshot per scenario via `screencapture -l <windowID>` (window ID found by `qc/find_window.swift` via Quartz `CGWindowListCopyWindowInfo`), and emits `qc/index.html` for visual review. See `qc/README.md` for prereqs (Screen Recording permission, simulator running, persisted state cleared). The harness modifies `resources/settings/properties.xml` per build to bake in scenario defaults, then restores the original — a backup at `qc/properties.xml.backup` serves as crash recovery.

### Current status (parked 2026-06-04)

Working: the script runs end-to-end, produces screenshots for most scenarios, generates the HTML index, and survives crashes (recovery restores `properties.xml` from backup).

**Known issue — some screenshots come out blank.** Likely causes, in rough order of likelihood:

1. **Race between `monkeydo` deploy and `screencapture`.** The harness sleeps 3 seconds after deploying before capturing, but the sim's transition between apps (kill old, load new, run `onLayout`, first `onUpdate`) can take longer for some scenarios — especially when changing device target. The screenshot then catches a transitional "loading" or blank state. Fix to try: bump the sleep, or poll the sim somehow (e.g. by inspecting pixel content via Quartz before deciding the frame is rendered).
2. **Persisted property state still bleeding through.** If `Application.Properties` from the previous scenario weren't cleared, the new build's defaults are ignored. The README mentions clearing persisted content manually as a prereq, but it's easy to forget. Future fix: drive the sim's *File → Reset All App Data* menu via AppleScript between scenarios (`osascript -e 'tell process "Connect IQ Device Simulator" to click menu item ...'`) — menu click works but the resulting confirmation dialog needs to be dismissed too.
3. **`monkeydo` background process leaks.** Each scenario starts a new `monkeydo` subprocess; the previous one is `terminate()`d. If the prev sub-process is still mid-deploy when terminated, the sim can end up in an undefined state. Maybe use `wait()` with timeout instead of `terminate()`.
4. **Sim window briefly loses focus or is obscured** during deploy — `screencapture -l` works across Spaces but maybe not when the target window is mid-redraw. Hard to verify without instrumentation.

### Where to pick up

- First low-effort attempt: increase the post-deploy sleep from 3s → 6s and re-run. Cheap test of hypothesis #1.
- Higher-effort but more correct: write a pixel-checking helper that takes a small region screenshot before the real capture and verifies it has non-black, non-uniform content — if not, sleep more and retry. Caps blank-output failures.
- Hypothesis #2 fix (auto-reset between scenarios) is medium effort — the AppleScript menu navigation works but the confirmation dialog handling is fragile.

## Colour-variants screenshot harness

`colour-variants/` is a smaller, more focused sibling of `qc/` that generates one sim screenshot per combination of the three "look" properties (BackgroundColor × GraphNumberColor × TimeColor = 12 images) on top of `TestMode=true` synthetic ramp data. Each PNG is named after its shareable settings code so the file maps 1:1 to a code you can paste into a real watch. See `colour-variants/README.md` for the full pipeline and gotchas.

Two findings from this harness that matter project-wide (and aren't yet reflected in the `qc/` notes above):

- **`Reset All App Data` in the sim does NOT clear `Application.Properties`** — only Storage. Properties set in a previous sim session bleed across redeploys, so `properties.xml` default changes are silently masked. Use `File → Delete All Apps` for a true fresh install. This was likely a contributor to the qc/ "blank screenshots" issue too — scenarios were getting stale property values rather than the baked-in defaults.
- **The sim can get stuck on the GARMIN splash** if `monkeydo` was killed mid-deploy or a watch face crashed during init. No menu action (`Kill App`, `Reset Simulator`, etc.) reliably recovers it — full quit + relaunch of `ConnectIQ.app` is the only fix. The `find_window.swift` window ID changing is a good health check that a relaunch actually happened.

## Shareable settings codes

Compact ASCII string encoding all user-tunable settings. Shareable in store descriptions, social posts, screenshots — a recipient types the code into the watch via Customize → Settings → Presets → "+ Enter code" and saves it as a named preset to apply.

**Format:** `v1.0-XXXXX-Y` (12 chars)
- `v1.0-` versioned prefix.
- 5 chars Crockford Base32 (case-insensitive; `I`/`L` map to `1`, `O` maps to `0`) = 25 bits of packed settings.
- `-Y` 1-char checksum (mod-32 sum of payload chars) — catches single typos before applying garbage.

**Bit layout (LSB = bit 0):**

| Bits | Field | Encoding |
|---|---|---|
| 0 | `ShowGraphAxis` | `0=on, 1=off` — inverted so v1 codes from before this field existed (with bit 0 always 0) still decode to the "axis on" default |
| 1-2 | `BackgroundColor` | 0=black, 1=white |
| 3-4 | `TimeColor` | 0=default (`-2`), 1=gray (`0x555555`) |
| 5-6 | `GraphNumberColor` | 0=default (`-2`), 1=hidden (`-3`), 2=gray (`0xAAAAAA`) |
| 7-9 | `HRMin` | 0=30, 1=35, … 7=65 |
| 10-14 | `HRMax` | Encoded as `(HRMax - HRMin - 20) / 10` so the +20-from-Min constraint holds by construction; decoded HRMax is always ≥ HRMin+20 |
| 15-16 | `HRStep` | 0=5, 1=10, 2=15, 3=20 |
| 17-20 | `PaletteIndex` | 0..15 (cap of 16 palettes for v1) |
| 21 | `GraphBandPixels` | 0=10, 1=20 |
| 22-23 | `HeartGraphMinutes` | 0=3, 1=5, 2=10 |
| 24 | `MinimalMode` | bool |

**Files:**
- `source/SettingsCode.mc` — `encodeSettings(values) -> String`, `decodeSettings(code) -> Dictionary or Null`, plus Base32 helpers. Pure functions, no UI.
- `source/SettingsView.mc` — `PresetsMenu` shows each preset's code as its sub-label; the `EnterCodeTextDelegate` runs TextPicker → decode → name picker → `savePresetWithNameAndValues`. `PresetActionsMenu` has Apply / Update / Delete (Update overwrites the preset with current watch settings via the existing upsert path).

**Adding a new setting that should be part of codes:**
1. Add the property as usual (`properties.xml`, `presetKeys()`, `getDefaultPresetValues()`).
2. Find an unused bit range in the layout above (the v1 layout now fills all 25 bits). If you need to add a new field, you're past the v1 budget — bump to v2.0, change the prefix to `v2.0-`, and redesign the layout. Have the v1 decoder still match on its prefix so older watches reject v2 codes cleanly instead of mis-decoding.
3. Add an `_encX` / `_decX` pair in `SettingsCode.mc` and update `encodeSettings` / `decodeSettings`.
4. Recipients running an older watch face version won't understand the new bits — the version prefix exists so they get a clean "Invalid code" rejection instead of silently mis-decoding.

**Known v1 limitations (parked for v2):**
- **Custom palettes don't travel with the code.** PaletteIndex refers to the recipient's `palettes/palettes.json` index. If sender and recipient have different palette lists at the same index, the recipient sees their own palette. Mitigation: ship a curated, stable built-in palette set; users sharing custom palettes will need a separate "+ Palette code" flow (v2).
- **PaletteIndex > 15** can't be encoded (cap is 4 bits). The encoder clamps silently. If we ever ship more than 16 built-ins, bit count needs to expand.
- **Display width on smallest screens (218×218).** 12-char sub-label fits comfortably; v2 inline-palette codes would balloon to ~23 chars and would need a separate "Show code" action.

## Run in simulator

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"

open -a "$SDK/bin/ConnectIQ.app"   # launch sim if not running
"$SDK/bin/monkeydo" bin/HeartGraphWatchFace-enduro3.prg enduro3
```

`monkeydo`'s syntax is positional: `monkeydo <prg> <deviceId> [-a <src>:<dest> ...]`. Long flags like `--device` and `--file` confuse the wrapper script — always use positional form.

## Install on watch

See README.md (`How To Install` section). TL;DR: plug watch via USB, copy the matching `bin/HeartGraphWatchFace-<device>.prg` to `GARMIN/Apps/`, eject, unplug, switch face on watch.

## Settings

Defaults live in `resources/settings/properties.xml`. Strings in `resources/strings/strings.xml`. All user-tunable properties (see `Presets.mc::presetKeys()` for the canonical list):

| Property | Type | Meaning |
|---|---|---|
| `HeartGraphMinutes` | Number | Graph time window: 3 / 5 / 10 |
| `GraphBandPixels` | Number | Pixels per palette band: 10 (normal) or 20 (double). Bar height scales as `(hr-hrMin) * bandPixels / hrStep`. |
| `BackgroundColor` | Number | `0x000000` or `0xFFFFFF` |
| `GraphNumberColor` | Number | `-2` = auto/foreground, `-3` = hidden/matches background, else literal RGB |
| `TimeColor` | Number | Applies to both time AND date. Same sentinels as above. |
| `PaletteIndex` | Number | Index into `getPalettes()` result |
| `HRMin`, `HRStep`, `HRMax` | Number | Color-bucket sizing. `HRMax` no longer caps bar height — bars grow past it into the time/date chrome by design (those elements render after `drawGraph` so they sit on top). Decoupled from the graph's visual band size (see `GraphBandPixels`). |
| `MinimalMode` | Boolean | Hides time/date/battery/alarm chrome |
| `TestMode` | Boolean | When true (debug builds only), the live HR buffer is replaced by a synthetic curve and the displayed clock locks to 13:37. Scenario picked by `TestScenarioIndex`. |
| `TestScenarioIndex` | Number | Index into `getTestScenarioNames()` selecting which synthetic curve to play. 0=Ramp, 1=Anxious Rest, 2=Active Burst, 3=Steady Calm. Defined in `source/TestScenarios.mc` (`(:dev_only)` — see jungle-layering note below). |

**Reading values in code:** `Application.Properties.getValue("KeyName")`. The older `getApp().getProperty(...)` is deprecated.

**Sentinel values for color settings:** several color properties use negative ints as sentinels (`-1` is `COLOR_TRANSPARENT`; we use `-2` for auto-contrast/foreground and `-3` for hidden/background). When extending, keep sentinels negative to avoid collision with the 24-bit RGB color space.

## On-device customization

All on-device customization lives in `source/SettingsView.mc`. The Garmin `Menu2` + `MenuItem` pattern is used throughout.

**Top-level hierarchy** (`Customize → Settings`):

```
Presets                  → PresetsMenu
    <preset row>         → PresetActionsMenu     (Apply / View code / Update / Rename / Delete)
    + Save current       → TextPicker → SavePresetTextDelegate
    + Enter code         → TextPicker → EnterCodeTextDelegate → name TextPicker → save
Colours                  → ColoursMenu
    Background           → BackgroundColorMenu
    Numbers              → GraphNumberColorMenu   (graph axis labels)
    Time & Date          → TimeColorMenu           (shared between drawTime + drawDate)
    Palette              → PaletteMenu             (the HR gradient)
Graph                    → GraphMenu
    Duration             → GraphDurationMenu       (3 / 5 / 10 min window)
    Bar Height           → GraphSizeMenu           (Normal=10px / Tall=20px per band)
    Heart Rate           → HRRangeMenu             (Min / Step / Max — via HRPresetMenu)
Modes                    → ModesMenu
    Minimal              → ToggleMenuItem          (hides time/date/battery/alarm)
    Test Data            → TestDataMenu            (Off + one row per scenario in getTestScenarioNames())
Reset                    → Confirmation → ResetConfirmDelegate
```

**Patterns used:**
- Parent menus that show dynamic sub-labels (`GraphMenu`, `ColoursMenu`, `HRRangeMenu`, `PresetsMenu`) override `Menu2::onShow()` and call a `refreshLabels()` helper that walks each item by index and calls `setSubLabel()` (and `setIcon()` for the Palette row). The framework fires `onShow()` whenever the view re-enters the foreground, including after a child sub-menu pops, so sub-labels always reflect the latest value.
- Color choices use `WatchUi.IconMenuItem` with a custom `ColorSwatch extends Drawable` (a colored circle with a dark-gray ring so a white swatch stays visible on a light menu background).
- Palette items use a `PaletteStrip extends Drawable` — same pattern, but draws N colored bands horizontally.
- Each sub-menu has a parallel `Menu2InputDelegate` class with `onSelect` that writes via `Application.Properties.setValue` and calls `WatchUi.popView`.
- HR Min/Step/Max all use a single `HRPresetMenu` parameterized by which property it edits (`HRPresetDelegate` takes the property key as a constructor arg) — keeps three almost-identical menus from being copy-pasted.

**Why `(:dev_only)` instead of `(:debug)` for test code:** `monkeyc -e` (any `.iq` export) auto-strips `:debug` regardless of whether `-r` is also passed — so a sideload build using just `-e` would lose the Test Data picker. We use the custom annotation `:dev_only`, which monkeyc doesn't auto-strip. The store build (`./build.sh --export`) layers `store.jungle` on top of `monkey.jungle` to add `dev_only` to `excludeAnnotations`; the sideload build (`./build.sh --export-with-test`) omits `store.jungle` so the test code survives. Per-device .prg builds (`./build.sh fr955`) never exclude `:dev_only` so test scenarios are always available in the simulator.

**Test Data scenarios** (`source/TestScenarios.mc`, `(:dev_only)`):
- `getTestScenarioNames()` returns the menu labels in display order. The index into this array is what's persisted in `TestScenarioIndex`.
- `buildTestScenarioData(idx, length=601, hrMin, paletteSize, hrStep)` returns the full 1-Hz curve. The Ramp scenario (idx 0) honours `hrMin`/`paletteSize`/`hrStep` so it scales to the user's HR range; the realism-driven scenarios (Anxious Rest, Active Burst, Steady Calm) emit absolute integer HR values calibrated against published resting/orthostatic literature.
- `HeartGraphWatchFaceView::maybeBuildSyntheticHR` caches the 601-entry buffer per `(idx, hrMin, paletteSize, hrStep)` tuple and rotates it by `Time.now().value() % 601` so the curve scrolls and loops every 10 min. The view then slices + resamples to the displayed bar count, identical to the real-HR path.
- Adding a new scenario: append a name to `getTestScenarioNames()` and a branch in `buildTestScenarioData()`. The menu picker auto-grows. Reuse the `_smoothRandomWalk` + `_applyPulses` helpers; seed `Math.srand(<unique>)` so the curve is deterministic across runs. **Performance note**: pulse contributions are applied per-pulse-window (`_applyPulses`), not per-time-step — an earlier per-time `_spikeContribution` design tripped the watchdog on the 6-pulse Steady Calm scenario.

**Adding a new setting (recipe):**
1. Add a `<property>` to `properties.xml` (and to `presetKeys()` in `Presets.mc` if it should be captured in saved presets, plus its default to `getDefaultPresetValues()`).
2. Decide which submenu owns it (Colours / Graph / Modes / its own top-level row) and add a `MenuItem` row in that menu's `initialize` with a fresh `Symbol` id.
3. Branch on the id in the matching parent `Menu2InputDelegate::onSelect`.
4. Add a sub-menu + delegate pair (model on `BackgroundColorMenu` / `BackgroundColorDelegate` for a color picker, or `GraphSizeMenu` for a simple list).
5. If the parent menu shows a dynamic sub-label, update its `refreshLabels` to refresh the new row.
6. Read the property in `HeartGraphWatchFaceView.mc::onUpdate` (or wherever it affects rendering).

## Presets

Snapshots of all `presetKeys()` settings persist in `Application.Storage["userPresets"]` as `[ {"name", "values"}, ... ]`. Plus a built-in "Default" preset (`getDefaultPresetValues()`, hardcoded in `Presets.mc`) that can't be deleted.

**Per-preset actions** (in `PresetActionsMenu`):
- **Apply** — write all settings into `Application.Properties`. Default and user presets both support this.
- **View code** — display the preset's 12-char shareable code in a Confirmation dialog (info-only; any button dismisses).
- **Update** — overwrite this preset's values with the current watch settings. User presets only.
- **Rename** — TextPicker prefilled with current name; rejects "Default" and empty. User presets only.
- **Delete** — confirmation, then removes. User presets only.

**Save / share entry points** at the bottom of `PresetsMenu`:
- **+ Save current** — TextPicker → `savePresetWithName(name)` (snapshots current settings)
- **+ Enter code** — TextPicker → `decodeSettings(code)` → if valid, name TextPicker → `savePresetWithNameAndValues(name, decoded)`

**Shipped presets:** `presets/shipped.json` defines a curated starter list. `presets/gen-shipped.py` (run by `./build.sh`) emits `source/ShippedPresetsGenerated.mc` with `getShippedPresets()`. On each launch, `maybeImportShippedPresets()` checks `Application.Storage["importedShippedPresetNames"]` (an array of names already seen) and imports any shipped preset whose name isn't in that list — appending to user storage and recording the name. After import, shipped presets are indistinguishable from user-saved ones — fully renameable, updateable, deletable. A deleted shipped preset stays in the imported-names list, so it doesn't resurrect on subsequent launches; conversely, adding a new entry to `shipped.json` and shipping an updated .prg DOES surface the new preset on existing installs.

Migration: an older code version used a single boolean `shippedPresetsImported`. `maybeImportShippedPresets()` detects the legacy flag and seeds `importedShippedPresetNames` with the currently-shipped names (so renamed/deleted entries don't come back) before deleting the old key.

Adding a new persisted setting? Add its key to `presetKeys()` so it's captured in snapshots, add its default to `getDefaultPresetValues()`, add it to the `KEYS` list in `presets/gen-shipped.py` and to every entry in `presets/shipped.json`, and reserve bits for it in `SettingsCode.mc` per the shareable-code section.

## Known gotchas

- **Sim's "App Settings Editor" requires a cloud-registered app** when logged in to Garmin Connect — for unpublished local builds it reports "No settings file found." Workaround for testing: change the default in `properties.xml`, rebuild, redeploy. The on-watch settings UI (via Garmin Connect mobile app) works fine without this.
- **Sim persists property values across deploys.** Once a property has been written, changing the default in `properties.xml` won't override it. To force a value during testing, temporarily hardcode it in `HeartGraphWatchFaceApp.mc::initialize` after the `getValue` call.
- **`getHeartHistory()` returns an empty array in the simulator** (no real sensor data). `CircularBuffer.interporalate` has a defensive empty-input check (added 2026) to avoid crashing in this case.
- **Unified HR history buffer at 1-second resolution**: heart data is stored in a single `"heartData"` key as **601 entries at 1 sample/sec** (10 min). `CircularBuffer` keeps only a flat `Array<Number>` of values plus a single `freshestTimeSec: Number` anchor — the per-entry timestamps are fully derivable since `addData` only ever writes nominal grid times (`previous + approxSecondsBetweenBins`, never the caller's actual sensor read time). Per-entry footprint: ~4 bytes (just the value slot). The earlier 601-entry attempt OOM'd on fr955 because the original DataPair storage was ~60 bytes/entry; this flat layout fits with massive headroom. `markStaleSec` is O(1) (closed-form arithmetic against `freshestTimeSec`). `HeartGraphWatchFaceView::onUpdate` reads `HeartGraphMinutes` per tick, slices the tail (181/301/601 entries for 3/5/10 min), and downsamples to the visual bar count (181/151/201) via `resampleToBars` averaging — zero values (no-reading sentinel) are excluded from per-bar averages so they don't drag a bar down. 3-min mode is effectively 1:1; 5-/10-min modes average groups of 2 and 3 samples respectively. Switching durations no longer loses history. **Migration check** in `getCorrectInitialData`: if persisted data's entry count doesn't match `dataDensityForHeartTrack`, discard and re-interpolate from system sensor history. `CircularBuffer.loadData` also handles a legacy persistence migration (old `_time` array per-entry) → derives `freshestTimeSec` + `durationSec` from it on first load. Legacy per-mode keys (`"heartData3_data"` etc.) are dead storage on upgraded installs — harmless.
- **`getInitialView` return type** must be `[Views] or [Views, InputDelegates]` on SDK ≥ 7.x. Older `Array<Views or InputDelegates>?` form fails to compile.
- **`getSettingsView` return type** is verbose and doesn't accept the `[Views] or [Views, InputDelegates]` shortcut from `getInitialView` (its allowed view types are a different enumerated union that excludes `Menu2` by name though Menu2 fits via its `View` superclass). Easiest: omit the return type annotation entirely.
- **"Signature check failed" on watch install** is misleading — the message implies a key/signature mismatch, but on the fr955 with firmware 25.04 it actually meant the .prg binary format was rejected by the firmware. SDK 6.4.2 and SDK 7.3.1 both produced .prgs the watch rejected; **SDK 9.1.0 produced an accepted .prg**. If you see this error, first check the SDK version is current. Genuine key mismatches do exist as a separate failure mode (per Garmin forum threads) but the symptom on this device was the same.
- **`self` in static functions** is silently allowed by SDKs 6.x and 7.x but fails to compile in SDK 9. Class-level `const` fields aren't accessible via `ClassName.field` either — they're per-instance. Inline string literals or use module-level `const` instead. (See `CircularBuffer.mc::loadData` for the pattern that broke.)
- **Watch uses MTP, not USB Mass Storage** — `/Volumes/GARMIN/` is not available on macOS. Use Android File Transfer to drag .prg files into `GARMIN/Apps/`. To "eject" for MTP, just close the AFT window. After the watch reboots, the .prg is moved out of `Apps/` (consumed) and the face appears under **Settings → Watch Face → Add New** (scroll to bottom).
- **Launcher icon size warning** during build (30x30 vs expected 40x40) is cosmetic — fix by replacing `resources/drawables/launcher_icon.png` if it matters.
