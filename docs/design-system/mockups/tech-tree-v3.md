# Tech tree panel: spec (v3 transit map)

Status: **default approved for building** (2026-09-30). The project owner was away, so Claude picked this and he can still revise it.
Mockup: https://claude.ai/artifact/9WgaSRvMp18nqHV24w96CY (the boards "Tech tree v3" and "Tech tree v3, hovering Granary").
Node data: 09-tech-tree.md. Tokens: the Solace visual design system.

## Layout
- The panel fills the screen over the map, on `ui-panel` (#1d3557). It pans and scrolls, and opens centered on the frontier (the ready techs).
- **Columns are tiers.** There are 6 of them, spaced 252px apart, starting at x=150. The gate is the last column.
- **Rows are lanes:** Hearth, Stone, Fiber, Land and Lore, top to bottom.
  - Each lane has slots 56px apart (Hearth 2, Stone 2, Fiber 3, Land 2, Lore 1).
  - A 40px channel separates lanes. Lanes alternate between a faint band (white at 3.5%) and none.
  - The lane name sits at the left with a 12px dot in the lane color (Hearth `ff7b39`, Stone `c0c6cc`, Fiber `e9c46a`, Land `90be6d`, Lore `b8b8ff`).
- Tier headers are in small caps at 11px, 75% opacity: "TIER I · ROOTS", "TIER II" to "TIER V", and "THE GATE".
- **Bronze Dawn** is one tall card spanning every lane. Its background is `3a2f1f`, with a 3px inner ring in `e3a857`. It lists "NEEDS ALL FIVE" and the cost.

## Cards (180 × 46)
- A 7px strip on the left in the tech's own color, with a 2px `outline` divider after it.
- Line 1 is the name (13px bold). Line 2 is the unlock, at 10.5px and 80% opacity. Side branches append " · side branch" to line 2.
- States:
  - **Done:** background `24475e` and a green check (`9fe39f`) at the top right.
  - **Ready:** background `ui-card` (`32607f`), a 3px `highlight` border, and a "Ready" pill in `highlight` with `outline` text.
  - **Locked:** background `1f3b53`, text `b9c6d0`, and a lock icon at 70% opacity.
  - **Hidden** (Star Lore, until the Strange Stone is clicked): transparent, with a 2px dashed `8fb3c9` border, the text "? ? ?", and "Click the Strange Stone".
- Side branches have a 2px border. Everything else has 3px.

## Tech colors (hue family per lane)
| Tech | Lane | Tier | Slot | Color |
|---|---|---|---|---|
| Fire | hearth | 1 | 0 | `ff7b39` |
| Knapping | stone | 1 | 0 | `d9d9d9` |
| Cordage | fiber | 1 | 0 | `e9c46a` |
| Foraging | land | 1 | 0 | `90be6d` |
| Storytelling | lore | 1 | 0 | `b8b8ff` |
| Charcoal | hearth | 2 | 0 | `f4a259` |
| Stonecutting | stone | 2 | 0 | `b8c0c8` |
| Weaving | fiber | 2 | 1 | `f6d776` |
| Shelter | land | 2 | 0 | `a7d676` |
| Ochre | lore | 2 | 0 | `d4a5ff` |
| Pottery | hearth | 3 | 0 | `ffb4a2` |
| Smoking | hearth | 3 | 1 | `f28c6a` |
| Ground Stone | stone | 3 | 1 | `9aa5b1` |
| Paths & Haulers | fiber | 3 | 0 | `f2b134` |
| Nets | fiber | 3 | 2 | `ffe08a` |
| Cultivation | land | 3 | 0 | `6fbf5b` |
| Star Lore | lore | 3 | 0 | `bdf4ff` |
| Rafts | fiber | 4 | 2 | `fff0a8` |
| Water Wheel | stone | 4 | 0 | `9cc3d5` |
| Roads | stone | 4 | 1 | `c9c2b8` |
| Sledges | fiber | 4 | 1 | `f0c75e` |
| Storehouse | fiber | 4 | 0 | `d9a441` |
| Seed Keeping | land | 4 | 1 | `b9e08a` |
| Megaliths | lore | 4 | 0 | `9d8df1` |
| Grindstone | stone | 5 | 0 | `adb5bd` |
| Irrigation | land | 5 | 0 | `7fd6a0` |
| Granary | land | 5 | 1 | `c5e384` |
| Calendar | lore | 5 | 0 | `c9b6ff` |
| Pack Frames | fiber | 5 | 1 | `c9a13b` |
| Bronze Dawn | gate | 6 | 0 | `e3a857` |

## Arrows
- One arrow runs from each parent to each child, in the **parent's** color, and ends in a 12px arrowhead at the child's left edge.
- **Met** (parent researched): a 4px colored line over a 7px `outline` line.
- **Still needed:** a 2.5px dashed line (6 on, 5 off) with no outline, at 55% opacity. This keeps the resting tree calm.
- **Routing:** lines are orthogonal with 7px rounded corners, never diagonal.
  - Out-ports are spread down a card's right edge and in-ports down its left edge, sorted by the other end's y, up to 7px apart.
  - An arrow to the next tier takes one vertical run in the gutter between the two tiers.
  - An arrow that skips tiers leaves through the gutter, runs along the nearest lane channel, and drops in through the gutter before its target.
  - Vertical runs in a gutter get 7px lanes, and horizontal runs in a channel get 7px slots. Pick the first free one, so lines never overlap.
- **"Or" parents** (Megaliths, Calendar): both arrows share one in-port. A small "or" pill (22 × 16, `ui-panel` fill, `outline` border) sits 24px left of the card. The arrow counts as met when either parent is.
- A skip arrow into Bronze Dawn enters at its channel's height, not the middle of the card.

## Hover
- Hovering a card lights its full chain: every ancestor back to the roots and every descendant.
- Lit arrows use the met style (thicker, outlined), even when dashed.
- Everything else drops to 10% (arrows) and 32% (cards).
- The bottom strip becomes a detail panel:
  - The tech's name, lane, state, description and cost.
  - NEEDS and LEADS TO chips in each tech's color, with a check or lock inside.
  - **YOUR ROUTE:** the unresearched chain in tier order, as chips joined by "›", with a line naming which of them are ready now.

## Header and legend
- The title reads "Tech Tree · Stone Age" at 22px. The counter reads "7 of 30 researched · 6 ready · 1 hidden".
- The legend at the top right: met, still needed, "arrow color = the tech it comes from", "or = either parent", and a Close (T) button.
- With nothing hovered, the bottom strip is **Frontier**: every ready tech as a chip with a gold border, plus one hint line.

## Era tabs (Bronze Dawn)
Era 2 uses the same panel with its own 16-tech tree. Put tabs by the title, "Stone Age" and "Bronze Dawn", with the current era selected.

## Option B: research board (the serious take, 2026-09-30)
the project owner said the transit map "looks so silly lol but maybe that's ok". Board "Tech tree B" is a calmer alternative using the same layout and routing. **The project owner hasn't picked A or B yet. Build A unless he picks B.** The differences:
- **Cards are 212 × 62**, with a 44px sprite icon on the left in a 2px `outline` frame.
  - Each card shows the name, the unlock, and the cost (hidden once done).
  - Locked icons are desaturated (grayscale 70%, brightness 80%).
  - Ready shows as a gold border plus a small gold dot, with no "Ready" pill.
- **Neutral lines, no tech colors, no dashes:**
  - Met: `d3e2ef`, 2.5px.
  - Still needed: `5f7d9c`, 2px.
  - Corners are rounded at 14px, and arrowheads are small and unoutlined.
- **The hover chain is gold** (`ffd166`, 3.5px). Everything else drops to 25%.
- **Lanes:** each lane is a dark band (black at 14% or 7%) with a 4px left border in the lane color. Lane names are uppercase with letter spacing.
- The panel background is `172c4a`, and the title is "Research · Stone Age".
- Icon per tech: Fire=camp, Knapping=flint tools, Cordage=twine post, Foraging=hut, Storytelling=kith, Charcoal=pit, Stonecutting=quarry, Weaving=rope, Shelter=dwelling, Ochre=clay, Pottery=kiln, Smoking=smokehouse, Ground Stone=rock, Paths=path, Nets=weir, Cultivation=field, Star Lore=cairn, Rafts=raft, Water Wheel=wheel, Roads=road, Sledges/Pack Frames=pack hauler, Storehouse=storehouse, Seed Keeping=grain, Megaliths=standing stone, Grindstone=grindstone, Irrigation=field on river, Granary=granary, Calendar=cairn on night sky, Bronze Dawn=bronze ingot.
