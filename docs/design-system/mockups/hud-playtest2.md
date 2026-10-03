# HUD, playtest 2: flows, rates, fog, demolish, water, settlement

Status: **default approved for building** (2026-09-30). Jon was away, so Claude picked this and he can still revise it.
Mockup boards: "HUD: where resources go", "HUD: placing a Dwelling" and "HUD: demolish" at https://claude.ai/artifact/9WgaSRvMp18nqHV24w96CY.
This adds to hud.md. It answers Jon's second playtest: "I don't understand where the resources are going", "no way to demolish", "cross water", "fog of war", "+ or − rates in green or red", and "dwellings can just be put wherever".

## 1. Rates under every good (top bar)
- Each chip shows the count (14px) with the **net rate per second** under it, at 10px bold.
  - A gain is `positive` green (`9fe39f`) with a "+". A loss is `ff9aa9` with a real minus sign (−).
  - A rate of 0 is grey `9fb4bf`.
- The chip's name moves into its tooltip, and the icon carries it. A small "per sec" note sits at the bar's right end.
- **Food** turns red when its net rate is negative: "Food 26 · −0.2/s · 2 min left", with the bar in `alert`.

## 2. Where a good goes (hovering a good in the top bar)
- Hovering a chip rings it in `highlight` and drops a panel (260px, `ui-panel`) under it with a pointer. The panel shows:
  - The header: icon, name, count, and the net rate (colored).
  - **COMING IN:** one row per source, with its rate in green. For example: "2 Gatherer's Huts on grass +0.60".
  - **GOING OUT:** one row per consumer, with what it turns the good into. For example: "Twine Post: 3 Fiber into 1 Rope −0.75".
  - When the net is negative, a red line: "Runs out in 1 min 30 s. Then the Twine Post stops."
  - One line on how to fix it: "Fix: another hut on grass, or pause the Twine Post."
- This is the main answer to "fiber just disappears". Every loss names the building that took it and what it became.

## 3. Flow arrows (selecting a processor)
- Selecting a workshop draws two curved, dotted arrows between it and the Hearth:
  - Input goes out in the input's item color (Fiber `a7c957`), labeled "3 Fiber".
  - Output comes back in the output's color (Rope `bc8a5f`), labeled "1 Rope".
  - Both are a 4px line with 2-on, 7-off dots over a 7px `outline` line. Animate the dash offset so goods visibly move.
- The selection panel shows the recipe as a row: [icon] 3 Fiber → [icon] 1 Rope / 4 s. Its buttons are **Pause**, **Move** and **Demolish** (the last with an `alert` border).

## 4. Settlement (Hearth, dwellings, new Kith)
- The **Camp becomes the Hearth**, the settlement center. See `sprites/hearth.svg`: a longhouse with a big fire.
- **The settlement is 5.5 tiles around the Hearth.** It's drawn as a circle with a dashed `kith` edge (10 on, 7 off).
  - Normally it's faint (2.5px, 70% opacity, fill at 5%).
  - While placing a Dwelling it's strong (4px, fill at 14%), with a `kith` label: "Settlement · 5 tiles around the Hearth".
- **Dwellings can only go inside the settlement.** Outside it, the ghost turns `alert`, with the pill "Too far from the Hearth · dwellings go inside the ring".
  - Good empty spots inside show as dashed white squares.
- **New Kith appear at the Hearth**, with a "+1 Kith" float and the label "New Kith arrive at the Hearth while food lasts".
- Other buildings (huts, quarries) can go anywhere. Only housing is tied to the settlement.

## 5. Fog of war
- A tile is explored when it's within 9 tiles of any building.
  - Tiles 8.6 to 9.8 tiles away get a soft edge (`2c3834` at 55%).
  - Tiles farther out are covered (`2c3834` at 94%). Terrain shapes show faintly through.
- A hint pill on the fog reads "Unexplored · build nearby to see".
- Bronze Dawn's Watchtower reveals a wider radius, and the eastern map expansion starts fogged (10-bronze-dawn.md).

## 6. Crossing water
- Hovering a river tile before any crossing tech shows a white pill: "Can't cross yet · Roads build bridges, Rafts float haulers".
- Pieces: a wooden bridge (Roads), a raft (Rafts), and a stone bridge (Causeways, era 2). They're in `sprites/`.
- **Idea, not in the tree:** Stepping Stones (`sprites/tile_stepping_stones.svg`), a slow early crossing Kith can walk. Add them only if the river blocks too much before Roads.

## 7. Demolish
- The build bar has a **Demolish** tool after a divider. It's 118px, with a red X, the text "Half back", and the hotkey X. Selected, it fills with `alert`.
- Hovering a building in demolish mode:
  - A red frame and a 35% `alert` wash, with a white X outlined in `outline` (`sprites/demolish_hover.svg`).
  - A pill: "Demolish Gatherer's Hut · get back 5 Wood, 2 Stone · its Kith goes idle".
- After a click the building becomes **rubble** (`sprites/rubble.svg`) for a moment, and then the tile clears. Refund half the cost, rounded down.
- Demolish also appears as a button in every building's selection panel.

## Goal panel
- It collapses to one line while you play: the title, the current step in a `highlight` pill, and "Show all steps (G)". Jon wanted less clutter, and the full list is one key away.
