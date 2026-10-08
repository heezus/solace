# Ironfall item icons

Five original painted icons in `art/rendered/ironfall-items.png`, with generated Godot import. Built-in ImageGen prompts and source basenames are recorded beside this page.

The atlas is a 3×2 grid: coal, iron_ore, iron, steel, iron_tools, then an empty cell. Use the measured regions in [spec.json](spec.json); do not include a neighboring cell. The transparent original is preserved. [native-review.png](native-review.png) shows 24/32/40 px HUD sizes and 96 px inspection on the current dark UI palette.

## Claude hook

Extend the item ID mapping with the five IDs after the existing eighteen. Route these five to the sibling `ironfall-items` atlas and its measured regions, keeping existing `items.png` and its crops unchanged. Rough iron is one dark oxidized bar; steel is two brighter silver-blue bars. Coal is angular mineral coal, distinct from wooden charcoal. Tool heads are grey rather than bronze.

Run the documentation-only board with Godot `--path . --script docs/art/ironfall/items/preview.gd`. No gameplay or loader edits are in this asset PR.
