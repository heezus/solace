# Units and buildings: spec

Status: **default approved for building** (2026-09-30). Jon was away, so Claude picked this and he can still revise it.
Mockup: https://claude.ai/artifact/9WgaSRvMp18nqHV24w96CY (the board "Units and buildings").

## The source art is in `sprites/`
Every piece is a 32 × 32 SVG in [sprites/](sprites/), drawn with the same primitives the game already uses (rect, circle, ellipse, polygon, line, and simple paths). You have two options:
- **Import them straight into Godot** as textures. Godot imports SVG and rasterizes it at import, so set the scale to 2 or 4 for crisp zoom.
- **Or port them to `_draw()` calls** as the stone age does today. Coordinates are in tile-local pixels, 0 to 32.

The building sprites have no ground. Draw them over the tile's terrain (grass, unless the sprite brings its own river or gravel background).

## Rules every sprite follows
- The Kith plate: a rect from (2, 2) to (28, 28) filled with `kith-plate` and a 2.5px `outline` stroke, under every Kith building.
- Every shape gets a 2px `outline` stroke, and small details 1 to 1.5px. Joins are round.
- 1 to 3 main shapes plus details, readable at 32px.
- Badges sit at the top right, at 80% size: a number in `highlight` for held output, or "!" in `alert` for blocked. Pair them with the status pill described in hud.md.

## Stone age (v3 tree)
| Sprite | File | Tech |
|---|---|---|
| Camp | camp.svg | start |
| Gatherer's Hut | gatherers_hut.svg | Foraging |
| Dwelling | dwelling.svg | Shelter |
| Quarry | quarry.svg | Stonecutting |
| Charcoal Pit | charcoal_pit.svg | Charcoal |
| Twine Post | twine_post.svg | Cordage |
| Kiln | kiln.svg | Pottery |
| Field | field.svg | Cultivation |
| Water Wheel | water_wheel.svg (draw on river) | Water Wheel |
| Grindstone | grindstone.svg | Grindstone |
| Storehouse | storehouse.svg | Storehouse |
| Granary | granary.svg | Granary |
| Smokehouse | smokehouse.svg | Smoking (side) |
| Fishing Weir | fishing_weir.svg (has its own river) | Nets (side) |
| Standing Stone | standing_stone.svg (no plate, stands on grass) | Megaliths (side) |
| Shard Cairn | shard_cairn.svg (no plate, rings the Strange Stone) | Star Lore |
| Path tile | tile_path.svg. On the map, draw it as connected lines instead (see hud.md) | Paths & Haulers |
| Road tile | tile_road.svg | Roads |
| Wooden bridge | tile_bridge_wood.svg | Roads |
| Kith / Hauler / Hauler with pack frame | kith.svg, hauler.svg, hauler_pack.svg | walking update / Pack Frames |

## Bronze Dawn (era 2, from 10-bronze-dawn.md)
| Sprite | File | Tech |
|---|---|---|
| Copper Hills (tile) | tile_copper_hills.svg, on `hill` | Prospecting |
| Tin Stream (tile) | tile_tin_stream.svg, on `gravel` | Prospecting |
| Fog (tile) | tile_fog.svg | the map grows east |
| Mine | mine.svg | Mining |
| Smelter | smelter.svg | Smelting |
| Crucible | crucible.svg | Alloying |
| Cart Shed | cart_shed.svg | The Wheel |
| Cart (unit) | cart.svg | The Wheel |
| Trading Post | trading_post.svg | Markets (side) |
| Watchtower | watchtower.svg | Sky Watch |
| Stone Bridge | stone_bridge.svg | Causeways |
| The Wanderer (sky marker and end card) | wanderer.svg | Sky Watch, The Falling Star |
| Items | item_copper_ore.svg, item_tin.svg, item_copper.svg, item_bronze.svg, item_bronze_tools.svg | |

## New color tokens (added to the design system, 2026-09-30)
| Token | Hex | Use |
|---|---|---|
| path | c8a36a | dirt paths |
| road | b3aca2 | roads, stone slabs |
| soil | 8a6a44 | Fields |
| fog | 3b4a45 | unexplored land |
| hill | 8f9b5a | Copper Hills, the Mine mound |
| copper | b87333 | copper ore and ingots |
| tin | c0c7cf | tin |
| bronze | cd7f32 | bronze, Bronze Tools |
| positive | 9fe39f | good-state UI text |
| card-done | 24475e | researched tech card |
| card-locked | 1f3b53 | locked tech card |
| gate / gate-bg | e3a857 / 3a2f1f | era gate card |

## Playtest 2 additions (2026-09-30)
| Sprite | File | Use |
|---|---|---|
| Hearth | hearth.svg | The settlement center, 2×2 tiles (64-unit sprite). It replaces the Camp, and new Kith arrive here |
| Settlement edge | tile_settlement_edge.svg | Sample of the dashed `kith` border |
| Demolish hover | demolish_hover.svg | The overlay on a building in demolish mode |
| Rubble | rubble.svg | Shown briefly after demolishing |
| Raft | raft.svg | Rafts |
| Stepping Stones | tile_stepping_stones.svg | An idea only, not in the tree |

## Flax (2026-09-30, new stone-age resource)
Flax was first drawn as reeds. Jon preferred a plant that is not tied to water, so it is a plain grass tile.
| Sprite | File | Use |
|---|---|---|
| Flax patch (tile) | flax.svg | Source of Fiber. Wild flax grows on `grass` anywhere. Draw it as a full grass tile with five slender green stems, each topped with a small blue five-petal flower and a gold center. Same 2px `outline` strokes as the other tiles. Colors: grass, stem #6f9a3c, flower #6d8fe0, center #f2c14e. It replaces the game's placeholder. |

## Stone-age item icons (2026-09-30)
The top bar, cost pips and tooltips use these instead of plain colored squares. Each is a 32-unit SVG with no plate, a bold 2 to 2.4 unit outline, and a different silhouette so it reads at 20 to 24 px. Draw them at 24 px in the top bar and 20 px in cost pips, and never fill a square behind them.

| Resource | File |
|---|---|
| Wood | item_wood.svg (a log with a cut end) |
| Stone | item_stone.svg |
| Flint | item_flint.svg (dark slate with a bright edge) |
| Fiber | item_fiber.svg (a tied bundle of flax with blue flowers) |
| Berries / Food | item_berries.svg |
| Grain | item_grain.svg (the yellow one in the top bar) |
| Clay | item_clay.svg |
| Charcoal | item_charcoal.svg |
| Rope | item_rope.svg |
| Flint Tools | item_flint_tools.svg |
| Brick | item_brick.svg |
| Flour | item_flour.svg |
| Fish | item_fish.svg |
| Star Shard | item_shard.svg |

Ochre has no icon yet, since it is a tech that boosts Clay and not a resource. Bronze Dawn items keep their own sprites (item_copper_ore, item_tin, item_copper, item_bronze, item_bronze_tools).
