# Era ground families

Owner brief: 2026-10-19. Branch: `codex/era-ground`. Parent contract: [terrain kit](../README.md) and [design page 22](../../../design-system/22-terrain-kit.md).

## Delivery state

The owner-requested [scale/readability correction](corrections-v2/README.md) repaints all eight ground materials and reduces decal subject size. Native Godot before/after fixtures now include resources and Kith at 24/48/80 px per tile. Production integration is implemented on this branch; final owner visual approval remains pending.

Art phase: eight sheet candidates and a 32-cell decal atlas are painted and packed. Starfall studies use the merged kit's meadow/woodland source composition; their historical input hashes are recorded below. Terrain-kit PR #114 is merged. This branch now selects the corrected materials through its shader using existing story milestones and revealed visual masks. Per-era generated-map pairs and validation are documented in [integration review](integration/README.md); owner visual approval is still required.

## Owner-agreed refinement gate, 2026-10-19

The owner agreed with Codex's visual assessment: the painted miniature direction fits the existing assets, but these candidates are not visually approved. Before final acceptance:

- [x] Repaint to reduce the apparent size of Starfall grass and woodland litter beside existing buildings, while preserving alignment with the final base kit. Resolve shared base sampling with the parent kit rather than silently changing only the era companion's layout.
- [x] Repaint to quiet Ironfall and firebreak ground: lower the contrast/density of bright gravel and sharp fragments so resource deposits and small moving characters remain clear. Keep crisp local detail; do not solve visual noise by blurring the whole ground.
- [x] Use the existing visual masks to concentrate Bloom growth at patch edges and leave quieter healthy interiors, using the existing patch IDs and visual masks.
- [x] Extend comparisons beyond the Hearth: include existing trees, ordinary rocks, coal/iron resources and Kith at wide/default/close views. Confirm silhouette separation, grounded contact and consistent material scale in actual game captures.

Bronze Dawn is the strongest immediate material match; preserve its warm dry direction. Water matching remains part of the parent kit and subsequent integrated review. This gate adds no gameplay or save changes and does not lift the parent-merge requirement.

## Material contract

All seamless ground sheets are 1920×1920, representing 20×20 tiles at 96 source pixels per tile. Upper-left light and lower-right shadows. Repeat in both axes without mirroring. No landmark exceeds six tiles (576 source pixels); material detail stays much smaller. Each family uses a compact palette and its adjacent surfaces share two middle colors. Transparent decal cells are 96×96 with clear gutters and baked lower-right shadows. Decal placement must use the kit's map-seeded visual hash, never gameplay RNG.

Starfall meadow and woodland must preserve the final kit base layouts. Bronze Dawn supplies warm dry hill earth with restrained patina; tin gravel remains a decal. Ironfall extends the southern-earth slot below `world.base_height`, with a separate darker resource apron. Livewire supplies healthy ground, creeping Bloom ground and scorched firebreak. Existing Bloom patch IDs and sample identities remain intact. Skyreach is concept only.

## Material interface

| Family | Sheets | Decals / overlay |
|---|---|---|
| Starfall | layout-matched meadow and woodland | pale cyan motes, glass shard chips |
| Bronze Dawn | dry hill ground | copper-green flecks, tin-grey gravel |
| Ironfall | southern earth, dark resource apron | cinders, ash, slag |
| Livewire | healthy ground, Bloom growth, firebreak | creeping green/magenta edges, sparse embers |

Files use a dedicated `art/rendered/era-ground/` namespace through the merged kit's runtime material selection. No tile IDs, terrain generation, simulation, footprints or save formats change.

## Provenance

Painted originals are generated with the built-in imagegen tool. Exact prompts, source dimensions, hashes and any packing steps accompany the selected assets. Do not claim a resized image is a native 1920-pixel original. All eight seamless-sheet originals are 1254×1254 (62.7 native generated pixels per logical tile). The final 1920×1920 sheets are Lanczos-packed to the required 96-pixel sampling contract, then mechanically made periodic with periodic-plus-smooth decomposition; no new painted detail is synthesized and no mirroring is used. Exact outer texels match on both axes. This does not make the sources native 1920 masters or establish the close-view pass; retain that limitation for review.

`pack_assets.py` reproduces the mechanical preparation. `sources.json` records source and packed SHA-256, dimensions and mean RGB. Full generation prompts are in `prompts.json` and the named prompt text files. The first decal atlas and its unsuccessful edit are rejected because they retain ground backing. The accepted replacement uses loose objects; packing trims the empty 10% outer source-cell gutter (including faint generation guide artifacts), fits each corrected subject within 44×44 of its 96×96 slot (initially 76×76), and preserves original alpha. It does not key colors or fabricate transparency.

Eight `*-wrap-review.jpg` images show literal 2×2 repeats for inspecting discontinuities. These are asset proofs, not game screenshots; the shader still needs to break the visible material repeat at unrelated scales. The [initial before captures](before/README.md) cover the original default-era harness. The [integrated review](integration/README.md) supplies paired baseline/current views for all four eras on all three requested seeds.

## Skyreach concept (no wiring)

Skyreach ground is exposed high rock interrupted by shallow pockets of thin soil and small wind-bent grass, so the map feels elevated and open without changing its logical tile scale. Cool slate planes catch the same upper-left light as the buildings; narrow warm-grey soil seams and muted olive grass share two mid-tones with the rock, keeping transitions clean. Short grass leans consistently with the wind while rock chips and worn striations remain small enough to avoid repeating landmarks. The sketch is a material study only: no floating-island mechanics, new resources, water behavior or era implementation is implied.

## Packed candidate paths

All paths below are beneath `art/rendered/era-ground/`. They are selected by the era renderer in this branch.

| File | Runtime use |
|---|---|
| `starfall-meadow.png` | Cooler color companion to the kit meadow A layout |
| `starfall-woodland.png` | Cooler color companion to the kit woodland A layout |
| `bronze-dawn-earth.png` | Warm east-growth hill ground; mineral decals remain separate |
| `earth-south.png` | Ironfall southern earth slot, gated by `y >= world.base_height` |
| `ironfall-apron.png` | Darker apron at existing Coal Seam / Ironstone resource cells |
| `livewire-healthy.png` | Healthy Livewire material |
| `livewire-bloom.png` | Painted Bloom ground, masked by existing patch tile IDs |
| `livewire-firebreak.png` | Black/ash firebreak material; ember decals separate |
| `decals.png` | 8×4 cells, one-based regions below |

Decals: 1–4 cyan motes; 5–8 glass shard chips; 9–12 copper stain flakes; 13–16 tin-grey gravel; 17–20 coal cinders; 21–24 rusty slag; 25–28 green/magenta Bloom tendrils; 29–32 ember chips. Region for zero-based index `i`: `(96 * (i % 8), 96 * (i / 8), 96, 96)` with integer division. Do not rotate or mirror baked lighting. Motes/embers need restrained opacity and density; no emissive blanket across the base texture.

## Runtime integration

Existing story events select Stone (base kit), Bronze Dawn (warm dry east), Starfall (cool meadow/woodland), Ironfall (southern coal earth and known-resource aprons), and Livewire (healthy ground with edge-focused Bloom and scorched ground). The continuous shader retains eight samplers: related earth sheets share a small grid atlas, and secondary visual masks share the existing terrain-mask texture. Identical era turf sheets reuse one texture instead of GPU copies.

Fog and resource-discovery gates apply before mask generation. Bloom and burnt masks read existing patch IDs and tide state; they do not create or change tiles. `BloomLook` draws painted vine detail with the existing sample color/pulse, while `TideLook` retains object/status overlays. The base kit's river materials and contour bank remain shared. The renderer retains the kit's 20/27-tile macro coordinates and fine brush subscale (3x) so foliage reads below miniature scale. Era-only runtime mipmaps filter that fine detail at wide zoom, avoiding pixel shimmer; sprite/decal imports are unchanged.

The preview harness accepts an era and `baseline|current`; baseline holds the same scene setup while selecting the base-kit material family. Raw material scale fixtures remain useful but do not replace these real main-scene captures. Skyreach is untouched and has no renderer branch.

[Asset scale proof](asset-scale-review.jpg): literal 80 px/tile crops beside the existing 2x2 Hearth, plus 24 px/tile wide strips. This is a labeled composite, not an engine capture or final visual approval.

## Initial art-stage validation, 2026-10-19

Godot 4.7.2 import completed without errors/warnings and generated all nine PNG `.import` files. Strict editor-warning loading passed for 227 scripts. The complete `tests/run_tests.gd` suite ended `ALL TESTS PASSED`; the checked scripted input play-through ended at frame 4961 / 18.3 simulated minutes without errors/warnings. No engine code is changed by this art stage. Final CI status is tracked on PR #115.

For the initial v1 color studies, the published PR #114 inputs at `9809aae` match the recorded Starfall input hashes. `starfall-layout-check.json` records historical v1 high-frequency luminance correlation after common-size resampling (meadow 0.8236, woodland 0.7849). Visual arrangement matches, but generative recoloring is not pixel-identical; use the base-sheet palette switch if exact texel alignment is needed for the remaining meadow/woodland variants. The merged parent retains those source inputs; the v2 motif/contrast corrections are deliberately not claimed as pixel-identical recolors.
