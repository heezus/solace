# 17. Needs and upgrades: keeping the long game alive

Status: approved by Jon on 2026-10-06 with the defaults below, in build. PR 1 (Logistics) and PR 2 (Needs) are built; Tree is not. Written 2026-10-06 from Jon's playtest of the 2026-10-05 release.

## The problem
Late in a run the Kith are so automated that the game becomes a waiting game, and food stops mattering (Jon's screenshot: 144 Kith, 14,380 food, +9.5/s). Everything is free once unlocked: paved roads, bigger homes, more of the same building. The tech tree is a single lane, so there is nothing to choose. Pacing is almost too fast.

## The one idea
**Every step up asks the settlement for something it must keep producing.** Growth is paid for with goods, not unlocked for free, and every upgrade can be seen on the map. Think of it as blocks and interfaces: a Dwelling tier is a block with an input spec (needs) and an output (capacity). The upgrade is the testbench that passes when the spec is met.

## What Jon picked (2026-10-06)
| # | Ask | Decision |
|---|-----|----------|
| 1 | Waiting game, food irrelevant | Kith needs, Anno-style: bigger homes need steady food variety and goods |
| 2 | Upgrades | Visible on the map and a real choice, not a flat +% |
| 3 | Pacing | Needs and upgrades slow the mid and late game |
| 4 | Tech tree | More branches, and either/or picks that never strand a run |
| 5 | Same building again | Each copy costs more, production buildings only |
| 6 | Roads | Path, gravel, paved; drag over old road to upgrade |
| 7 | Bridges | Wood to stone in place |
| 8 | Dwellings | Upgrade themselves when their needs are met, under a player cap |
| 9 | Carts | One Kith, 3x carry, roads only |
| 10 | Beasts | Shard-touched animals; Starfall era; note only |
| 11 | Megaliths | Start lore is the only way in |
| 12 | Scouting | Click fog to send a scout; no road needed |

## 1 to 3. Needs, dwelling tiers, pacing
- **Tiers.** Dwelling, then Homestead, then Longhouse (names in `scripts/data/words.gd`, tunable). Each tier houses more Kith.
- **Needs.** Tier 1 needs food. Tier 2 needs two kinds of food plus one good (cordage). Tier 3 needs three kinds of food plus two goods (for example tools and brick). A household takes what it needs from the Hearth and Storehouses; haulers bring it. Needs are checked slowly, so a missed delivery is a warning, not a famine.
- **Upgrade.** When a Dwelling's needs have been met for a while, it asks for upgrade materials (wood, clay, brick by tier). Haulers deliver them to the site, a scaffold shows on the map, and the home changes sprite. The player sets a cap per tier (a small control on the Homes tab), so a settlement can stay small on purpose.
- **Unmet needs.** The home does not drop a tier. It stops growing and the goal line says what is missing. This avoids the lock-ups Jon worries about.
- **Why this fixes the waiting game.** More Kith means more variety and goods to keep flowing. Food stays relevant because variety, not volume, gates growth.
- **Pacing.** Stone age stays as tuned. The mid and late game stretch because upgrades take time and goods. Proposed target: the full bot run grows from about 36 min to about 50 min. The pace bot and goldens check it.

## 4. Tech tree forks
- A **fork** is two techs that both lead to the same next tech (two routes to one goal). Learning one hides the other until the shared goal is learned.
- After the goal, the other route is learned later at +50% cost, so a pick delays the other route and never strands it.
- Forks never gate a unit, a road tier or a building that the era's goals need.

## 5. Copy cost
Production buildings (workshops, mills, kilns, smelters and the like) cost 15% more for each copy already standing, up to a ceiling of 4x. Homes, roads, bridges and storage stay flat. The build bar shows the price of the next copy.

## 6 and 7. Roads and bridges
- **Roads.** Path (today's road), gravel, paved. Gravel needs gravel (clay and gravel sit on river bends); paved needs cut stone and the Masonry tech. Drag over an existing road to upgrade it, paying per tile. Nothing upgrades for free when a tech unlocks.
- **Speed.** Haulers walk faster on higher tiers (proposed 1.0, 1.25, 1.5). Hand carts need a road.
- **Build bar.** It shows the real cost of the tier being laid, which fixes the late-game mismatch Jon saw.
- **Bridges.** Click a wooden bridge with the Stone Bridge tool and pay the difference; no delete and rebuild. Passage rules from page 14 stay the same.

## 9 and 10. Carts and beasts
- **Today** a Cart Shed turns two haulers into carts that carry 2x, so two Kith carrying double gains nothing.
- **Hand cart (Bronze Dawn, The Wheel).** One Kith, carries 3x, roads only. A Cart Shed makes them from single haulers.
- **Beast cart (Starfall era).** A tamed beast pulls a cart. Not built now.
- **Beasts.** The starstuff from the fall touches native animals, which become tameable. It is the first hint of magic in living things and foreshadows the Bloom. This is a canon addition for page 16 (Starfall), pending Jon's OK; it is a note, not a build.

## 11. Megaliths
`megaliths` requires the start lore (Storytelling) and, as now, Masonry. The `star_lore` route is removed. It opens a small branch: Standing Stone and Shard Cairn.

## 12. Scouting
Clicking fog sends the nearest idle Kith out to look, so no road is needed. The scout reveals a radius around the tile and walks home. Lookouts come later: a Watchtower or a hill reveals a radius without a trip.

## Fixes with no question
- Cart Shed, Trading Post and other buildings show in the build bar before the tech tree reveals them. They stay hidden until learned.
- "Jobs filled 63 of 55": the top bar counts everyone not idle as working, but jobs counts only building slots. Show working Kith in building jobs against jobs, and list hauling, building and scouting separately.
- The bottom build bar clips on the right ("Craft by hand" cut off). That is Codex's UI lane: logged in `docs/art/requests.md`.
- New art slots are logged for Codex: road tiers, house tiers, upgrade scaffolding, hand cart, later beasts.

## Build plan (three bundled PRs)
1. **Logistics:** hidden-until-learned buildings, jobs count, road and bridge tiers with in-place upgrade, copy cost, hand cart, fog scouting.
2. **Needs:** dwelling tiers, needs, auto-upgrade with caps, pacing pass and golden re-pin.
3. **Tree:** forks, more branches, megalith gating.
Each PR is one commit per ask, with tests and the decision log. Art ships as Codex's slots land; until then the new tiers reuse current sprites with a tint.

## Open questions for Jon (decided: defaults)
Jon approved the page on 2026-10-06 and took every default.
1. Unmet needs: (a) the home only stops growing. **Decided.**
2. Pacing target for the full run: (a) about 50 min. **Decided.**
3. Copy cost ceiling: (a) 4x. **Decided.**
4. A passed-over fork route: (a) learnable later at +50%. **Decided.**
5. Megaliths: (a) still need Masonry. **Decided.**

## How PR 1 (Logistics) differs from the sketch above
- **Road tiers are build cards.** Gravel Road and Paved Road sit beside the Road in the Logistics tab, so the bar shows each tier's real price. Path costs 2 Wood; gravel 2 Wood and 2 Flint (flint comes off the river gravel); paved 2 Wood, 2 Stone and 1 Brick, with the Paved Roads tech. An upgrade pays the difference per item, so Wood is never owed twice.
- **Speed.** Path 1.0, gravel 1.25, paved 1.5 times the road pace (a path is 2x open ground, so paved is 3x). Paved Roads and Causeways no longer speed every road for free: Paved Roads unlocks the paved tier, and Causeways only the Stone Bridge, which walks at the paved pace.
- **Old saves.** A save from before tiers has none: with Paved Roads or Causeways known its land roads load as paved, otherwise as paths.
- **Copy cost** counts the Workshops and Metal tabs (kilns, pits, posts, benches, wheels, grindstones, mines, smelters, crucibles). Gatherer's Huts, Fields, Storehouses, the Cart Shed and the Lore buildings stay flat.
- **Hand cart.** One Cart Shed turns one hauler into a hand cart at 3x load (was two haulers at 2x).
- **Scouting.** Clicking fog sends the nearest idle Kith (a hauler with an empty hand counts); they look in a 5 tile radius (Scouting research adds to it) and walk home.

## How PR 2 (Needs) differs from the sketch above
- **Tiers and needs as built.** A home houses 3, 4 or 5 Kith at Dwelling, Homestead and Longhouse. Tier 1 needs one kind of food held in the stockpile (8 of it counts as in stock). Tier 2 needs two kinds of food and keeps 2 Rope in the home. Tier 3 needs three kinds of food and keeps 2 Brick and 2 Charcoal in the home. A household uses its goods once every 45 s, and haulers keep two rounds of them in the home.
- **Looks are slow.** A home checks its needs every 20 s. `met` counts up while they are met and down while they are not, and never drops a tier. Once it has run down to nothing the home houses only a Dwelling's worth, so no new Kith are born into it until the needs are met again.
- **Upgrades cost.** A Dwelling asks for the Homestead after 2 minutes of met needs: 24 Wood and 16 Clay. A Homestead asks for the Longhouse after 5 minutes: 70 Wood, 50 Brick and 10 Bronze. Haulers carry the materials, a scaffold stands while they arrive and then while the build runs (45 s and 150 s), and at most 2 scaffolds stand at once. The player sets a cap per tier on the Homes tab.
- **Art.** The map draws Codex's Homestead and Longhouse (`GrowthArt.draw_house`) and the open scaffold (`GrowthArt.draw_scaffold`) with a progress bar under it.
- **Pacing.** The bot's stone age is now 1091, 936 and 923 s on maps 1 to 3 (was 843, 843 and 777), and the whole run is about 43 to 61 min by bot (about 36 before). The pacing windows in the tests moved to match.
- **Saves.** Old saves load every home at tier 1 with all caps open. Home timers are kept to a thousandth so a save reads back the same numbers.
