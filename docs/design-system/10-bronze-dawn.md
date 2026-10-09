# Era 2: Bronze Dawn

Status: **stage 1 merged, stage 2 built** (2026-10-02, branch `bronze-2`, not merged yet): carts, the Stone Bridge, Bronze Tools with wear, the Trading Post, the Watchtower and Wanderer, and the Falling Star ending are in. See the decision log for the numbers. The project owner's call: polish the stone age, then build Bronze Dawn. No star crash yet. Every choice below is a default Claude picked and logged, so tell me to change any of them.

See "Stage 1: built and not built" at the end for exactly what the game does today.

## The feeling
- The stone age is about **gathering**. Bronze Dawn is about **metal and distance**.
- Bronze needs two ores that are never found together:
  - **Copper** sits in the hills.
  - **Tin** is rare and far away.
- Getting tin home is the era's puzzle, and roads, carts and storehouses are how you solve it.
- The sky is part of the story. A new light rises over the era, and the era ends as it falls. Hopeful, with a first chill.
- **Length target:** about 20 minutes on a first playthrough, the same as the stone age.

## One new thing at a time
Each new system is small and arrives on its own tech, so the player learns them one by one.

| # | New system | How it works | First tech |
|---|---|---|---|
| 1 | **The map grows** | Researching Bronze Dawn doubles the map east. The new land starts under fog, and your buildings and Kith reveal a few tiles around them. | Bronze Dawn |
| 2 | **Ore** | Copper Hills (common, near) and Tin Streams (2 to 3 tiles, far to the north-east). Clicking them by hand works, but slowly. | Prospecting |
| 3 | **Mines** | Built on an ore tile. Its worker digs without walking. Mines are the first building that needs **two** Kith. | Mining |
| 4 | **Smelting** | Smelter: 2 Copper Ore + 1 Charcoal becomes Copper. Crucible: 3 Copper + 1 Tin becomes Bronze. Both need a worker and fuel. | Smelting, Alloying |
| 5 | **Carts** | A Cart Shed turns one hauler into a cart: it carries 20, but only on roads. Off-road it waits. This rewards road networks. | The Wheel |
| 6 | **Tools age** | Bronze Tools replace Flint Tools, and every worker gets +50%. They wear out, one per 200 items gathered, so bronze becomes a steady upkeep chain, not a one-off. | Bronze Tools |
| 7 | **The watch** | The Watchtower reveals fog in a wide radius. At night-colored intervals it logs sightings of the new light (flavor text in the event log). | Sky Watch |

## Tech tree (Era 2): 16 techs
The same five lanes and rules as the stone age: two parents from different lanes, plus side branches. It unlocks after Bronze Dawn and draws as a second tree panel, with a tab for each era.

| Tier | Tech | Lane | Needs | Unlocks |
|---|---|---|---|---|
| 1 | Prospecting | Stone | Bronze Dawn | Ore tiles shown and named, hand mining |
| 1 | Tally Sticks | Lore | Bronze Dawn | The event log keeps counts. Research costs -10% |
| 1 | Plough | Land | Bronze Dawn | Fields yield +50% |
| 2 | Mining | Stone | Prospecting, Tally Sticks | Mine (2 Kith) |
| 2 | Smelting | Hearth | Prospecting, Plough (the harvest feeds the smiths) | Smelter |
| 2 | Kilns II | Hearth | Smelting, Tally Sticks | *side:* Brick x2 per firing |
| 2 | The Wheel | Fiber | Tally Sticks, Plough | Cart Shed |
| 3 | Alloying | Hearth | Smelting, Mining | Crucible (Bronze) |
| 3 | Causeways | Stone | The Wheel, Mining | Bridges are a building. Roads are 1 Stone and 1 Brick, and 5x as fast |
| 3 | Markets | Fiber | The Wheel, Tally Sticks | *side:* Trading Post. Swap 3 of anything for 1 of anything, slowly |
| 3 | Sky Watch | Lore | Tally Sticks, Mining (the tower is stone) | Watchtower. The new light is named "the Wanderer" |
| 4 | Bronze Tools | Stone | Alloying, Causeways | +50% to all workers, with wear |
| 4 | Granaries | Land | Plough, Markets **or** Kilns II | Housing +1 per 20 food stored |
| 4 | Bronze Ploughshare | Land | Bronze Tools, Plough | *side:* Fields yield another +50% |
| 4 | Star Charts | Lore | Sky Watch, Alloying (bronze instruments) | The Wanderer's path is drawn. It's getting closer |
| 5 | **The Falling Star** | gate | Bronze Tools, Star Charts, Granaries | Era end (see below) |

Gate cost: 60 Bronze, 100 Brick, 60 Flour and 40 Rope.

## The era ending (a cliffhanger, not the crash)
- Researching The Falling Star plays a short end card: the Wanderer grows huge and bright over the map, the screen dims, and a line of text reads "It is not a star. It is coming down."
- The ship landing and the Lumen are **era 3** and not built yet. The project owner picked stone age plus Bronze Dawn only.
- **Save and continue:** after the end card, the game keeps running so the player can keep building.

## Star Lore carry-over
If the Shard Cairn from the stone age was built, it glows brighter as the Wanderer approaches. It's still only flavor. Everything magic waits for the Lumen.

## New content
- **Tiles:** Copper Hills and Tin Stream.
- **Items:** Copper Ore, Tin, Copper, Bronze and Bronze Tools.
- **Buildings:** Mine, Smelter, Crucible, Cart Shed, Trading Post, Watchtower and Bridge.
- **Colors:** copper `b87333`, tin `c0c7cf`, bronze `cd7f32`. The Wanderer's light uses `lumen-glow` from the visual design system, so it quietly matches the Lumen.

## Defaults picked (tell me to change any)
- The map grows east at the era change. It isn't a separate new map.
- Mines need 2 Kith.
- Tools wear out.
- Carts use roads only.
- The era ends on a cliffhanger, and the game keeps running afterward.

## Stage 1: built and not built
**Built (it plays from Bronze Dawn to the first Bronze, about 9 to 13 minutes on the eight test maps):**
- **The map grows.** The tick after Bronze Dawn is researched, the map doubles to the east, under fog. The new strip is the same size as the stone map and is made from the map's seed (a seed always grows the same land). The stone-age half is not touched, so the win moment and the stone-age golden are unchanged. A banner (a 14 s toast) says the land has opened, and the game goes on: no win screen.
- **Ore.** Copper Hills are common and lie near the strip's west edge. A Tin Stream (3 tiles) lies far to the north-east, 36 to 55 tiles from the Hearth. A strip that is unfair (too little copper, too little near the edge, tin more than 3 river tiles from the Hearth) is rerolled on a fixed seed sequence, 12 tries.
- **Techs.** All 16 techs are in the data with their parents, on a second tab of the tech panel (one tab per era; the second is locked until Bronze Dawn). Seven have effects: Prospecting, Tally Sticks (log counts, tech costs -10%), Plough (fields +50%), Mining, Smelting, Kilns II (Brick x2) and Alloying. The other nine (The Wheel, Causeways, Markets, Sky Watch, Bronze Tools, Granaries, Bronze Ploughshare, Star Charts, The Falling Star) show their card and parents but say "Needs the next update" and cannot be bought.
- **Tiles and goods.** Copper Hills, Tin Stream, Copper Ore, Tin, Copper and Bronze. After Prospecting a click mines an ore tile by hand, slowly (Copper Ore 3 s, Tin 4 s, faster with tools).
- **Buildings.** Mine (two Kith, built on an ore tile, digs without walking), Smelter (2 Copper Ore + 1 Charcoal -> Copper) and Crucible (3 Copper + 1 Tin -> Bronze). Haulers, roads and depots serve them like any workshop.
- **The top bar** has a third row for the four new goods (the bar is 130 px tall, from 113).
- **Tests.** Tech parents, growth determinism, mines need two Kith, smelting recipes, tin fairness, save round-trip of the grown map and new buildings, a second golden (the game at the first Bronze, seeds 1 to 3), no dead tech buyable, and the layout and play passes play on into era 2.

**Built in stage 2 (see the decision log):** carts and the Cart Shed, Bronze Tools and wear, Bridge as a building, Causeways, Trading Post and Markets, Watchtower and Sky Watch, Granaries, Bronze Ploughshare, Star Charts, The Falling Star and the era ending, the Wanderer's light, the Shard Cairn glow. Their tech costs in the data are placeholders.
