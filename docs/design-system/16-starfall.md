# Era 3: Starfall

Status: **designed, not built** (2026-10-03). Jon agreed the five main picks on 2026-10-03 and asked for a mix on the Lumen choice (a hidden trust meter plus a few big choice moments). Anything marked *default* is a pick Claude made, and Jon can change it. Mechanics page, so Claude owns it. Tech additions live here, not in [09](09-tech-tree.md) or [10](10-bronze-dawn.md).

Picks up where [Bronze Dawn](10-bronze-dawn.md) ends: the Falling Star card, then "Keep building".

## The feeling
- Bronze Dawn was **metal and distance**. Starfall is **strangers and meaning**: someone arrived, they cannot speak your language, and they are afraid of something.
- Hopeful turns ominous (see [03](03-world-lore.md)). Early on there is wonder. The turn comes when the Bloom glyph is decoded.
- **Length target:** about 20 minutes, ending on the first Bloom sign.

## One new thing: glyphs
The era adds exactly one mechanic, built on [12](12-knowledge-is-progress.md). Expeditions feed it, and the trust meter shapes how it plays, but neither is a second system to learn.

### Rules
- Glyphs are small marks. Each belongs to a **set** (Light, Body, Warning and so on) and a set has 3 to 4 glyphs.
- **Collecting is automatic.** Build a **Glyph Wall** (stone, near the Hearth). Kith **scribes** copy every glyph the colony has seen: on the hull, on shard crates, on things expeditions bring back. No clicking to copy.
- **Meaning is the player's job.** Each collected glyph gets a meaning from a short list of Kith words (Fire, Water, Hurt, Home, Star, Come, Go, Hunger, Danger, and so on). You guess.
- **Confirmed 3 at a time** (Obra Dinn's rule). The game says nothing until three guesses in a set are all right, then locks all three. No one-at-a-time brute force.
- A locked glyph opens the magic node it names. The first set you can lock is "the name", and from then on the game says **Lumen** instead of Starfallen.
- **Context makes guessing fair.** Every glyph shows where it was found (on a healer's hands, on a hull panel by the door, on a crate of shards). Better contact with the Lumen gives more context (a short line of what they were doing when they used it).
- Wrong guesses cost nothing but time. A set stays open until you get it.

### Why this fits the pillars
- No chores: scribes copy, the wall holds the set, the only active step is a thought.
- It stays cheap to test: guesses are data (`glyph_id -> word`), and a set locks when all three match.

## The landing
- The Falling Star card is followed by **a tick of silence**. Then the ship comes down inside the fog on the far east of the grown map. The crash site is a **Wreck** zone, hidden until an expedition reaches it.
- **Day 0:** a streak of fire in the sky and a thump. The Watchtower logs one line. The event log says "Something big came down to the east."
- **Survivors come to you.** A few Starfallen walk out of the fog toward the nearest building with light in it (the Hearth by default). They stop at the edge of the settlement.
- The Wreck is where glyph sets 2 and up come from. The Kith cannot go there alone at first (see expeditions).

## The Shard Cairn hook
Code records a flag, `cairn_built_before_landing`. This page defines what it does.
- **Cairn built before the star fell:** the Starfallen walk in as **guests**. Trade is open from the first minute, trust starts at +1 step, and the first glyph set is easier (more context lines).
- **No cairn:** they arrive as **wary outsiders**. Trade is closed, trust starts at 0, and the first glyph set has fewer context lines. A trade offer (the first batch of food) opens it.
- Either way nothing is locked out. The cairn buys a friendlier start, not a different game.

## Expeditions
Set and forget, in line with Jon's feedback that clicking chores are the bad part.
- Build an **Expedition Post**. Pick a **fog target** on the map (a tile or a marker), pick a **pack** from a short list of presets (Light, Standard, Heavy), and send 2 or 3 Kith.
- The party **walks there and back on its own** along roads where possible. Roads shorten the trip, so the road network matters (roads were the fun part).
- **Nightfall rule:** the party must be home by dark. If the target is too far, the post shows a warning before launch and suggests a road or a closer stop.
- **Haulers resupply** the Post like any workshop, so repeat trips need no clicking. A **standing order** ("keep one party going to the Wreck") is the automation step.
- **Finds** (shown on return, in the event log):
  - **Glyphs** for the Glyph Wall.
  - **Alternate recipes** (a different way to make a good).
  - **Bloom samples**, held for later eras.
- Late parties lose part of the pack and bring less. Nobody dies.

## The magic tree (about 14 techs)
It opens from glyph locks, not from research points, and draws as a **third tab** on the tech panel. Costs are placeholders.

| Set | Locks | Opens |
|---|---|---|
| 1. Name | Lumen, Star, Come | The Lumen name; the **Lumen Camp** (trade, a place for the survivors) |
| 2. Light | Light, Fire, Bright | **Shardlight**: shards become a fuel and a lamp. Shard Cairn wakes up (see below) |
| 3. Body | Hurt, Heal, Rest | **Lumen Healer**: healing raises Kith growth and cuts tool wear |
| 4. Growth | Seed, Rain, Soil | **Starfruit**: a crop that grows in shardlight |
| 5. Craft | Shape, Bind, Weave | **Shardwork**: magic items made from shards, rope and bronze |
| 6. Warning | Hunger, Spread, Danger | The **Bloom** glyph. Ends the era (see below) |

- The first three sets are enough for the era's economy to feel different from Bronze Dawn.
- Locks in set 6 are gated behind the Wreck, so the player must reach it.

## The Shard Cairn wakes
In Bronze Dawn the Cairn glows brighter as the Wanderer comes closer, and does nothing else. In Starfall it becomes real when **set 2 (Light)** locks:
- It starts to hum and gives the area around it **shardlight**, a small bonus to nearby workers.
- It keeps the same footprint and sprite, so no new art slot is needed (a glow layer only).

## The Lumen choice (trust meter plus big moments)
Jon's pick: a mix of a hidden meter and a few explicit decisions.
- **Trust** is a hidden number from 0 to 100. Buildings and trade move it quietly:
  - Up: a **Lumen Camp** with housing, shared food, sharing glyph sets, a shared shrine.
  - Down: a **Guard Post**, refusing trade, taking shards by force, hoarding food while they starve.
- **Three big moments** (pop-up, one choice each) add or cut a large step of trust. They are rare and always shown with the likely result:
  1. **The Hunger.** The survivors are starving. Share your food or hold it.
  2. **The Shards.** They ask for the cairn's shards. Give, trade, or refuse.
  3. **The Warning.** They ask you to go dark: stop smoke and noise so the hunters cannot find you.
- The meter is never shown as a number. The Lumen's behavior shows it: how close they stand, what they say, and whether they bring glyph context.
- At the era's end, trust and the choices set a **lean** toward a reset (for later eras to use). The draft mapping from [06](06-mechanics.md) stays as is:

| Lean | What it looks like | Leads toward |
|---|---|---|
| High trust, shared everything | Allies | Time loop |
| Middle, trade only | Neighbours | Exodus |
| Low trust, force | Enemies | Cataclysm |

*Default:* the lean is stored in the profile save as `lumen_lean`, never the run save. Nothing reads it yet.

## The ending (about 20 minutes in)
- Locking the Bloom glyph set plays a short card: the Lumen speak the word and the mood changes. A line says "They did not come to live here. They came to hide."
- The first **Bloom sign** appears: a patch of strange growth at the edge of the fog. It does nothing yet. The game keeps running, as it did after the Falling Star.
- A story id `bloom_seen` goes in the profile save.

## Pacing against Jon's feedback
Jon said the early game is slow, tools by hand are annoying, and roads were the fun part. For this era:
- No hand-crafted items. Anything crafted runs from a building.
- Roads matter more, because expeditions and the Lumen Camp both want them.
- Clicking is for decisions: guessing glyphs, picking a fog target, answering a big moment.
- (Early game and tech tree fixes are separate asks for Game build, not part of this page.)

## Open questions
- Exact glyph list and the word list (design with the first build stage).
- Whether the era gets its own 24 px sprites for the Lumen or reuses the Wanderer palette (`lumen-glow`). *Default:* reuse, then Codex polishes.
- Does set 6 need the Wreck, or can an expedition find it elsewhere? *Default:* the Wreck.
- Sound is still off for the whole game.

## Build stages (proposal)
1. **Stage 1:** the landing, the Lumen Camp, trust meter, set 1 and the Glyph Wall.
2. **Stage 2:** the Expedition Post, the Wreck, sets 2 to 5 and the third tab.
3. **Stage 3:** the three big moments, set 6 and the ending card.
