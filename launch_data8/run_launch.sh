#!/bin/bash
# Step 8 Mac launch: ONE off-screen run of the game, driven by launch_data8/shot_driver.gd. Run from the repo root.
# Nothing here touches the real Solace save folder: HOME is a throwaway folder, so Godot's user dir is inside it.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
OUT="$REPO/launch_data8/shots"
HOMEDIR="$(mktemp -d /tmp/solacehome8.XXXXXX)"
USERDIR="$HOMEDIR/Library/Application Support/Godot/app_userdata/Solace"
mkdir -p "$OUT" "$USERDIR"
cp "$REPO/launch_data8/profile.json" "$USERDIR/profile.json"
cp "$REPO/launch_data8/run.json" "$USERDIR/run.json"
export HOME="$HOMEDIR"
cd "$REPO"
echo "import (headless, no window)"; "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1; echo "import exit $?"
echo "launch at $(date)"
"$GODOT" --path . --rendering-driver opengl3 --disable-vsync --windowed --resolution 1280x800 --position 20000,20000 \
  --log-file "$OUT/godot.log" -s launch_data8/shot_driver.gd -- --steps=launch_data8/steps.txt --out="$OUT" --max=150 --offscreen > "$OUT/stdout.log" 2>&1 &
PID=$!
( sleep 240; kill -9 $PID 2>/dev/null ) &
KILLER=$!
wait $PID; echo "godot exit $? at $(date)"
kill $KILLER 2>/dev/null
ls "$OUT"
