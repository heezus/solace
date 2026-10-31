# Step 7 Mac launch: report

All four items are NOT ASSESSED. No ending or Chronicle screen was reached.

| # | Item | Verdict | Judged by |
|---|------|---------|-----------|
| 1 | Skyward checkpoint (cutscene, "The first telling ends here", ending card and locks) | NOT ASSESSED | nothing |
| 2 | Each ending from the checkpoint (Exodus, Cataclysm, Time loop) | NOT ASSESSED | nothing |
| 3 | Chronicle from title and pause menu | NOT ASSESSED | nothing |
| 4 | Kin reveal at glyph set 7 | NOT ASSESSED | nothing |

## What happened
- The first Godot launch was refused by Claude Code's safety check until Jon allowed Godot on this clone.
- Try 1: windowed, `--position 20000,20000 --resolution 1280x800`, driver `launch_data/shot_driver.gd`, steps = wait, shot, dump, quit. Godot printed its banner and the Metal line, then ran more than 2 minutes without executing a single step (driver.log stayed empty, no PNG). The task was stopped.
- Try 2 (the limit): same driver with `--headless` and a 60 s alarm. Same result: banner only, driver.log empty, killed by the alarm. A headless run would also give a blank viewport, so it could not have produced screenshots anyway.
- Likely cause (not confirmed): the title scene or the driver stalls before the first `_process` step. The off-screen window may also be occluded and paused by macOS. The log in the throwaway HOME has only the banner, so no error was captured.
- No further attempts were made, per the two-try limit.

## Setup left in place
- solace-latest on step7-mac-launch; project imported (`.godot/` present).
- Throwaway HOME: /private/tmp/claude-502/solacehome.zzb8 holds `run.json` (copy of skyward_end_1.json).
- No Godot process is left running.

## Jon's real Solace user dir
Unchanged: 365 files before and after, identical listing of mtimes and sizes. ~/Applications/Solace.app, ~/actions-runner-solace and the old solace folder were not touched.

## Suggested next step
Run `launch_data/shot_driver.gd` once in a visible, supervised window with a one-line step file, to see where it stalls. Or have a repo test tool (tests/tools/menu_pass.gd, kin_pass.gd) drive the checks instead, since those are known to run headless.
