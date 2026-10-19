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

The AI player is not a human. It does not tire, and it reads every word. Its diary says where a careful reader gets stuck, and the recorder says where Jon does. Both go beside the bots' numbers in the scorecard, and each says which it is.

## What this changes in the scorecards

The scorecard keeps its two reviewers. Under them goes a "Measured play" block with three columns: Bot (the pacing tool), AI player (diary and decisions), and Jon (the recorder), so a grade can say what a person felt, not only what a bot did. Page 24 pick 7 is the first step of this and folds in here.

## Not in this page

Sound, accessibility testing and a public build's analytics are out of scope. Nothing here collects names, accounts or anything outside the game's own state.
