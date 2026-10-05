# Art Direction

## Current overhaul direction (2026-10-04, PR #33)

Jon selected grounded, atmospheric rendered miniatures: beautiful and mysterious, with cool moss/grass/water, warm thatch and timber, sculpted stone and readable warm Kith. Codex is implementing this direction in the visual-overhaul branch; the older vector direction below records the shipped baseline.

Use transparent rendered subjects, coherent three-quarter miniature lighting and chunky silhouettes that remain readable on a dense orthogonal map. Ground should flow continuously beneath occupied cells rather than giving every object a square base. Appearance variants stay stable across redraws; animation and decorative motion must not alter simulation. Keep the 48 px default and existing footprints until a scale change is discussed.

See the [real Godot integration and captures](../art/overhaul/misty-highlands/engine/README.md) and [asset provenance](../../art/rendered/README.md). Full directional animation, separate Hearth fire and water-wheel motion remain follow-up work. Terrain uses small-scale meadow and woodland ground with soft transitions derived from revealed tree groups, damp banks and flowing water with modular crossings. Worn aprons and tight contact shadows seat subjects in the ground. These are visual regions, not new biome gameplay rules. The interface now follows the [miniature interface specification](mockups/miniature-interface.md): charcoal green surfaces, ivory text, restrained brass actions, moss success and ember warnings. This supersedes the cocoa-and-cream UI palette while preserving the established controls and map scale.

## Original visual style
**Decided (2026-09-29): clean vector, in the spirit of Advance Wars.** The look is a bright, toy-like tactical cartoon:
- Flat, saturated colors with minimal shading
- Bold dark outlines so every building and unit reads instantly
- Chunky, slightly oversized, toy-like proportions
- A clean tile grid; the map reads like a game board
- Each faction owns a strong signature color

Built as SVG so Claude can generate and edit all of it. The art is swappable, so we can upgrade to 3D-rendered sprites later.

## Camera / perspective
**Decided (2026-09-29):** top-down 2D.

## Palette
Faction colors (direction, not final): **Kith** warm (orange, red, iron), **Lumen** starlight (pale gold, cyan), **Bloom** alien life (magenta, sickly green).
Should shift with the tone: warm, bright early eras, cooling and darkening after the ship lands (direction only, 2026-09-29).

| Token | Hex | Used for |
|---|---|---|

## Shape language

## UI style

## Audio & music mood

## Reference board
Games, films, art that capture the look. Link or describe each and say what we take from it.

| Reference | What we take |
|---|---|
| Advance Wars (GBA; Re-Boot Camp) | Bright toy-like style, bold outlines, faction colors, readable grid |
| Factorio | Top-down readability of dense machinery |
