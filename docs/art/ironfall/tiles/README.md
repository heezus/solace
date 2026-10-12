# Ironfall resource tiles

Three new named transparent PNGs, each with three variants and a Godot-generated import: `art/rendered/coal_seam.png`, `iron_hills.png`, `spent_seam.png`. Logical footprint stays 1×1. Originals are 2172×724; exact regions and source hashes are in [spec.json](spec.json), with built-in generation prompts beside it.

[Native comparison](native-review.png) shows 45 px features in 48 px cells and 90 px inspection, beside existing plain ore and copper. Coal has black bands, iron has broad rust-red faces with grey ore, and spent coal has grey depleted channels. No square grass base or distant scenery is painted into the assets.

## Claude hooks

Add the three arrays from `spec.json` to `Rendered.REGIONS`, keyed by the exact stems above. Set `FEATURES` to `["coal_seam",0,3]`, `["iron_hills",0,3]`, `["spent_seam",0,3]`. Remove those three `TINTS` overrides: color is already painted. Keep `plain_ore` discovery masking, counts, footprints and the simulation RNG unchanged.

Use the **coal_seam visual hash salt for both coal_seam and spent_seam** so depletion selects the corresponding ridge variant rather than switching its shape. The corresponding variants are deliberately paired; this is a presentation change only. Keep the existing feature fit/selection overlays. Main currently hashes each type separately, so pairing needs that small renderer hook.

Godot 4.7.2 import and documentation-only native review passed. Actual map integration remains Claude's action; the preview changes no production code or saved state. Run `preview.gd` through Godot to regenerate the board.
