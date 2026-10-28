# Roadmap: the eras after Starfall, the Bloom and the three resets

A short map of everything past [Era 3: Starfall](16-starfall.md), up to "super advanced". It is a proposal (Claude, 2026-10-06): the project owner answered the main forks on 2026-10-06 (see **Decided**); the rest keep their defaults under **Open**. Nothing here is built. It follows the pillar in [12](12-knowledge-is-progress.md): each era adds one new way of **knowing**, not just a new number.

## The shape
| Era | Working name | Tech and look | New way of knowing | Story beat |
|---|---|---|---|---|
| 1 | Stone age | hands, huts, roads | Teach by doing | Hopeful: the Kith make a home |
| 2 | Bronze Dawn | metal, carts, distance | Distance and trade | A light falls |
| 3 | Starfall | magic arrives | Decipher the Lumen, expeditions | The Lumen land; the Name is read |
| 4 | **Ironfall** | iron, steam, engines | **Teardown** | Lumen and Kith work side by side; first Bloom signs |
| 5 | **Livewire** | power lines, factories, standing orders | **Standing orders** | The Bloom tide starts to spread; the clock |
| 6 | **Skyreach** | orbit, the sky, signal | **Survey the sky** | The Bloom arrives. The run ends in a reset |

The three factions form a triad: machine (Kith), magic (Lumen), life (Bloom). Eras 4 to 6 braid the machine tree with the magic tree; the life tree is the Bloom's (see below).

## Era 4: Ironfall
Designed in detail on [19](19-ironfall.md).
- **Mechanic: Teardown.** Take apart a Lumen device or a Bloom sample at a Workshop; the Kith learn how it works and the part becomes a recipe, a machine or a new use for a shard. It is "what the Kith know" made literal: you learn by opening things. Fits the expeditions loop, which bring the finds home.
- **Beat:** the Kith machine tree finally meets the Lumen magic. Trust from Starfall decides how freely the Lumen share. Beasts and the beast cart arrive here (shard-touched, per [17](17-needs-and-upgrades.md)).
- **Bloom:** a few growth patches show at the edge of the fog. They do nothing yet.

## Era 5: Livewire
Designed in detail on [23](23-livewire.md).
- **Mechanic: Standing orders.** A Kith (or a machine) can be given a short rule, "when the Kiln is below 10, bring Clay", once, in a small picker. It is the next step after "hands, taught, dispatched, automated" ([14](14-hands-to-haulers.md)), and the player's automation dream: you stop moving stock and start writing rules.
- **Beat:** the Bloom tide starts. Patches grow slowly toward the Hearth and eat what they touch.
- **Pressure:** the tide is the clock. Burning it back needs power, so factories now have a reason to be built.

## Era 6: Skyreach
- **Mechanic: Survey the sky.** Watchtowers become signal towers; the Kith map the sky and the Bloom's path in. What you read there decides how long you have and which reset is open.
- **Beat:** the Bloom arrives for real. This is the end of a run and it hands off to a reset.

## The Bloom
- A living tide on the map, not an enemy unit: it spreads along ground that is cheap to cross (grass, damp), is slowed by roads, fire and shard light, and eats stock and buildings in its way. Fits "what the Kith know": you learn it (samples, Teardown) to fight it, not by building a wall.
- Era 4 signs, era 5 tide, era 6 arrival. It hunted the Lumen across the stars, so how the Lumen act around it is the story.
- **The life tree** is the Bloom's third tree. *Default:* the Kith can open a small branch of it late (era 5 to 6), by Teardown of samples, never the whole thing. Playing as the Bloom stays in [13](13-three-perspectives.md) as an idea.

## The three resets
Each reset ends a run, keeps knowledge (not stock) and changes the map, as the Time loop already says in [12](12-knowledge-is-progress.md). Triggers and carry-over start from [06](06-mechanics.md); the Lumen lean from [16](16-starfall.md) decides which is open.

| Reset | Plays like | Carries | Opens when |
|---|---|---|---|
| **Exodus** | Pack up, move to a new region with what you know. A calmer run, a new map. | Knowledge: faster research, starting blueprints | Lean "neighbours" (trade only) |
| **Cataclysm** | Magic overreach breaks the world. You wake in the ruins and dig up relics. | Relics: magic artifacts | Lean "enemies" (force), heavy magic |
| **Time loop** | The planet rewinds; only you remember. Each loop is shorter and goes further. | Memory: permanent meta-upgrades, glyphs, finds | Lean "allies", the deepest layer |

## Exodus as built (Step 7)
The first reset is real. (Step 7C turned its "Set out" button into "Choose an ending", below; the Exodus is one of the three rows and its confirm reads "The town stays behind. The Kith walk into a land they have not seen, carrying what they know.") Setting out folds the run into the profile, banks what carries, and starts a new run on a new map.
- **Carries** (profile v2: `techs`, `marks`, `echoes`, `exoduses`; a v1 profile loads with them empty): every tech the run learned costs `Data.EXODUS["known_share"]` (0.3) of its materials (rounded up per item, applied before Tally Sticks and the Cairn); every read glyph mark shows its word, while the Wall still copies it and the strangers' moments still happen; one Lumen echo per fully read Lumen set (the Lantern, Healing House, Grove and Shardwright cards open at minute 0 and still need their normal materials); taught job kinds and shown hints, as before.
- **Does not carry:** the map, buildings, stock, people, research progress, Starfall choices.
- **Banking** happens only on Set out. A finished run that is not set out leaves the profile alone, and "Forget past runs" (a confirm in the game menu) gives a true first run again. The run save records its own carry, so a mid-run load keeps it; a save without one loads as a first run.
- **A new land** card opens the new run once and lists what the Kith remember. Tech cards say "Known from before: 30% of the study".
- **First runs do not change.** An empty carry has no effect: the goldens did not move and the empty-profile bot times are identical.
- **Bots** in the Exodus run build the Lantern and Healing House as soon as they can pay, in any era, and know everything from run 1 (the pace tool's `exodus=` argument sets a saved Skyward end out onto the map seed + 1000).
- **Pace, measured** (bots on three new maps, 1001/1002/1004 = seeds 1/2/4 set out from the Step 6 Skyward ends; each era its own job; run 1 is 79.2 / 80.0 / 87.6 min on the original maps):

| Known share | Run 2, seeds 1 / 2 / 4 | Against run 1 | Eras |
|---|---|---|---|
| 0.5 | 62.3 / 93.5 / 57.4 min | -21% / +17% / -34% (mean -14%) | map 1002 had Bronze 30.5 and Ironfall 29.3 (over 25) and Livewire 7.4 (under 8) |
| **0.3 (shipped)** | 55.8 / 64.2 / 54.6 min | -30% / -20% / -38% (mean -29%) | all 15 eras 8.0 to 16.1 min, every era won |

  Map 1002 is a hard map: its first run with no carry needed 47 min for Bronze Dawn and did not finish Ironfall in 70, so the half-price run was good news there and still too slow; 0.3 brings it in. Livewire on map 1004 sits at the 8-minute floor, so 0.3 is as far as this knob should go. The ledger leak was under 0.4% of the flow in every era of both chains.


## Endings as built (Step 7C)
Skyward's card has "Choose an ending" beside "Keep building" (the game menu has it too, greyed until Skyward stands). It opens a card headed "The first telling ends here" (later runs: "Telling N ends here") with three rows, each with its name, a line of story, what it gives and, when the lean shuts it, why. A chosen row asks "Leave this land?" in the words of how that ending ends; a yes records the ending as a Chronicle moment (`ending_exodus`, `ending_cataclysm`, `ending_loop`), banks the carry and begins the next run. Before the card, the `skyward_end` cutscene (the mast lit, the Bloom on the horizon, Sela: "Not this time. But you'll remember.") plays. After any ending, before the next run starts, a short `fireside` scene plays (two stills: the painting of the ending just chosen, `ending_exodus_1`, `ending_cataclysm_1` or `ending_loop_1`, then the Hearthkeeper telling the children the telling that just ended, with the elder's portrait beside the caption; placeholder lines); the Chronicle book that opens after it is Step 7G, so for now the next run's "A new land" card follows it. Cutscenes switched off skip it.
- **Locks** (the lean Starfall ended with): Exodus always; Cataclysm needs "the Lumen as enemies"; Time loop needs "the Lumen as allies". Neighbours open only the Exodus.
- **Exodus:** a new map (as built in 7B).
- **Cataclysm:** the next run keeps the same map seed. Up to 60 of the old town's dearest buildings become Ruins tiles (one tile each; none within 8 tiles of the Hearth, `Data.ENDINGS["ruins_clear"]`, so the old square is open ground): rubble nothing can be built on until a Road is laid over it (the Road clears it and gives its Stone, no extra step) or Demolish clears it; the Stone is the building's cost over 25, from 3 to 20. Ruins in the land that grows east or south are laid when the land grows. Two to four dormant Bloom patches (two tiles of Bloom ground) sit at the old town's rim: each at least 20 tiles from the Hearth (`Data.ENDINGS["patch_clear"]`) and beyond the distance that 90% of the old town's buildings stood within (`patch_edge`, `Ruins.edge_of`), at the open grass nearest one of the largest ruins, 6 or more tiles apart; the tide still wakes at the first engine and spreads from them as well as from the south. The Lumen arrive wary even if a Cairn stood first (trust 0, no guests).
- **Time loop:** a new map. The Lumen remember: trust starts at the trust the last run ended with, Sela greets the Kith by name and the run notes the lean they had.
- **Profile (version 3):** `runs`, `tellings` (one record per ended run: number, seed, the small Starfall choices, lean, trust, ending) and `last` (the latest ending's handoff: seed, trust, lean, and after a Cataclysm the ruins and patches). A version 1 or 2 profile loads (its runs are its Exoduses).
- **Not built yet:** the gifts (relics, memory beyond trust; blueprints are built, see below), the new glyph sets, Skyreach and the Chronicle book that opens after an ending. The end cards use placeholder words.

## Blueprints as built (Step 7D)

The Exodus's gift. A **Blueprints** button sits beside Demolish on the build bar (it appears once Haulers is known, or once the book holds a blueprint) and opens a small panel over the foot of the map: up to six blueprints, each with a name that can be typed over, "Lay down" and a delete, and "Save a blueprint: drag a box".

- **Saving.** The next drag on the map becomes a box. Everything inside it that the player built is kept: roads, bridges, fields and buildings, never the Hearth, as a type and an offset from the box's corner (kinds and shapes, never places). A box over bare ground keeps nothing, and a seventh blueprint is refused until one is deleted.
- **Laying.** "Lay down", then a click puts the blueprint's corner on that tile and queues one plan per part that falls on the map (no rotation). A plan is built the way the player would build it, so nothing is free: roads first, then fields, then buildings, one pass every tick. A part waits while its tech is not known or its ground is still in the fog; the part that waits for materials holds the ones behind it back, so a road grid never eats the stone its smelter is waiting on; a part that can never go (the ground is wrong, something stands there) is dropped. Ordinary buildings have no construction site in this game (they are paid for and stand at once), so the plans place themselves; they do not wait for haulers.
- **Banking.** Blueprints saved in a run live in the run's save. Only an **Exodus** banks the run's whole book into the profile; a Cataclysm or a Time loop leaves the profile's blueprints as they were before the run. A new run begins with the profile's book.
- **What the Kin know.** A part laid from a banked blueprint (one carried from an earlier run) costs 70% of its price, each item rounded up and never below 1 (`Data.EXODUS["bp_share"]`); the Kin have built it before, the same idea as a known tech costing 30% of its study. A blueprint saved in the run in hand costs full price.
- **The AI player.** `tests/autoplay_blueprints.gd`, used by the pace tool (`baseline exodus=<run> blueprints[=all|yards|roads]`): the run's Hearth yard (everything within eight tiles of the Hearth but the gatherers) and its smelter yard are kept at the end of run 1 and laid at the new Hearth.

**What the bot got from it** (minutes of game time through all five eras, run 2 on maps 1001 / 1004; 7B without blueprints: 55.8 / 54.6, every era 8.0 to 13.0):

| Bot keeps | Share | 1001 | 1004 |
|---|---|---|---|
| Hearth yard and smelter yard | full price | 60.9 | 66.6 |
| the same | 70% | 55.8 | 61.1 |
| road grid and storehouses only | 70% | 52.3 (Livewire 7.8) | not won in 70 |
| roads and storehouses, smelter yard | 70% | 55.8 | 55.9 (Livewire 7.3) |

The first bar was a bot Exodus run at least 3 minutes faster on both maps with no era under 8: **not met**. A blueprint saves a player's clicks, not materials; the bot already places what it wants the moment it can pay, so queued plans mostly spend stone and wood on things it would have built later, ahead of research. The 70% share (the director's call) was kept as the rule and not lowered.

**The revised bar** (director, 2026-10-27): at 70%, a bot Exodus run with blueprints is no more than 2 minutes slower than 7B on the same map, stays inside 50 to 75 minutes, and has no era under 8. 1004 was +6.5 because the bot queued a whole yard at minute 0, which tied its stone and wood up before research could use them. So the AI player now keeps its blueprints on a waiting list and lays one only once every type in it is known and the stores hold half of what its parts cost (at the banked share); roads still go down first. Rerun at 70%, both Hearth yard and smelter yard:

| Map | 7B (no blueprints) | Laid at minute 0 | Laid when half paid for | Eras of the new run |
|---|---|---|---|---|
| 1001 | 55.8 | 55.8 | 55.8 | 10.6 / 10.2 / 12.3 / 12.8 / 9.9 |
| 1004 | 54.6 | 61.1 | 54.6 | 11.4 / 9.5 / 12.7 / 13.0 / 8.0 |

Both maps now meet the revised bar. The real value of a blueprint is the clicks it saves a player, which the bots cannot feel: that is checked in the Mac launch. See the decision log, 2026-10-27.

## Relics as built (Step 7E)

The Cataclysm's gift. In a Cataclysm run the three heaviest ruins (the first three of the carried ruin list, heaviest first) each hold a **relic**: the Everburning Forge, the Old Lantern, the Founders' Cart, in that order (`Data.ENDINGS["relics"]`). A ruin that holds one wears a gold glint on the map, and its hover pill says what lies under it ("click to send a crew to dig").

- **Digging.** Click the ruin: the nearest idle Kith (a hauler with nothing in hand counts) walks to a road tile beside it (any of the eight neighbours), digs for 60 game seconds (`dig_seconds`; a ring fills round the glint) and walks home. No road beside the ruin, no crew; one crew a relic; nobody free, nobody goes. The crew is a scout in the Kith's own fields (job "scout", phase "dig_out", "dig_work" or "dig_home", `task` {tile, relic}), so it saves with them and needs no new Sim code; the people list calls it a Digger. Demolish refuses a ruin that still holds a relic ("dig it out first"); an ordinary ruin clears for its Stone as before, by Demolish or by a Road laid over it (a Road refuses a ruin that still holds a relic).
- **The Everburning Forge** becomes a real Forge on the cleared ground that burns nothing: its recipe is 2 Iron to 1 Steel (no Coal), it has no fuel setting, and it keeps the Forge's other needs (a Smith, power, a road). It stands where the old town's heaviest building stood, so it is not always where the smelters are.
- **The Old Lantern** becomes a Shard Lantern whose shardlight reaches 8 tiles, double the usual 4 (`lantern_reach`); the lantern rings drawn while placing a Lantern follow each one's own reach.
- **The Founders' Cart** leaves no building: a small cart is drawn on the cleared ground, and any hauler within 8 tiles of it (`cart_reach`) carries 50% more (`cart_load`, rounded up) on its next pickup.
- **Used up with the run.** `carry.dug` is saved with the run and is never handed on, so the next Cataclysm finds its own three; nothing about a dug relic survives an ending. Any ending that is not a Cataclysm has no ruins and so no relics. First runs are unchanged (goldens did not move).
- **The AI player** (`tests/autoplay_relics.gd`): once haulers are known it lays road from the network to the Lantern's and the Cart's ruins and sends a Kith. It leaves the Forge alone: it builds its own Forge beside the Boiler it powers.

**What the bot got from it** (Cataclysm run on the same seed as run 1, minutes of game time per era; every era is won):

| Map | Stone age | Bronze Dawn | Starfall | Ironfall | Livewire | Total | Relics dug |
|---|---|---|---|---|---|---|---|
| 1 | 11.0 | 10.7 | 11.3 | 13.4 | 8.1 | 54.5 | cart in the Stone age, lantern later |
| 4 | 13.4 | 9.5 | 11.0 | 12.2 | 11.0 | 57.1 | cart and lantern before Ironfall |
| 2 | 11.6 | 10.0 | 11.3 | 13.3 | lost | n/a | Livewire lost: see the tune below |

The bar (a bot Cataclysm run on map 1 won in every era, 8 to 25 minutes an era): met on maps 1 and 4. Map 2 lost Livewire, because its dormant patches sat 4 tiles from the Hearth and the tide reached the town almost at once.

**The Cataclysm tune (director, 2026-10-27).** Step 1 of the director's three: dormant patches lie 12 or more tiles from the Hearth (either tile of a patch, counted both ways), still beside the largest ruins that allow it; two to four, as before. Steps 2 (the patches wake 5 game minutes after the first engine, "The old ground stirs") and 3 (cap the patches at 2) were not needed. Bot Cataclysm runs on the same seed as run 1, minutes of game time, every era won:

| Map | Stone age | Bronze Dawn | Starfall | Ironfall | Livewire | Total | Buildings the Bloom took in Livewire |
|---|---|---|---|---|---|---|---|
| 1 | 10.7 | 9.9 | 12.0 | 12.4 | 9.2 | 54.2 | 6 |
| 2 | 11.5 | 9.8 | 11.3 | 11.7 | 12.3 | 56.6 | 19 |
| 4 | 13.3 | 10.4 | 11.3 | 14.4 | 7.9 | 57.3 | 7 |

Verdict: **CONCERNS**. Every era is won on all three maps and the tide still takes buildings (6 to 19), but map 4's Livewire is 7.9 minutes, 0.1 under the 8-minute floor. The director accepted that as bot noise: the floor exists to catch trivially short eras. A check at 10 tiles (the director's one extra try) won maps 2 (Livewire 9.1) and 4 (15.2), but the tide took only 2 buildings on map 2 (toothless) and map 1 was still computing after an hour (a stuck or very slow Livewire), so 12 stays. The AI player's relic dig also waits 30 seconds before it tries a failed dig again (`tests/autoplay_relics.gd`).

## Old marks as built (Step 7F)

Three glyph sets beyond the six, kept in `Data.ENDINGS["old"]` and read by `OldShip` (`scripts/old_ship.gd`); `Data.GLYPH_SETS`, `set_order`, the "of 6" count and the Warning are untouched, so a first run and its goldens do not move. The old sets are optional: the Warning does not wait on them.

| Set | Name | Appears | Marks (words) | Reading it shows |
|---|---|---|---|---|
| 7 | The First Ship | run 2 on | Ship, Kin, Home | lore layer 2 (`kin_reveal`): the Kith are Kin |
| 8 | What Broke | run 3 on, or run 2 after a Cataclysm (found in the sprouting ruins then) | Shape, Broke, Hurt | lore layer 3 (`broken_world`): the Bloom is the broken world |
| 9 | The Way Out | run 4 on, and only read while the Lumen are allies | Door, Heal, Go | lore layer 4 (`way_out`): shut it, heal it or go |

- **The first ship's site.** From run 2 the land holds one more hidden place: the hull of the ship that fell ages ago. `OldShip.tile` picks open grass 12 to 22 tiles from the Hearth and at least 10 from the crash site that a party can walk to and back in one day, from a fixed scramble of the map (the same tile every time, no gameplay random numbers). `Starfall.old_ship` and `old_ship_found` are saved. A first run has none.
- **The Expedition Post.** A fourth target, "The first ship's site", listed once a site exists, and in a Cataclysm run a fifth, "The sprouting ruins": What Broke lies at the largest ruin there, not at the ship (every other run keeps it at the ship; `OldShip.source`). A pack brings back the same number of marks as at the crash site (half when late), taken from the lowest old set first. Reaching it for the first time logs a line and records `old_ship_found`. The site is drawn with Codex's `first_wreck` and `first_wreck_2` (one of the two by the tile, never the sim's random numbers).
- **The Wall.** An old set shows once its first mark is home, headed "An older set: n of 3 marks copied". Old marks reuse words of the six (Kin, Home, Shape, Hurt, Heal, Go) and add three (Ship, Broke, Door), which only old marks can try; read words settle only within their own group, so a word read among the six never blocks an old mark. Set 9 with all three marks right but the Lumen not allies waits, and the Wall says so.
- **Gifts.** Reading an old set gives the usual trust step. Reading The First Ship also warms every later run: the carried marks include `g_ship`, and the strangers begin one step (6 trust) warmer in any run after it.
- **Scenes.** `kin_reveal`, `broken_world` and `way_out`, two stills each, placeholder words over Codex's `kin_reveal`, `broken_world` and `way_out` stills.
- **Carried on.** The old marks read are carried with the others, so a later run shows their words at once.
- **The AI player** uses them (Jon's rule: bots know everything from earlier runs). Once the Wreck has given all it has, its Post sends the party to the first ship's site, or in a Cataclysm run to the largest ruin for What Broke, and it guesses the old marks like the others. Set 9 waits for Step 8 (only read while the Lumen are allies). A first run is unchanged.

## Decided (the project owner, 2026-10-06, on cards)
1. Three eras after Starfall: Ironfall, Livewire, Skyreach.
2. The Bloom builds slowly: signs in Ironfall, a tide in Livewire, arrival in Skyreach.
3. The Kith can learn a small branch of the life tree, from Bloom samples, never the whole tree.
4. The Lumen lean opens one reset and the player confirms it on the end card.
5. Era names: Ironfall, Livewire, Skyreach (a set offered on a card; the earlier names Ember, Wire and Reach are retired).

## Open (defaults stand until the project owner says otherwise)
- **Does every reset change the map.** *Default:* yes (Exodus means a new region).
- **Pacing.** About 20 minutes per era, the whole run about 2 hours. *Default:* yes, revisit after Starfall.

## Cross-faction carry-over (the project owner's idea, 2026-10-06; details decided 2026-10-07, not built)
the project owner: with each playthrough, some tech from the other factions carries into the Kith, and later the reverse into the other factions once Lumen and Bloom runs exist.
- **How it fits.** It rides on the Chronicle and the profile save from [13](13-three-perspectives.md): a run records named events (ids plus an outcome), and the profile, not the run save, holds what carries. The Chronicle stays a list of bookmarks, not a simulation. It is a second kind of carry-over beside the reset kinds above (knowledge, relics, memory).
- **The Kith side.** What the Kith learn about the Lumen and the Bloom (glyphs read, sets locked, Bloom samples taken apart) could unlock a small number of echoes in later Kith runs: a Lumen-style recipe or a Bloom-style trick, shown as "known" from the start.
- **The reverse, later.** Once Lumen and Bloom runs exist, the Kith's finished techs (iron, power) would echo into them the same way. Nothing to build until those runs do; keep the profile faction-neutral so it can.
- **Rules to keep.** Carry kinds of knowledge, not stock or places. An echo never skips an era's own mechanic. It is optional flavor, not a power curve.
- **Decided (the project owner, 2026-10-07, on cards).** What carries: one echo per fully read Lumen glyph set and one per Bloom sample type. How much: a handful of techs per run, never a whole branch. Cost: an echo shows as known but the Kith still need its normal materials to build it. When: echoes bank only when a run ends in a reset (Exodus, Cataclysm or Time loop), not after any finished run, so a reset is the turning point.
- **Still canon-pending.** Nothing is built; the Chronicle and profile save from [13](13-three-perspectives.md) come first.

## Not decided here
Anything that changes canon (the Bloom's nature, what the resets mean for the Lumen) goes to [open-questions](open-questions.md) for the project owner's OK before it is built.

### The tellings' art as wired (Step 7)

Codex's 29 paintings (docs/art/tellings) are wired by name, with no change to a first run:

- **Stills.** `skyward_end_*`, `fireside_1`, `kin_reveal_*`, `broken_world_*` and `way_out_*` play in their sequences. The three endings' paintings are the fireside's first still (`ending_*_1`, picked by the ending just recorded); a run that begins after an ending plays `next_telling` after its opening, with `next_land_1` (Exodus), `next_ruins_1` (Cataclysm) or `next_valley_1` (Time loop). A still may name a `portrait` (art/rendered/portraits): the fireside's second still shows `portrait_kin_elder` at the lower left with the caption beside it. `portrait_sela` and `portrait_bloom` wait for the Chronicle's People page (7G).
- **Map.** A standing ruin is `ruins` or `ruins_2` (by the tile and the map, `Rendered.telling`); ground a ruin was cleared from wears `ruins_cleared` while nothing is built on it; a dormant patch wears `bloom_dormant` until the tide begins; a crew at a relic shows `relic_dig`; the first ship's site is `first_wreck` or `first_wreck_2` (`scripts/telling_marks.gd`).
- **Relics.** Each relic's 20 px icon (`relic_everburning_forge`, `relic_old_lantern`, `relic_founders_cart`) marks its ruin on the map in place of the gold dot, and the three sit under the Cataclysm's row on the ending card. The feed and the dig text stay words.

## Kith, then Kin (Step 7)
The people are Kith until set 7 is read, then Kin everywhere they are shown, in every later run (`kin_known` in the profile; scripts/kin_name.gd). The `kin_reveal` sequence has a third still, the Hearthkeeper over the fireside: "We were never only Kith. We are Kin." After it, a one-time card ("A new name", `kin_told` in the profile) says "Your people are now called Kin." The Lore page's line for the first ship reads "The Kith learned they were Kin...". See the decision log, 2026-10-28.

## The Chronicle as built (Step 7G)

The book of every telling (`scripts/chronicle_book.gd`; the sky is worked out in `scripts/chronicle.gd`, the words are `scripts/chronicle_words.gd`). It reads the profile and nothing else, so a first run, its saves and its goldens are untouched.

- **Where.** On the title screen ("The Chronicle", always there, an empty sky before the first telling), in the pause menu, and between tellings: after the fireside the book opens on the telling that just ended with a button, "Begin the next telling", that starts the next run. Esc or Close puts it away.
- **Tellings.** A sky filling the page, one constellation per ended telling, each in its own patch of sky (one column up to three tellings, two after that) with its stars scattered by a scatter seeded from what that telling chose, over a faint starfield. Its stars are the choices of the Starfall (the Cairn, the Hunger, the Shards, the Warning), then the lean and the ending; only what happened is drawn (no faint stars, no question marks). A line of light joins one telling's ending to the next telling's first star. Picking a star reads its entry, written by whoever was there (the Hearthkeeper, Sela, a Lumen mender), then one whisper from the voice that wonders about each road not taken (every option has one), then, from the third telling on, a broken fragment from the Bloom. The ending star is the biggest and brightest, the lean medium, the Embers small and warm. Only the ending star also shows the telling's numbers (minutes, Kith, buildings, buildings the Bloom took), a map of its land at the end (one square a tile, drawn 220 px wide, buildings lit) and buttons to watch its ending and the next land again; the other stars show only their lines.
- **Embers.** Seven hidden moments, found by what a telling did (open hands, closed doors, a cairn before the star, friends without a cairn, the first ship found, all three relics dug, every set of marks read). Each is judged when the telling ends, lights a small gold star in the telling that first showed it, and is never lit twice. Nothing says what an Ember is until it is lit.
- **Lore.** The four layers (the strangers, the Kin, the broken world, the way out), shut until their marks are read; the nine sets of marks drawn from their strokes, a mark shown once it has been read in a telling that ended; and every scene seen, each with a Watch button.
- **People.** The Hearthkeeper, Sela (with the lean and trust of each telling) and the Bloom, with the painted portraits.
- **Endings.** The three endings with how many times each was reached, and the three true endings (Seal Solace, Heal the Bloom, Leave together) with what each needs; Step 8 builds them.
- **Watching again.** The book keeps its own cutscene player over a stand-in run: nothing is recorded, and the stills' variants follow the telling shown (`CutscenePlayer.play`). Every page has Watch buttons for the scenes it knows.
- **What the profile keeps.** Each ended telling's record now also holds `minutes`, `kin`, `buildings`, `lost` (what the Bloom took), `embers` (the ones it lit first) and `map` (one character a tile: `#` building, `b` Bloom, `=` road, `f` field, `r` ruins, `~` river, `t` trees, `^` rock, `.` grass) and `eras` (the minutes each era reached took, the stone age first); the profile holds `embers`. The Story block stamps the game minute each era opens (`Story.stamps`, saved; `era_minutes`). A profile from before loads without them and its sky still draws.
- **Known gap.** The town is counted at the end, not at its peak. Tellings recorded before the era stamps keep only their total minutes.

