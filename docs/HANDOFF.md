# Handoff: Claude and OpenAI (Codex) on Solace

Owner: Jon (heezus). Two AI teams, one repo, coordinated by responsibility. On 2026-10-04 Jon authorized Codex to make the engine changes needed for visuals as well as creating the art. Visual work no longer requires a Claude wiring handoff.

## Ownership
| Area | Owner | Notes |
|---|---|---|
| `art/` (SVG, raster, atlases, visual resources) | **Codex** | Art assets and the approved visual pipeline |
| `docs/art/requests.md` | both | Request queue, see below |
| `docs/design-system/` (lore, art direction, mockups, decision log) | **both**, in this repo | Single source of truth since 2026-10-03; the old project-folder copy is retired. Pages 06/09/10/11/14/15 are Claude-owned |
| Visual portions of `scripts/`, `scenes/`, `project.godot`, associated tests/resources | **Codex**, coordinated with Claude | Loading/imports, variant selection, terrain blending, shaders, lighting, animation, drawing order, camera presentation and visual UI integration |
| Gameplay portions of `scripts/`, `tests/`, `scenes/`, `project.godot` | **Claude** | Simulation, economy, progression, gameplay rules and save semantics; no visual refactor may change these implicitly |
| `.github/`, `export_presets.cfg`, releases | **Claude** | CI and release infrastructure |
| `main` branch, merging | **Claude** | Merges once CI is green |

## Interface (the "contract")
- The entries below describe the current SVG baseline. Codex may evolve the loader and asset formats together for the approved visual overhaul; preserve existing asset IDs/callers and gameplay footprints during migration.
- Code loads `res://art/sprites/<name>.svg` (`scripts/art.gd`, `Art.sprite(name)`). Name = interface; keep it stable.
- Items use `item_<id>.svg`. Buildings use their id (`hearth.svg`, `kiln.svg`). Tiles use `tile_*.svg`. A few aliases live in `SPRITE_OF` in `scripts/art.gd` (`camp` -> `hearth`, `road` -> `tile_path`).
- Sprites are authored on a 32x32 viewBox and drawn at 48 px per tile, so a 2 unit outline shows as 3 px. Larger buildings span several tiles (see `docs/design-system/mockups/units-and-buildings.md`).
- If a sprite is missing, code falls back to drawing shapes, so nothing breaks, but the game looks worse.
- Raster textures, atlases, new visual slots, animation resources and shaders are allowed when needed for the chosen aesthetic. Codex runs Godot import and commits required metadata under repository conventions, then verifies import and gameplay checks.
- Select visual variants from a stable tile-coordinate/family seed or unit ID, independently of gameplay RNG. Appearance must survive camera movement and redraws without affecting simulation. Terrain blending and animation must preserve placement cells, pathing, resource rules and readable selection/range overlays.
- A global tile-scale change still needs discussion with Jon and Claude. The engine authorization is for visual implementation, not changes to gameplay mechanics or save semantics.

## Workflow
1. Codex works in **its own clone**, never in Claude's checkout. Suggested: `~/Documents/Codex_Workspace/solace` on the Mac (clone of `github.com/heezus/solace`).
2. Branch `codex/<topic>` and implement focused visual changes in art, documentation and relevant engine/tests/resources. Open a PR to `main`; include the engine areas touched and visual/gameplay validation.
3. CI must pass (it imports the project, runs tests, and plays a scripted run that fails on any error).
4. Claude reviews and merges, then Jon pulls ("update" in the Claude thread).
5. Codex wires its own visual changes, including new sprite slots and imports. Record work and any shared-file overlap in `docs/art/requests.md`; coordinate before editing code Claude is actively changing. Requests that need gameplay decisions, save/schema changes or CI/release work stay with Claude. Routine visual wiring does not require waiting for Claude or asking Jon again.

## Requests queue
`docs/art/requests.md` tracks **Codex visual implementation**, **Codex -> Claude** work outside the visual lane or requiring coordination, and **Claude -> Codex** art/visual requests. Mark done items with `[x]`. A new visual slot, import or animation is Codex work, not automatically a Claude dependency.

## Seeing the result
Install Godot 4.7 (standard, not .NET), import `project.godot`, press F5. Windows builds come from CI at the repo's `latest` release. Screenshots of the game from CI playtests are shared in the Claude project, not in this repo; ask Jon for them if needed.

## Style quick facts
- Current overhaul: grounded, atmospheric rendered miniatures with warm timber/thatch, sculpted stone and cool natural surroundings. Preserve readable silhouettes and the 48 px baseline. Original SVG/vector outline rules below the art-direction overhaul section are historical compatibility guidance.
- Current interface: charcoal green, ivory labels, restrained brass actions, moss success and ember shortfalls. Use `scripts/ui.gd` tokens and the [miniature interface specification](design-system/mockups/miniature-interface.md), including miniature research illustrations. Cocoa-and-cream is the historical baseline. Faction identities remain Kith warm orange/red/iron, Lumen pale gold/cyan, Bloom magenta/sickly green.
- Full detail: `docs/design-system/05-art-direction.md`, `docs/design-system/mockups/look-and-scale.md`.

## Jon's follow-up requests — 2026-10-05
Research material symbols and resource-name hover labels are part of Codex's current UI pass. Gameplay requests are queued in [art requests](art/requests.md): reveal technologies after hand discovery of their resource and simplify the Gatherer's Hut dispatch/delivery interaction to one click before roads/runners. Optional Hearth improvements should visually reflect existing non-building research after a milestone mapping is agreed. Claude owns progression and order behavior; Codex supplies presentation. Clarifications listed in the queue are implementation decisions for Claude, not approvals already granted for a particular new rule.
