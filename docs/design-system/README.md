# Game Design System

The source of truth for our game's universe. If something is written here, it's canon. If it isn't, it's not decided yet.

**Status (2026-09-30):**
- The stone age is playable and on GitHub (heezus/solace, main).
- A polish pass is in progress. Research board B and tech tree v4 are approved.
- Bronze Dawn stage 1 is built (branch `bronze-1`): the map grows, ore, mines, smelting, bronze. Stage 2 is not built.

## How we use this
- **Keeping it in sync:** every new page (including mockups/ and research/) gets a link in this README and an entry in the Decision Log the same day.
- Every decision goes in the [Decision Log](decision-log.md) with a date and a reason.
- Anything undecided goes in [Open Questions](open-questions.md) until it's answered.
- When a new idea contradicts canon, we either reject it or log a decision that changes canon. No silent retcons.
- New names, places, and terms go in the [Glossary](07-glossary.md) the moment they're invented.

## Sections
1. [Pitch](01-pitch.md): what the game is, in one breath
2. [Pillars](02-pillars.md): the 3 to 5 rules every feature must serve
3. [World & Lore](03-world-lore.md): setting, history, factions, rules of the world
4. [Characters](04-characters.md): who lives here and what they want
5. [Art Direction](05-art-direction.md): look, palette, audio mood, references
   - [Shared character standard](mockups/character-standard.md): reference hierarchy, runtime sizes, detail rules and consistency review.
6. [Mechanics](06-mechanics.md): core loop, systems, controls, progression
7. [Glossary](07-glossary.md): every canonical name and term
8. [First Playable](08-first-playable.md): scope of the first prototype
9. [Tech Tree](09-tech-tree.md): the stone-age tree as built in the game (28 techs, moving to v4)
10. [Era 2: Bronze Dawn](10-bronze-dawn.md): metal, distance and the falling light (stage 1 built: growth, ore, mines, smelting, first Bronze; stage 2 designed)
11. [Genre Conventions](11-conventions.md): what players expect from the genre, and what Solace is adding (in progress)
12. [Knowledge Is Progress](12-knowledge-is-progress.md): what the Kith know is the real progress, with one new way of learning per era (agreed direction)
13. [Three Perspectives](13-three-perspectives.md): playing as each faction (idea, not canon yet)
14. [From Hands to Haulers](14-hands-to-haulers.md): one arc from clicking to automation, with scaling click yield, ranks and tiered costs (being built)
15. [Architecture](15-architecture.md): blocks, interfaces and a testbench, with a step-by-step refactor plan (all steps merged; the code is split into economy, research, map, walking, buildings, Kith, story and fog blocks)
16. [Era 3: Starfall](16-starfall.md): the Lumen ship lands; glyph deciphering, set-and-forget expeditions, a hidden trust meter plus three big moments (stages 1 to 3 built: the landing, Glyph Wall, Expedition Post, the Wreck, four gifts, three moments, the Warning and the first Bloom sign; trade and the third tab not built) Art for it: [Starfall art brief](../art/starfall-art-brief.md).
17. [Needs and upgrades](17-needs-and-upgrades.md): dwelling tiers and needs, road and bridge tiers, copy cost, tech forks, hand carts, scouting (approved by the project owner with the defaults; built in 3 PRs: Logistics, Needs, Tree)
18. [Roadmap](18-roadmap.md): the eras after Starfall, the Bloom and the three resets, with every open fork and its default (proposal, nothing built)
19. [Ironfall](19-ironfall.md): era 4 in detail, the Teardown mechanic, iron and steam, a 16-tech tree, the Lessons list, the Bloom patches and how it is built in three stages (stage 1 built)
20. [Cutscenes](20-cutscenes.md): short skippable painted sequences that tie the eras into one story, the story spine, the sequence list, art rules and how they play (Phases A and B built)
21. [Stage starts, save slots and debug keys](21-stage-starts.md): begin a new run at any stage on a fixed map with the town built, five save slots, and the F1 to F4 debug keys (built; nine starts, the last is Ironfall)
22. [Terrain kit](22-terrain-kit.md): how the ground and water get painted to match the sprites and read as one surface (layers, template sheets, preview script; art by Codex)
23. [Livewire](23-livewire.md): era 5 in detail, the Standing orders mechanic (the Order Board), power poles and factories, the Bloom tide as the clock, a 14-tech tree and three build stages (stage 1, wires and orders, built; the tide and the factories are design)
- [Decision Log](decision-log.md)

### Mockups (visual specs from the visual design thread)
- [Mockups index](mockups/README.md)
- [HUD](mockups/hud.md): trip times, pinned warnings, path-drag preview
- [HUD, playtest 2](mockups/hud-playtest2.md): rates, the flow panel, the Hearth ring, fog, demolish, river hints
- [Tech tree v3](mockups/tech-tree-v3.md): Option A (transit map) and Option B (research board, the one picked)
- [Tech tree v4](mockups/tech-tree-v4.md): corrected links and layout on board B (approved)
- [Units and buildings](mockups/units-and-buildings.md): sprite recipes, with the 32px SVGs in mockups/sprites/
- [Miniature interface](mockups/miniature-interface.md): current UI palette, hierarchy and actual Godot captures
- [Look and scale](mockups/look-and-scale.md): 48 px tiles, the 2x2 Hearth, a scrolling map view, fog without ghost icons, the historical cocoa-and-cream palette (superseded by Miniature interface)

### Research
- [Mechanics and tech trees](research/mechanics-and-tech-trees.md): genre research behind multipliers, the research queue, and Knowledge Is Progress

- [Open Questions](open-questions.md)
- [Inspiration](inspiration.md): what we took from the Steam library, and why
- [Visual design system](https://claude.ai/artifact/W4HdJcEXvz3awoVKjvYmnd): colors, type, terrain, buildings and UI panels, taken from the game code. Use it with Claude Design.
- [Pitches](pitches.md): early concepts, set aside for now

## Naming style
the project owner prefers short, real words with weight or a double meaning (Solace, Kith, Lumen). Invented fantasy names (Kharn, Ostrakai) and "The [Adjective]" labels were rejected.

> **Source of truth moved (2026-10-03):** this design system now lives in the repo at `docs/design-system/`, edited by Claude and Codex through PRs. The Claude project folder copy is retired. Sprite SVGs are in `art/sprites/` (the old `mockups/sprites/` copy was not carried over).
