# First Playable: Stone Age Loop

**Decided (2026-09-29):** the first prototype is the stone-age loop plus a lite tech tree. Goal: prove that designing, watching and advancing is fun before building anything else.

## The player's goal
Grow a Kith camp from bare hands to a self-running stone-age economy, then unlock the gate to the next era.

## Resources
| Resource | Source | Used for |
|---|---|---|
| Wood | Trees | Fire, charcoal, huts, water wheel |
| Stone | Rocks | Tools, grindstone, huts |
| Flint | Riverbeds (rare) | Flint tools |
| Fiber | Flax (wild patches on open grassland, or sown as a Flax Field) | Rope |
| Clay | Riverbanks | Pottery, bricks |
| Food | Berry bushes, later flour | Keeps workers working |

## Lite tech tree (9 nodes, interdependent)
Research costs resources. Every node needs at least one other node, so the tree is a web, not a line.

| # | Node | Requires | Unlocks |
|---|---|---|---|
| 1 | Fire | — | Campfire, Charcoal Pit (wood → charcoal) |
| 2 | Knapping | — | Flint Tools (faster gathering) |
| 3 | Cordage | — | Rope by hand, and the Twine Post (fiber → rope, automated) |
| 4 | Gatherer's Hut | Knapping | **First self-running building**: a worker auto-gathers nearby |
| 5 | Paths & Haulers | Cordage, Gatherer's Hut | Haulers move goods between buildings (stone-age belts) |
| 6 | Pottery | Fire | Kiln (clay + charcoal → brick) |
| 7 | Water Wheel | Cordage, Knapping | Power for machines next to a river |
| 8 | Grindstone | Water Wheel, Pottery | Grain → flour (better food) |
| 9 | **Bronze Dawn** (era gate) | Kiln, Grindstone, Paths & Haulers + a stockpile goal | Ends the prototype: "the next era begins" |

## Core loop
1. **Early (hands):** click to gather and craft by hand.
2. **Mid (huts):** place Gatherer's Huts; numbers start climbing on their own.
3. **Late (chains):** connect huts, kiln and grindstone with haulers so chains run hands-free; find and fix bottlenecks.
4. **Gate:** hit the stockpile goal and research Bronze Dawn.

## Build notes (as built, 2026-09-29)
- Before Paths & Haulers, buildings hold up to 10 output and you click them to collect and to load inputs. After it, everything flows to and from the Camp automatically.
- Running buildings eat food from the stockpile (berries = 1, flour = 3). No food, no work.
- The Water Wheel must touch the river and powers machines within 3 tiles.
- Code: `scripts/data.gd` holds all numbers, so balance changes happen there.

## Magic teaser (sparing)
One rare, faintly glowing stone (an ancient star shard) can be found on the map. It does nothing yet. Inspecting it shows one line of flavor text.

## Out of scope for this prototype
Prestige, the Lumen, the Bloom, combat, eras past the gate, audio, offline progress.

## Tech
Godot 4, top-down 2D grid, vector art (Advance Wars style). Built by Claude; Jon plays on Mac.
