# Era 5: Livewire

Status: **design, nothing built** (2026-10-09). Mechanics page, so Claude owns it. Everything marked *default* is a pick Claude made that the project owner can change; every number is a first guess to tune with the pacing bot. It follows [18](18-roadmap.md) (the shape, the Bloom and the Decided list) and picks up where [Ironfall](19-ironfall.md) ends, on the "The Wires Hum" card.

## The feeling
- Ironfall was machines and borrowed knowledge. **Livewire is rules and pressure.** The Kith stop moving stock by hand and start writing down how the town should run, while something green creeps up from the south and the clock is real for the first time.
- Humming and busy, with a deadline. Poles and lamps along the roads at dusk, a factory floor where there was a workshop, and at the edge of the lamplight a tide of green ground that moves a little every minute.
- **Length target:** about 20 minutes. It starts when the Wires Hum card is put away and ends on a short card of its own.

## One new thing: Standing orders
The era adds exactly one mechanic ([12](12-knowledge-is-progress.md)). Poles, factories and the tide are the content and the pressure around it.

### Rules
- Build an **Order Board** (Lore tab, one per town, no worker, near the Hearth like the Teardown Bench). It holds the town's standing orders and is where you write them. It is the era's "what the Kith know": a rule is knowledge the Kith carry out without being asked, and the number of rules you may keep grows with what they learn.
- **An order is one line:** *When* an item in the stores is below or above a number, *then* do one thing. It is picked from short lists in a small panel (item, below or above, a number, a verb, a target), with no typing and no scripting. Orders are read every few seconds, which costs the simulation almost nothing.
- **The verbs** (*default*, three in stage 1, a fourth later):
  - **Run** or **Pause** a kind of building ("when Planks are above 80, Pause Sawmills"; "when Bricks are below 40, Run Kilns"). A paused building keeps its workers and stock and simply does not start a job. This is the stockpile cap the genre taught the player to want.
  - **Bring first** an item to a kind of building: haulers serve that building ahead of the rest while the *When* holds ("when Coal is below 30, bring Coal first to Boilers").
  - **Send** (later stage): when the *When* holds and the Expedition Post is idle, send a party to a target ("when Shards are below 5, send a light party to the Strange Stone").
- **Slots are the budget.** The Board gives 3 orders. **Foremen** (tech) gives 3 more, **Chain Orders** (tech) lets an order name another to run next, and the cap is 9. The player spends slots on what hurts most, so the era asks "what is worth a rule" rather than "how many rules can I write".
- **Feedback.** An order that fires writes a short line to the event feed, at most one per order per minute, and the Board shows each order's last firing. A rule that has never fired for 5 minutes is marked so a mistake is easy to spot. The Goals panel notices the first working order.
- Why it fits the pillar: it is the next step after "hands, taught, dispatched, automated" ([14](14-hands-to-haulers.md)). The player's automation dream arrives as a short sentence they write once.

## The world
### The wire
- **Power Pole** (Logistics tab, wood and a little iron a tile, 1x1). Poles within 3 tiles of one another join into a **net**; every machine within 2 tiles of a pole on the net draws power from any engine on that net. The Boiler's 5-tile reach and the Water Wheel still work as before; a net is how power crosses the map.
- **Generator** (Workshops tab, 2x2, a Boiler and a dynamo): burns Coal like the Boiler but only on demand, and feeds a whole net. **Shard Dynamo** (later): the same on Shards, needing the Heat plate Lesson as the Shard Boiler does.
- A net that makes less than its machines ask for runs them all slower, not some of them dark, and the panel says "Net short by 2".
- **Wire** (new item, from Copper at a **Wire Mill**, Metal tab, needs power) is the era's good: poles, the gate and the factories use it. It gives the old copper hills a second life.

### The factory
- **Factory Floor** (Workshops tab, 2x2, needs power, two workers): runs one chosen recipe from the existing list (Bricks, Rope, Iron, Steel, Tools, Wire) at three times a workshop's speed and eats inputs three times as fast. It is not a new chain; it is the answer to "I have power and orders, now I want a lot of one thing".
- **Powered Mines** (tech): a Mine on a net digs twice as fast. Coal is finite, so this is a loan from the future and the era says so.

### The tide (the clock)
Page 18 sets the tide: a living spread, not a unit; it travels along cheap ground (grass, damp), is slowed by roads, fire and shard light, and eats what is in its way. *Defaults* for Livewire:
- **Where it starts.** From the four Ironfall Bloom patches (the three sample sites in the south and the one by the Wreck), the tick after the Wires Hum card closes. A patch's front advances **one tile about every 90 s** over open ground, 3 times slower over a road and 6 times slower over Rail or paved road. It does not cross the river by itself; a patch on the town's side of the river is the only way the tide reaches it there.
- **What it eats.** A building on Bloom ground is **overgrown**: it stops working at once and is **lost after 3 minutes** unless an Arc Lamp or Scorcher reaches it first; Fields and trees under it become Bloom ground. Stock inside is lost with the building. The Hearth, its 6-tile ring and the Lumen Camp are never taken in this era; the tide pushes against them and the player feels it, but Livewire cannot be lost. (Arrival and loss are Skyreach.)
- **What it threatens first.** The south land is where the coal and the iron are, so the Coal Mines and Iron Hills fall first. At the default speed the first mines are touched a few minutes in and the outer town about 10 minutes in, if nothing is done. That is the clock, and it is why orders ("keep Coal first for the Scorchers") matter.
- **Reading it.** **Tide Watch** (tech) draws the Bloom's front on the map as a soft line with a "reaches your outer mine in 4 min" note on the building it is heading for. Before it, the tide is visible only where the fog has been lifted.
- **Holding it.** **Arc Lamp** (Lore tab, needs power, lights 5 tiles): the tide does not enter its light; a better Shard Lamp. **Firebreak** (Land tab, cheap, a cleared strip of ground that burns, never grows): the tide goes round it or waits. **Roads** slow it, as above.
- **Burning it back.** **Scorcher** (Workshops tab, needs power and burns Coal): clears Bloom ground within 4 tiles, one tile per 30 s. This is "burning it back needs power" ([18](18-roadmap.md)): factories and coal now have a reason.
- **What clearing gives back.** **Living Ground** (tech, the small branch of the life tree from the Bloom Lessons, [18](18-roadmap.md) Decided 3): burnt Bloom ground becomes Ash Ground, and Fields on it yield +50%. Winning ground back pays for itself, and it is the only taste of the life tree the Kith get.
- **Why this fits the Bloom.** It is learned, not walled off: the Lessons from Ironfall (what it eats, how it spreads, what it fears) are exactly what Tide Watch, Firebreaks and the Scorcher use. Every player has them, since the Ironfall gate asked for the three Bloom Lessons.

## The tech tree (Era 5): 14 techs
The same five lanes and rules as [09](09-tech-tree.md). It unlocks when the Wires Hum card is put away and draws as a fifth tab. Costs follow the tier bands and are paid in the previous tier's goods (Steel, Iron, Wire).

| Tier | Tech | Lane | Needs | Unlocks |
|---|---|---|---|---|
| 1 | Power Poles | Fiber | Livewire (Ironfall gate) | Power Pole and the net; the Wire item and Wire Mill |
| 1 | Order Board | Lore | Livewire | Order Board, 3 orders, the verbs Run, Pause, Bring first |
| 1 | Tide Watch | Lore | Livewire, Bloom Sampling | The Bloom's front and arrival notes on the map |
| 2 | Generator | Hearth | Power Poles, Boiler | Generator |
| 2 | Arc Lamps | Lore | Power Poles, Shard Lamps | Arc Lamp |
| 2 | Foremen | Lore | Order Board, Taught Hands II | *side:* 3 more order slots |
| 2 | Powered Mines | Stone | Power Poles, Iron Tools | *side:* Mines on a net dig twice as fast |
| 3 | Factory Floor | Stone | Generator, Steel | Factory Floor |
| 3 | Scorcher | Hearth | Generator, Arc Lamps | Scorcher |
| 3 | Firebreaks | Land | Tide Watch, Iron Plough | *side:* Firebreak strips |
| 4 | Shard Dynamo | Fiber | Generator, Shard Boiler | Shard Dynamo, once the Heat plate is learned |
| 4 | Chain Orders | Lore | Foremen, Tide Watch | *side:* an order can run another; the Send verb |
| 4 | Living Ground | Land | Scorcher, the Bloom Lessons | *side:* Ash Ground, Fields +50% on it |
| 5 | **Skyward** | gate | Factory Floor, Scorcher, Chain Orders, Shard Dynamo | Era end (see below) |

Lore-lane cards are gated by Lessons where it reads well, never by a plain requirement (the Star Lore rule). The gate cost is about 200 Steel, 150 Iron, 120 Wire, 100 Brick, plus **five standing orders written** and **the tide held off the Hearth's ring** (the Board shows both): the era ends when the town runs on rules and has held the green back.

## Trust and the Lumen lean
- The lean keeps its mild role. **Allies** let the Lumen lend their Dynamo plans early (Shard Dynamo is a tier lower); **neighbours** change nothing; **enemies** make the tide faster near the Lumen Camp, because the Lumen will not light their end of the map for you. No lean locks a tech out.
- The tide is also a story beat for them: the Lumen know it, they hunted it across the stars, and Skyreach is where that pays.

## Ending
- Researching **Skyward** plays a short end card. A mast stands over the town with a lamp that never goes out, the hum carries up the wire, and, far above the south, something answers.
- The game keeps running so the player can keep building, as the earlier eras do. Skyreach (era 6) is the next design page.

## Staging (how it gets built)
Three stages, each its own PR with placeholder art and every art slot logged in `docs/art/requests.md`.
1. **Wires and orders.** The era's opening (a fifth tab and a Goals list), Power Poles and the net, the Generator, Wire and the Wire Mill, the Order Board and the Run, Pause and Bring first verbs. The era is playable without the tide.
2. **The tide.** The tide model, Tide Watch, overgrown buildings, Arc Lamps, Firebreaks, the Scorcher, Living Ground, Foremen and Powered Mines.
3. **Factories and the end.** Factory Floor, Shard Dynamo, Chain Orders and the Send verb, the gate and its end card.

## Saves and tests (the plan)
Optional fields only with defaults, so saves stay VERSION 1 and the frozen pre-Ironfall fixture loads unchanged. A `livewire` entry under `game` holds the orders, the tide fronts and the net is rebuilt on load. The golden pacing runs for earlier eras must not change; a stage-start and a pacing bot for the era follow the Ironfall pattern.

## Open (defaults stand until the project owner says otherwise)
- **How hard the tide bites.** *Default:* overgrown buildings are lost after 3 minutes and the Hearth ring is safe, so the era cannot be lost. A gentler setting (overgrown buildings only stop working, and run again when burnt clear) or a harsher one (the ring can fall) is one number away.
- **How many verbs.** *Default:* Run, Pause, Bring first, then Send with Chain Orders. More can come from play.
- **The gate's two asks** (five orders, the ring held). *Default:* both, so the gate rewards the mechanic and the pressure and not only a stockpile.
- Costs, speeds and the tide's rate are tuned with the pacing bot, not a human playthrough.
- Anything that changes the Bloom's nature or what the resets mean goes to [open-questions](open-questions.md) first. Nothing here does.
