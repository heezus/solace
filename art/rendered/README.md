# Rendered miniature art

Production assets for the Misty Highlands direction, integrated on PR #33. PNGs are unmodified outputs of the built-in image-generation tool. Godot-generated `.import` files accompany them. `regions.json` documents the atlas bounds; runtime bounds live in `scripts/rendered_art.gd` so exported games do not depend on JSON inclusion rules.

Trees, rocks, plants, core buildings and bridges come from the [coordinated variants study](../../docs/art/overhaul/misty-highlands/variants/README.md). Water comes from the original [tile kit](../../docs/art/overhaul/misty-highlands/README.md). New meadow, neutral walking Kith, workshops, industry, item icons and transport/resource extras have exact prompts and source provenance in [prompts.json](prompts.json). The first walking output was revised because its poses were too similar; only the revised output is used.

Sprites use transparent alpha, clipped atlas regions and preserved aspect ratios. The walk sheet deliberately uses uniform cells to preserve foot anchors across poses. Other regions follow subject alpha bounds. All original SVGs remain available for compatibility.

See the [engine integration](../../docs/art/overhaul/misty-highlands/engine/README.md) for implemented behavior, screenshots and limitations.

## Terrain revision

`turf-v2.png`, `river-v2.png`, `earth-v2.png` and `crossings-v2.png` are new unmodified built-in image-generation outputs. Exact prompts and source paths: [terrain-prompts.json](terrain-prompts.json). The previous meadow/water/bridge studies are retained for provenance.

`terrain.gdshader` samples detail in world space at viewport resolution, independently of the cached topology masks. Mirrored UV sampling gives continuous wrap at the source-image boundaries; secondary sampling reduces obvious reflection/repeat patterns. It animates shallow reflections and water flow. Road materials and shore breakup are world anchored, so camera movement does not reshuffle them.

The crossing atlas has twelve modules: three horizontal wood, three horizontal stone, three vertical wood and three vertical stone. Bounds exclude unrelated atlas cells. The engine handles single-cell crossings by combining the two end halves; longer spans use fixed-scale ends and repeatable center modules.

## Blended grounding pass, 2026-10-05

`meadow-ground.png`, `woodland-ground.png` and `calm-river.png` are new unmodified built-in imagegen outputs guided by the reviewed blended paintover. Exact prompts and original sources: [grounding-prompts.json](grounding-prompts.json). Godot import metadata accompanies each image. Earlier materials remain for provenance.

`world_ground.gd` now caches an RGBA presentation mask: R water, G road wear, B revealed-tree density, A visible foundation wear. The shader blends visual regions and locally colored paths; foundation aprons and native contact shadows anchor subjects without changing game state. See actual captures in the [engine integration](../../docs/art/overhaul/misty-highlands/engine/README.md).

## Research illustrations

`research-symbols.png` and `research-landmarks.png` preserve original transparent built-in image-generation outputs. Exact prompts, reference role and source paths: [research-prompts.json](research-prompts.json). Atlas regions in `Rendered` and the presentation-only `Art.research_sprite` resolver supply all research illustrations, including former vector placeholders. Existing map sprites are unchanged. Both research views use centered aspect-preserving drawing. Godot generates the accompanying import metadata.
