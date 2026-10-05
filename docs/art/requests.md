# Art requests

## Codex visual implementation (art and engine wiring)
- [x] Rendered miniature pipeline (Codex, 2026-10-04; PR #33): integrated transparent atlases, all map resource families, core buildings/workshops/industry, 18 item icons and fixed-anchor walking Kith in Godot. See [engine integration and real captures](overhaul/misty-highlands/engine/README.md). Existing IDs, footprints and 48 px default remain; Godot generated import metadata. No simulation/save changes.
- [x] Coordinated variants and connected terrain (Codex, 2026-10-04; PR #33): stable map-seeded coordinate/family and Kith-name choices, independent of simulation RNG. One cached continuous meadow, connected roads and riverbanks, single-span bridge sampling, preserved fog/selection/placement behavior.
- [ ] Rendered animation and terrain polish (Codex): add full directional walk/work cycles and separately animated Hearth fire/water-wheel layers; refine bridge bank caps and long-range terrain repetition. Current four-pose walking, charcoal smoke and foliage sway are integrated. Unique workshop/industry variants remain future art work; no new gameplay rules are implied.

## Codex -> Claude (gameplay, save/schema or CI/release work; shared-file coordination)
No open requests. Visual engine wiring is owned by Codex under the updated [handoff](../HANDOFF.md).

## Claude -> Codex (art wanted)
- [x] Jon's note (2026-09-30): the visuals look "okayish". First pass: improve the sprites most visible on screen: `hearth`, `gatherers_hut`, `kith`, `hauler`, then the tile art. Keep names and footprints.
- [x] Flax Field (2026-10-03, from Jon's request to plant fiber): a tile sprite `flax_field.svg`, 32x32, for flax that has been sown. It must read as farmed, not wild: the wild flax stalks in neat rows over a strip of turned soil or seed furrows, pale blue-green flowers, same outlines. It is also the build card icon. Until it exists the game draws `flax.svg` tinted pale blue-green. Under Jon's 2026-10-04 authorization, Codex may add the asset, wire the visual slot and run Godot import for its metadata.

- [x] Top-bar chips (Jon's playtest, 2026-10-03): the era-2 goods read as a different style next to the stone-age items at 24 px. Redraw `item_copper_ore`, `item_tin`, `item_copper`, `item_bronze` and `item_bronze_tools` to match `item_wood`, `item_stone`, `item_flint`: the 2.4 outline in `#1b1b1f` on every shape (the handle of the bronze tools has none, and tin and ore use 1 to 1.5), one light highlight, a chunky silhouette that fills the 32 viewBox. `item_copper` and `item_bronze` are the same ingot in two colours: give Bronze its own shape (a stack of two ingots, or a cast bar with a ring) so the two read apart at 24 px. Keep the names and the viewBox. The code already draws every chip the same way, so no code change is needed.

2026-10-04 resolution: the requests above for core sprites, planted flax and matching item chips are fulfilled by the integrated rendered atlas interface in PR #33. Original SVGs remain as fallbacks rather than being individually redrawn again. Planted flax has separate furrow drawing; all item chips share one rendered sheet.
