#!/bin/bash
# Build wrapper: regenerates source/PalettesGenerated.mc from palettes.json,
# then invokes monkeyc for the given device(s). Usage: ./build.sh [device...]
# Defaults to fr955 + enduro3 if no device specified.
set -e
cd "$(dirname "$0")"

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"

python3 gen-palettes.py

DEVICES=("$@")
if [ ${#DEVICES[@]} -eq 0 ]; then
  DEVICES=(fr955 enduro3)
fi

mkdir -p bin
for D in "${DEVICES[@]}"; do
  echo "=== building for $D ==="
  "$SDK/bin/monkeyc" -d "$D" -f monkey.jungle -o "bin/StressWatchFace-$D.prg" -y "$KEY" -w
done
echo "=== done ==="
ls -la bin/*.prg
