# Handoff: Claude and OpenAI (Codex) on Solace

Owner: Jon (heezus). Two AI teams, one repo, split by file ownership so they never collide.

## Ownership
| Area | Owner | Notes |
|---|---|---|
| `art/` (SVG sprites) | **Codex** | Visual and sprite improvements |
| `docs/art/requests.md` | both | Request queue, see below |
| `docs/design-system/` (lore, art direction, mockups, decision log) | **both**, in this repo | Single source of truth since 2026-10-03; the old project-folder copy is retired. Pages 06/09/10/11/14/15 are Claude-owned |
| `scripts/`, `tests/`, `scenes/`, `project.godot`, `.github/`, `export_presets.cfg` | **Claude** | All game code, CI, releases |
| `main` branch, merging | **Claude** | Merges once CI is green |

## Interface (the "contract")
- Code loads `res://art/sprites/<name>.svg` (`scripts/art.gd`, `Art.sprite(name)`). Name = interface; keep it stable.
- Items use `item_<id>.svg`. Buildings use their id (`hearth.svg`, `kiln.svg`). Tiles use `tile_*.svg`. A few aliases live in `SPRITE_OF` in `scripts/art.gd` (`camp` -> `hearth`, `road` -> `tile_path`).
- Sprites are authored on a 32x32 viewBox and drawn at 48 px per tile, so a 2 unit outline shows as 3 px. Larger buildings span several tiles (see `docs/design-system/mockups/units-and-buildings.md`).
- If a sprite is missing, code falls back to drawing shapes, so nothing breaks, but the game looks worse.

## Workflow
1. Codex works in **its own clone**, never in Claude's checkout. Suggested: `~/Documents/Codex_Workspace/solace` on the Mac (clone of `github.com/heezus/solace`).
2. Branch `codex/<topic>`, edit `art/` only, open a PR to `main`.
3. CI must pass (it imports the project, runs tests, and plays a scripted run that fails on any error).
4. Claude reviews and merges, then Jon pulls ("update" in the Claude thread).
5. Need code or a new sprite slot? Add a line to `docs/art/requests.md` (below). Claude picks it up, adds the slot and the `.import` file, and reports back.

## Requests queue
`docs/art/requests.md` has two sections: **Codex -> Claude** (needs code or new files) and **Claude -> Codex** (art wanted, with the sprite name and what it depicts). Mark done items with `[x]`.

## Seeing the result
Install Godot 4.7 (standard, not .NET), import `project.godot`, press F5. Windows builds come from CI at the repo's `latest` release. Screenshots of the game from CI playtests are shared in the Claude project, not in this repo; ask Jon for them if needed.

## Style quick facts
- Outline `#1b1b1f`, 2 units on the 32-unit grid. Flat colors, little shading.
- Warm "cocoa and cream" UI; Kith are warm (orange, red, iron). Lumen are pale gold and cyan. Bloom are magenta and sickly green.
- Full detail: `docs/design-system/05-art-direction.md`, `docs/design-system/mockups/look-and-scale.md`.
