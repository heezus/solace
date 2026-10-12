# Terrain kit (for Codex)

How to paint the ground and water so they match the sprites and read as one surface, not a texture repeated. The design behind it is [page 22](../../design-system/22-terrain-kit.md); this page is the working brief.

## What the game does today (read this first)
The ground is **not a grid of tiles**. `scripts/world_ground.gd` writes four masks for the whole map (R water, G road wear, B forest density, A building wear) and `art/rendered/terrain.gdshader` paints every screen pixel from them, sampling `meadow-ground`, `woodland-ground`, `calm-river` at 320 to 440 world pixels per repeat with **mirrored** UVs. So an autotile set (47 edge pieces, dual grid) is the wrong tool: the blends between ground, forest, river and road are already continuous. What shows as repetition is the texture, not the grid:
- one meadow texture mirrored every ~6.7 tiles, so the same patches come back (see [today-south.png](examples/today-south.png), the mottled patches);
- ground texture sampled at about 4 source pixels per screen pixel at the default zoom, so it is soft next to sprites that are drawn 1:1;
- a river bank that is a blend, with no painted lip or outline (see [today-bank.png](examples/today-bank.png)).

## What to paint
All sizes assume **96 source pixels = one map tile** (twice the default 48 px, so the closest zoom, 80 px per tile, is still sharp). Light comes from the **upper left**; shadows fall to the lower right (the yellow sun on each template shows it). Keep the sprites' dark-outline weight and saturation as the reference.

| Slot | File to add or replace | Size | Notes |
|---|---|---|---|
| Meadow, three variants | `meadow-a.png`, `meadow-b.png`, `meadow-c.png` | 1920x1920 each | **Seamless without mirroring** (left edge continues into right, top into bottom). A is the base; B is drier and paler; C is lush and darker. Same palette family so blends stay clean. Template: [ground-seamless-1920.png](templates/ground-seamless-1920.png). |
| Woodland floor, two variants | `woodland-a.png`, `woodland-b.png` | 1920x1920 | Leaf litter, roots, moss. Darker than meadow, shares its mid-greens. |
| Water, flowing and calm | `water-flow.png`, `water-calm.png` | 1920x1920 | Seamless in both directions; flow reads along the vertical axis (the shader scrolls it down). |
| Trodden earth | `earth.png` | 1920x1920 | Worn path and building aprons. |
| Southern earth (Ironfall) | `earth-south.png` | 1920x1920 | Drier, darker earth with coal dust; sits under y >= `world.base_height`. |
| Decals | `decals.png` | 768x384, 8x4 cells | One cell = one tile, numbered 1 to 32 on [decal-atlas-768x384.png](templates/decal-atlas-768x384.png). Cells 1 to 8 grass tufts, 9 to 12 flowers, 13 to 18 pebbles and stones, 19 to 24 leaf litter and mushrooms, 25 to 32 reeds, bank stones and driftwood. Transparent background, subject near the cell center, **drop shadow baked toward the lower right**. |
| Bank strip | `bank.png` | 1920x192 | Land on the top tile, water on the bottom tile, the waterline in the middle. Seamless left to right. A painted lip (dark outline), a lighter shallow band, wet stones. Template: [bank-strip-1920x192.png](templates/bank-strip-1920x192.png). |

Rules for every seamless sheet:
1. The edge bars on the template (magenta left/right, cyan top/bottom) must carry the same pattern on both sides, so the sheet wraps. Test by tiling a 2x2 copy.
2. No feature larger than about 6 tiles (576 px) and no single strong landmark (a big flower, a lone rock): a repeat would show. Put landmarks in the decals.
3. Mean brightness and hue within a few percent across the sheet, so a tile does not look like a patch.
4. Each ground family keeps a small palette (about 5 colors plus highlights); neighbours (meadow and woodland, meadow and earth) share two mid-tones so a blend never turns muddy.

## What the shader should do with them (Codex owns `terrain.gdshader` and `world_ground.gd`)
1. **Stop mirroring.** Use `repeat_enable` and `fract(uv)`; the sheets above wrap by design.
2. **Break the repeat three ways:** sample meadow A at two scales that share no common repeat (for example 20 and 27 tiles) and mix by noise; blend B and C over A with low-frequency noise (wavelength 30 to 60 tiles); add a slow brightness drift (a few percent). Together nothing looks tiled.
3. **Decals:** scatter by the per-tile hash `Rendered.variant(tile, count, family, map_seed)` (same map, same decals, independent of the simulation RNG), drawn above the ground and below sprites; thin out near roads and building aprons, thicken near the river and in forest shade.
4. **Bank:** sample `bank.png` along the water mask contour (the mask gradient gives the direction) instead of the plain blend. Corners and river ends need no extra pieces because the contour is continuous.
5. **Transitions:** keep the mask blends but break the boundary with noise (the existing `noise_field` calls) so a forest edge is ragged, not a smooth gradient.

## Check your work
`tests/tools/terrain_preview.gd` renders the real ground in the real game on a generated map and writes seven screenshots (town, wide, close, river bank, open meadow, forest edge, the new land south). It needs a window, so run it normally, not `--headless`:

```
godot --path . -s tests/tools/terrain_preview.gd -- 3 /tmp/terrain_shots
```
The first argument is the map seed (try 3, 11, 42), the second the output folder. Compare against [today-south.png](examples/today-south.png). Pass when: at the wide view you cannot find the same patch twice, at the close view the ground has the same outline and highlight weight as the trees and rocks, and the bank reads as drawn. If you want the template sheets again, `godot --headless --path . -s tests/tools/terrain_templates.gd` rewrites them.

## What Claude will do on the generator side
`MapTerrain` already makes a `height` field and a `wet` field for every map. When you want them as shader inputs (drier meadow on high ground, damp ground near the river, so the biome follows the land instead of only noise), say so in `docs/art/requests.md` and Claude will expose them as two extra mask channels in a small PR. Nothing changes in tiles, ids, saves or the map generated for a seed. The south land is already identifiable by row (`y >= world.base_height`).

Note that the shader, texture names and `Rendered.sheet` loading are yours to change; new files in `art/rendered/` need Godot's `.import` files, which Codex's Godot generates.
