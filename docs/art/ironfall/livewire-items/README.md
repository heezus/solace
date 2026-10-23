# Ironfall / Livewire item icons

Three original transparent built-in imagegen outputs: `art/rendered/wire.png`, `steel_tools.png`, `shard.png`, with generated Godot imports. [Measured regions/source hashes](spec.json), [20/24/32/40 px and 96 px comparison](native-review.png), and individual prompts accompany them. Claude wires these after review; no `.gd`, tests or UI changes.

Use [Art Direction](../../../design-system/05-art-direction.md): chunky miniature silhouettes, upper-left highlights, warm copper/timber, cool blue-silver steel and pale cyan shard material. Check on charcoal green and ivory at native size.

The inspected native board shows all three on both backgrounds beside existing Iron Tools: copper spool, blue-silver axe/pick, and single cyan shard stay recognizable at 20 px. The comparison is a documentation composite, not a runtime capture. Originals remain unmodified; `preview.py` reproduces the board with Pillow.

## Claude hooks

Region rectangles are `[x,y,width,height]` in source pixels, measured at alpha >8 plus 2 px padding. Route item IDs `wire`, `steel_tools`, `shard` to these regions using aspect-preserving fitting; retain the 20 px caller. Remove Wire/Steel Tools' borrowed tints and replace the temporary Starfall shard mapping only for this item slot. Keep the Starfall atlas and other callers intact. Color and highlights are painted; no extra badge, background or tint is needed.

Godot 4.7.2 import, alpha checks and whitespace checks pass. Full CI is tracked on draft PR #137; Claude reviews, wires and merges after green CI.
