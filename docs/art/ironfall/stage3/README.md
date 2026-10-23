# Ironfall stage 3 miniatures

Fourteen transparent original PNGs and Godot-generated imports live in `art/rendered/`; individual prompts record built-in imagegen provenance. All building footprints remain 1×1. Claude wires the measured regions and mappings after review. [Regions, source dimensions and hashes](spec.json), [native buildings](native-review.png), [joined Rail](native-rail-review.png), [native carts](native-cart-review.png).

Design references: [Art Direction](../../../design-system/05-art-direction.md), [Ironfall](../../../design-system/19-ironfall.md), [Misty Highlands](../../overhaul/misty-highlands/README.md), and the existing Coal Mine/Bloomery. Retain coherent three-quarter camera, upper-left highlights, cool shadows, warm Kith materials, restrained pale-gold/cyan shard accents, irregular contact and small-scale silhouettes. No decorative ground plates or new lore.

The native comparison is a documentation composite, not a runtime capture. No `.gd`, test, UI, overlay or gameplay changes belong to this group.

## Claude hooks

Use exact stems `boiler`, `shard_boiler`, `forge`, `steam_shed`, `shard_lamp`, `shard_lamp_lit`, `beast_pen`, `rail`, `rail_corner`, `rail_t`, `rail_cross`, `rail_end`, `steam_cart`, `beast_cart`. Regions are `[x,y,width,height]` in source pixels; building/cart bounds use alpha >8 with 2 px padding. Keep painted colors and remove placeholder tints; retain IDs, recipes, worker logic and selection footprints.

The lamp states share the same region and source canvas so switching light does not rescale the post. Its halo is static; ground lighting remains separate. Shard Boiler has the requested pale-gold port and no stack. The Pen's bluish animal is reused as the cart reference, not a new creature/lore system.

Rail regions are square **48×48 ground-cell samples**, not visible-alpha fit boxes: straight left/right; corner left/down; T left/right/down; cross all four; end left connection and timber buffer to right. Rotate for other directions. Measured crops normalize gauge and anchors; the joined fixture checks them at 48 px. Source texture detail and organic ballast vary slightly between pieces. These need connected-piece selection when Claude wires them; this is not a drop-in fourth material row for the current road shader.

Steam Cart edits the existing hand-cart source while preserving its Kith, camera and costume; beast cart uses the same wooden-cart family. Both leave an empty bed for a caller-supplied cargo illustration. Their native review includes the existing cart at 36 px (the current 35×1.04 caller, rounded), plus 96 px inspection. Steam puff is static in this source; do not layer the old chimney/beast placeholder marks over the new sprites. Cargo placement needs fitting to the new empty beds when wired.

Godot 4.7.2 import and alpha checks pass; CI status is tracked on the draft PR. Review and wiring remain Claude's action after green CI. `preview.py` regenerates the documented composites with Pillow, from the repository root, taking this directory and the fourteen stems as arguments.
