# 25. Playtesting: the recorder and the AI player

Owner: Claude (gameplay, tests, CI). Written 2026-10-19 at Jon's ask: "how can we improve this because it seems kind of like a major hole".

## The hole

Every playtest so far is a scripted bot or an AI persona grading screenshots. A bot never gets bored, never reads a card, never decides to try something odd. So the scorecards can say the game runs and fits the screen, and they cannot say whether it is fun to sit in front of for twenty minutes. Two things fill it, and Jon chose both: a recorder that watches real people play, and an AI player that makes its own choices and says how it felt.

## Part 1: the play recorder (in the game)

A passive observer. It never writes to the game, never touches the simulation's random numbers, and never changes a result; a run with the recorder off plays the same second for second (a test checks the state hash both ways).

**What it logs** (one JSON object per line, `user://playlogs/<start>-seed<n>.jsonl`, nothing leaves the machine by itself):
- `run`: version stamp, map seed, start time, window size.
- `sample` every 10 game seconds: game time, era, Kith, food total and seconds of food, each stockpile with its cap, buildings by type, researched count, the goal now showing, speed, idle Kith, and `quiet` (real seconds since the player last clicked or pressed a key).
- `act` for each change the player made, read by diffing the town between samples and from the input stream: built, demolished, researched, hut focus changed, season answered, Order written, speed changed, paused.
- `card` when a card opens and when it is answered, with the real seconds it waited (famine card, season card, era card, moment card).
- `era_end` with the three answers below, and `quit` or `end` with the reason (menu quit, window closed, run won).

**The era-end card.** After each era card is put away, one small card asks three things by tapping, never typing:
1. How did that era feel? (Dull, Okay, Good)
2. What got in your way most? (Waiting for goods, Not knowing what to do, Too hard, Nothing)
3. Play on? (Yes, Not now, I'm done)

It is skippable, it asks once per era, and the game waits behind it like the other cards. The answers go in the log, which is the point of asking at the moment, not afterwards.

**Switch.** Pause menu, "Play log": on or off. On by default, kept in `user://playlog.cfg` like the cutscene switch.

**Reading it back.** `tests/tools/play_summary.gd` turns a log into the scorecard's measured block: decisions a minute, longest idle stretch, minutes waiting on a want, seconds each card waited, the quit point, the era-end answers. A manual workflow, `playlogs.yml`, uploads the logs folder from the Mac as an artifact, so Jon plays and nothing else is asked of him.

## Part 2: the AI player (a harness on the Mac)

A Claude session plays the real game through text, with no view of the code.
- `tests/tools/ai_player.gd` runs the real Sim headless. Every few game seconds (15 by default) it stops and writes `snapshot_<n>.txt`: time and era, the goal, each good with stock, cap, and rate in and out, Kith and how many are idle, buildings and what each is doing, what can be built or researched now with its cost, any card waiting, the last few messages.
- The player answers with `moves_<n>.json`: a list of the same commands the game offers (build here, demolish, research, set a hut, answer a card, write an Order, change speed) and a `diary_<n>.md` line on what it wanted and how it felt (bored, pleased, stuck, surprised). A move the game would refuse comes back in the next snapshot as a refusal, as it would to a person.
- The harness applies the moves through the same Sim commands the game uses, so nothing is possible that a person could not do. Real time per decision is the player's own; game time stands still while it thinks.
- Rules for the player: it sees only the snapshot, plays to win the era it is in, and keeps a diary even when nothing happens. The diary is the product; the win or loss is secondary.
- Cost: about 60 decisions an era. It runs only when Jon asks, one era at a time, like the scorecards.

**How a session runs it.** Start the table, then loop: read `snapshot_<n>.txt`, write `moves_<n>.json` and `diary_<n>.md`, read the next page.
`godot --headless --path . -s tests/tools/ai_player.gd -- --dir=<folder> --seed=3 --decisions=60 --stop-at-era="Bronze Dawn"`
The page also carries the move list and an ASCII map with a coordinate ruler. Moves in version 1: gather by hand, build, demolish, research, set the research goal, answer a Season card, answer a story moment, wait. Standing Orders (Livewire) are not offered yet; that era is played by what the other moves can do, and the diary says if that hurt. The table has `ai_player_tests.gd` for the page and the hands.

**Replay and waits (2026-10-22).** `--replay=<folder>` plays a finished game back from its `moves_<n>.json` (same `--seed` and `--start`): the game is deterministic, so every page comes out as it did, with whatever the page shows now. It is how a change to the hauling or the words is measured on the very towns the player built. A `wait` inside a move list now lets the game run before the moves after it are made (waits side by side count as the longest); at the end of a list it behaves as before. A waiting workshop's line on the page ends with the short reason ("Needs Wood · haulers busy", `scripts/wait_why.gd`).

**Long runs keep their place (2026-10-23).** A run can stop part way (the machine restarts, Jon closes the lid). `pace.gd baseline` keeps a checkpoint every ten game minutes and a Livewire-alone or variant run (`from=`) every five, in `user://baseline_work/`, and picks up from it when started again. An AI player folder that already holds `moves_<n>.json` is picked up on its own: the saved moves are replayed (the game is deterministic, minutes) and the next page waits for a live player; `--fresh=1` starts it over. `tests/tools/long_run.sh start <name> <command...>` registers a run and starts it in the background; after any restart `tests/tools/long_run.sh resume` starts again every registered run that has not finished (`status` lists them). The registry lives in `/mnt/project-files/runs/` by default.

The AI player is not a human. It does not tire, and it reads every word. Its diary says where a careful reader gets stuck, and the recorder says where Jon does. Both go beside the bots' numbers in the scorecard, and each says which it is.

## What this changes in the scorecards

The scorecard keeps its two reviewers. Under them goes a "Measured play" block with three columns: Bot (the pacing tool), AI player (diary and decisions), and Jon (the recorder), so a grade can say what a person felt, not only what a bot did. Page 24 pick 7 is the first step of this and folds in here.

## Not in this page

Sound, accessibility testing and a public build's analytics are out of scope. Nothing here collects names, accounts or anything outside the game's own state.

**The era click pass.** `tests/tools/era_pass.gd` plays the start of one era like a person: the real UI is live and every click and key is a real input event. It opens each build tab and clicks the cards on show, puts a few buildings down with the mouse, clicks a building of every type and what its panel offers, presses every tab key and the research board, opens the menu, saves and loads, and lets the town run at triple speed. A card the game puts up is answered with its first button. It fails on any ERROR, WARNING or PROBLEM line. The manual workflow `era-pass.yml` ("Era click pass", never on a push, never nightly) runs it on eight starts, from the late stone age to the earned Livewire checkpoint; the two earned starts build their checkpoint from a real run, so a full pass takes a while. Give it one start id to run just that era.

## The playtest log (Nov 4 2026): numbers behind the fun rubric

Owner: Claude. The rubric (the director's `fun-rubric.md`) scores nine items 1 to 5 from a fresh player's opinion. Fifteen measured metrics (M1 to M15) back them up with numbers. The play log above answers a different question (what Jon did, with an era-end card) and stays as it is; this log is for the fresh-eyes playtests and the scripted players.

**What it is.** `scripts/playtest_log.gd`, a read-only observer. A local file of JSON lines in `user://playtest_logs/` (one file per run, named by time, seed and a count), no network, nothing in a save or the profile. **Off by default.** It turns on with `-- --playtest-log` (or `--playtest-log=<folder>`) on the command line, or `[playtest] on=true` in `user://playtest_log.cfg`. Every `Sim` made while it is on writes a log, so the bots (`pace.gd`, the autoplay tests) and the AI player log with the same flag and no code of their own. The log hangs on the Seasons block (`sim.seasons.watcher`, null when off) and is called once a tick; it listens to the town's `built`, `demolished` and `refused` signals and the research board's `tech_researched`, and reads the rest from the Sim's own records. The Sim itself is untouched. It never writes to the game or draws a random number, and a test checks the state hash is the same with it on or off.

**Raw events, not scores.** `run`, `era`, `goal`, `tech` (with `known` for a tech carried from an earlier telling), `act` (kind, target, game minute, and `decision`: true for a build, research, choice or demolish; false for upkeep: a hand harvest, a refused placement; a pause or resume counts as a decision; a dragged line of roads is one act), `first_use` (the first sign of each era's new mechanic), `stopped` (a building whose alert stayed up 10 game seconds), `loss` (a building the Bloom took, `warned` when the game had announced the tide for it), `regret` (a building taken down within 60 s of being put up), `tick` (every 10 game seconds: acts, goods by hand, by haulers and by buildings, the seconds since the last progress, whether a step that moves the goal on show was affordable) and `snap` (every 5 game minutes: buildings, goods a minute, hand and hauled totals). In the real game a small recorder (`scripts/playtest_recorder.gd`) adds `click`, `panel` (a building's card opened), `menu`, `cutscene` (watched or skipped), `chronicle`, `endings` (how long the card was up), `detail` (an ending's confirm card opened) and `quiet` (two minutes with no input).

**The table.** `tests/tools/playtest_summary.gd -- <log.jsonl> [--base=<run 1 log>]` prints M1 to M15 as markdown with each target and PASS, MISS or N/A (the log has nothing to judge it by: no stopped building, no cutscene, a scripted run has no clicks). Every row prints how it was counted. `--base` gives M8 its run 1. A bot's M3 and M4 read hard on purpose: it hand-harvests and builds tile by tile; the table is for people and the AI player, and says "acts, no clicks logged" when there are no clicks.

**Choices.** "Warned" is the game's own Tide Watch announcement, because that is what the game shows before a loss; Sight itself does not draw the tide. "Progress" for M5 and M6 is a goal, a tech, a first building of a kind or a new era. The hand share leaves the stone age unjudged (no haulers yet). The first use of an era's mechanic is a small table at the top of `playtest_log.gd` (hand harvest, first crucible, first moment answered, first lesson learned, first power pole or order, first signal tower). M1 counts the first two minutes in which buildings make goods and nothing is made by hand (building other things in that time is allowed). M5 idles only when nothing affordable moves the goal on show. M6 reports the longest spell and the minutes stuck in all, and misses on any spell over 5 minutes; such a spell is also a near-quit in M10. All of these are one-line changes in `playtest_log.gd` and `playtest_summary.gd`.

## No silent gates (Nov 5 2026, from fun playtest 1)

Owner: Claude. The first fresh-eyes playtest lost 30 to 40 minutes at the Grindstone goal: Farming was out of view (a tech shows only once the Kith have held every good it costs) and nothing said so. The rule now is one walk back through the tech data, `scripts/chain.gd`:

- `Chain.step(s, tech)` walks the tech's route and returns the first step that is not just a price: a good never held, a gift, Lesson or deed not had, a story moment, else the first price not met. `Chain.note` words it ("Grindstone needs Farming. Farming isn't in view yet: get Grain in your hands once (gather or make it) to see it."); `Chain.refusal` says why a tech cannot be discovered now.
- It shows in three places: under the current goal (Goals panel), on the locked card of the building the current goal asks for (the card shows even when its tech is out of view, says "Blocked by Farming", and its tooltip has the whole sentence), and in the AI page ("IN THE WAY", and a refused research move).
- A dragged line reports the first tile that will not take it ("Laid 3 of 9. Stopped at (22, 6): Roads can't go on Riverbed Gravel: go around it, over grassland, Forest or Rocks"). Ground refusals name the ground ("Build on open grassland (this is Wild Grain)").
- A building's requirement is a `Needs:` line at the start of its blurb ("Needs: a river tile beside it."), never a status. The blurb shows once; the status line shows only what is true now.
- `gravel_road` is a road tier (faster, laid over a Road), not a road for gravel ground; roads still refuse gravel, clay, grain, berry and flax ground.
- The AI page is no longer a thinner screen than the player's: it prints a building's own status in full (the cause is in it), the Kith growth notes, hauler counts as "haulers for places", FOOD as a count of food with the worth of each good, and "forage" for the internal famine flag.

## No dead air, and the page says the same as the stock (Nov 6 2026, from fun playtest 2)
- **The wait after "all met".** The dawn's checklist ended at the first Bronze, so both players saw "All goals done." for 21 and 31 minutes while the Falling Star, the gate that opens the next era, was still unmade. Each era's list now ends on its gate (the dawn's last goal is the Falling Star with its price), so "all met" is true only when the next era has begun. Test: `test_every_era_ends_on_its_gate_goal`.
- **Teach the machine.** `scripts/chores.gd` keeps the last minute of hand work (a harvest by hand, or a click on a hut or workshop no road serves). Five of the same good in that minute and the goal line adds the building that would do it: "A staffed Twine Post on a road makes Rope." or "A Gatherer's Hut beside the Wild Flax, on a road, gathers it for you." If the building is not discovered it says to discover it first. Only in the first two eras: later eras assume the player learned it. No costs changed.
- **Hauler places.** "Waiting for hands: haulers come first" now names the two real controls: the - on the Hearth's Haulers row, or a Dwelling for more Kith.
- **One source for statuses.** A hand-run building whose input is in the stockpile says "Fiber is in stock: click it to load" (pill "Needs a click", or "Needs road" once Paths & Haulers is known), and says "Needs Fiber (none in stock)" only when the stockpile is empty. "Food is short" shows only when `Economy.food_is_short()` is true; a lean season that sends idle hands out with a full store says "A lean season". The AI page's food line uses the same `Economy.food_rate()` as the top bar. Every refusal the table prints carries a reason.
- **Boxed in.** A gatherer or workshop placed where no road can ever touch it (every side is flax, berries, grain, clay, ore or a building roads do not run through) gets a warning in the hover and in the log (`Roads.boxed_in`). It is a warning, not a refusal: before Paths & Haulers the building still works by clicks.
