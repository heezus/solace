# Era ground families

Owner brief: 2026-10-19. Branch: `codex/era-ground`. Parent contract: [terrain kit](../README.md) and [design page 22](../../../design-system/22-terrain-kit.md).

## Delivery state

Art phase: eight sheet candidates and a 32-cell decal atlas are painted and packed. Starfall studies use the kit worker's current meadow/woodland layouts; recheck their recorded input hashes after merge. These assets are not loaded by production. Integration waits for `codex/terrain-kit` to merge, as requested by the owner. Wide/close acceptance and per-era seeds 3, 11, 42 remain pending; an asset inspection is not a gameplay screenshot.

## Material contract

All seamless ground sheets are 1920×1920, representing 20×20 tiles at 96 source pixels per tile. Upper-left light and lower-right shadows. Repeat in both axes without mirroring. No landmark exceeds six tiles (576 source pixels); material detail stays much smaller. Each family uses a compact palette and its adjacent surfaces share two middle colors. Transparent decal cells are 96×96 with clear gutters and baked lower-right shadows. Decal placement must use the kit's map-seeded visual hash, never gameplay RNG.

Starfall meadow and woodland must preserve the final kit base layouts. Bronze Dawn supplies warm dry hill earth with restrained patina; tin gravel remains a decal. Ironfall extends the southern-earth slot below `world.base_height`, with a separate darker resource apron. Livewire supplies healthy ground, creeping Bloom ground and scorched firebreak. Existing Bloom patch IDs and sample identities remain intact. Skyreach is concept only.

## Planned interface

| Family | Sheets | Decals / overlay |
|---|---|---|
| Starfall | layout-matched meadow and woodland | pale cyan motes, glass shard chips |
| Bronze Dawn | dry hill ground | copper-green flecks, tin-grey gravel |
| Ironfall | southern earth, dark resource apron | cinders, ash, slag |
| Livewire | healthy ground, Bloom growth, firebreak | creeping green/magenta edges, sparse embers |

Files use a dedicated `art/rendered/era-ground/` namespace until the merged kit defines final loading. No tile IDs, terrain generation, simulation, footprints or save formats change.

## Provenance

Painted originals are generated with the built-in imagegen tool. Exact prompts, source dimensions, hashes and any packing steps accompany the selected assets. Do not claim a resized image is a native 1920-pixel original. All eight seamless-sheet originals are 1254×1254 (62.7 native generated pixels per logical tile). The final 1920×1920 sheets are Lanczos-packed to the required 96-pixel sampling contract, then mechanically made periodic with periodic-plus-smooth decomposition; no new painted detail is synthesized and no mirroring is used. Exact outer texels match on both axes. This does not make the sources native 1920 masters or establish the close-view pass; retain that limitation for review.

`pack_assets.py` reproduces the mechanical preparation. `sources.json` records source and packed SHA-256, dimensions and mean RGB. Full generation prompts are in `prompts.json` and the named prompt text files. The first decal atlas and its unsuccessful edit are rejected because they retain ground backing. The accepted replacement uses loose objects; packing trims the empty 10% outer source-cell gutter (including faint generation guide artifacts), fits each cell within 76×76 of its 96×96 slot, and preserves original alpha. It does not key colors or fabricate transparency.

Eight `*-wrap-review.jpg` images show literal 2×2 repeats for inspecting discontinuities. These are asset proofs, not game screenshots; the shader still needs to break the visible material repeat at unrelated scales. The [before captures](before/README.md) are actual production screenshots on the three requested seeds, but only the unchanged harness's default era. Per-era after captures remain pending.

## Skyreach concept (no wiring)

Skyreach ground is exposed high rock interrupted by shallow pockets of thin soil and small wind-bent grass, so the map feels elevated and open without changing its logical tile scale. Cool slate planes catch the same upper-left light as the buildings; narrow warm-grey soil seams and muted olive grass share two mid-tones with the rock, keeping transitions clean. Short grass leans consistently with the wind while rock chips and worn striations remain small enough to avoid repeating landmarks. The sketch is a material study only: no floating-island mechanics, new resources, water behavior or era implementation is implied.

## Packed candidate paths

All paths below are beneath `art/rendered/era-ground/`. They are **not loaded** by the current renderer.

| File | Use after kit merge |
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

## Integration gate

After the parent kit merges: recheck Starfall input hashes against merged base sheets, preserve the base layout through palette selection, wire era materials through the same shader, paint mask transitions without changing tiles, replace only the ground decoration portion of `BloomLook` where the painted sheet is cleaner, retain animated sample identity, and update `terrain_preview.gd` to select each era and cover the actual east/south/Bloom/firebreak areas. Run all 3 seeds × 4 eras and inspect wide and close pairs. Water remains the parent kit's material. No request for a gameplay/schema change is needed.

[Asset scale proof](asset-scale-review.jpg): literal 80 px/tile crops beside the existing 2x2 Hearth, plus 24 px/tile wide strips. This is a labeled composite, not an engine capture or final visual approval.
