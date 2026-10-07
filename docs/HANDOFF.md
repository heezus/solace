# Handoff: Claude and OpenAI (Codex) on Solace

Owner: Jon (heezus). Two AI teams, one repo, coordinated by responsibility. On 2026-10-04 Jon authorized Codex to make the engine changes needed for visuals as well as creating the art. Visual work no longer requires a Claude wiring handoff.

## Active work

### Codex — Briana and Jon title v4
- **Task:** Jon requested v4: slightly smaller foreground characters and dusk lighting matching the original background, retaining title-menu space, Hearth fire, falling star and Bloom hint. Branch `codex/lumen-briana`, PR #75.
- **Reserved files:** none after publication; delivered `art/rendered/title_briana.png`, relit `title-pair-foreground.png` with imports, `docs/art/title-pair/` v4/source/layers/menu previews and v3 archive; current art requests and design decisions. No Claude-reserved code edits.
- **Acceptance criteria:** pair about 13% smaller (canvas height 68% versus 78%), cool ambient fill with restrained warm/cool rim light, actual original background unchanged, both faces inside frame, menu clear and narrative landmarks visible.
- **Status:** v4 complete. Original source byte check, foreground source byte check, Godot imports, native layered render and actual title-menu captures at 1280×800/1600×900 passed. Output remains 1586×992; right shoulder/arm crop is intentional foreground framing. Prior versions archived. Full CI tracked on #75; synchronization with main resolves shared docs conflicts.
- **Next action:** Claude reviews v4 and merges after CI green. Alternate title selection already exists in #74; also merge original-title #68 so both images are available. Briana map/portrait art remains separate; Jon is title art only, not a gameplay visitor. Saved #73 art and overhaul documentation cleanup remain queued.

### Claude — Starfall stage 4
- **Task:** Jon's "whatever else is next" (2026-10-07). Page 16 stage 4: Lumen Market, Shared Shrine, Guard Post. Stage 3 (#64) and the title screen, pause menu and zoom (#66) are merged. PR `stage4`.
- **Reserved files:** `scripts/starfall.gd`, `scripts/data/starfall.gd`, `scripts/data/buildings.gd`, `scripts/data/tuning.gd`, `scripts/bonuses.gd`, `scripts/buildings.gd`, `scripts/rendered_art.gd` (three placeholder slots), tests. Codex: please avoid these until it merges.
- **Hooks for Codex:** art slots for stages 1 to 4 are in `docs/art/starfall-art-brief.md` and `docs/art/requests.md`; Jon starts Codex on them himself.
- **Next action:** CI green, merge.

### Claude — gameplay asks (PR #44, merged) and the visual merge (PR #33, merged)
- **Task:** none open. PR #44 shipped the four gameplay asks (one-click Gatherer's Hut round, techs show once their items are found, roads through buildings, Hearth stage helper). PR #33 is merged with main's gameplay preserved.
- **Reserved files:** none. For the next gameplay task Claude records its files here before editing.
- **Hooks for Codex:** `HearthLook.stage(state)` counts five milestone techs (0 to 5) for staged Hearth props (`scripts/hearth_look.gd`). `Research.visible_set()` is the one list of techs the board may show. Roads run through building cells of the passage kinds (`Roads.PASSAGE_KINDS`), so a through-passage may now be drawn: the rule is road, building, road.
- **Test note:** tests that look at tech cards must mark `Data.ITEM_ORDER` as seen (`s.economy.seen[id] = true`), or the cards are hidden by discovery.
- **Next action:** Codex ticks the three done asks in `docs/art/requests.md` and may draw a through-passage and staged Hearth art; Claude waits for the next task from Jon.

Claude maintains its own entry here. Jon reports Claude is preparing one bundled gameplay PR for one-click hut interaction, resource-discovery tech visibility, roads through buildings and Hearth upgrade appearance, and will flag necessary drawing-code overlap in `docs/art/requests.md`.

## Automatic coordination protocol — agreed with Jon, 2026-10-05

1. Shared state lives under **Active work**, with one entry per agent: task, reserved files, acceptance criteria and next action. Update your entry on task start, completion or blockage; preserve the other agent’s entry.
2. Messages go in PR comments. To reach Claude, comment on one of Claude’s open PRs; Jon confirms this wakes Claude automatically. Claude reads Codex PR comments at task boundaries and before shared-file edits. Check messages at those boundaries, without constant polling.
3. Before editing a shared file, check the current handoff. If another agent has reserved it, ask in a PR comment before changing it. Reservation changes and necessary overlap must be explicit.
4. Post a short PR comment on completion or blockage: result, commit/files, validation, blocker and next owner/action.
5. Claude is preparing this protocol in a small AGENTS.md PR. Once merged, that text is the source of truth. PR #33 remains draft until Jon’s visual sign-off.
6. **Mailbox.** One draft PR, "Claude and Codex mailbox" (#53, branch `mailbox`), is the standing channel and is never merged. Anything not tied to a single PR goes there as a comment: asks, handoffs, blockers, "your PR is ready". Start each comment with who it is from and a tag (ASK, DONE, BLOCKED, FYI) and keep it short. Messages about one PR still go on that PR. Both agents subscribe for GitHub notifications, but subscription alone is not a verified wake-up for the local Codex chat. Claude's Game build thread is woken by comments on PRs it is subscribed to. Codex's local chat checks the mailbox on a scheduled heartbeat, every two hours (up to 12 checks a day), and stays quiet unless something needs attention, so expect Codex replies on that cadence, not instantly. Jon only steps in for decisions that are his. This text lands through a docs PR; the mailbox PR itself stays open and unmerged.

## Token discipline and task coordination — Jon, 2026-10-05

- Work on one active deliverable at a time. Record its owner, scope, files, acceptance criteria and next action here; finish or report a concrete blocker before expanding scope.
- Codex’s active deliverable is the **48 px shoreline/crossing fixture**: both bridge axes, dry-bank seating, aligned road approaches and contour-following bank props. Done means one inspected native capture, focused geometry/privacy/RNG checks and a documented result. No additional concept directions, UI redesign, biome expansion or animation work in this task.
- Claude owns discovery gating, hut interaction and road-through-building gameplay. Claude is implementing Jon’s four gameplay asks in one bundled PR and will record its reserved files; Codex will avoid those files. No duplicate investigation or implementation across teams.
- Reuse the existing approved subject assets, target reference and prior validation. Read relevant sections/diffs rather than repeatedly loading whole documents. Batch independent reads, cap outputs and use focused checks first; run required full checks once for the final candidate and repeat only after a relevant change or failure.
- Keep updates short and substantive: result, blocker or next decision. Avoid unchanged CI polling narration and repeated plans. Use one compact completion handoff: commit/PR, files touched, validation, limitations and next owner.
- New image generation must address a specific missing asset in the active deliverable. No open-ended variant generation or delegation unless Jon requests it. When blocked, report what can resume the task; do not burn tokens on unrelated work.
- No numeric token budget was specified. These are workflow constraints, not an invented token cap. Both teams should flag expected substantial extra work before widening the task.

**Coordination status:** Jon has relayed Claude’s agreement and current bundled gameplay scope. Claude’s open PR #44 (`oneclick`) is now the wake-up channel; its `main.gd` input-handler change does not overlap the completed drawing fixture. The agreed protocol above replaces the earlier pending-acknowledgement note.

## Claude return briefing — 2026-10-05

Start from [draft PR #33](https://github.com/heezus/solace/pull/33), branch `codex/visual-overhaul`, in Codex’s separate clone. Do not merge yet: Jon still wants the playable ground, water, roads and shore contact to match the richer approved concept. The miniature buildings, resources and Kith are the visual anchor; preserve them.

### What is implemented versus under review
- **Implemented in the PR:** rendered miniature map subjects/items, stable visual variants independent of simulation RNG, four-pose walking, modular wood/stone bridges, continuous terrain rendering, matching HUD/build/selection/research theme, research readability and material-symbol hover identification. These are presentation changes; the PR does not implement the gameplay requests below.
- **Last fully CI-validated head:** `0bfd64149bbb125e379b4cc72e015b15a7896e3d`. [Exact-head CI run 37319336078](https://github.com/heezus/solace/actions/runs/37319336078) passed import, metadata, strict warnings, logic tests, input play-through and long layout checks. Codex’s later study commits do not alter production art/code; the branch now also incorporates Claude’s newer main changes. The synchronized head needs fresh integration validation.
- **Visual target:** [blended regions paintover](art/overhaul/misty-highlands/grounding-studies/blended-regions.png) is AI concept art, **not** a screenshot of a better previous game build. Jon explicitly wants the native game to approach it. The flatter quiet-terrain experiment was withdrawn and archived, not integrated.
- **Latest published native review:** [sculpted terrain study](art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/README.md), with actual main-scene captures at 48 px and the existing 64 px zoom. Normal play does not load this study. Ground repetition, orthogonal paths and shoreline composition remain unresolved; successful CI does not constitute visual approval.
- **Latest shoreline review:** [native shoreline/crossing study](art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/README.md). Actual 48 px capture and focused checks complete: contour-following separate stone/reed props, fixed lighting, bridge entrance clearance, dry-bank seating, aligned road approaches and continuous deck seams. Review-only; normal play is unchanged. Overall terrain quality remains on hold.

### Claude’s next work
The full requirements and acceptance criteria are in [art requests](art/requests.md). Pick up gameplay changes on a separate Claude branch; coordinate shared UI files with Codex before changing them.

1. **Hand-discovery research visibility:** reveal the relevant technology branch after the player gathers its resource by hand. Define mappings, discovery thresholds, crafted-resource/gate exceptions and persistence; cover all research surfaces to avoid hidden-branch leaks.
2. **One-click Gatherer’s Hut dispatch/delivery:** reproduce Jon’s three-click sequence before roads/runners and make the available trip/delivery action work from one clear click without duplicate orders or lost bundles. Preserve inspection and later automation.
3. **Roads through buildings:** implement actual network and route continuity through occupied connector cells, including both axes, carts/bridge restrictions, demolition and saves. Codex must not draw a through passage until it is functional.
4. **Optional Hearth visual milestones:** agree a mapping from existing non-building research/ranks to modest visual improvements. Codex can supply staged art afterward; no new capacity/cost/progression mechanic is authorized by this idea.

Codex continues terrain/shoreline/bridge visual studies and owns their eventual renderer integration. Preserve the 48 px default, existing gameplay footprints and independent visual RNG; discuss any global scale change with Jon and Claude. This briefing is published through PR #33; newer documentation-only commits require their own CI status check before merge.

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
