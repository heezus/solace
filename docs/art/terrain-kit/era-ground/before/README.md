# Before: production ground at bc66986

Actual game captures from unmodified `tests/tools/terrain_preview.gd`, Godot 4.7.2, seeds 3, 11 and 42. The harness reveals fog, grows the south and captures its default Stone-era state. Wide = 24 screen px/tile; close = 80. These are baseline captures only, **not** per-era acceptance or after images. The era-aware harness and paired captures wait for the parent terrain kit merge.

Command: `/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/tools/terrain_preview.gd -- <seed> /tmp/solace-era-before/seed-<seed>`

All three capture runs exited 0 without errors/warnings; each produced all seven expected views. Only wide/close are retained here to keep review focused.
