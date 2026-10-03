# Three Perspectives (long-term idea, not canon)

Status: **idea only** (2026-09-30). Nothing here is decided, designed in detail or scheduled. It's written down so current work doesn't rule it out.

Jon, thinking out loud: "Eventually I'd like to be able to start as each race, and have different canonical events, and maybe have playthroughs bleed together where those events kinda bookmark stuff... after a few playthroughs as the Kith you unlock starting as the Lumen. And then after a few playthroughs as them you can start as the Bloom. And what happened in previous playthroughs decision wise will somehow impact it as if it were a story told out of order and simultaneously."

## The idea in one line
One history of Solace, seen from three sides. Each playthrough fills in part of a shared **Chronicle**, and the choices you made as one faction show up as facts when you play another.

## How it ties in
- **Knowledge is progress** (12-knowledge-is-progress.md): playing another side is the deepest kind of knowledge. As the Kith you decipher the Lumen. As the Lumen you learn why they fled, and as the Bloom you learn what it wants.
- **The Time loop** (06-mechanics.md) gives the in-story reason. The planet rewinds, and each loop you wake up remembering, but in someone else. That makes the three perspectives the Time loop's reward rather than a separate mode.
- **The three resets** become outcomes the Chronicle records. An Exodus, a Cataclysm or a Time loop in a Kith run is part of what the Lumen and the Bloom later find.

## Keeping it simple
The rule: **the Chronicle is a list of bookmarks, not a simulation.** Other factions aren't simulated in the background. Each bookmark is a named event with a recorded outcome (one flag or a small value), and a run reads only the flags it cares about.

| Unlock | Plays like | Start | Reuses |
|---|---|---|---|
| **The Kith** (default) | Automation from the stone age up, as now | The Hearth, stone age | Everything |
| **The Lumen** (after a few Kith runs) | Magic-first automation, with a crashed ship as the base and a starlight tree as the main tree | The crash site, mid-timeline | The same engine, map generator and chains, with a different tree and different buildings |
| **The Bloom** (after a few Lumen runs) | Spread instead of build. You grow across tiles and consume, and the others push back | Landfall, late in the timeline | The map, and the tide rules from research idea E. It's the most new work |

## Bookmark events
These are the moments all three stories share. Each records one outcome that the other perspectives read.

| # | Bookmark | Seen by | Outcome recorded (examples) | Felt in later runs |
|---|---|---|---|---|
| 1 | **The first shards fall** (ages ago) | All, as legend | None. It's fixed history | Shards are on the map in every run |
| 2 | **The Wanderer appears** (Bronze Dawn) | Kith watch it. Lumen are aboard it | Did the Kith build a Watchtower and chart it? | The Lumen see a signal fire and know someone saw them coming |
| 3 | **The Falling Star** (the crash) | Kith and Lumen | Where it landed relative to the Kith | The Lumen crash site sits where the Kith player saw it fall |
| 4 | **First words** (the translation) | Kith and Lumen | How many glyphs the Kith deciphered, and whether trade happened | The Lumen start with Kith words they already understand, or a total language barrier |
| 5 | **The choice** (trade, conflict or a mix) | Kith and Lumen | Which path the Kith took | The Lumen start with allies, wary neighbors or enemies |
| 6 | **The noise** (Kith industry is heard) | All three | How loud the Kith grew (pollution, size) | The Bloom arrives sooner and closer in a loud world |
| 7 | **The Bloom arrives** | All three | Which faction it found first | The Bloom's landfall point and first prey |
| 8 | **The ending** (Exodus, Cataclysm or Loop) | All three | Which reset happened | Ruins, relics or a strange sense of déjà vu in later runs |

## Games that did something similar
- **13 Sentinels: Aegis Rim.** Thirteen characters, one story told out of order. You unlock perspectives, and each one reframes the others. It also pairs the story with a strategy mode, which is close to Solace's mix.
- **Resident Evil 2 (1998), the "zapping" system.** Two characters in the same disaster. The second scenario starts after the first and changes based on what the first character took or did. It's the simplest proof that "choices in one run shape the other side" works with plain flags.
- **StarCraft and Warcraft III.** Each race gets its own campaign of the same war, and the player unlocks and plays sides in turn. It's the RTS version of the idea, but without choices carrying over.

## What it needs from today's design
Cheap things to keep in mind now, so the door stays open:
1. **No hard-coded "Kith" in the engine.** Buildings, techs, starting units and HUD text come from data tables keyed by faction. `scripts/data.gd` already holds the numbers, so keep new systems data-driven too.
2. **A profile separate from the run save.** Prestige needs this anyway. The Chronicle lives in the profile, as a small file next to the saves.
3. **Named events.** When a big moment happens (the Wanderer sighted, Bronze Dawn researched), the game logs it with an id. The Chronicle is those ids plus an outcome.
4. **A map generator with inputs.** The smarter maps (12-knowledge-is-progress.md) should take parameters like "crash site here" or "Bloom landfall there", not only a seed.
5. **Canon from both sides.** The world lore should record what each event looks like to each faction, so the Lumen's story matches what the Kith saw.

## Claude's take
- It's worth keeping as the game's long-term payoff. It turns the Time loop from a reset into the reveal, and it fits "knowledge is progress" exactly.
- Cost rises steeply. Bookmarks in Kith runs are cheap and worth adding early. A Lumen campaign is a big but reusable chunk. A playable Bloom is almost a second game.
- **Suggested ladder:** (1) log bookmark events in Kith runs, which is nearly free, (2) the Lumen as a shorter campaign from the crash onward, and (3) the Bloom as a short final mode first, grown only if it's fun.

## Jon's answers (2026-09-30)
- **The Bloom:** a short finale first, with a fully playable Bloom later.
- **The Lumen's timeline:** Jon was unsure ("as a first game maybe it's a pickup"). Claude's default is **start at the crash**:
  - The Lumen run opens at bookmark 3 (the Falling Star), which is the middle of the Kith story.
  - It replays the second half from the Lumen side (first words, the choice, the Bloom arriving), shaped by the Kith run's Chronicle flags.
  - It then carries on past where the Kith run ended.
  - Nobody replays the stone age as the Lumen, so it's cheaper than a full replay. You still get the "same story, other side" feeling where it matters most.

## Open
- How many runs unlock each faction?
