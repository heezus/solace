# In-game HUD: spec

Status: **default approved for building** (2026-09-30). The project owner was away, so Claude picked this and he can still revise it.
Mockup: https://claude.ai/artifact/9WgaSRvMp18nqHV24w96CY (the board "In-game HUD", 1280 × 800).
It builds on what the code thread shipped: a goal panel, a full top bar, build buttons that say what they need, and hut range. Only the changes are listed here.

## Top bar (56px, `ui-bar`, 3px `outline` bottom border)
- **Left:** a Kith icon, then "Kith 7 / 9" (15px), with "Jobs 6 / 7 · 2 hauling" under it (10px).
- **Food:** "Food 26 · lasts 3 min" over a 110px bar in `highlight`. "Lasts" is stored food divided by net burn.
- **Goods** come in two groups, each with a small-caps label at 9px and 60% opacity:
  - **RAW:** Wood, Stone, Flint, Fiber, Clay, Berries, Grain.
  - **MADE:** Rope, Charcoal, Brick, Flour, Flint Tools.
- Each good is a fixed-width chip (74px for raw, 62px for made), so nothing jumps as numbers change.
  - A 22px icon, then the count at 15px.
  - Under the count, the name at 9.5px and 80% opacity, followed by the rate in green (`9fe39f`, e.g. "+1.2").
  - Goods at 0 stay visible at 40% opacity.
- 2px dark dividers separate the blocks.

## Map overlays
- **Selected gatherer:** every tile in its square is tinted `highlight` at 20%, with a solid 3px `highlight` frame.
- **Placing a gatherer:** the same square, tinted white at 16%, with a dashed white frame. A white tooltip counts what's in range ("9 trees in range").
- **Paths:** a 12px dirt line (`path` `c8a36a`) over a 16px `outline` line, joining the centers of adjacent path tiles and buildings.
  - **Dragging a path:** the ghost is white at 55% over the outline at 35%, with a dashed cursor tile at the end.
  - The tooltip reads "Path: 7 more tiles · free · release to lay".
- **Status labels:** blocked buildings get a pill under the tile with a small pointer up to it, in `alert` with `outline` text: "Full: needs a path or a click", "Idle: no free Kith". The badge on the tile stays (a number in `highlight`, or "!" in `alert`).
- **Floating gains** ("+5 Wood") use the `info` style with a 5px `outline` stroke.

## Selection panel
- It's anchored to the building with a pointer, not docked. It's 232px wide on `ui-panel`.
- Icon, name, and a status line in green ("Working · 1 Kith").
- One sentence about what it does ("Cuts Stone from 8 rocks in its square.").
- Holding: "6 / 10 Stone" and a bar.
- **Trip line:** "To Camp · 11 tiles · 22 s a trip", on a darker inset. This is where distance becomes visible.
- Buttons: "Collect 6" (primary, `highlight`) and "Move" (outline).

## Goal panel (right, 272px)
- The title reads "Goal: Bronze Dawn" with "8 of 20" beside it, over a thin progress bar in `kith`.
- Done steps are struck through at 55% opacity, with a green check.
- The current step is a `highlight` card with `outline` text: title, "4 / 11", a bar, and one sentence of how-to.
- Upcoming steps get an empty circle. "Hide goal (G)" sits at the bottom.

## Build bar (92px, `ui-bar`)
- The buttons are 142 × 62: a 30px icon, the name (12.5px bold), the cost or reason (10.5px), and the hotkey number at the top right.
- **Path** is the first button: "Free · drag". It's selected here, shown with a `highlight` fill and `outline` text.
- Locked buttons use `1f3a47`, with the text in `9fb4bf`, a lock icon, and the tech's name ("Pottery").
- On the right, **Tech tree** is a `kith` button with "6 ready · T" under it.
