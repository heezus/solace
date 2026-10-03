# AGENTS.md — start here (Codex / ChatGPT / any non-Claude agent)

Solace is a top-down 2D automation game in Godot 4.7 (GDScript). Two AI teams share this repo.
Full coordination rules: [docs/HANDOFF.md](docs/HANDOFF.md). Machine setup: [docs/CODEX_SETUP.md](docs/CODEX_SETUP.md). Read them before your first change.

## Your lane: visuals
You own the **art assets**: everything under `art/` (SVG sprites in `art/sprites/`), plus the art specs in `docs/art/`.
Style: clean vector, Advance Wars feel: flat saturated colors, bold dark outlines (`#1b1b1f`), chunky toy-like shapes. See `docs/art/art-direction.md` and `docs/art/look-and-scale.md`.

## Not your lane (Claude owns it)
`scripts/`, `tests/`, `scenes/`, `project.godot`, `.github/`, `export_presets.cfg`. If a visual change needs code (a new sprite slot, a different size, an animation), write it up in `docs/art/requests.md` and Claude will wire it. Do not edit those files.

## Rules
1. Work on a branch named `codex/<short-topic>`; open a PR into `main`. Never push to `main`.
2. Change only files in `art/` and `docs/art/`. Keep the PR small (a handful of sprites).
3. **Replace, don't rename.** Game code loads `art/sprites/<name>.svg` by exact name. Keep the filename, the 32x32 viewBox and the sprite's footprint (a 2x2 building like the Hearth stays 2x2).
4. Do not add new sprite files or delete `.import` / `.uid` files. New sprites need Godot to generate a `.import` file, and CI fails without it. Ask for new slots in `docs/art/requests.md`.
5. Plain SVG only (shapes, paths, gradients optional but keep it flat). No raster images, no external fonts, no scripts.
6. Wait for CI (lint, import, tests, a scripted play-through that must show no errors) to go green. Claude merges.
