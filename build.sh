#!/bin/bash
# Build wrapper: regenerates source/PalettesGenerated.mc from palettes.json,
# then invokes monkeyc.
#
# Usage:
#   ./build.sh                  builds per-device .prg files (fr955 + enduro3)
#   ./build.sh fr955            single device .prg
#   ./build.sh --export         builds bin/HeartGraphWatchFace.iq (store/beta bundle)
set -e
cd "$(dirname "$0")"

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"

python3 palettes/gen-palettes.py
python3 presets/gen-shipped.py

mkdir -p bin

if [ "$1" = "--export" ]; then
  echo "=== building .iq bundle for Connect IQ Store upload ==="
  "$SDK/bin/monkeyc" -e -f monkey.jungle -o bin/HeartGraphWatchFace.iq -y "$KEY" -w
  echo "=== done ==="
  ls -la bin/HeartGraphWatchFace.iq
  exit 0
fi

DEVICES=("$@")
if [ ${#DEVICES[@]} -eq 0 ]; then
  DEVICES=(fr955 enduro3)
fi

for D in "${DEVICES[@]}"; do
  echo "=== building for $D ==="
  "$SDK/bin/monkeyc" -d "$D" -f monkey.jungle -o "bin/HeartGraphWatchFace-$D.prg" -y "$KEY" -w
done
echo "=== done ==="
ls -la bin/*.prg
