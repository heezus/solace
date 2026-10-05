# Rendered miniature art

Production assets for the Misty Highlands direction, integrated on PR #33. PNGs are unmodified outputs of the built-in image-generation tool. Godot-generated `.import` files accompany them. `regions.json` documents the atlas bounds; runtime bounds live in `scripts/rendered_art.gd` so exported games do not depend on JSON inclusion rules.

Trees, rocks, plants, core buildings and bridges come from the [coordinated variants study](../../docs/art/overhaul/misty-highlands/variants/README.md). Water comes from the original [tile kit](../../docs/art/overhaul/misty-highlands/README.md). New meadow, neutral walking Kith, workshops, industry, item icons and transport/resource extras have exact prompts and source provenance in [prompts.json](prompts.json). The first walking output was revised because its poses were too similar; only the revised output is used.

Sprites use transparent alpha, clipped atlas regions and preserved aspect ratios. The walk sheet deliberately uses uniform cells to preserve foot anchors across poses. Other regions follow subject alpha bounds. All original SVGs remain available for compatibility.

See the [engine integration](../../docs/art/overhaul/misty-highlands/engine/README.md) for implemented behavior, screenshots and limitations.
