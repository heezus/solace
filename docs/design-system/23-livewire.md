# Era 5: Livewire

Status: **stage 1 built** (2026-10-09), stages 2 and 3 are design only. Mechanics page, so Claude owns it. Everything marked *default* is a pick Claude made that the project owner can change; every number is a first guess to tune with the pacing bot. It follows [18](18-roadmap.md) (the shape, the Bloom and the Decided list) and picks up where [Ironfall](19-ironfall.md) ends, on the "The Wires Hum" card.

## The feeling
- Ironfall was machines and borrowed knowledge. **Livewire is rules and pressure.** The Kith stop moving stock by hand and start writing down how the town should run, while something green creeps up from the south patches and the clock is real for the first time.
- Humming and busy, with a deadline. Poles and lamps along the roads at dusk, a factory floor where there was a workshop, and at the edge of the lamplight a tide of green ground that moves a little every minute.
- **Length target:** about 20 minutes. It starts when the Wires Hum card is put away and ends on a short card of its own.

## One new thing: Standing orders
The era adds exactly one mechanic ([12](12-knowledge-is-progress.md)). Poles, factories and the tide are the content and the pressure around it.

### Rules
- Build an **Order Board** (Lore tab, one per town, no worker, near the Hearth like the Teardown Bench). It holds the town's standing orders and is where you write them. It is the era's "what the Kith know": a rule is knowledge the Kith carry out without being asked, and the number of rules you may keep grows with what they learn.
- **An order is one line:** *When* an item in the stores is below or above a number, *then* do one thing. It is picked from short lists in a small panel (item, below or above, a number, a verb, a target), with no typing and no scripting. Orders are read every few seconds, which costs the simulation almost nothing.
- **The verbs** (*default*, two in stage 1, a third later):
  - **Pause** a kind of building *while the When holds*, and it resumes the moment it stops holding ("Pause Sawmills while Planks are above 80"; "Pause Kilns while Bricks are above 40", which is how a Run is written). A paused building finishes its current job, then waits with its workers in place and its stock kept. Only workshops and mines (buildings with a job) can be paused; power, food, the Hearth and the Board cannot, so a rule cannot starve the town or switch off the net.
  - **Bring first** an item to a kind of building *while the When holds*: haulers serve that building ahead of the rest. A haul for an item that is not in stock is skipped after 60 s, so a rule can never stall a hauler. When a Pause and a Bring first meet on one building, the Pause wins.
  - **Send** (later stage): when the *When* holds and the Expedition Post is idle, send a party to a target ("when Shards are below 5, send a light party to the Strange Stone").
- **Slots are the budget.** The Board gives 3 orders. **Foremen** (tech) gives 3 more and **Chain Orders** (tech) 3 more, which also lets an order name another to run next; the cap is 9. The player spends slots on what hurts most, so the era asks "what is worth a rule" rather than "how many rules can I write".
- **Feedback.** An order that fires writes a short line to the event feed, at most one per order per minute, and the Board shows each order's last firing. A rule that has never fired for 5 minutes is marked so a mistake is easy to spot. The Goals panel notices the first working order.
- Why it fits the pillar: it is the next step after "hands, taught, dispatched, automated" ([14](14-hands-to-haulers.md)). The player's automation dream arrives as a short sentence they write once.

## The world
### The wire
- **Power Pole** (Logistics tab, wood 2 and iron 1 a tile, 1x1). Poles within 3 tiles of one another join into a **net**. A machine within 2 tiles of a pole on the net draws from the net, and so does an engine within 2 tiles of one. The Boiler's 5-tile reach and the Water Wheel still work as before for anything that is not on a net; a Boiler or Wheel near a pole simply adds to the net as well.
- **Power in units** (*default*, tuned later): a machine asks 1 unit while it works; a Water Wheel gives 2, a Boiler 3 (while lit), a **Generator** 8 and a **Shard Dynamo** 8. A net that makes less than its machines ask runs them all slower by the ratio, not some of them dark, and the panel says "Net short by 2".
- **Generator** (Workshops tab, 2x2, a Boiler and a dynamo): burns Coal like the Boiler but only while the net asks for it, and feeds a whole net. **Shard Dynamo** (later): the same on Shards (1 Shard for 160 s), needing the Heat plate Lesson as the Shard Boiler does.
- **Wire** (new item, from Copper at a **Wire Mill**, Metal tab, needs power) is the era's good: Generators, Factory Floors and the gate use it. It gives the old copper hills a second life.

### The factory
- **Factory Floor** (Workshops tab, 2x2, needs power, two workers): runs one chosen recipe from the existing list (Bricks, Rope, Iron, Steel, Tools, Wire) at three times a workshop's speed and eats inputs three times as fast. It is not a new chain; it is the answer to "I have power and orders, now I want a lot of one thing".
- **Powered Mines** (tech): a Mine on a net digs twice as fast. Coal is finite, so this is a loan from the future and the era says so.

### The tide (the clock)
Page 18 sets the tide: a living spread, not a unit; it travels along cheap ground (grass, damp), is slowed by roads, fire and shard light, and eats what is in its way. *Defaults* for Livewire:
- **Where it starts.** From the three Bloom patches in the far rows of the south land (page 19's patches, left as plain Bloom ground once their samples were taken), the tick after the Wires Hum card closes. The one by the Wreck is a sight, not a source. A front advances **one tile about every 35 s** over open ground, 3 times slower over a road or a river tile and 6 times slower over Rail or paved road. The river slows it but does not stop it: its banks are damp, which the Bloom likes.
- **What it eats.** A building on Bloom ground is **overgrown**: it stops working at once and is **lost after 3 minutes**; Fields and trees under it become Bloom ground. Stock inside is lost with the building. A building in an Arc Lamp's light or a Scorcher's reach is never lost (its 3 minutes stop counting) but stays dead until the ground is burnt clear. No Bloom ground may start within 6 tiles of the Hearth and the tide stops at that edge, so the Hearth cannot fall in this era (arrival and loss are Skyreach).
- **What it threatens first.** The coal seams lie in the first rows of the south land and the patches in the last, about 12 to 16 tiles apart, so unchecked the front reaches the first mines in about **8 minutes** and the old map's south edge in about **12**; past the river and into the town takes longer still, and the Hearth ring is further than the era runs. The mines, and so the finite coal, are the first thing the clock threatens, which is why orders ("Bring Coal first to Scorchers") matter.
- **Reading it.** **Tide Watch** (tech) draws the Bloom's front on the map as a soft line with a "reaches your outer mine in 4 min" note on the building it is heading for, worked out from the real front. Before it, the tide is visible only where the fog has been lifted.
- **Holding it.** **Arc Lamp** (Lore tab, needs power, lights 5 tiles): the tide does not enter its light, and a plain **Shard Lamp**'s light (3 tiles) only slows it to half speed, as page 18 says. **Firebreak** (Land tab, cheap, a cleared strip of ground that burns, never grows): the tide goes round it or waits. **Roads** slow it, as above.
- **Burning it back.** **Scorcher** (Workshops tab, needs power and burns Coal): clears Bloom ground within 4 tiles, one tile per 30 s. This is "burning it back needs power" ([18](18-roadmap.md)): factories and coal now have a reason.
- **What clearing gives back.** **Living Ground** (tech, the small branch of the life tree from the Bloom Lessons, [18](18-roadmap.md) Decided 3): burnt Bloom ground becomes Ash Ground, and Fields on it yield +50%. Winning ground back pays for itself, and it is the only taste of the life tree the Kith get.
- **Why this fits the Bloom.** It is learned, not walled off: the Lessons from Ironfall (what it eats, how it spreads, what it fears) are exactly what Tide Watch, Firebreaks and the Scorcher use. Every player has them, since the Ironfall gate asked for the three Bloom Lessons.

## The tech tree (Era 5): 14 techs
The same five lanes and rules as [09](09-tech-tree.md). It unlocks when the Wires Hum card is put away and draws as a fifth tab. Costs follow the tier bands and are paid in the previous tier's goods (Steel, Iron, Wire).

| Tier | Tech | Lane | Needs | Unlocks |
|---|---|---|---|---|
| 1 | Power Poles | Fiber | Livewire (Ironfall gate) | Power Pole and the net; the Wire item and Wire Mill |
| 1 | Order Board | Lore | Livewire | Order Board, 3 orders, the verbs Pause and Bring first |
| 1 | Tide Watch | Lore | Livewire, Bloom Sampling | The Bloom's front and arrival notes on the map |
| 2 | Generator | Hearth | Power Poles, Boiler | Generator |
| 2 | Arc Lamps | Lore | Power Poles, Shard Lamps | Arc Lamp |
| 2 | Foremen | Lore | Order Board, Taught Hands II | *side:* 3 more order slots |
| 2 | Powered Mines | Stone | Power Poles, Iron Tools | *side:* Mines on a net dig twice as fast |
| 3 | Factory Floor | Stone | Generator, Steel | Factory Floor |
| 3 | Scorcher | Hearth | Generator, Arc Lamps | Scorcher |
| 3 | Firebreaks | Land | Tide Watch, Iron Plough | *side:* Firebreak strips |
| 4 | Shard Dynamo | Fiber | Generator, Shard Boiler | Shard Dynamo, once the Heat plate is learned |
| 4 | Chain Orders | Lore | Foremen, Tide Watch | *side:* 3 more order slots, an order can run another, and the Send verb |
| 4 | Living Ground | Land | Scorcher, the Bloom Lessons | *side:* Ash Ground, Fields +50% on it |
| 5 | **Skyward** | gate | Factory Floor, Scorcher, Chain Orders, Shard Dynamo | Era end (see below) |

Lore-lane cards are gated by Lessons where it reads well, never by a plain requirement (the Star Lore rule). The gate cost is about 120 Steel, 100 Iron, 120 Wire, 100 Brick, plus **five standing orders written** and **the south held**: a Scorcher and two Arc Lamps burning in the south land (the Board shows both). The era ends when the town runs on rules and has made a stand against the green. The Steel and Iron come to about 300 coal through the Forge and Bloomery, on top of what the Generators and Scorchers burn, so coal is tight on purpose; the Shard Dynamo is the way out, and the pacing bot tunes it.

## Trust and the Lumen lean
- The lean keeps its mild role. **Allies** let the Lumen lend their Dynamo plans early (Shard Dynamo is a tier lower); **neighbours** change nothing; **enemies** make the tide faster near the Lumen Camp, because the Lumen will not light their end of the map for you. No lean locks a tech out.
- The tide is also a story beat for them: the Lumen know it, they hunted it across the stars, and Skyreach is where that pays.

## Ending
- Researching **Skyward** plays a short end card. A mast stands over the town with a lamp that never goes out, the hum carries up the wire, and, far above the south, something answers.
- The game keeps running so the player can keep building, as the earlier eras do. Skyreach (era 6) is the next design page.

## Staging (how it gets built)
Three stages, each its own PR with placeholder art and every art slot logged in `docs/art/requests.md`.
1. **Wires and orders.** The era's opening (a fifth tab and a Goals list), Power Poles and the net, the Generator, Wire and the Wire Mill, the Order Board and the Pause and Bring first verbs, and the Ironfall end card's line about "far to the north" changed to the south, where the tide starts. The era is playable without the tide.
2. **The tide.** The tide model, Tide Watch, overgrown buildings, Arc Lamps, Firebreaks, the Scorcher, Living Ground, Foremen and Powered Mines.
3. **Factories and the end.** Factory Floor, Shard Dynamo, Chain Orders and the Send verb, the gate and its end card.

## Saves and tests (the plan)
Optional fields only with defaults, so saves stay VERSION 1 and the frozen pre-Ironfall fixture loads unchanged. A `livewire` entry under `game` holds the orders, the tide fronts and the net is rebuilt on load. The golden pacing runs for earlier eras must not change; a stage-start and a pacing bot for the era follow the Ironfall pattern.

## Open (defaults stand until the project owner says otherwise)
- **How hard the tide bites.** *Default:* overgrown buildings are lost after 3 minutes and the Hearth ring (6 tiles) is safe, so the era cannot be lost. A gentler setting (overgrown buildings only stop working, and run again when burnt clear) or a harsher one (the ring can fall) is one number away.
- **How many verbs.** *Default:* Pause and Bring first, then Send with Chain Orders. More can come from play.
- **The gate's two asks** (five orders written, the south held). *Default:* both, so the gate rewards the mechanic and the pressure and not only a stockpile.
- Costs, speeds and the tide's rate are tuned with the pacing bot, not a human playthrough.
- Anything that changes the Bloom's nature or what the resets mean goes to [open-questions](open-questions.md) first. Nothing here does.

## What stage 1 built, and where it differs
Stage 1 is in the game (placeholder art; every slot is in [requests](../art/requests.md)). The era opens the tick after the "The Wires Hum" card is put away (`livewire_begun`, as `ironfall_begun` follows the Starfall card), a fifth research tab opens and the Goals panel switches to eight Livewire goals, the last of which says the tide is next. The Ironfall card now says the green moves "far to the south". Dev start `livewire` ([21](21-stage-starts.md)) begins on top of the steam start. The tide, Tide Watch, Arc Lamps, Firebreaks, the Scorcher, Living Ground, Foremen, Powered Mines, Factory Floor, Shard Dynamo, Chain Orders and Skyward are on the board, locked ("Opens in a later age"), so the tree is whole; only Power Poles, Order Board and Generator can be bought (`Data.ERA_BUILT_STAGE`, `Rules.tech_enabled`). Their costs are first guesses in Iron, Steel, Rope and Brick.

**The net.** Poles within 3 tiles of one another join (a chain of poles joins all of it); a machine (a building with `needs_power`) or an engine (a `power` building) within 2 tiles of a pole stands on that pole's net, the nearest pole's if two reach. A Wheel gives 2, a Boiler and a Shard Boiler 3 while lit, a Generator 8 while lit; a machine asks 1 while it would work (it has its crew, its inputs and room for its output, and no order holds it), so an idle machine asks for nothing. A net that gives less than it is asked runs every machine on it at the ratio (`given / asked`), and its cards say "Net short by N" (or "No power" when nothing on it burns). A fed engine on a net lights when the net is asked for more than the engines already burning give, in the order they were built, and goes on to burn its 25 s of Coal before it looks again; the Generator is a Boiler that reaches no tiles of its own, so it only ever feeds a net and says "Not on a net" when it stands off every one. Anything that is not on a net is exactly as before: the Boiler's 5 tiles, the Wheel's reach and every earlier era's numbers (a machine on a net that gives some power runs at the net's ratio; on one that gives none it falls back to the old reach).

**The Board.** Placing it needs the Hearth's reach and allows one. It holds 3 orders (Foremen and Chain Orders would add 3 each, the code already counts them, but they are locked). The panel is a row of buttons per order: the good (the goods the Kith have held), below or above, a number (5, 10, 20, 30, 40, 60, 80, 100, 150, 200, 300, 500 with - and +), the verb and the kind of building, and Clear. A new order has no building named and does nothing until it has. Orders are read every 3 s of game time and only while a Board stands (they are kept, and wait, if it is torn down). An order "fires" when its When begins to hold and a building of the named kind stands; the feed gets one line at most a minute for each order, the Board shows "Holding now" or "Last fired 3 min ago", and an order that is not holding and has not fired for 5 minutes (counted from when it was written, if it never has) is marked in red.

**Pause** names workshops and mines (every `processor`: the Mine, Coal Mine, Smelter, Bloomery, Forge, Wire Mill and the rest, plus the Trading Post and the Lumen Market). The building finishes the job it is on (`progress > 0`), then waits with its worker still assigned and its stock kept; haulers bring it nothing and it asks the net for nothing, but they still empty its output. It is not the Pause button (a building paused by hand frees its worker): the two are separate. Power, the Hearth, homes, huts, fields and the Board are not on its list.

**Bring first** names a kind a hauler serves, and the good it brings is the order's own: "when Coal is below 20, bring Coal first to Bloomeries". While it holds, haulers take a trip for that kind of building (a pickup or a delivery) ahead of any other kind, whatever the distance. If the targets want more of the good than the stockpile has, the others are also kept from the rest of it; after 60 s of that the claim is dropped and the others are served again, and the clock starts over once the targets are served. It is a priority, not a reservation of haulers, so with no hauler free nothing moves faster. When a Pause and a Bring first meet on a building the Pause wins (no deliveries at all).

**Where it differs from the page, and why.**
- The **Generator is 1x1**, not 2x2: every building in the code is one tile today, and a 2x2 footprint would touch placement, the roads and the overlays. It keeps the Workshops tab and its cost; the Factory Floor (stage 3) is the place to introduce a bigger footprint. The tech is gated on Power Poles and the Boiler as the table says.
- **Power Poles and the Order Board have no "Needs Livewire"** in the tree: the Ironfall gate is in the other era's board and is already learned when this one opens. They carry `after: livewire_begun` instead, like Ironfall's first techs, which keeps them out of view until the card is put away.
- **The Wire Mill's tech is Power Poles** (the table says so); the Wire item and the Mill have placeholder art and the Mill's job is the Wiredrawer.
- **Units.** A machine asks 1 only while it would work, and a net's engines light by need, so a net with nothing to do burns nothing; the page's "a Boiler or Wheel near a pole adds to the net as well" holds, and a Boiler still lights for the machines in its own 5 tiles.
- **The event feed line** reads "Standing order: When Coal is below 20: Pause Forges". The goals ask for a pole pair, a machine and an engine on one net, a Generator, the first Wire, the Order Board, a first order with a target and the first firing.
- **The gate is not built.** The page's "five orders written" and "the south held" asks, Send, Chain Orders and the tide belong to stages 2 and 3; nothing in stage 1 depends on them.
- **Saves.** `game.livewire` holds the orders (with whether each is holding and when it fired) and the clock; the nets are rebuilt when the buildings are first read after a load. A save without it loads with no orders, and VERSION is still 1.
- **The research board's stock line wraps.** With Wire there are 26 goods, and with three-digit counts the line no longer fits a 1280 window, so the goods sit in a wrapping flow (`scripts/tech_panel.gd`); the queue keeps the end of the line.

**Tests.** `tests/livewire_tests.gd` (data, opening, tab, techs, the net, the Generator, Wire) and `tests/orders_tests.gd` (the Board, Pause, Bring first, the feed, goals, saves, panels), run with `-- livewire`; `dev_tests.gd` builds the `livewire` start; the layout pass (`tests/tools/livewire_checks.gd`) walks the fifth tab, the four new build cards, the Board's card with three orders and a pole's card.
