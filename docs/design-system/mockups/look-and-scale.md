# Look and scale: make the game read as chunky and warm

> The rendered miniature world and [miniature interface](miniature-interface.md) now supersede this page’s original vector and cocoa palette. Its map-scale and control-layout guidance remains applicable.

Status: approved by Jon on 2026-09-30 ("Apply it"). The design system artifact tokens and the new hearth.svg are done. It answers items 23 to 31 of playtests/2026-09-30-newcomer-1/ui-ux.md. Sprite art itself is fine: sprites/*.svg are already chunky with 2px outlines on a 32-unit grid. The game draws them too small, thin and on a cold, loud palette.
Baseline screen: 1280×800. Everything scales from that.

## 1. Tile and sprite scale
- **Tile = 48 px** at the default zoom (was about 26). A 32-unit sprite is drawn at 1.5×, so its 2-unit outline becomes 3 px. Draw the SVGs at their native scale; never redraw them thin.
- Zoom steps: 32, 48 (default), 64 px. Scroll or pinch to zoom. Below 32 px, hide outlines and use flat icons.
- Outline is always at least 2 px on screen. Terrain tiles (grass, fog) have no outline, only features and buildings do.
- **Hearth is 2×2 tiles (96 px)** with a real fire: a stone ring, a wood pile and a tall flame in `fire` and `kith` orange. It is the largest thing on the map, so it reads as home. sprites/hearth.svg is now this 2×2 sprite (64×64 units, so draw it at 96 px). It has a longhouse behind a stone ring, crossed logs and a tall flame.
- Buildings are 1 tile on the `plate`, except the Hearth, Storehouse and Granary, which are 2×2.
- **Kith are 0.7 tile (about 34 px)**, with a 3 px outline, a round head bigger than the body, and a soft oval shadow so they stand out on grass. Always drawn, walking or standing. A Kith carrying a load shows the item icon above the head.
- Trees fill about 0.9 tile, with a visible trunk. Rocks, flax and berry bushes are the same size class. Berry bushes get a different shape from trees (low and round, not a tree with dots), so they aren't confused.
- Body text is 14 px minimum, UI labels 16 px, numbers 18 px bold. Nothing smaller.

## 2. Map framing
Layout at 1280×800:

| Area | Size |
|---|---|
| Top bar | 1280×52 |
| Bottom build bar | 1280×72 |
| Right panel (Goals, Info) | 264 px wide |
| **Map viewport** | **1016×676** (about 21×14 tiles at 48 px). It was 950×590. |

- The map fills its viewport edge to edge with a 4 px cocoa frame. No inner margin.
- Start with the camera centered on the Hearth. The lit area (radius 6 from the Hearth, per 11-conventions.md) is about 13 tiles across, so about 60% of the map width, not a small patch.
- The lit area is drawn as flat tiles. The `grass` checker is two shades 4% apart, so it reads as a texture, not a grid of blocks.
- **Fog edge is soft**: a one-tile feathered gradient into the fog color, with no ragged darker rim.
- **Fog shows nothing.** No ghost icons of trees, hills or water, and no far-off markers. This also fixes the Strange Stone spoiler (item 28). Unexplored land is one flat `fog` color with a very light diagonal hatch.
- The Hearth's reach ring is a 2 px dashed cream line at 40% opacity, drawn only while placing a Dwelling or hovering the Hearth, and labelled "Build range". The hut range highlight is `highlight` gold at 18% fill with a dashed gold border. No beige grid.

## 3. Warmer UI palette
The Kith are warm, so the UI is warm. Cold navy goes away. These replace the tokens in the visual design system artifact once approved. Sprite colors are unchanged, except the map `grass` (see below).

| Token | Old | New | Use |
|---|---|---|---|
| uibar | #264653 | **#3b2a24** | top and bottom bars (dark cocoa) |
| uipanel | #1d3557 | **#4a372e** | Goals, Info, popovers |
| uicard | #32607f | **#6a4c3b** | cards, buttons at rest |
| card-done | #24475e | **#57703f** | researched card (moss) |
| card-locked | #1f3b53 | **#3f2f28** | locked card |
| uitext | #dfdfdf | **#f6ead7** | text (cream) |
| uitext-dim | new | **#c9b59b** | secondary text |
| ui-line | new | **#211510** | 2 px card outline, radius 8 |
| grass | #7cb342 | **#9bb85c** and **#93b055** (checker) | map ground, less neon |
| forest | #2e7d32 | **#3f7d3a** | trees |
| fog | #3b4a45 | **#5b5046** | unexplored land (warm dusk brown) |

Everything else in the visual design system stays: outline #1b1b1f, kith #e76f51, plate, lumen, bloom and the resource and metal colors.

## 4. Tighter accent set
Four accents, each with one job. Nothing else may be colored.

| Accent | Hex | Job |
|---|---|---|
| Kith orange | #e76f51 | The one primary action (Tech tree button), selected tab, the Hearth. |
| Gold | #ffd166 | The current goal, "ready to research", the hover chain, range highlights. |
| Moss | #7fb069 | Good state: enough of a cost, done goals, researched. |
| Alert red | #d64550 | Shortage and danger only: missing cost, starving, a Kith in trouble. |

Fixes that follow:
- **Tech tree button**: `kith` orange, filled, not purple. It is the only filled button on screen.
- **Demolish**: a 40×40 icon button (a hammer with a small X) at the far right of the bottom bar, in the `uicard` ghost style. It turns alert red only while active, and shows "Demolish (X). Refunds half." on hover. It is no longer the second loudest thing on screen. Renames "Half back".
- **Resource chips** in the top bar: the icon carries the color, the number is cream. No lime fiber chip. Rates go below in moss (+) or alert red (−), as in hud-playtest2.md.
- **Hunger and shortage**: a 16 px alert red icon badge on the building's corner, no text pill. Text appears on hover only, so the badge never covers the neighboring tile.
- **Gold text** is only for the one current goal. Goals after it are cream, done ones moss.
- **Hover hints**: one place only. The Info panel carries the detail. The cursor bubble is a 1-line name, no numbers.

## 5. Flax and small map fixes
- Flax uses flax.svg exactly (blue five-petal flowers on grass), so it matches the Goals text "little blue flowers" (item 20).
- Grain (orange stalks) uses field.svg-style gold heads, and the brown patch by the gravel is Clay in the `clay` color, both with a hover name. Berry bushes use the low round bush shape from section 1.

## Not decided here
Sound, the Goals wording and pacing (items 12 to 19, 32 to 42) are code and writing work, not look.

## Token changes made
The design system artifact (https://claude.ai/artifact/W4HdJcEXvz3awoVKjvYmnd) now carries the new values: ui-bar, ui-panel, ui-card, ui-text, alert, grass, forest, positive, card-done, card-locked, fog and ground changed; grass-alt, ui-text-dim, ui-line, flax-stem and flax-flower added; tile is 48px, radius-panel 8px, and body, badge, button and stockpile text sizes are 14 to 18px. Sprites are unchanged apart from hearth.svg.
