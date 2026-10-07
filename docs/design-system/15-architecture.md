# Architecture: blocks, interfaces and a testbench

Status: **built** (2026-09-30). Written from main at 46a0f13. Steps 0 to 7b are merged (PRs #5 to #13); step 8 (thin Sim, PR #14) is in review. The golden snapshot (1053 s, 894 s, 857 s) has been identical after every step.

Jon (a DV hardware engineer) asked whether the code should be split into compartmentalized subsystems. Yes. This page frames it his way: every subsystem is a block with a defined interface and its own testbench, and the bot playthrough is the system-level test.

## Why now
- `scripts/game_state.gd` is about 1,000 lines. It holds the map, the stockpile, research, buildings, walking, the Kith, food, fog hooks and the tick order. It is the one block everything touches, so every change edits it.
- Half of it has already been carved out: `fog`, `flows`, `bonuses`, `haulers`, `goals`, `map_gen`, `rules` and the UI modules exist. The rest still lives in GameState.
- The goal is more than tidiness. Blocks with frozen interfaces let separate threads build separate blocks without merge collisions.

## The blocks

| Block | Owns | Interface (in / out) | Today it lives in |
|---|---|---|---|
| **Data** | Every number and name: items, tiles, techs, buildings, goals, tuning, display names | Read-only constants, grouped by domain | `data.gd` (one big file) |
| **World** | Tiles, the river, roads, fields, walkability, buildable checks | in: `generate(seed)`, `set_tile`. out: `tile_at`, `walk_cost`, `is_buildable`. Signal: `tile_changed` | `game_state.gd` + `map_gen.gd` |
| **Economy** | Stockpile, food and eating, item flows and rates | in: `add`, `pay`. out: `can_afford`, `food_total`, `rate(item)`. Signal: `item_changed` | `game_state.gd` + `flows.gd` |
| **Research** | Researched techs, requirements, the queue and goal, tech visibility | in: `research(id)`, `set_goal(id)`. out: `can_research`, `unlocked(id)`. Signal: `tech_researched` | `game_state.gd` + `research.gd` |
| **Buildings** | Placement rules, demolish, statuses, power, processors | in: `place`, `demolish`, `pause`. out: `building_at`, `status`. Signals: `built`, `demolished` | `game_state.gd` |
| **Kith** | Population, jobs and their titles, worker assignment, haulers | in: `tick(dt)`. out: `kith_list`, `idle_count`. Signals: `born`, `left`, `learned` | `game_state.gd` + `haulers.gd` |
| **Pathing** | Walking grid, A*, walk speeds, bridges and passes | in: `path(from, to)`. out: `cost`. Reads World | `game_state.gd` |
| **Fog** | Which tiles the Kith have seen | in: `reveal(pos, r)`. out: `seen(pos)` | `fog.gd` (already a block) |
| **Bonuses** | Speed and Yield multipliers | out: `multiplier(kind, ctx)` | `bonuses.gd` (already a block) |
| **Story** | Goals, teach-by-doing, story events with stable ids | in: listens to every signal. out: `current_goal`, `events` | `goals.gd` |
| **Sim** | The tick order, the only place blocks meet | in: `tick(dt)`. Owns one of each block | `game_state.gd` (becomes thin) |
| **UI** | The HUD, panels, tech board, drawing | reads queries, sends commands, listens to signals. Never mutates a block directly | `main.gd`, `ui.gd`, panels |
| **Save / Profile** | A run save and a separate profile save (knowledge and story events that outlive a run) | in: `save(run)`, `load`. Each block offers `to_dict` and `from_dict` | not built |

## How blocks talk
- **Commands go down, events come up.** UI and Story call a block's methods (commands). Blocks announce changes as signals (events). A block never reaches into another block's variables.
- **One small event bus.** Signals live on the blocks themselves. `Sim` connects them, so wiring is in one file and visible.
- **Queries are read-only.** Anything the UI shows comes from a query or a signal, so the UI is safe to change or replace.
- **Data files, not hardcoding.** Names, costs, radii and tuning live in `Data`, split by domain (`data/items.gd`, `data/techs.gd` and so on). Faction words like "Kith" stay in data, never in block logic, so the same engine can serve another faction ([13-three-perspectives.md](13-three-perspectives.md)).
- **Save and profile split.** Each block serializes itself. The profile save keeps knowledge and story event ids across runs, and a run save keeps everything else.

## The testbench
Each block gets the same three things a DV block gets:
1. **A unit testbench.** A small fixture builds the block alone (World with a tiny fixed map, Economy with a hand-set stockpile) and checks its interface. No other block is needed.
2. **Interface assertions.** The public methods check their arguments and states (a demolish on empty ground, a negative pay). Failures print an error, and CI fails on any printed error.
3. **A monitor.** Signals are logged, so a test can assert "researching Fire emitted `tech_researched` exactly once".

Above the blocks:
- **Integration test:** the pacing bot plays the whole game through the public interfaces. It is the system-level test, and it prints the win time.
- **Constrained-random seeds:** the bot runs on several map seeds, like randomized stimulus.
- **Golden regression:** before any refactor step, the bot's result on fixed seeds (win time and a hash of the final state) is recorded. Every refactor step must reproduce it exactly. That is what makes each step behavior-preserving.
- **CI as the regression farm:** lint, import, the scripted play pass and every test run on each PR, and any error or warning fails the job.

## Refactor plan: small, behavior-preserving steps
Every step is its own PR, keeps CI green and reproduces the golden result. Merge each one before starting the next.

0. **Golden snapshot.** Done (PR #5). A test records the bot's win time and a state hash on three seeds.
1. **Split `data.gd` by domain.** Done (PR #6). `scripts/data/` holds seven domain files and `Data` is a facade.
2. **Extract Economy** (stockpile, food, flows). Done (PR #7): `scripts/economy.gd`.
3. **Extract Research.** Done (PR #8): `scripts/research.gd`, reached as `state.tech_tree`.
4. **Extract World and Pathing.** Done (PR #9): `scripts/world.gd` and `scripts/pathing.gd`.
5. **Extract Buildings.** Done (PR #10): `scripts/buildings.gd`, reached as `state.town`. The per-building work cycle stays in GameState until Bonuses, Hands, Roads and Workers stop taking the whole GameState.
6. **Extract Kith** (with jobs, walking and titles). Done (PR #11): `scripts/kith.gd`, reached as `state.people`.
7. **Introduce signals** and move Story onto them (7a, PR #12: `scripts/story.gd`, `sim.story`, signals wired in `Sim._init`). Then `to_dict` and `from_dict` on each block, a versioned run save (`scripts/run_save.gd`) and a separate profile save (`scripts/profile.gd`, holding only the Chronicle of story ids and the items the Kith have learned) (7b, PR #13). Nothing reads the profile yet. The run save has a UI since 2026-10-07: the pause menu (Esc) saves and loads it (`scripts/game_menu.gd`, `scripts/pause_menu.gd`) and the title screen's Continue starts from it (`scripts/title_screen.gd`, `scripts/launch.gd`).
8. **Retire the pass-through methods.** Done (PR #14): GameState is now `Sim` (`scripts/sim.gd`, 293 lines, 10 public commands). The work cycle moved to `scripts/work.gd` and `Workers.tick_building`. Convention tests fail if a retired pass-through name returns.

Each extraction ships with that block's unit testbench.

## Who owns what
Once step 8 lands, each block is a folder-sized unit (`scripts/<block>/`) with its own tests. A thread owns one block at a time, and interface changes go through the design doc first. That is what lets several threads work in parallel.

## Open
- The ordering of steps 3 to 6 may change once the in-flight branch lands, because it touches Kith, buildings and research.
- Resolved in 7a: `RefCounted` blocks hold signals and connecting them in `GameState._init` works under the headless test runner. Use method references, not lambdas that capture the owner, to avoid reference cycles.
- Testbench conventions learned: assert with return values (CI fails on any printed error), keep discarded-return methods `void`, and a block takes the other blocks it needs in its constructor, or a read-only callable when a block reference would be circular.

## Where things live now (after step 8)
- `Sim` owns `economy`, `world`, `pathing`, `tech_tree`, `town` (Buildings), `people` (Kith), `story` and `fog`. Callers reach a block directly: `sim.economy.inv`, `sim.world.tile_at(p)`, `sim.town.placement_error(...)`.
- Sim's commands: `generate`, `tick`, `place`, `place_line`, `demolish`, `set_paused`, `research`, `gather_by_hand`, `hold_harvest`, `release_harvest`.
- Save: `RunSave.dump(sim)` and `RunSave.restore(sim, d)` for a run; `Profile` for what outlives a run. A mid-run save loaded into a fresh Sim continues identically (tested).
- Still to tidy later: the trailing "Needs road" alert loop in `Sim.tick` could move to a Roads helper, and the static modules (`Bonuses`, `Hands`, `Roads`, `Workers`, `Work`) still take the whole Sim as an argument.
