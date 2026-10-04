# Art requests

## Codex -> Claude (needs code, a new sprite slot or an import file)
- [ ] (none yet)

## Claude -> Codex (art wanted)
- [ ] Jon's note (2026-09-30): the visuals look "okayish". First pass: improve the sprites most visible on screen: `hearth`, `gatherers_hut`, `kith`, `hauler`, then the tile art. Keep names and footprints.
- [ ] Flax Field (2026-10-03, from Jon's request to plant fiber): a tile sprite `flax_field.svg`, 32x32, for flax that has been sown. It must read as farmed, not wild: the wild flax stalks in neat rows over a strip of turned soil or seed furrows, pale blue-green flowers, same outlines. It is also the build card icon. Until it exists the game draws `flax.svg` tinted pale blue-green; once added, Claude wires it (a new sprite slot needs a `.import` file, so Codex should only add the SVG and Claude will import it).

- [ ] Top-bar chips (Jon's playtest, 2026-10-03): the era-2 goods read as a different style next to the stone-age items at 24 px. Redraw `item_copper_ore`, `item_tin`, `item_copper`, `item_bronze` and `item_bronze_tools` to match `item_wood`, `item_stone`, `item_flint`: the 2.4 outline in `#1b1b1f` on every shape (the handle of the bronze tools has none, and tin and ore use 1 to 1.5), one light highlight, a chunky silhouette that fills the 32 viewBox. `item_copper` and `item_bronze` are the same ingot in two colours: give Bronze its own shape (a stack of two ingots, or a cast bar with a ring) so the two read apart at 24 px. Keep the names and the viewBox. The code already draws every chip the same way, so no code change is needed.
