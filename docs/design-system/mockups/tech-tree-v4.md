# Tech tree v4: logical links and a cleaner layout

Status: approved by Jon on 2026-09-30. Ready for the code thread.
Mockups: the "Tech tree v4" boards on the UI canvas (https://claude.ai/artifact/9WgaSRvMp18nqHV24w96CY).
Built on the 28-tech tree in 09-tech-tree.md. Same techs, costs and effects. Only the links, columns and lane order change.

## Style
Board B (research board) from tech-tree-v3.md "Option B". Each card uses the same 32×32 sprite as the building or item it unlocks (mockups/sprites/), so the tree matches the map and the HUD icons. Stone Axe uses a new axe icon and Baking a bread icon.

## Why the links changed
Each link should read as "you need X to invent Y". These links did not:

| Tech | Was | Now | Reason |
|---|---|---|---|
| Gatherer's Hut | as built | Knapping + Foraging | Flint tools to build it, foraging to fill it |
| Stone Axe | Knapping | Knapping + Cordage (column 1 → tier II hub) | An axe is a flint head hafted with cord |
| Thatched Roofs | Fire | Cordage + Foraging | Reeds are gathered and tied; fire has nothing to do with it |
| Nets, Smoking | later column | column 1 (tier II) | They need only a root tech |
| Farming | as built | Gatherer's Hut + Stone Axe | You clear land with an axe |
| Scouting | as built | Gatherer's Hut + Storytelling | Scouts report back as stories |
| Water Wheel | as built | Stone Axe + Masonry, moved to Stone lane | Timber wheel on a stone race |
| Rafts | as built | Nets + Stone Axe | Cut logs, lashed like a net |
| Grindstone | Pottery | Water Wheel + Farming | It grinds grain, driven by the wheel |
| Carrying Poles | as built | Paths & Haulers + Stone Axe | A cut pole for haulers |
| Baking | Fire | Grindstone + Pottery | Flour plus a clay oven |
| Era gate | tier IV | tier V | Baking now sits one tier later |

Everything else is unchanged.

## Layout
- Lane order, top to bottom: Fiber, Stone, Land, Hearth, Lore. Each lane has two slots.
  This order has the fewest lane-crossing lines. The crossing cost drops from 39 to 29.
- Columns: Tier I (roots) through Tier V, then the gate.
- Each tech's outgoing lines share one trunk in the gutter after it, so a hub like Stone Axe draws one vertical line instead of five.
- "Or" parents (Megaliths, Calendar) still merge with an "or" pill.

Metrics, built vs v4: links 47 → 48, links that skip a column 15 → 11, total column span 65 → 61.

## Hover
Hovering a tech lights its whole chain (ancestors and descendants) in gold #ffd166 and dims the rest. The v4 hover board shows Baking.

## Update 2026-10-03: compact cards, fitted view
Links, lanes and columns above are unchanged. The research board now draws each card as one compact line (icon, name, status mark, a price bar) so a whole era fits the window; the price and the full text are in the hover strip and in the "What to learn next" cards. Details in decision-log.md, 2026-10-03: tech board fit and next-steps clarity.
