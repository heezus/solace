# From Hands to Haulers: one arc from clicking to automation

Status: **designed, being built** (2026-09-30).

Jon's playtest: "a weird disconnect in the clicking to get resources and then suddenly workers go get them... Maybe we click buildings and that sends a worker out to the spot. then when we get paths unlocked we end up getting automated workers... split up the techs into more pieces. and scale what clicking gets you as well as scale what is required."

All the defaults below are Claude's picks.

## The arc: four steps, one per resource
Each resource (Wood, Stone, Fiber from Flax, Berries, Flint, Clay, Grain) moves through these steps on its own. The player feels the handoff happen one resource at a time, not all at once.

| Step | You do | What happens | How you move on |
|---|---|---|---|
| 1. **Hands** | **Hold** on a resource tile | A progress ring fills (0.8s base). When it completes you get +yield, and it repeats while you keep holding | Harvest that resource 10 times (6 for the very first one). A Kith has watched and learned it (teach by doing, file 12) |
| 2. **Taught** | Build a hut for that resource | Its hut is unlocked, and the toast says "Aro can gather Wood now" | Place the hut |
| 3. **Dispatched** | Click the hut | Its Kith walks out, gathers a **bundle** (3x your click yield) and carries it back. One click is one trip. Clicking again while the Kith is out queues up to 3 trips | Research Paths & Haulers |
| 4. **Automated** | Lay roads, then nothing, or click to **rush** | Huts loop on their own and haulers move the goods. Clicking a working building **rushes** it: it finishes the current cycle instantly (5s cooldown per building) | Done |

Clicking never stops mattering: it goes from gathering, to dispatching, to rushing. In an idle game the click is the throttle.

## Hold to harvest (2026-09-30, Jon's call)
- You gather by **holding**, not clicking. A ring fills over the tile, and when it completes the yield pops. Holding keeps harvesting.
- Upgrades act on both parts of that: **tools shorten the hold** (Flint Tools 0.6s, Bronze 0.4s; bare hands 0.8s), and **ranks raise the yield**.
- UI clicks (tabs, buttons, panels) are never throttled or delayed. Only harvesting on the map has a hold time.
- Clicking a hut (dispatch) and clicking a building (rush) stay as single clicks.
- **A hold forgives a shaky hand (2026-10-03).** A pointer that slides to the next tile of the same kind keeps the ring. A slip onto bare ground, a bar or another kind of tile, and a click that lets go early, keep their progress for 0.6s: come back to the tile in time and the ring carries on, so a run of short taps adds up to a harvest. The waiting ring stays drawn, fading. Holding is still the fastest way: a tap run takes about 1.2s of a 0.8s ring.

## Harvest yield scales
A harvest's yield is **base x tool x rank**:
- **Base:** 1.
- **Tool:** Flint Tools x2, Stone Axe x3 (Wood only), later Bronze Tools x4.
- **Rank:** each Gathering Rank (below) adds +1 to the base, for that resource.

The top bar shows your current click yield when you hover a resource tile ("Hold: +4 Wood, 0.6s").

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
| III | 60 to 150 | crafted goods (Rope, Charcoal, Brick) |
| IV | 200 to 400 | tier-III goods (Brick, Flour) |
| V (gate) | about 600 total | a mix of everything |

Each tier is paid in the goods the tier before it taught you to make (from the research thread's recommendation 3).

## Pacing
The 20-minute target for a first stone-age run still holds. The bot plays the arc too: it clicks tiles, then dispatches, then rushes.

### The first minutes (2026-10-03, from Jon's playtest)
Jon: "the early game is kinda slow and wonky with clicking, but once I got roads oh boy was that fucking fun." So the hand phase is trimmed and roads come sooner, without losing the arc (hands, taught, dispatched, automated):
- The base hold is 0.8s (was 1.0s) and Flint Tools 0.6s (was 0.7s); Bronze Tools stay 0.4s. Ore keeps its pace (copper 2.4s, tin 3.2s by hand, scaled with the base).
- The very first resource a Kith learns takes 6 harvests, every later one 10.
- Paths & Haulers costs 20 Rope and 40 Wood (was 30 and 50). It still needs only Cordage and the Gatherer's Hut.
- The Goals ask for Rope, Haulers and the first road before the Charcoal Pit (nothing waits on the pit).
- Pacing bot, maps 1 to 8: first hut placed at 79 s (was 98 s), first trip about 96 s (was 120 s), Paths & Haulers researched about 286 s (was 332 s) and the first road laid a second later. The stone age is still won in 12.9 to 16.3 min (mean 14.1, was 14.3).

## Haulers need roads (2026-09-30, Jon's call)
- Researching Paths & Haulers doesn't start hauling by itself. A hauler serves a building only if a **road connects it to the Hearth or a Storehouse**. Connected means the building touches a road tile that joins the road network of that depot.
- A building with no road link shows a "Needs road" marker and status, and its hover text says what to connect. Its own worker still gathers and drops off by hand-carry trips, as before Haulers.
- Haulers walk the road network. Off-road tiles are not part of a hauler's route.
- This makes Roads part of the automation step, not a later extra. Paths & Haulers unlocks Roads, and roads are the visible sign that a building is automated.
