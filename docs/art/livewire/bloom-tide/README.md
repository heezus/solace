# Bloom tide ground

Three original transparent PNGs and Godot-generated imports in `art/rendered/`: `bloom_tide`, `bloom_tide_field`, `bloom_tide_wood`. [Full-cell regions and source hashes](spec.json), [native 48/96 px comparison](native-review.png), individual prompts and reproducible `preview.py` accompany the group. Built-in imagegen originals are unmodified.

Retain the Bloom's magenta/sickly-green family from the historic patch palette, approved `bloom_sign_1` painting and current #115 terrain family, with thinner younger growth and transparent creeping edges. Grass has loose root strands; former Field adds broken furrow/straw remnants; former wood adds dry leaves and a small twig. Visible alpha >8 covers only 28–34% of each canvas, leaving the existing ground visible. Earlier wood attempts retained blurred halos and were rejected; the final variant edits the accepted transparent grass source.

## Design review and Claude hooks

Checked against [Art Direction](../../../design-system/05-art-direction.md), [terrain layering](../../../design-system/22-terrain-kit.md), and the [requested slot](../../requests.md): overhead ground perspective, upper-left light, crisp tiny botanical shapes, no square ground plate, mature bulb or new palette/lore. All remain 1×1 cells. The board composites these at native 48 px over a source sample of current Livewire healthy ground and shows isolated alpha. A labeled current #115 Bloom material source sample compares the dense mature family; it is not an engine capture or a claim about shader sampling scale. Current main already has #115's painted Bloom ground and sample decals. These separate young tide sources do not replace those existing resources in this art-only group.

Use full source rectangles in `spec.json`, mapped to 48×48 cells; do not tight-crop/fill the gaps or add a violet rectangle beneath them. The former-ground variants are separate source art for Claude to select under the existing/future presentation contract. This PR adds no mappings, overlay rules, tile IDs, RNG or save changes. Ground art only: no changes to the coming overlay view, `tide_look.gd`, UI or tests; no over-road, burnt-ground or overgrown-building assets.

Godot 4.7.2 import, original RGBA/alpha and whitespace checks pass. Full CI is tracked on draft PR #138; Claude reviews and wires after green CI.
