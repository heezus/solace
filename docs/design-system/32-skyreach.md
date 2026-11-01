# 32. Skyreach (Step 8A)

Era 6, mechanic **Survey the sky**, beat **the Bloom arrives**. Spec: the director's Step 8 (2026-10-31). Code: `scripts/skyreach.gd` (the block, `sim.skyreach`), `scripts/data/skyreach.gd` (`Data.SKYREACH`, every number and word), `Tide.land`.

## When
- **Run 1 is unchanged.** Skyward still ends the first telling and its card reads as it always did. The goldens do not move.
- **From run 2 on** (`carry.is_first()` false), Skyward does not end the run. Once its card is put away `Story.update` records `skyreach_begun`; the card says "The sky is open" and the goals list becomes the Skyreach's (`Data.SKYREACH["goals"]`).
- **The end.** The third stage records `skyreach_done`; the endings card (Set out) opens there from run 2 on, and its title is "The Skyreach stands". `GameMenu.set_out_open` follows the same rule.

## Survey the sky
- The map is cut into **6 sectors** round the Hearth (`Skyreach.sector_of`), 60 degrees each, 0 east then clockwise, each centred on the direction it is named for (east, south-east, south-west, west, north-west, north-east).
- A **Signal Tower** (Wire 16, Brick 15, Shard 1, sight 12; no Steel, which some maps have little of after Livewire) surveys the sector it stands in. One tower, one sector; two in one sector survey it once. A tower the Bloom has taken surveys nothing.
- The **first** Signal Tower finds the **site** of the Skyreach: of the open grass tiles 8 to 20 tiles from the Hearth in its own sector that a road can reach (within `site_walk` 40 steps of a depot or a road that reaches one, over roads and open ground a road goes on, with an open side to start from; so not across a river, round a long way, or boxed in by fields and buildings), the one furthest from the Bloom (up to 8 tiles), nearer the Hearth on a tie, with fog lifted round it. So the first tower's sector is the player's choice of where the Skyreach goes; a sector with no such tile gives the best tile anywhere. (The first measure put the site in ground the tide later covered, and the Skyreach stood cut off.) (Design call: the spec says the Watchtower is upgraded; it is a separate building here, so the Watchtower and every save stay as they are.)

## The floor of stores (design call, director 2026-11-01)
When the sky opens (run 2 on) the stores are topped up to **Wire 100 and Steel 30** wherever they are lower (`Skyreach._share`, `Data.SKYREACH["floor"]`); a store already above that is not touched. The log says "The Lumen share what they salvaged", or "Scavengers bring what they found" when the Lumen are enemies. **Why:** the Cataclysm start of run 3 map 1 had Wire 0 and Steel 0. The Skyreach's haulers carry off what is made, the Bloom cut the pole net, and with empty stores the cut could never be mended nor a Scorcher bought, so that town was lost (the same start with no landfalls stands in 12.1 minutes; with them it took 28.9). Any player would hit the same wall. Numbers are in the Step 8 report.

## Landfalls
- Waves from **180 s** after the era begins, then every **120 s**. Wave k has `2 + floor(k / 3)` falls, at most 4. Each fall is 10 to 36 tiles from the Hearth, on ground a seed can land (grass, tree, gravel, berry, grain, flax), at least 6 tiles from the other falls of its wave. A map falls the same way every time: the generator is seeded from the map seed and the wave.
- A wave is planned 90 s before it falls. A **surveyed** sector shows its landfalls on the map and in Sight (`Skyreach.marked`: position and seconds to go) and the log says "A landfall is coming in the west in 90 seconds". An unsurveyed sector gives no warning: the log says "Something fell in the dark, far off".
- **A seed burns out near a Scorcher (design call, director 2026-11-01).** A fall that lands where a lit Arc Lamp keeps the Bloom off, or within reach (6 tiles) of a burning, powered Scorcher, takes no ground there (`Tide.scorched`; the lamp's light already did this). So meeting a warned fall with a Scorcher pays off. Measured on the four bot starts it changed no time (the Scorcher is seldom there in time: see the run 3 note in the Step 8 report), so it is kept as the player's tool, not as balance.
- A fall starts a Bloom patch of radius 2 (`Tide.land`), which then spreads as the tide does. **Scorchers, Arc Lamps, Wards, Firebreaks and shard light stop it exactly as they stop the tide**; the Skyreach itself is immune (`Tide.IMMUNE`).

## The Skyreach
- Build the **Skyreach** (Stone 20) on the site; no other tile takes it, and only one stands. It is raised in **three stages**, each one delivery: haulers bring the whole stage at once (`Haulers.stock_wanted` -> `Skyreach.wanted`), then the stage takes **270 s**, or **189 s** when the Lumen help (lean allies or neighbours: -30%; enemies build alone).
- Stage 1 Steel 30, Stone 400. Stage 2 Wire 120, Shard 4. Stage 3 Steel 30, Wire 60, Brick 200, Rope 120, Copper 120, Shard 3.
- Shards are chipped off the Strange Stone by hand (5 s a hold); the era asks 7 for the stages and 3 for the towers.

## The tower's ground holds (design call, director 2026-11-01)
- For every run: the Skyreach tower's tile, and the road tiles that link it to a depot (the shortest road path from the tower's sides to a depot), cannot be overgrown by the Bloom (`Skyreach.holds`, read by `Tide._state`). A player cannot be locked out of their own Skyreach by a Bloom that closes round the tower.
- It holds only roads that still stand when the tower is placed: it cannot restore a road the Bloom has already taken. In the chain-built run 3 on map 1 the roads were gone before the tower, so this alone did not finish that cell (Step 8 report).

## Pace
A chain-built run 3 start (Cataclysm) on map 1 carries over about 1500 tiles of Bloom with every Copper Hill under it: the bot there trades its surplus for Copper and Wire at Trading Posts and rebuilds works on clear ground, and still ends with the Bloom round the tower (Step 8 report).

Bar: about 15 minutes, 10 to 20; the 6-minute floor for an era played twice before stays. Numbers in `Data.SKYREACH` are first guesses tuned with the bots (`tests/autoplay_skyreach.gd`, `pace.gd skyreach from=<a run from the end of Livewire>`). The result is in the Step 8A report.

## Saves
Run saves carry the block under `game.skyreach` (site, when the era began, the planned falls, the sectors told); a save from before has none and plays as if the era had not begun.

## Tests
`tests/skyreach_tests.gd`: run 1 ends at Skyward, run 2 goes on, a tower surveys its sector, a surveyed landfall is marked 90 s ahead, an unsurveyed one is not, a fall starts a patch, the site is the only place, three deliveries raise it and open the endings card, help shortens a stage, the save keeps the sky.
