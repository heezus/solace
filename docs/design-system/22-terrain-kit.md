# 22. Terrain kit: ground and water that read as one surface

**Status (2026-10-08):** agreed with the project owner; the kit is written, the art and the shader changes are Codex's.

## The ask
The ground and water should match the sprites' finish, look seamless rather than the same tile repeated side by side, and the map generator should be considered in the plan.

## What was found
The ground is drawn by one world-space shader from four masks (water, road wear, forest density, building wear), sampling a few seamless-ish textures with mirrored UVs at 320 to 440 world pixels. There are no ground tiles, so the usual studio answer (a 16 or 47 piece autotile set) would add seams, not remove them. The visible repetition comes from three places: one meadow texture mirrored every ~6.7 tiles, texture detail averaged down to about a quarter at the default zoom (sprites are drawn 1:1), and a river bank that is only a blend.

## The approach
Keep the continuous shader and feed it better material, in three layers.
1. **Base ground:** three non-mirrored seamless meadow sheets (base, dry, lush), two woodland floors, calm and flowing water, trodden earth and a southern earth. 96 source pixels per tile, 20 tiles per sheet. The shader mixes two scales of the base that share no repeat, plus the variants by low-frequency noise, so no pattern repeats within view.
2. **Decals:** a transparent atlas of tufts, flowers, pebbles, leaf litter and reeds, placed per tile by the existing map-seeded hash and kept off roads and aprons. This is what makes the ground look painted at the sprites' level rather than blurry.
3. **Edges:** a painted bank strip laid along the water contour, and noise-broken transitions between ground families (palette rule: neighbours share two mid-tones).

## The template and the preview
Codex gets numbered template sheets with the tile grid, wrap-edge colors and the light direction, and a screenshot script that renders the real ground on a generated map (`tests/tools/terrain_preview.gd`). All in `docs/art/terrain-kit/`. Light comes from the upper left, as for the sprites.

## Map generation
Nothing in the generated tiles needs to change for the art. The generator already produces a height field and a wetness field per map (`MapTerrain`); they are not yet visible to the renderer. The offer to Codex: if the shader wants them (drier meadow on high ground, damper near the river, so the biome follows the land), Claude exposes them as two extra mask channels. Derived from the seed, so no save change. The Ironfall land is already identifiable by row. Smoother shore shapes would need the river path to be less blocky; defer until the bank strip shows whether the current river reads well.

## Not decided
- Whether Codex keeps one shader or splits the ground and water layers (their call).
- Biome channels from the generator (offered, not yet requested).
