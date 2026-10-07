# Era 3: Starfall

Status: **designed, not built** (2026-10-03). The project owner agreed the five main picks on 2026-10-03 and asked for a mix on the Lumen choice (a hidden trust meter plus a few big choice moments). Anything marked *default* is a pick Claude made, and the project owner can change it. Mechanics page, so Claude owns it. Tech additions live here, not in [09](09-tech-tree.md) or [10](10-bronze-dawn.md).

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
Set and forget, in line with the project owner's feedback that clicking chores are the bad part.
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
the project owner's pick: a mix of a hidden meter and a few explicit decisions.
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

## Pacing against the project owner's feedback
the project owner said the early game is slow, tools by hand are annoying, and roads were the fun part. For this era:
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

## Stage 1 as built (Claude, 2026-10-06)
- **The landing.** The Falling Star card closes, 20 s of silence pass, the star lands (log line), 40 s later three strangers walk out of the fog. A Shard Cairn built before the star fell makes them arrive close (trust 20, "guests"); without one they stop far from the Hearth (trust 0, "wary").
- **Strangers.** Three plain figures drawn by `KithArt.draw_strangers`, standing 6 tiles from the Hearth at trust 0 and 2.5 at trust 100 (or 1.6 tiles from a Lumen Camp once one stands). They borrow the Kith art with the Wanderer glow until Codex draws them.
- **Glyph Wall** (Lore tab, opens once the strangers have arrived, event-gated). Copies one more mark every 45 s while it stands and a stranger is alive. Click a mark on the Wall panel to cycle the word guess. Every 20 s the Kith talk it over; when all three marks of a set are right at once the set is read. A wrong guess is never punished and never hinted at, apart from the context line each mark shows.
- **Set 1, "The Name":** Star, Come, Kin. Reading it names the strangers (the Kith start saying "the Lumen") and opens the **Lumen Camp** (Lore tab, event-gated).
- **Trust** is hidden (0 to 100): +8 when the Camp goes up, +1 per minute it stands, +6 per set read. From 40 the strangers say a little more about each mark. Nothing else moves it yet.
- **Save:** the block lives inside "game" in the run save and the three story moments (`star_landed`, `lumen_arrived`, `name_read`) are absorbed by the profile.
- **Not in stage 1:** sets 2 to 6, trade, Guard Post and shared-food trust movers, the third (magic) tech tab, expeditions and the Wreck, the three big moments and the ending (stages 2 and 3). Beasts and the beast cart come after.

## Stage 2 as built (Claude, 2026-10-06)
- **Expedition Post** (Lore tab, event-gated: opens when the first set is read). Panel lines: where to go (the crash site or the nearest fog), the pack (Light, Standard or Heavy), the trip time against the day, a Send button and a Keep sending switch. A party is two Kith who walk out, look, and walk home on their own (Scouting's walking, roads shorten it). The pack comes out of the stockpile as they leave, so a standing order needs no clicking. One party per Post.
- **Nightfall rule:** the whole trip must fit in 80 s (`DAYLIGHT_SECONDS`, about the length of a walk across the grown map). The panel warns before launch; a party home late brings back half its finds, rounded up. Nobody dies.
- **The Wreck:** set at the far east edge when the star falls, hidden until a party reaches it (a hull and embers, placeholder art). Reaching it records `wreck_found`. Each trip there brings marks (Light pack 1, Standard 2, Heavy 3) copied straight onto the Wall, in set order. The far-fog target lifts a wide patch of fog (8 tiles) instead and brings no marks.
- **Sets 2 to 5** (Light, Body, Growth, Craft; three marks each, `source: "wreck"`) are read like set 1: guess all three right at a check. The Wall copies only the strangers' marks itself. A guess skips words already read, so the list shrinks as sets lock.
- **Gifts instead of a new tab.** Each read set gives a real effect through existing hooks, shown on the Wall's panel: **Shardlight** (gatherers within 4 tiles of a Shard Cairn work 25% faster), **Lumen Healer** (tools last 40% longer, births 20% sooner), **Starfruit** (berries near a Cairn yield 50% more), **Shardwork** (workshops near a Cairn work 25% faster). Set 2 is the Cairn waking, as planned. Not built: the third tech tab, trade, Guard Post and shared-food trust movers, alternate recipes and Bloom samples as finds, set 6, the three big moments and the ending (stage 3).
- **Why no third tab yet:** the research board, queue and bots all assume every tech is bought with goods. Glyph-gated techs would need a new way to unlock them, so the four gifts ship first and the tab can follow once the gifts have been played.

## Stage 3 as built (Claude, 2026-10-07)
- **Three moments**, each a card the game pauses behind (`scripts/moment_card.gd`), asked once, a wait after the set they follow is read, one at a time: **the Hunger** (after set 1, 150 s: share about 40 food worth, or hold it back; +14 or -12 trust), **the Shards** (after set 2, 120 s: give them, trade, or refuse; the Cairn's shardlight is lent away for 150 s, 60 s or not at all; +14, +5 or -10), **the Warning** (after set 5, 90 s: go dark, workshops at half speed for 90 s, +14; or keep working, -12). Every answer is a story id in the Chronicle.
- **Set 6, the Warning** (Hunger, Spread, Danger, from the Wreck like sets 2 to 5): it cannot be read until all three questions are answered. Reading it ends the era: trust at that moment sets the **lean** (70 or more allies, 35 or more neighbours, otherwise enemies), recorded as `lean_allies`, `lean_neighbours` or `lean_enemies`, and a Bloom sign shows seven tiles north of the Wreck, with the fog lifted round it (`bloom_seen`). The ending card says "They did not come to live here. They came to hide." and the game goes on.
- **Not built** (see stage 4 below for trade, the Guard Post and the shrine): the third tech tab, alternate recipes and Bloom samples as finds, the beast cart. Nothing reads the lean yet; the Ironfall era will ([18](18-roadmap.md)).

## Stage 4 as built (Claude, 2026-10-07)
- **Three more buildings that move trust**, all on the Lore tab and gated by story events, not research. Counted once when they first stand (a step and a log line), then a little each minute.
- **Lumen Market** (opens when the name is read and trust reaches 8, so guests at once and the wary after a Camp). It is a trade building like the Trading Post but swaps **2 for 1** (`trade_give` 2) and works in 8 s. While one stands it lifts trust by 0.6 a minute, **up to 60 only**: trade alone makes neighbours, never allies.
- **Shared Shrine** (opens when the name is read): +10 trust once, then +1 a minute. A refuge, no worker.
- **Guard Post** (opens when the strangers arrive): -6 trust once, then -1 a minute (never below 0). The Kith whose huts and workshops stand within 4 tiles of one work **15% faster** (the `watchful` bonus), so force pays now and costs trust. A refuge, no worker.
- Story ids `market_open`, `shrine_raised` and `guard_raised` go in the Chronicle. The seen-once flags save in the run save (`starfall.seen`); older saves load.
- **Still not built:** the third tech tab, shared food as an ongoing trust mover (the Hunger moment is the shared food), alternate recipes and Bloom samples as finds, the beast cart. Placeholder art borrows the Trading Post, Watchtower and Standing Stone; slots in `docs/art/requests.md`.

## The lead stranger (Claude, 2026-10-07)
- One of the three Lumen is a named lead character, **Sela**. She is the **tall one with long pale hair**, the first of the strangers to trust the Kith and the voice of the trust choices. Her name is `Data.LEAD_NAME`, one constant, so a rename is one edit.
- **Voice:** warm, playful, quick to tease, perceptive and confident; glamorous at first sight, goofy and loyal once she trusts you. She notices the Kith's mood before they say it, and her smile fades when the choice goes against her (the fade is the feedback).
- **Where she speaks:** the arrival line (she waves first), the moment she gives her name when the first set is read, a line on each moment card (the Hunger, the Shards, the Warning) and her reply to every choice in the event log, and the end card. The trust meter stays hidden: her warmth shows it, not a number.
- **Art:** a 24 px figure, a 160x160 portrait and an optional card header, in [the art brief](../art/starfall-art-brief.md). The look is stylized and tasteful.

