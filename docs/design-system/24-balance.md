# Balance: the seven picks

Status: **design only** (2026-10-18). Mechanics page, so Claude owns it. It turns the project owner's approval of 2026-10-14 ("the game plays itself", "1200 wood is dumb") into rules. The research behind the picks is the "Making the middle game matter" page (artifact 3c4kgKaiwvRpkXnnHKowBb); this page only holds what was decided. Every number is a first guess, tuned with the pacing bots on [21](21-stage-starts.md)'s earned checkpoints, never by hand-stuffed starts. It follows [12](12-knowledge-is-progress.md): the price of a thing should say what the Kith know, not how long a pile took to grow.

## What goes wrong today
- Once roads, haulers and Orders are up nothing asks for a decision; the player watches numbers climb.
- Costs of 100 to 500 raw wood or grain say nothing about the world, and the stockpile grows to thousands, so the cost never bites.
- An idle town starves with no runway shown. Livewire's coal runs out before Skyward (about 700 left, about 1100 needed after the Ironfall gate, found by the pacing bot in PR #108).
- The goal strip can show stage-start script text, and map luck moves an era by ten minutes.

## The seven picks
Built in the order below, in four PRs, each green on the Mac runner before the next starts. Pick 5 and pick 4 come first because they cost the least and the bots can check them.

### Pick 5: one live headline goal (PR A)
- The strip shows exactly one line: the first unmet item of the current gate or tutorial goal, written from live state, never stage-start script text. It wraps to two lines (the chip from PR #108) and a click opens the full list.
- A goal that is already true is never shown (the "Lay two Power Poles" line while poles stand).

### Pick 4: time left, a pausing card, a safety Order (PR A)
- Each good in the top bar shows time left at the current net rate under its count ("4:10"): **amber under 5 minutes, red under 2**. Only goods with a negative net rate show one. Food uses the Economy's existing runway; coal and charcoal use the flow window.
- The **first real famine of a run** (`Economy.famine` turning on) opens one card and pauses the game: what is short, how long it lasts, and a button that points the camera at the Hearth. It never opens twice in a run, and not in the first two minutes (the opening is the player's).
- A new game starts with one written Order, "Keep food above 100" (a Bring first on the nearest food huts), in the first free slot as soon as the Order Board is built. The player can delete it; it is a net, not a rule.

### Pick 3: tech-scaled storage, slow spoilage, the Bloom eats stock (PR B)
- **Cap per good:** 150 at the Hearth. Each **Storehouse** adds 100 (up to 6) and the techs Storehouse, Granary and Warehousing each add 150. A full good spills: the surplus is lost and the chip shows "full". Haulers do not pick up what has nowhere to go.
- **Food spoils slowly:** berries, grain, fish and flour lose 2% of the stock above 40 per minute (rounded down; the 40 below is safe, so a small buffer is never taxed). Preservation halves it, Smoking and Baking make the same loss worth more. Stone, ore, metal and charcoal do not spoil.
- **The Bloom eats stock late (Livewire and after):** while it holds at least one overgrown building, once a minute it takes 5% of one good, picked by the minute and the map seed (not gameplay RNG). It is the late sink the research asked for, and a reason to hold the south.
- Upkeep is left for Skyreach.

### Pick 2: raw costs under about 60, bigger prices in made goods plus a lesson (PR B)
- **Rule:** no building or tech asks for more than **60 of any raw good** (wood, stone, flint, clay, grain, fiber, coal, ore, copper, tin, berries). Anything that cost more is paid in made goods in single or double digits: Rope, Brick, Charcoal, Bronze, Iron, Steel, Wire, Flour, Planks.
- **Conversion:** 1 Brick stands for 4 stone and 1 clay's worth of work, 1 Rope for 3 fiber, 1 Charcoal for 2 wood, 1 Plank for 2 wood. A raw price over 60 becomes the raw part up to 60 and the rest at that exchange rate, rounded up; the table lives in `tests/cost_tests.gd` as the audit that fails CI on any raw over 60.
- **A Kith lesson on the biggest prices:** each tech and building at the top of an era asks for one named lesson in the town ("one Taught Hand II mason"), so the pillar shows in the price. First pass: the three biggest techs of each era, picked from the audit.
- Copper, tin and coal for Livewire are set so the era's gate fits what the earned checkpoint leaves (about 700 coal) with one new coal vein guaranteed by pick 6.

### Pick 1: Seasons of Strain (PR C)
- A season is a pressure of about 90 seconds that arrives every **4.5 minutes** of an era, never in the first 6 minutes and never twice running. The schedule comes from the run's map seed and the clock, so every bot and playtest sees the same seasons.
- Four kinds, unlocked as the story brings them: **Lean** (food yields 0.6x), **Cold snap** (coal and charcoal burn twice as fast), **Bloom surge** (Livewire on: the tide moves 1.5x toward one side), **Lumen asking** (Starfall on: shards for a lesson).
- Each opens a one-card choice with **no right answer**, two options, each hurting something else (Lean: "Ration" eats 25% less but pauses births, or "Forage" sends idle people out and slows the Hearth's work). The answer lasts the season. An Order can prepare for a season; nothing can make the choice for the player.
- A card never opens in the first two minutes after another card, and never while the game is paused on a famine card.

### Pick 6: pacing guarantees near the Hearth (PR C)
- `map_gen.gd` guarantees, for each era's key resource (clay and flax for Bronze Dawn, iron for Ironfall, copper, coal and shards for Livewire), at least **12 tiles within 24 tiles of the Hearth**, checked by a test over 20 map seeds.
- Era gates are tied to lesson time: a gate's techs and lessons set the clock, not a pile, so the 10-minute map spread closes. The Livewire bot (the pace tool's `livewire` mode) must finish within 4 minutes of the median on every seed.

### Pick 7: scorecards measure decisions, idle time and a diary (PR D)
- The bots log **decisions per minute** (a build, a research, an order, a seasons answer, an expedition), **idle time** (seconds with nothing affordable or nothing to do) and the **stock to cost ratio** of the last gate. They go in `scorecard-history.json` beside the grades.
- Each scorecard persona writes a **diary** of five fixed questions, every answer citing a log line (When did you last choose? When did you stop needing the screen? What did you ignore? Which cost felt silly? Where were you lost?). The diary points at lines; it is never proof of fun. Jon's own hour beats it.

## Order of work and checks
1. **PR A**: picks 5 and 4, plus the pacing bot's runway log. Tests: the strip never shows a true goal; the chip colours at 300 and 120 seconds; the famine card opens once; the default Order exists and can be deleted.
2. **PR B**: picks 3 and 2 with the cost audit. Tests: the cap spills, spoilage leaves 40, the audit finds no raw over 60, every earned checkpoint still reaches its next gate.
3. **PR C**: picks 1 and 6. Tests: the schedule is the same on a seed twice; each season's two answers change different numbers; the guarantee holds on 20 seeds.
4. **PR D**: pick 7, in the playtest tools and the rubric files only.

## Open
- Does Lean ration or forage read as a real choice? Tune after the first earned-checkpoint run.
- Should the cap show on the chip as "80/150" or only when near full? *Default*: only at 80% and above, to keep the bar quiet.
