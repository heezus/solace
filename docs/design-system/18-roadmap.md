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
Skyward's card has "Choose an ending" beside "Keep building" (the game menu has it too, greyed until Skyward stands). It opens a card headed "The first telling ends here" (later runs: "Telling N ends here") with three rows, each with its name, a line of story, what it gives and, when the lean shuts it, why. A chosen row asks "Leave this land?" in the words of how that ending ends; a yes records the ending as a Chronicle moment (`ending_exodus`, `ending_cataclysm`, `ending_loop`), banks the carry and begins the next run. Before the card, the `skyward_end` cutscene (the mast lit, the Bloom on the horizon, Sela: "Not this time. But you'll remember.") plays. After any ending, before the next run starts, a short `fireside` scene plays (one still, three placeholder lines: the Hearthkeeper tells the children the telling that just ended); the Chronicle book that opens after it is Step 7G, so for now the next run's "A new land" card follows it. Cutscenes switched off skip it.
- **Locks** (the lean Starfall ended with): Exodus always; Cataclysm needs "the Lumen as enemies"; Time loop needs "the Lumen as allies". Neighbours open only the Exodus.
- **Exodus:** a new map (as built in 7B).
- **Cataclysm:** the next run keeps the same map seed. Up to 60 of the old town's dearest buildings become Ruins tiles (one tile each, none within 3 tiles of the Hearth): rubble nothing can be built on until Demolish clears it, which gives Stone (the building's cost over 25, from 3 to 20). Ruins in the land that grows east or south are laid when the land grows. Two to four dormant Bloom patches (two tiles of Bloom ground) sit by the largest ruins; the tide still wakes at the first engine and spreads from them as well as from the south. The Lumen arrive wary even if a Cairn stood first (trust 0, no guests).
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

The spec's bar was a bot Exodus run at least 3 minutes faster on both maps with no era under 8: **not met**. A blueprint saves a player's clicks, not materials; the bot already places what it wants the moment it can pay, so queued plans mostly spend stone and wood on things it would have built later, ahead of research. The 70% share (the director's call) was kept as the rule and not lowered. See the decision log, 2026-10-27.

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
