# Scale and readability correction, 2026-10-19

The owner explicitly requested corrections after the first comparison showed oversized ground motifs. These are revised paintings made with the built-in imagegen tool; the old material PNGs are retained byte-for-byte in `before/`. Tile size, footprints and production sprite sizes are unchanged.

## What changed

- Starfall meadow and woodland: smaller grass, clover, litter and roots; a subsequent lighting pass quiets the small-detail highlights while preserving their corrected size.
- Bronze Dawn: smaller gravel and dry grass, retaining its warm ochre/copper-green family.
- Ironfall: smaller slag/gravel, darker coal-dusted earth; the resource apron is a darker, lower-contrast companion to the corrected southern material.
- Livewire: smaller healthy ground motifs; Bloom uses thin creeping threads and tiny muted buds rather than large pink bulbs. Firebreak has smaller char/ash and fewer conspicuous light fragments.
- Decals: the same original isolated objects are packed within 44x44 rather than 76x76 pixels of each 96x96 cell. This is a 42% reduction in linear packed subject size, preserving original alpha, upper-left lighting and stable cell IDs.

Prompts request quarter/third-scale ground motifs; these are artistic targets, not measured guarantees for every painted mark. Inspect the native comparisons for the actual result. The original 1254x1254 source-resolution limitation remains; packing to 1920x1920 does not manufacture native painted detail.

## Comparison method

`tests/tools/era_ground_scale.gd` renders the actual production `Art.map_feature`, `Art.map_building` and `Rendered.kith` helpers. Both columns use identical sprite positions, identity, variation seed (3), fixed pose time, texture filter and 96 source-texture pixels per tile. Rows show actual 24, 48 and 80 pixels per tile. Subjects include the existing 2x2 Hearth, 1x1 Dwelling, tree, ordinary rock, Coal Seam, Ironstone and two Kith poses at the production 35 px per 48 px tile contract. No subject was enlarged to flatter the corrected material.

The saved 1560x1000 area crops only unused window expansion beyond the fixture canvas; it does not resize the capture. These are **native Godot asset fixtures**, not screenshots of the integrated terrain shader, a generated map, or the era-aware acceptance pass. They cannot establish seamless biome transitions, roads/aprons, edge masking, fog safety or live motion readability.

Run with a display:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/tools/era_ground_scale.gd
```

The output is `native/<material>.png`, with old on the left and corrected on the right. `before/asset-scale-review.jpg` retains the original Hearth-only board; the parent `asset-scale-review.jpg` is rebuilt from corrected materials.

## Provenance and preparation

`generation.json` records exact imagegen prompts and inputs; the selected generated originals live alongside it. Intermediate scale-only Starfall paintings are retained when a separate contrast pass is selected. The parent `pack_assets.py` maps the selected sources to unchanged production candidate filenames, mechanically resamples/packs them and enforces non-mirrored wrap continuity. Parent `sources.json` records dimensions and source/output hashes for the corrected selection; `before/sources.json` is the old manifest.

`material-metrics.json` compares grayscale mean and local detail RMS at 48 px/tile, with a two-pixel Gaussian low-pass used only for measurement. This is diagnostic, not a perceptual pass threshold. No blur is applied to the art by that measurement.

## Runtime follow-through

Terrain-kit PR #114 merged during the correction pass. Runtime integration now uses existing revealed patch/tide masks to concentrate Bloom at boundaries, darken known-resource aprons and paint burnt ground. See the parent integration review for real main-scene baseline/current pairs on all three preview seeds in all four eras. Skyreach remains unchanged and concept-only. Owner visual approval is still pending.
