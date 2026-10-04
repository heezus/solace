# From Hands to Haulers: one arc from clicking to automation

Status: **designed, being built** (2026-09-30).

Jon's playtest: "a weird disconnect in the clicking to get resources and then suddenly workers go get them... Maybe we click buildings and that sends a worker out to the spot. then when we get paths unlocked we end up getting automated workers... split up the techs into more pieces. and scale what clicking gets you as well as scale what is required."

All the defaults below are Claude's picks.

## The arc: four steps, one per resource
Each resource (Wood, Stone, Fiber from Flax, Berries, Flint, Clay, Grain) moves through these steps on its own. The player feels the handoff happen one resource at a time, not all at once.

| Step | You do | What happens | How you move on |
|---|---|---|---|
| 1. **Hands** | **Hold** on a resource tile | A progress ring fills (1.0s base). When it completes you get +yield, and it repeats while you keep holding | Harvest that resource 10 times. A Kith has watched and learned it (teach by doing, file 12) |
| 2. **Taught** | Build a hut for that resource | Its hut is unlocked, and the toast says "Aro can gather Wood now" | Place the hut |
| 3. **Dispatched** | Click the hut | Its Kith walks out, gathers a **bundle** (3x your click yield) and carries it back. One click is one trip. Clicking again while the Kith is out queues up to 3 trips | Research Paths & Haulers |
| 4. **Automated** | Lay roads, then nothing, or click to **rush** | Huts loop on their own and haulers move the goods. Clicking a working building **rushes** it: it finishes the current cycle instantly (5s cooldown per building) | Done |

Clicking never stops mattering: it goes from gathering, to dispatching, to rushing. In an idle game the click is the throttle.

## Choosing what a hut works (2026-10-03)
A Gatherer's Hut works **one** resource, by default the one nearest it. When two or more are in reach the player chooses, never by accident: while placing, a small picker by the ghost lists them (the chosen one lit; click one, or press Tab or R) and the hut goes down working it; afterwards the hut card shows a button per resource (icon and name, current one pressed). A hut put down without a choice says once which it works and what else is in reach.

## Hold to harvest (2026-09-30, Jon's call)
- You gather by **holding**, not clicking. A ring fills over the tile, and when it completes the yield pops. Holding keeps harvesting.
- Upgrades act on both parts of that: **tools shorten the hold** (Flint Tools 0.7s, Bronze 0.4s), and **ranks raise the yield**.
- UI clicks (tabs, buttons, panels) are never throttled or delayed. Only harvesting on the map has a hold time.
- Clicking a hut (dispatch) and clicking a building (rush) stay as single clicks.

## Harvest yield scales
A harvest's yield is **base x tool x rank**:
- **Base:** 1.
- **Tool:** Flint Tools x2, Stone Axe x3 (Wood only), later Bronze Tools x4.
- **Rank:** each Gathering Rank (below) adds +1 to the base, for that resource.

The top bar shows your current click yield when you hover a resource tile ("Hold: +4 Wood, 0.7s").

## Techs split into smaller steps: ranks
Every v4 tech card keeps its place on the board. On top of that, **gathering and workshop techs get ranks I to III**:
- Rank I is the tech itself.
- Ranks II and III are cheaper follow-ups that appear on the same card as pips.
- Each rank gives +1 click base for its resource, or +25% Speed for its building.
- Each rank costs 2.5x the one before it.

Ranks are optional (side progress). They give the player something small to buy between big techs. The critical path never requires them.

## Costs scale by tier
Tech costs roughly follow tier. These are targets, and the pacing bot re-tunes around them:

| Tier | Typical cost | Paid in |
|---|---|---|
| I | 10 to 20 | raw goods (Wood, Stone, Fiber) |
| II | 30 to 60 | raw goods plus the first crafted goods (Rope, Flint Tools) |
| III | 80 to 150 | crafted goods (Rope, Charcoal, Brick) |
| IV | 200 to 400 | tier-III goods (Brick, Flour) |
| V (gate) | about 600 total | a mix of everything |

Each tier is paid in the goods the tier before it taught you to make (from the research thread's recommendation 3).

## Pacing
The 20-minute target for a first stone-age run still holds. The bot plays the arc too: it clicks tiles, then dispatches, then rushes.

## Haulers need roads (2026-09-30, Jon's call)
- Researching Paths & Haulers doesn't start hauling by itself. A hauler serves a building only if a **road connects it to the Hearth or a Storehouse**. Connected means the building touches a road tile that joins the road network of that depot.
- A building with no road link shows a "Needs road" marker and status, and its hover text says what to connect. Its own worker still gathers and drops off by hand-carry trips, as before Haulers.
- Haulers walk the road network. Off-road tiles are not part of a hauler's route.
- This makes Roads part of the automation step, not a later extra. Paths & Haulers unlocks Roads, and roads are the visible sign that a building is automated.

## Rich patch: more tiles in a hut's reach (2026-10-03, from Jon's playtest)
- A hut has one worker and works one tile at a time, taking the tiles of its one resource in turn. Before this, tiles never ran out, so one tile in reach was worth exactly as much as fifty.
- Now each tile of the hut's resource in reach, beyond the first, adds **+10% Speed** (a shorter harvest), up to **8 tiles (+70%)**. Wild tiles and Fields count alike. The numbers are `PATCH_STEP` and `PATCH_MAX_TILES` in `scripts/data/tuning.gd`.
- It shows at three places: under the placement preview (and as a pill on the map: "Clay x4 · +30% speed"), on the hut's panel ("4 Clay tiles in range: +30% speed", with a live "About 51 Clay a minute"), and on a Field's Info panel ("Each field adds +10% to the hut's speed: this one is worth about +N Grain a minute", or "adds nothing" once the hut has all 8 it can use).
- Speed only shortens the harvest, not the walk, so a clay hut with 1 tile makes about 41 a minute, with 4 tiles 51 and with 8 tiles 61 (+49%). More tiles than the cap do not help and, since the hut takes them in turn, the far ones lengthen its walk: 12 tiles make 54 a minute, 24 make 48.
- A Field's other payoffs stand: +25% (Calendar), +50% (Plough), +50% (Bronze Ploughshare) more grain a harvest from sown tiles, and half the harvest time on the river bank with Irrigation. Grain is not eaten raw: a Grindstone mills 2 Grain into 1 Flour.
