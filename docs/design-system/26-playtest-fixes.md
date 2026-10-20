# 26. Playtest fixes (Jon's notes, 2026-10-19)

What Jon found playing the 2026-10-19 build, and how each was settled. A UI/UX redesign is queued behind this page, so every fix here is small and practical.

## Era starts are handed over working
- A start used to arrive with the bots' pauses, a lattice of roads and most Kith idle. `scripts/start_tidy.gd` now resumes every paused building, re-pauses the most overstocked ones only until about a third of the Kith are free to haul (once Paths & Haulers is known), and takes up road tiles no building uses (`Roads.needed_tiles`).
- A building touching a linked hut, workshop, house, shed, tower or water wheel is linked itself (`Roads._chain_neighbours`): haulers already walk through those cells, so a tight block needs a road to one of them.

## The side panel
- It is only ever the player's choice (G, the chip, the Fold button) and starts open. Selecting a building changes what is in the panel, never whether it shows, so the map never jumps.

## Keys
- Space or P pauses, 1 to 3 set speed, B opens the drawer, one letter per build tab (H A W M L E C, printed on each tab), T tech, X demolish, G side panel, Home, + and - zoom, Esc cancels. The pause menu has a Keys button listing them (`scripts/hotkeys.gd`).

## Top bar
- A chip never changes size. A good running out turns its number amber or red, and the time left lives in its tooltip.
- The hover panel draws over the goal chip and shrinks to its text.
- The Homes cap row reads "Homesteads built: 10 / Allow 19" and its tooltip says what the cap does.

## The Wanderer
- Once The Falling Star is worked out the Wanderer is "fallen", not a percentage on its way.

## Glyph Wall
- The panel opens with how it works: copy interval, check interval, all three right reads the set, one Wall is enough. Every mark's clue was rewritten to point at its word and away from the others; a test keeps the first clue free of any word on the list.

Left for the redesign: Trade and Glyph panels in the top bar (all options at a glance), the build drawer's look, and the road-drag glitch (waiting on a description).
