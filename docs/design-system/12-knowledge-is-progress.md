# Knowledge Is Progress

Status: **agreed direction** (2026-09-30). Jon: "I love that progress idea. Except we do want the map to change." The details below are defaults Claude picked, and none of this is built yet.

Research behind it: [research/mechanics-and-tech-trees.md](research/mechanics-and-tech-trees.md), section 7.

## The idea
In Solace, what the Kith **know** is the real progress, beyond what they stockpile. Each era adds one new way of learning, so the player learns one system at a time:

| When | Mechanic | Inspired by | What it adds |
|---|---|---|---|
| Stone age | **Teach by doing** (small) | Autonauts | The first time you do a kind of job by hand, a Kith learns it and takes over |
| Era 3 (ship lands) | **Decipher the Lumen** (headline) | Chants of Sennaar, Heaven's Vault, Obra Dinn | The magic tree is written in Lumen glyphs. Working out what they mean unlocks it |
| Era 3 | **Expeditions** | DREDGE | Parties go into fog with a small pack and must get home before dark. They bring back glyphs, samples and new recipes |
| Time loop reset | **Keep only knowledge** | Outer Wilds | The world resets and **the map changes**. What you learned carries over |

Set aside for now: the Bloom as a spreading tide (its own later era), stories that fade (too much upkeep next to tool wear), and research that darkens the world (flavor on the Cataclysm path, not a system).

## Teach by doing (stone age)
- Each job kind (gather Wood, gather Stone, haul to the Kiln, and so on) starts unknown.
- Do it by hand 3 times near a spot, and a watching Kith says it can do it. The hut for that job unlocks, or the hauler learns the route.
- It applies only to a job kind's **first** time. After that, huts are placed normally.
- It replaces nothing in the tech tree. Techs still unlock buildings, and teaching is the moment the first worker takes over.

## Decipher the Lumen (era 3)
- The Kith call the refugees "the Starfallen". Their glyphs appear in context: over a healer, on a crate of shards, on the ship's hull, and on items brought back by expeditions.
- The player gives each glyph a meaning from a short list of Kith words. The game confirms guesses **3 at a time** (Obra Dinn's rule), so there's no brute-forcing one at a time.
- A confirmed glyph opens the magic node it names. The name "Lumen" is the first glyph set you can confirm, and from then on the game calls them the Lumen.
- The more you trade with the Lumen, the more context you see. This feeds the refugee choice, which picks the prestige layer (06-mechanics.md).

## Expeditions (era 3)
- Send 2 or 3 Kith from a Watchtower or the Hearth to a point in the fog.
- Their pack is a small grid (DREDGE). Glyph tablets, samples and recipe finds take different shapes.
- They must get home before nightfall. Late parties lose part of their pack, but the Kith aren't lost.
- Finds: glyphs (for deciphering), alternate recipes (a different way to make a good), and Bloom samples (for later).

## The Time loop (deepest prestige)
- The planet rewinds. The Kith wake somewhere **new**, because the map regenerates each loop and the land is different.
- **What carries over** is knowledge of *kinds*, not places:
  - Glyph translations stay confirmed.
  - Alternate recipes found on expeditions stay known.
  - Jobs taught in earlier loops are already known, so there's no teach-by-doing again.
  - Resource signs: kinds you've found before (tin streams, copper hills, star shards) show as faint markers through the fog. You know what to look for, even though the land has changed.
  - Hidden techs you've found (Star Lore and later ones) start visible.
- **What resets:** the map, buildings, stockpiles, Kith and research.
- Each loop goes further because the player knows more, not because a number grew.

## Open
- Map generation: see "Smarter maps" below.
- Exodus and Cataclysm, the other two resets, keep their own carry-overs (06-mechanics.md). Whether they also change the map is open. The default is yes, since Exodus means moving to a new region.
- How many glyphs, and the word list, get designed with era 3.

## Smarter maps (proposed, 2026-09-30)
Jon: the map is "already randomly seeded, although geographically it was kinda un-intelligent."

**Why it feels that way** (`scripts/map_gen.gd` on stone-age-polish):
- The river is always one north-to-south strip in the right third of the map.
- Trees, rocks, berries and grain are dropped as random blobs anywhere on grass, without regard to terrain or to each other.
- Clay and gravel are a coin flip on each river bank.
- There's no height and no wetness, so nothing explains why anything is where it is.

**Proposed fix** (standard in Civ-style and Dwarf Fortress-style generators, e.g. Red Blob Games' map generation articles). Godot's built-in FastNoiseLite covers the noise:
1. **Height** from noise, with a high side and a low side picked per seed.
2. **The river flows downhill** from high ground to the map edge, bending around hills. It can fork, or have a tributary.
3. **Wetness** is high near the river and falls off with distance, with noise mixed in.
4. **Resources follow the land:**
   - Rocks sit on high ground and form ridges, which suits mountain passes.
   - Forest grows in wet ground near the river.
   - Grain grows in open, mid-wet lowland meadows.
   - Berries grow at forest edges.
   - Clay forms on the inside of river bends, and gravel on the outside.
   - Flint is found where rock meets river.
   - The Strange Stone sits somewhere odd, like a lone hilltop.
   - Bronze Dawn copper goes in the hills and tin on a far stream.
5. **Fairness checks stay:** the Hearth goes on dry lowland near the river, with each basic resource within reach. A seed that fails the checks is rerolled.

Every loop gets a different land that still makes sense, and players can read it ("forest means water nearby"). That's the "resource signs" knowledge the Time loop carries over.
