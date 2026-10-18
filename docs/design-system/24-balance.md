# Balance: the seven picks

Status: **design only** (2026-10-18). Mechanics page, so Claude owns it. It turns the project owner's approval of 2026-10-14 ("the game plays itself", "1200 wood is dumb") into rules. The research behind the picks is the "Making the middle game matter" page (artifact 3c4kgKaiwvRpkXnnHKowBb); this page only holds what was decided. Every number is a first guess, tuned with the pacing bots on [21](21-stage-starts.md)'s earned checkpoints, never by hand-stuffed starts. It follows [12](12-knowledge-is-progress.md): the price of a thing should say what the Kith know, not how long a pile took to grow.

## What goes wrong today
- Once roads, haulers and Orders are up nothing asks for a decision; the player watches numbers climb.
- Costs of 100 to 500 raw wood or grain say nothing about the world, and the stockpile grows to thousands, so the cost never bites.
- An idle town starves with no runway shown. Livewire's coal runs out before Skyward (about 700 left, about 1100 needed after the Ironfall gate, found by the pacing bot in PR #108).
- The goal strip can show stage-start script text, and map luck moves an era by ten minutes.

## The seven picks
Built in the order below, in four PRs, each green on the Mac runner before the next starts. Pick 4 comes first because it costs the least and the layout pass checks it.

### Pick 5: one live headline goal (already how it works)
- The goal strip already shows exactly one line, the first goal not yet met, and `Story.update` marks every goal that is true each tick, so a goal that is already true is never shown. The chip wraps to two lines (PR #108) and a click opens the full list. The "Lay two Power Poles" line the scorecard saw came from a stuffed stage start that did not set the goals, which the earned checkpoints replaced.
- Nothing to build for this pick; it stays here so the plan reads whole. The era's last goal (the gate) is a price plus deeds, and the strip names the first unmet part, so it needs no change either.

### Pick 4: time left and a pausing card (PR A, built)
- Each good in the top bar shows time left at the current net rate beside its count ("4:10"): **amber under 5 minutes, red under 2**. Only goods with a net loss show one, and the goods Food is made of (berries, fish, flour) do not, because the Food readout already says how long the food lasts. The count and the sprite shrink a little while the time shows, so the chip never grows. The logic is `scripts/runway.gd`; the thresholds are `Data.RUNWAY_AMBER_SECONDS` and `RUNWAY_RED_SECONDS`.
- The **first real famine of a run** (`Economy.famine` turning on) opens one card (`scripts/notice_card.gd`) and pauses the game: how long the food lasts, what idle people will do, and a button that centres the camera on the Hearth. It never opens twice in a run (the flag is saved), and not in the first two minutes (the opening is the player's).
- **Left out, and why:** a default Order "Keep food above 100". The Order Board only exists from Livewire, and its two verbs (Pause, Bring first) act on workshops, so a rule cannot say "make food". A real safety net needs a third verb, **Work first** (huts of that good are worked ahead of the rest, the visible form of `Data.FOOD_SHORT_STOCK`); it goes with the seasons in PR C, where the Lean season needs it.

### Pick 3: tech-scaled storage, slow spoilage, the Bloom eats stock (PR B)
- **Cap per good:** 300 at the Hearth. Each **Storehouse** adds 150 (up to 6) and the techs Granaries, Rails and Factory Floor each add 100. A cap never falls below the biggest price of that good, so nothing becomes unaffordable. A full good spills: the surplus is lost and the chip shows "full". (First guess was 150 and 100: the Ironfall bot then arrived at the coal seams ten minutes late, because its early copper never piled up, so the caps were widened.)
- **Food spoils slowly:** berries, grain, fish and flour lose 2% of the stock above 40 per minute (rounded down; the 40 below is safe, so a small buffer is never taxed). Preservation halves it, Smoking and Baking make the same loss worth more. Stone, ore, metal and charcoal do not spoil.
- **The Bloom eats stock late (Livewire and after):** while it holds at least one overgrown building, once a minute it takes 5% of one good, picked by the minute and the map seed (not gameplay RNG). It is the late sink the research asked for, and a reason to hold the south.
- Upkeep is left for Skyreach.

### Pick 2: raw costs under about 60, bigger prices in made goods plus a lesson (PR B)
- **Rule:** no building or tech asks for more than **60 of any raw good** (wood, stone, flint, clay, grain, fiber, coal, ore, copper, tin, berries). Anything that cost more is paid in made goods in single or double digits: Rope, Brick, Charcoal, Bronze, Iron, Steel, Wire, Flour, Planks.
- **Conversion (strict):** 1 Brick stands for 4 stone and 1 clay's worth of work, 1 Rope for 3 fiber, 1 Charcoal for 2 wood, 1 Plank for 2 wood. A raw price over 60 becomes the raw part up to 60 and the rest at that exchange rate, rounded up; the table lives in `tests/cost_tests.gd` as the audit that fails CI on any raw over 60.
- **Prices follow the exchange rate and no more.** A first pass priced made goods above the rate ("bigger prices in made goods"); the bots then ran short of charcoal and bricks (the kilns and pits cannot keep up), so every row now pays exactly the exchange rate. A tier-4 and 5 tech may cost as little as 170 items. **Not built yet:** the Kith lesson on the biggest prices; it needs a new check in the tech tree and goes with the next balance pass.
- **Open: the Livewire coal margin.** The pacing bots beat the Bloom's first wave on main by about a minute, and any change to the economy (these included) moved that margin: with the new prices the bot builds the Scorcher late and the south is never held. A test with 600 coal handed over at the gate holds it at once, so coal is the whole gap. Richer seams (1000) and faster mines (4 a cycle) bring the Scorcher in but not a held south, so this page leaves the coal rules as they were and drops the earned "south held" checkpoint ([21](21-stage-starts.md)) until a coal rule is picked with the project owner.

### Pick 1: Seasons of Strain (PR C, built)
- A season is a pressure of 90 seconds. The first comes at **6 minutes** of a run, then one every **4.5 minutes** (plus or minus 30 seconds), never twice running. The schedule comes from the map seed and how many seasons have passed, so every bot and playtest sees the same seasons. A card nobody answers answers itself with its first option after 20 seconds of game time, so a bot never stalls on one.
- Three kinds, each unlocked by the story: **Lean** (always), **Cold snap** (after Bronze Dawn) and **Bloom surge** (once the tide has begun). The **Lumen asking** season is left for later, with the "Work first" verb and the default Order.
- Each opens a one-card choice with **no right answer**, two options, each hurting something else, and the answer lasts the season:
  - **Lean:** *Ration* (people eat a quarter less, no births, food huts work at 0.6x) or *Forage* (idle hands go out and bring back twice as much, famine mode is on at once).
  - **Cold snap:** *Burn fuel* (one charcoal, else coal, every 6 seconds, and the workshops keep their pace) or *Huddle* (nothing burns, workshops work at 0.8x).
  - **Bloom surge:** *Let it come* (the tide moves 1.5x as fast, and overgrowth costs nothing this season) or *Hold it back* (pay 20 coal; the tide keeps its pace).
- The code is `scripts/seasons.gd` (state, saved with the run) and `data/seasons.gd` (numbers and words). Everything it changes is a switch on Economy, Tide or the speed of a building, so a season never needs special cases elsewhere.
- Not built: a card never opens while another card is up (the notice card queues it instead).

### Pick 6: pacing guarantees near the Hearth (PR C)
- The stone-age map already guarantees its basics near the Hearth (`MapGen.faults_of`), and the Bronze Dawn strip already guarantees copper near its way in (`MapEast`, tested over many seeds in `tests/era_fair_tests.gd`). So this pick is a check, not new map code: the pacing tool (`tests/tools/pace.gd`) runs the bots across maps and the spread is read off its table.
- Era gates are tied to lesson time: a gate's techs and lessons set the clock, not a pile, so the map spread shrinks as the raw piles stop mattering (pick 2).

### Pick 7: scorecards measure decisions, idle time and a diary (PR D)
- The bots log **decisions per minute** (a build, a research, an order, a seasons answer, an expedition), **idle time** (seconds with nothing affordable or nothing to do) and the **stock to cost ratio** of the last gate. They go in `scorecard-history.json` beside the grades.
- Each scorecard persona writes a **diary** of five fixed questions, every answer citing a log line (When did you last choose? When did you stop needing the screen? What did you ignore? Which cost felt silly? Where were you lost?). The diary points at lines; it is never proof of fun. Jon's own hour beats it.

## Order of work and checks
1. **PR A**: pick 4 (pick 5 needs no code). Tests: the chip's tones and clock face at 300 and 120 seconds, the famine card opens once and not in the opening, the flag survives a save, the layout pass finds no cut-off number.
2. **PR B**: picks 3 and 2 with the cost audit. Tests: the cap spills, spoilage leaves 40, the audit finds no raw over 60, every earned checkpoint still reaches its next gate.
3. **PR C**: picks 1 and 6. Tests: the schedule is the same on a seed twice and never repeats a kind; each answer changes its own numbers; a season survives a save.
4. **PR D**: pick 7, in the playtest tools and the rubric files only.

## Open
- Does Lean ration or forage read as a real choice? Tune after the first earned-checkpoint run.
- Should the cap show on the chip as "80/150" or only when near full? *Default*: only at 80% and above, to keep the bar quiet.
