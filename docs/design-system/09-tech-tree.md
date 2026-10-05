# Stone Age Tech Tree (29 techs, v4 as built)

Status: **v4 built** on the `stone-age-polish` branch (2026-09-30), from mockups/tech-tree-v4.md (approved by Jon).
- v4 keeps v3's 28 techs, costs and effects. Only the links, the columns and the lane order changed, so each link reads "you need X to invent Y".
- Jon's earlier asks: "more intricate and branching", "visually more appealing with arrows", "maybe just need more tech. Let's be creative. Tighten all of it."
- 2026-09-30: the **Storehouse** became its own tech (Jon's playtest: the tree "isn't following and unlocking items like a warehouse"), so there are now 29. See the decision log.
- 2026-09-30, From Hands to Haulers (14-hands-to-haulers.md, `hands-to-haulers` branch): costs now scale by tier, nine techs have ranks II and III, and the effects below are corrected to what is built. See "Costs" and "Ranks".
- Source of truth for numbers and layout: `scripts/data.gd` (TECHS, LANE_ORDER, TIER_NAMES, BUILDINGS, BONUSES). The research board is laid out from each tech's `lane`, `tier` and `slot` alone, so a layout change is a data edit.

## Shape
- 29 techs in five tiers, read left to right, then Bronze Dawn alone in the gate column.
- Five lanes, top to bottom: **Fiber, Stone, Land, Hearth, Lore**. Each lane has two rows. This order has the fewest lane-crossing lines (crossing cost 39 → 29).
  - **Fiber** (rope, hauling, water): Cordage, Nets, Rafts, Paths & Haulers, Carrying Poles, Storehouse.
  - **Stone** (tools and building): Knapping, Stone Axe, Masonry, Water Wheel, Paved Roads, Grindstone.
  - **Land** (food and people): Foraging, Gatherer's Hut, Thatched Roofs, Farming, Scouting, Irrigation, Preservation.
  - **Hearth** (fire and craft): Fire, Pottery, Smoking, Baking.
  - **Lore** (story and sky): Storytelling, Ochre, Star Lore, Megaliths, Calendar.
- 5 roots, one per lane. **Rule:** almost every tech past the roots joins two branches (21 of 23). Pottery and Star Lore have one parent.
- 51 links. 13 skip a column.
- **Critical path:** Bronze Dawn needs 19 techs, itself included. The Storehouse is on it (Bronze Dawn needs it). Stone Axe is too (Farming and the Water Wheel need it). Storytelling is too: Calendar needs it directly or through Megaliths. The other 10 are **side branches**: Thatched Roofs, Nets, Smoking, Ochre, Star Lore, Scouting, Rafts, Megaliths, Irrigation, Carrying Poles. A test checks that `side` marks exactly the techs Bronze Dawn can do without.
- **Hidden:** one node, **Star Lore**, stays out of the tree (drawn as "? ? ?") until you click the Strange Stone.

## Layout (as built)
| Lane | Tier I · roots | Tier II | Tier III | Tier IV | Tier V |
|---|---|---|---|---|---|
| Fiber | Cordage | Nets | Rafts, Paths & Haulers | Carrying Poles, Storehouse | |
| Stone | Knapping | Stone Axe, Masonry | Water Wheel | Paved Roads, Grindstone | |
| Land | Foraging | Gatherer's Hut, Thatched Roofs | Farming, Scouting | Irrigation, Preservation | |
| Hearth | Fire | Pottery, Smoking | | | Baking |
| Lore | Storytelling | Ochre, Star Lore (hidden) | Megaliths | Calendar | |

Bronze Dawn is the full-height gate card after Tier V.

## The research board (Option B, as built)
- Lane bands with 212 x 62 cards: icon, name, the one-line unlock, cost squares, and a check, lock, "ready" dot or queue number.
- Lines are neutral and orthogonal. They run only in the gutters between tiers and the channels between lanes, each on its own 7px track, never under a card. A headless test checks this. A tech may add a `via` hint in data.gd to steer a tier-skipping line into a named channel; v4 needs none.
- Hovering a card lights its whole chain (ancestors and descendants) in gold `ffd166` and dims the rest.
- "Or" parents merge at an "or" pill before the card.
- The board is 1492 px wide, so at 1280 x 800 it scrolls sideways by about a tier; it opens scrolled to the frontier. Drag to pan.
- Above the board: the research **queue** (click any far tech to queue its missing chain, researched as each becomes affordable) and **Ready to research**. Below: a strip about the hovered tech with YOUR ROUTE.

## Costs
- Each tier costs more than the one before. A tech's total cost sits in its tier's band, and a test holds it there:

  | Tier | Total goods per tech |
  |---|---|
  | I | 10 to 20 |
  | II | 25 to 60 |
  | III | 80 to 150 |
  | IV and V | 200 to 400 |
  | Bronze Dawn | 500 to 700 |

- Techs are paid in the previous tier's goods. A made good (Rope, Charcoal, Brick, Flour) only appears in a cost after the tech that makes it, one tier or more earlier. A test checks this too.
- The pacing bot (`tests/autoplay.gd`) wins in about 13.5 to 18 simulated minutes on maps 1 to 8 with these costs. The tuning is in the decision log.

## Ranks
- Nine techs have optional ranks II and III, bought on their card. Rank I is the tech itself. Bronze Dawn never needs a rank.
- Each rank costs 2.5x the one before: rank II is 2.5x the tech's cost, and rank III is 6.25x.
- A gathering tech adds +1 to its item's hand-harvest base per rank. A harvest yields base x tool x rank, and a hut's bundle is 3 harvests.
- A workshop tech gives that workshop +25% Speed per rank.

| Tech | Each rank II or III adds |
|---|---|
| Foraging | +1 Berries a harvest |
| Knapping | +1 Flint a harvest |
| Masonry | +1 Stone a harvest |
| Stone Axe | +1 Wood a harvest |
| Farming | +1 Grain a harvest |
| Ochre | +1 Clay a harvest |
| Cordage | +25% Twine Post speed |
| Fire | +25% Charcoal Pit speed |
| Pottery | +25% Kiln speed |

## Nodes
Costs as built (`scripts/data.gd`). "R" marks a tech with ranks.

### Tier I: roots
| Tech | Lane | Needs | Cost | Effect |
|---|---|---|---|---|
| Cordage (R) | Fiber | nothing | 15 Fiber | Craft Rope, Twine Post, Flax Field |
| Knapping (R) | Stone | nothing | 5 Flint, 10 Stone | Craft Flint Tools: a harvest by hand takes a 0.6s hold instead of 0.8s, and each worker holding one works 50% faster (a tool lasts 40 jobs) |
| Foraging (R) | Land | nothing | 5 Berries, 10 Fiber | Berries x2 (Yield), by hand and by hut |
| Fire (R) | Hearth | nothing | 10 Wood, 5 Stone | Charcoal Pit |
| Storytelling | Lore | nothing | 10 Berries, 10 Fiber | New Kith are born 25% faster (grow time 12s to 9s) |

### Tier II
| Tech | Lane | Needs | Cost | Effect |
|---|---|---|---|---|
| Nets | Fiber | Cordage, Foraging | 10 Rope, 20 Fiber | *side:* Fishing Weir. A new food: Fish (2) |
| Stone Axe (R) | Stone | Knapping, Cordage | 10 Flint, 15 Wood, 5 Rope | Wood x3 per harvest, a hand tool (huts get it through their bundle). A flint head hafted with cord |
| Masonry (R) | Stone | Knapping, Fire | 25 Stone, 5 Charcoal | Needed for the Water Wheel, Paved Roads, Megaliths and the Storehouse |
| Gatherer's Hut | Land | Knapping, Foraging | 20 Wood, 10 Stone | Gatherer's Hut: its worker walks out to resources within 2 tiles, but only to ones a Kith has learned by hand |
| Thatched Roofs | Land | Cordage, Foraging | 30 Fiber, 5 Rope, 20 Wood | *side:* Dwellings house 5 instead of 3 |
| Pottery (R) | Hearth | Fire | 20 Clay, 10 Charcoal | Kiln (Clay + Charcoal into Brick) |
| Smoking | Hearth | Fire, Foraging | 20 Wood, 15 Berries | *side:* Berries are worth 2 food instead of 1 |
| Ochre (R) | Lore | Storytelling, Foraging | 15 Clay, 15 Berries | *side:* Gatherer's Huts bring back twice the Clay (Yield x2, Clay only) |
| Star Lore | Lore | Storytelling, **the Strange Stone clicked** | 20 Stone, 10 Flint | *hidden, side:* Shard Cairn |

### Tier III
| Tech | Lane | Needs | Cost | Effect |
|---|---|---|---|---|
| Rafts | Fiber | Nets, Stone Axe | 50 Wood, 30 Rope | *side:* Kith can cross river tiles at a slow walk (cost 4; open ground is 1) |
| Paths & Haulers | Fiber | Cordage, Gatherer's Hut | 20 Rope, 40 Wood | Road, Wooden Bridge. Idle Kith haul, but only for buildings a Road links to the Hearth or a Storehouse; a linked hut loops on its own |
| Water Wheel | Stone | Stone Axe, Masonry | 30 Rope, 40 Wood, 20 Stone | Water Wheel: on the river, powers machines within 3 tiles |
| Farming (R) | Land | Gatherer's Hut, Stone Axe | 40 Grain, 30 Wood, 10 Rope | Field: sow grain on grassland |
| Scouting | Land | Gatherer's Hut, Storytelling | 40 Berries, 30 Wood, 10 Rope | *side:* huts reach 3 tiles instead of 2, and everyone sees 2 tiles farther |
| Megaliths | Lore | Masonry, **and** Storytelling **or** Star Lore | 60 Stone, 20 Rope | *side:* Standing Stone. Buildings right next to it (diagonals too) work twice as fast (Speed +100%) |

### Tier IV
| Tech | Lane | Needs | Cost | Effect |
|---|---|---|---|---|
| Carrying Poles | Fiber | Paths & Haulers, Stone Axe | 60 Rope, 100 Wood, 40 Charcoal | *side:* haulers carry 20 instead of 10 |
| Storehouse | Fiber | Paths & Haulers, Masonry | 60 Stone, 100 Wood, 40 Brick | Storehouse: a second stockpile that haulers drop off at and pick up from, and a depot roads can link to |
| Paved Roads | Stone | Paths & Haulers, Masonry | 100 Stone, 60 Wood, 20 Brick, 20 Rope | Roads 4x open ground, up from 2x |
| Grindstone | Stone | Water Wheel, Farming | 60 Stone, 80 Wood, 30 Brick, 30 Rope | Grindstone (Grain into Flour, 3 food) |
| Irrigation | Land | Water Wheel, Farming | 80 Clay, 80 Stone, 40 Brick | *side:* Fields touching the river grow twice as fast |
| Preservation | Land | Farming, Pottery | 60 Clay, 80 Berries, 40 Charcoal, 20 Brick | The Kith eat 25% less |
| Calendar | Lore | Farming, **and** Megaliths **or** Storytelling | 100 Grain, 40 Stone, 30 Wood, 30 Brick | Fields yield 25% more |

### Tier V
| Tech | Lane | Needs | Cost | Effect |
|---|---|---|---|---|
| Baking | Hearth | Grindstone, Pottery | 40 Flour, 80 Charcoal, 80 Brick | Flour plus a clay oven. Flour is worth 5 food, up from 3 |

### The gate
| Tech | Needs | Cost | Effect |
|---|---|---|---|
| **Bronze Dawn** | Preservation, Paved Roads, Baking, Calendar, Storehouse | 80 Brick, 60 Flour, 80 Rope, 100 Stone, 100 Charcoal, 160 Wood | End of the stone age. "Far above Solace, something is falling." |

Lore gates the era through Calendar, so story is part of progress, not flavor. The goals checklist asks for Calendar just before Bronze Dawn.

## Links changed in v4
| Tech | Was | Now |
|---|---|---|
| Gatherer's Hut | Knapping | Knapping + Foraging |
| Stone Axe | Knapping + Gatherer's Hut | Knapping + Cordage, moved to Tier II and onto the critical path |
| Thatched Roofs | Cordage + Fire | Cordage + Foraging, moved to the Land lane |
| Nets, Smoking | Tier III | Tier II |
| Farming | Foraging + Gatherer's Hut | Gatherer's Hut + Stone Axe |
| Scouting | Gatherer's Hut + Foraging | Gatherer's Hut + Storytelling |
| Water Wheel | Cordage + Knapping | Stone Axe + Masonry, moved to the Stone lane |
| Rafts | Nets + Paths & Haulers | Nets + Stone Axe |
| Grindstone | Water Wheel + Masonry + Pottery | Water Wheel + Farming |
| Carrying Poles | Paths & Haulers | Paths & Haulers + Stone Axe |
| Baking | Grindstone + Fire | Grindstone + Pottery, moved to Tier V |
| Bronze Dawn | Tier IV | after Tier V |

## What each card unlocks
- Every card's one-line `unlock` names every building and recipe the tech gates, and a test fails if one is missing, if a building names a tech that doesn't exist, or if a building can be placed before its tech.
- Only the Hearth and the **Dwelling** need no research. The build bar marks the Dwelling "Always available".

## "Or" parents
- A tech can list `requires_any` alongside `requires`. It needs all of `requires`, plus any one of `requires_any`.
- Only Megaliths and Calendar use it:
  - Megaliths: Masonry, and Storytelling or Star Lore.
  - Calendar: Farming, and Megaliths or Storytelling.
- This gives players a real choice of route. Storytelling alone opens both, so the magic hint is never on the critical path.
- **Rule:** Star Lore is never a plain requirement of anything. It only appears as one option of an "or". A test enforces this.

## The hidden node: Star Lore
- Clicking the Strange Stone (the shard tile) sets a `shard_seen` flag. The toast adds: "A new idea stirs in the tech tree: Star Lore."
- Until then, Star Lore's card, its arrow from Storytelling and its dashed branch into Megaliths are not drawn, and it can't be researched. Megaliths shows a plain arrow from Storytelling, so the "or" doesn't give the secret away.
- It unlocks the **Shard Cairn** (12 Stone), which must be built beside the Strange Stone. While one stands, every tech costs 5% less (`research_discount` 0.05 in the building's data). It stacks with Tally Sticks (the two multiply, the item is rounded once), and only one cairn counts however many are built. Its status reads "It hums. The Kith think clearer. Something far off may hear." It's drawn as a small ring of grey stones with a faint pale-cyan glow.
- **Built before the ship lands.** The first cairn records the story moment `cairn_raised`. If the Falling Star has not fallen yet, it also sets the saved run flag `cairn_before_landing` (set once, never cleared; a cairn raised after the star falls leaves it off). Nothing reads the flag yet, since the ship is not in the game. Once the Lumen arrive, it will mean the cairn guided them to the Kith, and first contact starts friendlier. The flag is the whole hook: no ship or Lumen gameplay exists until then.

## Why these edges
- **Stone Axe is the tool hub.** A flint head hafted with cord clears land (Farming), cuts timber (Water Wheel, Rafts) and poles (Carrying Poles).
- **Masonry is the stone hub.** It feeds the Water Wheel's race, Paved Roads and Megaliths.
- **Foraging feeds the food web.** The Gatherer's Hut, Thatched Roofs, Nets, Smoking and Ochre all branch from it. Each food boost (Smoking, Nets, Calendar, Irrigation, Baking) raises how many Kith you can keep.
- **Distance is part of the tree.** Haulers come before Roads, so walking feels slow first. Paved Roads, Carrying Poles and Rafts each fix a different part of that.
- **The Strange Stone pays off.** Clicking it reveals Star Lore, the first node that isn't about survival.

## How boosts stack
- Every boost is in one of two groups. **Speed** shortens each work cycle: a Flint Tool in the worker's hands (+50%), a Standing Stone next door (+100%) and workshop ranks (+25% each). **Yield** multiplies each harvest: Foraging (Berries), Ochre (Clay, huts only).
- Hand harvests: base x tool x rank. The base is 1 plus gathering ranks; the Stone Axe (x3 Wood) is the only yield tool so far; Flint Tools shorten the hold instead. A hut's bundle is 3 of those harvests.
- Boosts **add within a group and multiply across groups**. A hut with a tool and a Standing Stone works at x2.5, not x3; with a Stone Axe it brings back x3 Wood per trip, so x7.5 Wood in all.
- Side-branch boosts are big (x2) but narrow: Ochre only Clay at huts, Standing Stone only its 8 neighbours. The building panel shows the math, e.g. "20 jobs/min x Speed 2.5 (Flint Tools +50%, Standing Stone +100%) = 50 jobs/min".
- Later boosts (Bronze Tools) plug into the same two groups.

## Content this added
- **Buildings:** Fishing Weir (on grass touching the river; its worker makes Fish with no inputs), Standing Stone (30 Stone; shows its 1-tile ring while placing), Shard Cairn.
- **Items:** Fish (2 food). The Kith eat Berries, then Fish, then any Flour that research doesn't need.
- Each new building is one tile, drawn from 1 to 3 shapes as 05-art-direction.md describes.

## Changed from the v3 design
- 28 techs, not 30. The 18 built techs stay, and 10 are added. (The Storehouse came back as a 29th in playtest 4.)
- Dropped from v3: Charcoal (Fire covers it), Stonecutting (Masonry is the hub), Weaving, Ground Stone, Cultivation (Farming covers it), Roads and Storehouse (both in Paths & Haulers), Sledges, Seed Keeping, Granary, Pack Frames.
- Campfire's "Berries worth 2" moved to Smoking. There is no Smokehouse, Quarry, Pigment or Smoked Food.
- Not every tech has two parents from two lanes (see Rule above).
- The v3 mockup's side-branch tag, hover chain and pannable board opening on the frontier are built (board B, above).

## Open
- Costs are tuned with the pacing bot, not yet with a human playthrough.
- Flax can be sown (Jon, 2026-10-03): Cordage opens the Flax Field, 2 Fiber a tile, no grain. A hut set to Fiber cuts it exactly as it cuts wild flax and it never runs out; Calendar, Plough and Irrigation do not touch it.
- Calendar's +25% applies to hut harvests of sown Fields, not wild grain or hand gathering. Irrigation's "grow faster" means a hut worker harvests that Field in half the time.
- Spoiling doesn't exist, so preserving food is a flat bonus (Preservation).
- Discovery (Jon via Codex, 2026-10-05): a tech stays out of the tree until the Kith have held every item it costs and every tech it needs shows. Found items are `Economy.seen` (saved), so the fiber lane waits for flax, brick techs for the Kiln and the ore techs for ore. Researched techs always show. The board, "What to learn next", routes, tooltips and the counter all use the same list (`Research.visible_set()`), so nothing leaks early.
