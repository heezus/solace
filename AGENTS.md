# AGENTS.md — start here (Codex / ChatGPT / any non-Claude agent)

Solace is a top-down 2D automation game in Godot 4.7 (GDScript). Two AI teams share this repo.
Full coordination rules: [docs/HANDOFF.md](docs/HANDOFF.md). Machine setup: [docs/CODEX_SETUP.md](docs/CODEX_SETUP.md). Read them before your first change.

## Your lane: visuals
You own the **art assets** and the **engine work needed to make the visuals function**. Jon expanded this lane on 2026-10-04: Codex may implement visual changes end to end rather than waiting for Claude to wire them. This includes sprite/atlas loading, raster imports, visual variant selection, terrain blending, shaders, lighting, visual animation, drawing order, camera presentation and visual UI integration.
You may edit the relevant parts of `scripts/`, `scenes/`, `project.godot`, and associated tests/resources when needed for that visual work. Shared files remain coordinated with Claude; keep the changes focused and describe the touched engine areas in the PR. You may also read and edit the **design system** in `docs/design-system/`; `docs/design-system/README.md` indexes it.
Follow Jon's latest approved visual direction. The shipped baseline is clean vector / Advance Wars; the rendered miniature overhaul is being developed in `docs/art/overhaul/`. The existing SVG format is a baseline, not a restriction against implementing the new visual pipeline.

## Not your lane (Claude owns it)
Claude owns gameplay mechanics, simulation, economy, progression, save semantics, CI/release infrastructure and exports. Do not change those to achieve an art effect. Visual work in shared engine files is allowed; route actual gameplay changes or unrelated refactors through `docs/art/requests.md`. `.github/` and `export_presets.cfg` remain Claude-owned.

## Rules
1. Work on a branch named `codex/<short-topic>`; open a PR into `main`. Never push to `main`.
2. Change art, art documentation, allowed design-system pages, and the engine/tests/resources needed for visuals. Keep PRs focused and reviewable. Coordination documents may be updated when Jon changes these rules.
3. Preserve existing asset IDs, callers and gameplay footprints; a 2×2 Hearth stays 2×2. Existing SVG replacements keep their filename and viewBox. A visual pipeline migration may add raster/atlas assets and adapt loading/rendering together, with compatibility for existing callers. Discuss a global tile-scale change with Jon and Claude before changing it.
4. New sprite slots and import wiring are now within Codex's visual lane. Run Godot import and commit required `.import` / `.uid` files according to repository conventions; do not hand-author metadata or delete unrelated metadata. Verify CI creates no missing metadata.
5. Use the asset format appropriate to the approved direction: plain SVG, raster textures/atlases, animation resources and shaders are allowed. Keep SVGs free of embedded scripts and external fonts. Variant selection must be stable for a tile/unit and independent of gameplay RNG; visual changes must not affect simulation results.
6. Wait for CI (lint, import, tests, a scripted play-through that must show no errors) to go green. Claude merges.

## Design system rules (both teams)
- Every new design-system page is linked in `docs/design-system/README.md` the same day.
- Every design choice gets an entry in `docs/design-system/decision-log.md`, newest at the bottom, in this form:
  `## YYYY-MM-DD: short title (PR #n)` then 2 to 6 bullets: what was decided and why. Say "Codex" or "Claude" in the first bullet so the author is clear.
- Pages `06`, `09`, `10`, `11`, `14`, `15` describe game mechanics and code architecture: Claude owns them. Propose changes to those in `docs/art/requests.md` instead of editing.
- Changing canon (lore, factions, eras) needs Jon's OK: note it as a question in `docs/design-system/open-questions.md`.
