# Era 5: Livewire

Status: **stages 1 and 2 built** (2026-10-09 and 2026-10-12), stage 3 is design only. Mechanics page, so Claude owns it. Everything marked *default* is a pick Claude made that the project owner can change; every number is a first guess to tune with the pacing bot. It follows [18](18-roadmap.md) (the shape, the Bloom and the Decided list) and picks up where [Ironfall](19-ironfall.md) ends, on the "The Wires Hum" card.

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
- **Firebreaks and queued tiles.** A tile's crossing time is fixed when the front reaches its neighbour, so a Firebreak slows only the tiles the front has not yet queued: lay it before the front arrives. Tide Watch's arrival times treat an Arc Lamp's lit tiles as walls.

**What it eats.** A building on Bloom ground is **overgrown**: it stops working at once and is **lost after 3 minutes**; Fields and trees under it become Bloom ground. Stock inside is lost with the building. A building in an Arc Lamp's light or a Scorcher's reach is never lost (its 3 minutes stop counting) but stays dead until the ground is burnt clear. No Bloom ground may start within 6 tiles of the Hearth and the tide stops at that edge, so the Hearth cannot fall in this era (arrival and loss are Skyreach).
- **What it threatens first.** The coal seams lie in the first rows of the south land and the patches in the last, about 12 to 16 tiles apart, so unchecked the front reaches the first mines in about **8 minutes** and the old map's south edge in about **12**; past the river and into the town takes longer still, and the Hearth ring is further than the era runs. The mines, and so the finite coal, are the first thing the clock threatens, which is why orders ("Bring Coal first to Scorchers") matter.
- **Reading it.** **Tide Watch** (tech) draws the Bloom's front on the map as a soft line with a "reaches your outer mine in 4 min" note on the building it is heading for, worked out from the real front. Before it, the tide is visible only where the fog has been lifted.
- **Holding it.** **Arc Lamp** (Lore tab, needs power, lights 5 tiles): the tide does not enter its light, and a plain **Shard Lamp**'s light (3 tiles) only slows it to half speed, as page 18 says. **Firebreak** (Land tab, cheap, a cleared strip of ground that burns, never grows): the tide goes round it or waits. **Roads** slow it, as above.
- **Burning it back.** **Scorcher** (Workshops tab, needs power and burns Coal): clears Bloom ground within 6 tiles, one tile per 30 s. This is "burning it back needs power" ([18](18-roadmap.md)): factories and coal now have a reason.
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
| - | Firebreak (building) | - | Tide Watch | Step 4: Firebreaks have no research of their own; learning Tide Watch unlocks the building |
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
1. **Wires and orders (built).** The era's opening (a fifth tab and a Goals list), Power Poles and the net, the Generator, Wire and the Wire Mill, the Order Board and the Pause and Bring first verbs, and the Ironfall end card's line about "far to the north" changed to the south, where the tide starts. The era is playable without the tide.
2. **The tide (built).** The tide model, Tide Watch, overgrown buildings, Arc Lamps, Firebreaks, the Scorcher, Living Ground, Foremen and Powered Mines.
3. **Factories and the end (built, Send left for later).** Factory Floor, Shard Dynamo, Chain Orders, the gate with its two deeds and its end card.

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

## What stage 2 built, and where it differs
Stage 2 is in the game (placeholder art; the slots are in [requests](../art/requests.md)). The tide starts the tick after Livewire begins (`scripts/tide.gd`, numbers in `scripts/data/tide.gd`), seven more techs open (Tide Watch, Arc Lamps, Foremen, Powered Mines, Scorcher, Firebreaks, Living Ground; only Factory Floor, Shard Dynamo, Chain Orders and Skyward stay locked), and the Goals panel gains four lines (Tide Watch, an Arc Lamp, a Scorcher, the first Bloom ground burnt clear). Dev start `livewire_tide` ([21](21-stage-starts.md)) begins seven minutes into the tide with every tool learned.

**The creep.** A flood fill that takes time, never chance: a tile joins the Bloom 35 s after a neighbour does over open ground, 105 s over a road or a river tile, 210 s over Rail, 350 s over a Firebreak, and 70 s in the light of a burning Shard Lamp, so a map always floods the same way. It never enters the 6-tile ring round the Hearth, burnt ground, or an Arc Lamp's light (it waits at the edge and asks again every 10 s, so a lamp going dark lets it in). The three south patches are permanent sources. Plain ground, trees and Fields under it become Bloom ground (`bloom_tide`, not buildable: "The Bloom is here: burn it clear first"); ore, rivers and roads keep their own tile and only count as taken, so a road is not lost, and a road tile the Bloom stands on still carries haulers.

**What it eats.** A building on taken ground is overgrown at once: it stops (its crew waits, a home gets no goods or upgrades) and asks nothing of a net, and is lost 3 minutes later with its stock, a line in the feed and its ground turned Bloom. It is held (the count stops, it stays dead) while an Arc Lamp lights it or a Scorcher is burning within reach, and works again when the ground is burnt clear. The Hearth cannot fall.

**Holding it.** The **Arc Lamp** (Lore tab, 4 Steel, 6 Wire, 10 Brick) draws from the net and lights 5 tiles while powered. The **Scorcher** (Workshops tab, 10 Steel, 8 Wire, 20 Brick) draws from the net, burns 1 Coal per 120 s of burning, and each 30 s of burning turns the nearest Bloom tile within 6 tiles into burnt ground. The **Firebreak** (Logistics tab, 4 Wood, 1 Stone) is a 1x1 building dragged out as a line like Road, not a land action; the page's "Land tab" became Logistics. **Burnt ground** goes back to grass, is drawn with an ash tint, can be built on again, and is never taken again, so winning ground back is permanent.

**Reading it.** **Tide Watch** draws the front as an outline on the map (brighter within 30 s), puts "the Bloom reaches this in about 4 min" on the card of each building it is heading for (worked out from the real front every 3 s, up to 20 minutes ahead), says so once in the feed when the front is 3 minutes away. Without it nothing is worked out.

**The two side techs.** **Living Ground**: a Field on burnt ground yields half as much again (`Tide.ash_share`). **Powered Mines**: a Mine (or any dig building) within 2 tiles of a Pole joins its net once the tech is learned and digs twice as fast while the net is not short (`Data.POWERED_MINE_SPEED`); a Mine off a net digs as before. **Foremen** adds the 3 order slots stage 1 already counted.

**Fixes to stage 1 that stage 2 needed.** A machine held by a standing order that is mid-job still asks for power until the job is done; a machine inside a lit engine's own reach runs at full speed whatever its net does (it is powered by that engine, not rationed by the net); a Bring first claim no longer counts stock that already covers the want.

**Saves.** `game.tide` holds the clock, the taken, burnt and front tiles, the overgrown counts and the count lost; a Livewire save from stage 1 without it starts the tide on its first tick, and VERSION is still 1. Visual changes touch only `scripts/tide_look.gd` (a code-drawn wash, ash, glow, flame ring, overgrown tint and front) and the new `bloom_tide` tile, so Codex can paint over them by name.

**Tests.** `tests/tide_tests.gd`, run with `-- livewire`; `dev_tests.gd` builds `livewire_tide`; the layout pass walks the three new build cards and an overgrown building's card. Every number is a first guess to tune with the pacing bot; the Livewire pacing bot arrives with stage 3.

## What stage 3 built, and where it differs
Stage 3 is in the game (placeholder art; the slots are in [requests](../art/requests.md)), and every Livewire tech is now on sale (`Data.ERA_BUILT_STAGE` is `{5: 3}`). Six goals join the list (a Factory Floor, a Shard Dynamo, Chain Orders, five orders written, the south held, Skyward). Dev start `livewire_gate` ([21](21-stage-starts.md)) is the tide start with the three factory techs learned and the gate's price in store.

**Factory Floor** (Metal tab, 60 Brick, 40 Iron, 20 Wire; needs power; two hands). It copies one workshop from five (Twine Post, Kiln, Bloomery, Forge, Wire Mill; only the ones the Kith can build are offered) and works that recipe at three times the speed (`Data.FLOOR_SPEED`), so it makes three times as much from the same stock in the same time. The card's **Recipe** button steps through the choices (`scripts/floor_picker.gd`); stepping returns what was loaded to the stores. The choice is the building's `make` (the field the Tool Bench already uses), saved with it; a save without one loads the first workshop. Haulers feed it by the copied recipe.

**Shard Dynamo** (Workshops tab, 60 Brick, 30 Iron, 10 Steel, 20 Wire; needs the Heat plate Lesson). A Generator that burns 1 Shard per 160 s of burning instead of Coal, and gives its net 8 units. It is a `fed` power building like the Generator and uses the same net code.

**Chain Orders** adds three order slots (nine in all with Foremen) and a **While** button on each order when more than one is written: "While order 2 holds" makes an order read only while that other order is holding (`scripts/order_chain.gd`, the order's `after`, 0 for nothing). Tearing up an order frees the ones that waited on it and moves later places up. Saved with the order; an old save has no chains.

**The gate.** Skyward costs 120 Steel, 100 Iron, 120 Wire and 100 Brick, needs the Factory Floor, Scorcher, Chain Orders and Shard Dynamo, and two **deeds** (`scripts/gate.gd`): **five standing orders written** (each with a kind of building chosen) and **the south held** (a Scorcher burning and two Arc Lamps lit, all on a net, in the land eight or more rows south of the Hearth). A tech's `deeds` list sits beside `lesson` and `gift`: the research card says what is missing ("Write five standing orders", "Hold the south") and the tech cannot be bought until both are done. Researching it plays the end card (`Data.SKYWARD_*`, the Falling Star's card again) and records `skyward_raised`; the game keeps running.

**Where it differs from the page, and why.**
- **Not built: the Send verb.** Pause and Bring first stay the only verbs. Send needs a second target on an order (a destination for goods) and a choice about what a hauler does with it; it wants its own pass, and nothing in the gate depends on it.
- **Floor and Dynamo are 1x1**, as the Generator is: a 2x2 footprint still touches placement, roads and the overlays, and no stage has taken that on.
- **The Floor's recipe list** is the five workshops above, not "Bricks, Rope, Iron, Steel, Tools, Wire" by good: copying a workshop keeps the existing recipes as the one source of truth. Tools stay with the Tool Bench.
- **Allies make the Dynamo cheaper** is not built (the page's trust lean): no lean changes any Livewire number yet.
- **No Livewire pacing bot yet.** Every cost in the era is a first guess; the bot is the next piece of work. (It has since been built: see "The pacing bot and what it found" below.)

**Saves.** `make` on a Floor, `after` on an order; VERSION is still 1 and an old save loads with the defaults.

**Tests.** `tests/skyward_tests.gd`, run with `-- livewire`; `dev_tests.gd` builds `livewire_gate`; the layout pass walks the Floor's card and the While button.

## The pacing bot and what it found
`tests/autoplay_livewire.gd` plays on from the Ironfall gate to the Skyward tech through the public `Sim` calls only (it extends the Ironfall bot, so the town it starts with is one it earned from the Falling Star on). It takes the techs in the order Power Poles, Generator, Order Board, Tide Watch, Arc Lamps, Scorcher, Foremen, Factory Floor, Chain Orders, Shard Dynamo and Skyward; builds a Generator with two Poles beside it, Wire Mills on the net (up to three, by the Wire still short), the Order Board (a Gatherer's Hut is torn down for it when the Hearth's ring is full), a chain of Poles south to the coal mines, and two Arc Lamps and a Scorcher there; and writes five orders from a fixed plan. Run it with `godot --headless --path . -s tests/tools/pace.gd -- 1 90 livewire` (`quiet` for the numbers only, `coal+1500` for the what-if below).

**What it found (map 1, first run, 2026-10-14).**
- The bot reaches the Ironfall gate 26.6 min after the Falling Star (28.3 on map 2), then lays the net, the lamps and the Scorcher and holds the south 10.5 min into the era (`south_held`, `orders_written` and `burnt_clear` all by minute 37.6).
- **The coal runs out before Skyward.** The three seams hold 1500 coal in all; the Ironfall gate and its techs use about 800 of it, and the Livewire route needs about 1100 more (Steel is 1 Coal in the Forge and 2 Iron, and each Iron is half a Coal in the Bloomery) on top of what the Generators and the Scorcher burn. With the seams spent the Forges stop at 8 of the 20 Steel Foremen needs, and the Bloom, meanwhile, takes the buildings the lamps do not cover (120 lost by minute 90). With 1500 extra coal handed over when Livewire begins, the bot finishes: Skyward 46.1 min after the Falling Star, 19.5 min into the era. So the era as built can stall for good on the coal, though the tide cannot end it ("the era cannot be lost", above). Fixing that is a balance decision (more coal, cheaper Steel or a second source), left to the balance work and not retuned here.

**Ironfall's bot, fixed on the way.** From the era start it never reached the gate on maps 1 and 2 (0 coal, 9 to 14 thousand Iron Ore): the route to Bloom Sampling passes through none of Coal Seams, Ironstone, Bloomery or Boiler, so the bot never researched them, and then its overbuilt town left no room within 6 tiles of the Hearth for the Teardown Bench. It now takes those four techs first and tears a Gatherer's Hut down for the Bench, as a player would. It reaches the gate at 26.6 (map 1) and 28.3 (map 2) minutes.

## The coal fix (2026-10-19, from the AI player's first run)
The AI player (page 25) played Livewire from the earned checkpoint and got 4 of 18 goals in 13 minutes. Counted from the game's own tables, the path to Skyward needed 625 iron and 411 steel, which is about 1858 coal (an iron eats 2 ore and 1 coal, a steel eats 2 iron and 1 coal), while the ground held about 660. Jon chose both fixes:
- **Cheaper era.** Every iron and steel line in Livewire's tech costs and in the era's buildings (Wire Mill, Generator, Factory Floor, Scorcher, Arc Lamp, Dynamo, Order Board) is cut to 60%. The path to Skyward now needs about 375 iron and 247 steel, which is about 1120 coal.
- **+600 coal (removed in Step 3, see [31](31-fuel.md); Charcoal is the cushion now).** When the Wires Hum card is put away and the era begins, 600 coal is added to the seams that still hold some, split evenly (`World.deepen_seams`, `Data.LIVEWIRE_COAL_GIFT`). The seams read "N of N left" above their old 500. The ground now holds about 1260, so the path fits with a margin, and the Lumen Market swap stays a spare lever.
- **Steel waits behind iron.** While Livewire runs, a Forge does not start a batch when the stockpile holds more steel than iron (`Work.steel_waits`). Its status says so. Before this the forges turned every iron bar into steel the moment it existed and techs that need iron were never paid for.
- **The hauler label.** A full building whose roads reach a depot more than 14 tiles away no longer says only "waiting for a hauler": it says the depot is far and a Storehouse beside it would help (`Roads.depot_far`).

## Guidance (PR M)
The AI player's Livewire runs showed the era hid what it needed. Four small words fix that, with no new numbers:
- **The far seam.** When the era begins, the Lumen charts lift the fog off the nearest coal seam nobody has seen and the log says which way it lies and how far (`World.unseen_seam_tile`, `Story._chart_seam`).
- **Refusals say why.** A placement refused for want of materials now says what is short ("Not enough materials: 12 Stone short", `CardText.refusal`).
- **Who hauls.** The far-depot status adds that idle Kith are the haulers.
- **The tide's answer.** The tide's first line and the Scorcher goal now say a Scorcher beside the Generator burns the Bloom back before it arrives.
- **The wire chain.** A machine with no power now says to lay a Power Pole within 2 tiles and fuel a Boiler or Generator on that net with Coal (once Power Poles are known), and the Wire Mill's "Needs Copper" adds that Copper comes from the Smelters (`Data.NET_NO_POWER_STATUS`, `Data.INPUT_HINTS`).

## Step 4: the Bloom answers to the player

The tide used to start the tick Livewire did, at one fixed pace. Now the industry is what draws it (pillar 3: every threat has a clock you can read and an answer you can afford).
- **It wakes with the first power drawn from any engine** (a Water Wheel, a Boiler or a Generator; `Tide.units_drawn` above 0), not with the era. The first line is "The hum carries south. Something in the Bloom has heard it." `Tide.woke_at` keeps the game clock of that moment. A Livewire save without a tide waits for power to be drawn too.
- **Its pace follows the power drawn.** Seconds per open tile = 70 / (1 + P / 4), never under 20, where P is the units the machines draw now: for each net the smaller of what it is asked and what it gives, summed, read every 3 s (`Tide.units_drawn`, `Tide.step_for`). No power drawn: 70 s; 4 units: 35 s; 6 units: 28 s; 8 units: about 23 s. Roads (x3), rock and rivers (x3), Rail (x6), Firebreaks (x10) and a burning Shard Lamp's light (x2) multiply that as before, and a tile's time is still fixed when the front reaches its neighbour, so arrival times stay honest at the pace of the moment. A machine asks 1 unit (`Data.MACHINE_ASK`), so units are machines asking; the first design (/16) was tuned as if a machine drew far more, and the baseline showed towns drawing 1 to 8 units, so the pace barely moved.
- **Tide Watch says the pace.** On the card of an engine, an Arc Lamp or a Scorcher: "The Bloom moves faster while the town draws power: 24 units now, a tile every 28 s" (`Tide.pace_note`).
- **Firebreaks come with Tide Watch**: the tech "Firebreaks" is gone and Tide Watch unlocks the building; a tile still costs 4 Wood and 1 Stone.
- **Prices say what they are.** A research card says "Research (have/need): ..." and its row adds "then each Scorcher costs 6 Steel, 8 Wire, 20 Brick" (`Ui.then_builds_text`), for every tech that unlocks a building.
- **The global stock tax is gone.** The Bloom no longer eats 5% of a good a minute (page 24, pick 3 is superseded here); an overgrown building still loses its own stock when it is lost.
- **Map fairness.** Every coal seam of the south strip lies at least 12 tiles (rows plus columns) from every Bloom tile (`MapSouth.coal_bloom_faults`); a strip that fails is rerolled (attempts 12 to 40, so 200 of 200 seeds hold; about half of the first 40 seeds need a reroll).
- **The bot** lays a ring of Firebreaks (3 tiles out, the side facing the front first) round the southern mine and any Generator well out from the Hearth once Tide Watch is learned. `pace.gd baseline notide` plays the variant that lights a Generator and never answers the tide.
- **Measures** in the Livewire row of the baseline: `tide_woke_min`, `pace_every_min` (units and seconds per tile each minute), `lost_before_first_scorcher`, `lost_after_first_scorcher`, `lost_within_20_of_wake`, `firebreak_tiles`.
