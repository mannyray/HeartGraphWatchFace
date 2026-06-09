#!/usr/bin/env python3
"""Generate ONE watch-face image for a given color-settings combination.

Pipeline:
  1. Backup resources/settings/properties.xml
  2. Apply the scenario's overrides (Background/Numbers/Time + TestMode=true)
  3. Build .prg for fr955
  4. Deploy to the running simulator
  5. Capture the sim window via `screencapture -l <windowID>`
  6. Auto-crop to the bounding box of the watch face
  7. Save as output/<shareable-code>.png
  8. Restore properties.xml

Once this works for one scenario we'll iterate over the full matrix
(background × numbers × time = 12 images).

Prereqs:
  * Connect IQ simulator running (open the SDK's ConnectIQ.app once)
  * Terminal has Screen Recording permission (macOS 15+)
  * Pillow installed (`pip install Pillow`)
"""
import json
import os
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

import settings_code

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
PROPS_PATH = PROJECT_ROOT / "resources/settings/properties.xml"
PROPS_BACKUP = SCRIPT_DIR / "properties.xml.backup"
OUTPUT_DIR = SCRIPT_DIR / "output"
LOG_DIR = SCRIPT_DIR / "logs"
FIND_WINDOW = SCRIPT_DIR / "find_window.swift"

SDK = Path.home() / "Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY = Path.home() / "Library/Application Support/Garmin/ConnectIQ/developer_key.der"

# Settings we don't vary in this run.
DEFAULTS = {
    "HRMin": 40,
    "HRMax": 100,
    "HRStep": 10,
    "PaletteIndex": 0,
    "GraphBandPixels": 10,
    "HeartGraphMinutes": 3,
    "MinimalMode": False,
}


def get_window_id():
    r = subprocess.run(
        ["swift", str(FIND_WINDOW)], capture_output=True, text=True
    )
    return r.stdout.strip() if r.returncode == 0 else None


def write_props(overrides):
    """Mutate properties.xml in-place. Original was backed up by main()."""
    tree = ET.parse(PROPS_PATH)
    root = tree.getroot()
    for prop in root.findall("property"):
        pid = prop.get("id")
        if pid in overrides:
            v = overrides[pid]
            if isinstance(v, bool):
                prop.text = "true" if v else "false"
            else:
                prop.text = str(v)
    tree.write(PROPS_PATH, encoding="UTF-8", xml_declaration=False)


def build_prg(device):
    out = PROJECT_ROOT / "bin" / f"HeartGraphWatchFace-{device}.prg"
    # build.sh wraps gen-palettes/gen-shipped + monkeyc and handles cwd.
    subprocess.run(
        [str(PROJECT_ROOT / "build.sh"), device],
        check=True, capture_output=True,
    )
    return out


def sim_menu_click(item_name):
    subprocess.run([
        "osascript", "-e",
        f'''tell application "System Events"
            tell process "Connect IQ Device Simulator"
                click menu item "{item_name}" of menu 1 of menu bar item "File" of menu bar 1
            end tell
        end tell'''
    ], capture_output=True)


def reset_app_data():
    """Forcefully fresh-start the app between scenarios.

    `Reset All App Data` clears Storage but NOT Properties — so the
    BackgroundColor / GraphNumberColor / etc. set by the user in a
    previous sim session persist across deploys, masking our
    properties.xml changes. `Delete All Apps` uninstalls the app
    entirely so the next monkeydo performs a fresh install, which
    re-reads properties.xml defaults."""
    sim_menu_click("Kill App")
    time.sleep(0.5)
    sim_menu_click("Delete All Apps")
    time.sleep(0.5)


def deploy(prg, device, log_path):
    """Run monkeydo and capture stdout/stderr to log_path so we can read
    crash dumps after the fact."""
    log = open(log_path, "wb")
    proc = subprocess.Popen(
        [str(SDK / "bin/monkeydo"), str(prg), device],
        stdout=log, stderr=subprocess.STDOUT,
    )
    # Post-deploy wait. The watchface needs time to load past the
    # GARMIN splash, especially after a fresh install (Delete All Apps).
    time.sleep(20)
    return proc


def screenshot(window_id, dest):
    subprocess.run(
        ["screencapture", "-l", window_id, "-x", "-o", str(dest)],
        check=True,
    )


# Empirically determined: on macOS the fr955 simulator window captures
# at 792x1208 (retina 2x of 396x604 logical) and the round watch face
# screen sits centered at ~(396, 604) with diameter ~520 px (= 260px
# physical × 2 retina). We crop a 540x540 square — slightly larger than
# the screen — so the bezel ring is included as visual context without
# pulling in the surrounding strap / chrome / status bar.
WATCH_FACE_CROP = {
    "fr955": (126, 351, 666, 891),
}


def crop_to_watch_face(src_path, device):
    img = Image.open(src_path).convert("RGB")
    bbox = WATCH_FACE_CROP.get(device)
    if bbox is None:
        print(f"  warning: no crop bbox for {device}; saving uncropped")
        return img
    return img.crop(bbox)


def build_scenarios():
    """All combinations of the three color settings we vary.
    2 backgrounds × 3 graph-number colors × 2 time colors = 12 scenarios."""
    backgrounds = [0x000000, 0xFFFFFF]
    graph_numbers = [-2, -3, 0xAAAAAA]   # default / hidden / gray
    time_colors = [-2, 0x555555]         # default / gray
    out = []
    for bg in backgrounds:
        for gn in graph_numbers:
            for tc in time_colors:
                out.append({
                    "BackgroundColor": bg,
                    "TimeColor": tc,
                    "GraphNumberColor": gn,
                    "TestMode": True,
                })
    return out


def main():
    if PROPS_BACKUP.exists():
        print(f"recovering: restoring {PROPS_PATH}")
        shutil.copy(PROPS_BACKUP, PROPS_PATH)
        PROPS_BACKUP.unlink()

    OUTPUT_DIR.mkdir(exist_ok=True)
    LOG_DIR.mkdir(exist_ok=True)
    only = None
    if len(sys.argv) > 1:
        only = sys.argv[1].strip()
        print(f"filter: only running scenario(s) matching '{only}'")
    wid = get_window_id()
    if not wid:
        print("ERROR: simulator window not found — open ConnectIQ.app first")
        return 1
    print(f"sim window id: {wid}")

    scenarios = build_scenarios()
    print(f"running {len(scenarios)} scenarios\n")

    shutil.copy(PROPS_PATH, PROPS_BACKUP)
    last_proc = None
    try:
        for i, scenario in enumerate(scenarios, 1):
            full = dict(DEFAULTS)
            full.update({k: v for k, v in scenario.items() if k != "TestMode"})
            code = settings_code.encode_settings(full)
            if only and only not in code:
                continue
            print(
                f"[{i:2d}/{len(scenarios)}] {code}  "
                f"bg=0x{scenario['BackgroundColor']:06X} "
                f"tc={scenario['TimeColor']} "
                f"gn={scenario['GraphNumberColor']}"
            )

            # Reset props to original baseline each scenario, then apply.
            shutil.copy(PROPS_BACKUP, PROPS_PATH)
            write_props(scenario)

            try:
                prg = build_prg("fr955")
            except subprocess.CalledProcessError as e:
                print(f"  build failed: {e.stderr.decode()[:200]}")
                continue

            if last_proc:
                last_proc.terminate()
            # Wipe the previous scenario's persisted properties so the new
            # defaults in properties.xml actually take effect.
            reset_app_data()
            last_proc = deploy(prg, "fr955", LOG_DIR / f"{code}.log")
            raw = OUTPUT_DIR / f"{code}.raw.png"
            screenshot(wid, raw)
            cropped = crop_to_watch_face(raw, "fr955")
            cropped.save(OUTPUT_DIR / f"{code}.png", "PNG")

        if last_proc:
            last_proc.terminate()
    finally:
        shutil.copy(PROPS_BACKUP, PROPS_PATH)
        PROPS_BACKUP.unlink()

    print(f"\ndone — {len(scenarios)} images in {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
