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

## Tools are made by a workshop (2026-10-03, Jon's playtest)
Jon: "the tools creation is pretty annoying. That I have to make them by hand and shit the entire game."
- Crafting by hand is the first step for tools too, and it stays (it is the way in, and a fallback). Knapping also unlocks the **Tool Bench**, so the same tech that lets you craft a Flint Tool lets you build the workshop that does it for you.
- The Tool Bench is an ordinary workshop (kind `processor`, one Toolmaker, 6 s a tool, 10 Wood and 5 Stone). Before Paths & Haulers you load it and empty it by clicking, like any workshop. Once a road links it to the Hearth or a Storehouse, haulers bring it flint and wood and carry the tools to the stockpile: automated.
- It does not drain the early game. It keeps a small stock and then waits: **2 spare tools plus one for each working Kith who holds none**. Its panel says so in plain words: "Making: flint tools, 3 in stock (keeps 5 ready)", and "Enough flint tools: 5 in stock. It starts again when more are needed." Haulers stop loading it while it has enough.
- It is one building for both ages. With Bronze Tools learned and Bronze to spare it makes Bronze Tools (1 Bronze, 2 Wood, the same recipe as by hand), otherwise Flint Tools (2 Flint, 2 Wood). "To spare" means it never touches the Bronze that techs in the research queue are waiting for. It changes only between batches. Both recipes are the `RECIPES` entries hand crafting uses.
- Tools it makes are picked up and wear exactly as before: a Kith without a tool takes the best one from the stockpile, a flint tool lasts 40 jobs, a bronze tool 200.
