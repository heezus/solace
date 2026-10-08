# 21. Stage starts, save slots and debug keys

Three tools for playing, testing and debugging the game without replaying it from the start. They ship in the normal game; nothing here changes how a normal run plays.

## Save slots

- Five slots, `user://run_slot_1.json` to `user://run_slot_5.json` (`scripts/save_slots.gd`). A slot file is a run save exactly as `RunSave` writes it (the version is unchanged) plus one extra top-level key, `meta`: the era, minutes played, Kith and when it was saved. The Load screen reads `meta` to describe a slot without restoring it.
- Pause menu, **Save game**: pick a slot. Each shows "Starfall, 42 min, 7 Kith" or "empty". Saving over a filled slot asks for a second click. There is no autosave.
- **Load game** (pause menu) and the title's **Load game** open the Load screen: the filled slots first, then the stage starts. The title's **Continue** loads the most recently saved slot.
- The single save of earlier versions (`user://run.json`) moves into the first empty slot, normally slot 1, the first time slots are listed. Nobody loses a run.

## Stage starts

A stage start begins a **new run** at a chosen stage, on a fixed map (seed 1) with the town already built. Starts are read-only: Save only ever writes to a slot, so a start can never be overwritten. They are listed on the Load screen as "Stage: ...".

| Id | What it is |
| --- | --- |
| `stone_age` | A fresh map. |
| `stone_late` | The stone age played by the pacing bot, at the moment Bronze Dawn is discovered. |
| `bronze_first` | On to the first Bronze made. |
| `falling_star` | The Falling Star has just fallen (the silence before the landing). |
| `starfall_landing` | The star has come down and the strangers have walked out of the fog. |
| `starfall_camp` | Glyph Wall, Lumen Camp and Expedition Post stand; the first glyph set is read and the strangers have a name. |
| `starfall_market` | Trust built, the Lumen would trade, the Lumen Market stands. |
| `starfall_end` | Five sets read, every question answered, the Warning copied and guessed right: the era ends at the next talk, a few seconds in. |
| `ironfall` | The Starfall is over and its ending card put away: Ironfall has begun, its first techs are in view and the land waits to grow south. |
| `ironfall_teardown` | Teardown and Coal Seams are learned, the south is open, a Teardown Bench stands beside the Hearth and the Wreck's three parts are in the pack, ready to be opened. |

Nothing is committed as a save. `scripts/dev_starts.gd` builds a start on demand: the pacing bots (`tests/autoplay.gd`, `tests/autoplay_bronze.gd`) play the fixed map to the boundary, and the Starfall starts are a short scripted setup on top of the Falling Star using the normal `Sim`, `Starfall` and `Story` calls. So a start is deterministic, and it follows the balance by itself: change a price or a delay and the next build is the new stage.

The bots take about five minutes of real time in a debug build (one run makes `stone_late`, `bronze_first` and `falling_star` together), so the release builds ship them **baked**: `.github/workflows/release.yml` runs `tests/tools/bake_starts.gd` before exporting, which writes `stage_starts/*.run` (not in the repo, `.gitignore`d, shipped through the presets' `include_filter`). `DevStarts` looks for a start in this order: the baked file, then the cache in `user://stage_starts/`, then it builds on demand. A file is used only when its fingerprint (every `Data` constant, `DevStarts.REV` and the save version) matches, so a balance change builds afresh instead of loading a stale stage; bump `REV` if a bot's play changes without a change to `Data`. Without a bake (a checkout, CI tests) the Load screen says "Building the stage", builds on a thread so the window stays alive, and keeps the result in the `user://` cache. The scripted Starfall starts take a few seconds either way. Run the bake locally with `godot --headless --path . -s tests/tools/bake_starts.gd`.

The export ships the two bot scripts (the title screen reaches them through the starts) and leaves out the rest of `tests/`. Both presets in `export_presets.cfg` list the excluded files by pattern (and include `stage_starts/*`); `tests/dev_tests.gd` fails if a file under `tests/` is neither one of the bots nor excluded, so a new test file needs a pattern added.

### Adding a start

One row in `DevStarts._table()` (id, label, the function that builds it) and the function. A Starfall-style stage is a small function that takes an earlier start and runs `_wait`, `_build` and direct `starfall` edits on it, like `_starfall_camp`. Ironfall stages will be more rows. `tests/dev_tests.gd` then checks it automatically: unique id, a Hearth and buildings, a round trip through the run save, a minute of ticking, and the same run on every build.

## Debug keys

Off by default. The pause menu has a **Debug keys** switch; the choice is kept in `user://debug_keys.cfg` and starts off. With the switch off no key does anything.

| Key | Does |
| --- | --- |
| F1 | Adds a stack (100) of every good the era knows. Bronze Dawn's goods count once it is won. Not Bronze Tools, which speed workers up. |
| F2 | Researches every tech whose requirements are met now, topping up what each costs. A tech that opens only after another waits for the next press. |
| F3 | Cycles the game speed 1x, 3x, 10x, 30x. |
| F4 | Lifts the fog over the whole map. |

Each shows a short toast naming what happened (`scripts/debug_keys.gd`).

## Title screen

The title is a large Cinzel Decorative name over the painting, a dark band down the left that fades smoothly to clear (no edge), and four buttons: Continue (the newest save), New game, Load game, Quit. Nothing sits under the buttons. The pause menu and the Load and save screens use the same faces (`scripts/menu_fonts.gd`).

## Tests

`tests/dev_tests.gd`: the slots (round trip, summaries, newest, migration of `run.json`), a stage start loading as a new run and Save leaving the starts unchanged, the Load screen, the debug keys (off by default, each key), the export filters, and for every start a build, a round trip, a Hearth and buildings, and a minute of ticking. The bot-made starts are built only outside `-- fast` (or alone with `-- starts`). `tests/tools/menu_pass.gd` drives the title's Load screen, Save into a slot, Load from it and a stage start as a player would.
