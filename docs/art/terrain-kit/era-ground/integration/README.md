# Integrated era-ground review

Terrain kit #114 is merged. PR #115 now wires the corrected materials into the real continuous terrain renderer; the 48 px baseline and gameplay footprints are unchanged. Skyreach remains concept-only.

## What these images show

Actual `scenes/main.tscn` captures from `tests/tools/terrain_preview.gd`, Godot 4.7.2. Each era is rendered on preview seeds 3, 11 and 42 in both `baseline` and `current` modes, with seven views per run. The harness uses its existing seeded main-scene startup; `preview_seed` is the command-line seed, rather than an assertion that Main's internal `randi()`-selected map seed has the same numeric value.

The fixture pauses processing, expands existing east/south land for the chosen era, sets the existing story milestones and relevant resource-discovery techs, and reveals fog. Livewire includes a small manually marked burnt-ground fixture beside a natural Bloom sample so firebreak material appears in the captures. These are deterministic visual fixtures, not earned gameplay checkpoints or pacing evidence. The simulation and map generator are not modified by this PR.

`before` is a **base-kit material control**, selected by a visual preview override with the same era, map, camera and sprite helpers. It is not a claim that these are historical screenshots from an older executable. Both modes retain current object rendering, including the painted sample vines and existing sample identity colors. Water animation can differ in phase between process launches.

All packaged images are 1280x800, encoded as lossless WebP with pixel equality checked against each original PNG. No screenshot is resized. Wide is 24 logical px/tile; close is 80. Seven raw PNGs and a clean log are produced per run; wide/close for all seeds and town for seed 3 are retained here. `captures.json` records source PNG and decoded pixel hashes.

Reproduce a pair:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/tools/terrain_preview.gd -- 3 /tmp/era-before starfall baseline
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/tools/terrain_preview.gd -- 3 /tmp/era-after starfall current
```

Use `starfall`, `bronze`, `ironfall`, or `livewire` and seed `3`, `11`, or `42`. The legacy default `stone` remains available.

## Pairs

| Era / preview seed | Wide before / after | Close before / after |
|---|---|---|
| starfall / 3 | [before](starfall-3-before-wide.webp) / [after](starfall-3-after-wide.webp) | [before](starfall-3-before-close.webp) / [after](starfall-3-after-close.webp) |
| starfall / 11 | [before](starfall-11-before-wide.webp) / [after](starfall-11-after-wide.webp) | [before](starfall-11-before-close.webp) / [after](starfall-11-after-close.webp) |
| starfall / 42 | [before](starfall-42-before-wide.webp) / [after](starfall-42-after-wide.webp) | [before](starfall-42-before-close.webp) / [after](starfall-42-after-close.webp) |
| bronze / 3 | [before](bronze-3-before-wide.webp) / [after](bronze-3-after-wide.webp) | [before](bronze-3-before-close.webp) / [after](bronze-3-after-close.webp) |
| bronze / 11 | [before](bronze-11-before-wide.webp) / [after](bronze-11-after-wide.webp) | [before](bronze-11-before-close.webp) / [after](bronze-11-after-close.webp) |
| bronze / 42 | [before](bronze-42-before-wide.webp) / [after](bronze-42-after-wide.webp) | [before](bronze-42-before-close.webp) / [after](bronze-42-after-close.webp) |
| ironfall / 3 | [before](ironfall-3-before-wide.webp) / [after](ironfall-3-after-wide.webp) | [before](ironfall-3-before-close.webp) / [after](ironfall-3-after-close.webp) |
| ironfall / 11 | [before](ironfall-11-before-wide.webp) / [after](ironfall-11-after-wide.webp) | [before](ironfall-11-before-close.webp) / [after](ironfall-11-after-close.webp) |
| ironfall / 42 | [before](ironfall-42-before-wide.webp) / [after](ironfall-42-after-wide.webp) | [before](ironfall-42-before-close.webp) / [after](ironfall-42-after-close.webp) |
| livewire / 3 | [before](livewire-3-before-wide.webp) / [after](livewire-3-after-wide.webp) | [before](livewire-3-before-close.webp) / [after](livewire-3-after-close.webp) |
| livewire / 11 | [before](livewire-11-before-wide.webp) / [after](livewire-11-after-wide.webp) | [before](livewire-11-before-close.webp) / [after](livewire-11-after-close.webp) |
| livewire / 42 | [before](livewire-42-before-wide.webp) / [after](livewire-42-after-wide.webp) | [before](livewire-42-before-close.webp) / [after](livewire-42-after-close.webp) |

Town and Kith at seed 3: [starfall before](starfall-3-before-town.webp) / [after](starfall-3-after-town.webp), [bronze before](bronze-3-before-town.webp) / [after](bronze-3-after-town.webp), [ironfall before](ironfall-3-before-town.webp) / [after](ironfall-3-after-town.webp), [livewire before](livewire-3-before-town.webp) / [after](livewire-3-after-town.webp).

## Renderer areas touched

- `world_ground.gd`: existing story-milestone material selection, centered resource/Bloom/burnt masks in the second half of the existing mask texture, incremental invalidation on existing research/tide changes, and deterministic era decal selection. Unknown resources and hidden cells do not contribute identifying apron masks.
- `terrain.gdshader`: small material grid atlases, 20/27-tile macro coordinates with the kit's fine brush subscale for the corrected era sheets, noise-broken region boundaries, quiet Bloom interiors, resource aprons and firebreak material. The base kit's water/contour bank and Stone look remain shared. Eight samplers are retained; single era materials are reused without redundant atlas columns. Era ground textures receive runtime mipmaps so fine marks filter cleanly at wide zoom; the base kit and sprite/decal imports are unchanged.
- `bloom_look.gd`: remove placeholder ground rectangles/blobs and draw a small painted vine decal, retaining each sample's ID, color and breathing center. `tide_look.gd` keeps building/light/front overlays while ground washes move to the shader.
- Preview/scale/check tools provide the evidence; no gameplay, economy, progression, save schema, resource IDs, RNG behavior or global tile-scale changes.

## Validation and limits

Focused era checks verify discovery/fog privacy, centered apron masks, incremental/fresh equivalence, stable decal placement, unchanged saves/tile IDs and untouched simulation RNG. The parent terrain-kit asset/privacy checks remain passing. Compatibility shader rendering uses eight samplers; its known GLES3 2D-MSAA warning is allowed by the repository's checked-run wrapper. Strict warning loading and lint/format checks pass. Fast logic suite and scripted input play-through pass; full exact-head CI is tracked on #115.

Originals remain 1254x1254 paintings packed to 1920x1920. Their source dimensions are not relabeled. Native fixtures and real main-scene captures support the scale/readability assessment; owner visual approval is still pending. The point is smaller ground marks and clearer miniature silhouettes, not a technical check pretending to approve the art.
