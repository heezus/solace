# Livewire building miniatures

Eleven original transparent PNGs for eight buildings and the Firebreak straight, corner and end. All subjects retain 1×1 logical footprints. Claude wires regions and mappings after review; no `.gd` files or tests are changed.

Exact-stem transparent PNGs live in `art/rendered/`, with generated Godot imports. [Measured regions and source hashes](spec.json), [native comparison](native-review.png), and individual `*-prompt.json` provenance records accompany the group. Originals are unmodified built-in imagegen outputs. The comparison is a documentation composite, not a runtime capture or a claim that these are wired.

Order: power_pole, generator, wire_mill, order_board, arc_lamp, scorcher, factory_floor, shard_dynamo, firebreak (straight, corner, end).

## Regions and Claude hooks

`spec.json` uses `[x,y,width,height]` source-pixel rectangles. Building regions use alpha >8 bounds with 2 px padding; this avoids faint stray alpha shrinking the subject. Use aspect-preserving 46 px fitting inside the existing 48 px cell. Keep the painted color, remove placeholder tints, and preserve existing IDs and selection footprints. Pole has no wires; map wires, light discs and reach rings remain separate engine layers. Arc and flame are static art, not animated states.

Firebreak files are `firebreak.png` (left/right straight), `firebreak_corner.png` (left/down), and `firebreak_end.png` (left connection, rounded end). These are ground modules: stretch the specified **square region** to a full 48×48 cell, not to the tight visible-alpha bounds. The corner's centered 856×856 sampling region normalizes its strip width and connection anchors to the other pieces. Rotate for other connection directions. The native board includes a five-cell connected fixture. Tiny irregular bank-width differences are intentional organic edges; T/cross pieces are outside this brief. No road-tier or mapping code is included.

## Design-rule review

Checked against [Art Direction](../../../design-system/05-art-direction.md) and the [Misty Highlands kit](../../overhaul/misty-highlands/README.md): coherent three-quarter building camera, upper-left highlights, cool shadows, warm Kith wood/iron, cyan shard light, strong small silhouettes and transparent surroundings. Structural masonry follows machinery feet and hall walls; no decorative ground tile plates. Ground strips use an overhead camera to join the orthogonal road grid. Existing Coal Mine and Bloomery are shown beside the group at 46 px and 96 px. No new lore, palette system, scale or footprint is introduced.

Godot 4.7.2 import passes without errors or warnings. Full CI status is tracked on the PR; Claude reviews, wires, and merges after green CI. Regenerate the board with Pillow by running `preview.py docs/art/livewire/buildings` followed by the eleven stems listed in `spec.json`, from the repository root.
