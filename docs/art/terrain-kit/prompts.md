# Terrain kit generation record

Codex used the built-in `image_gen.imagegen` tool, one call per asset, on 2026-10-19. These are production materials, not a concept screenshot. No external source image was used. Original generated files remain in the Codex generated-image archive; `sources.json` records each source filename, SHA-256, original dimensions and packed dimensions. The generator returned smaller originals than requested; 1920px deliverables are resampled, not claimed to be native 1920px paintings.

## Meadow A prompt

> Use case: stylized-concept. Production game terrain texture, meadow-a.png for Solace. Create ONE 1920x1920 seamless tileable meadow material viewed straight down, no perspective, fills entire square. Rendered hand-painted miniature finish with crisp tiny sculpted grass blades and clover, moss olive and sage greens, restrained warm straw flecks, upper-left highlights and lower-right tiny contact shadows. 96 pixels represents one 48px game tile, whole sheet covers 20x20 tiles; detail must survive 2x downsampling. Even density and brightness across whole sheet, small palette of five greens with shared earth midtones, no large landmarks, flowers or rocks, no vignette or lighting gradient, no blur. Opposite edges must join naturally without mirroring. No text, borders, grid, objects or scenery. Save asset to local file and return file path.

## Other seamless sheets

Each separate call used the following template, substituting the name and subject from the table verbatim:

> Use case: stylized-concept. Production Solace game seamless terrain asset {name}.png. ONE 1920x1920 square seamless texture viewed straight down, fills entire image. Subject: {subject}. Hand-painted rendered miniature material, crisp fine sculpted details, five-color restrained natural palette, tiny dark contact outlines and upper-left highlights, lower-right shadows. 96 source pixels per game tile, sheet covers 20x20 tiles. Uniform brightness and density, no vignette, no large patches or landmarks, no blur, no scenery, no text or grid. Opposite edges join without mirroring. Return local saved file path.

| Name | Subject |
|---|---|
| meadow-b | drier paler meadow, sage olive short grass with restrained straw blades, tiny clover |
| meadow-c | lush darker meadow, moss and jade clover with crisp short grass blades |
| woodland-a | woodland floor, dark moss, tiny ochre leaf litter and fine roots, shares meadow mid greens |
| woodland-b | woodland floor, richer leaf litter, small roots and moss cushions, shares meadow mid greens |
| water-calm | calm river water, cool desaturated teal with delicate crisp small horizontal ripple arcs, no shore |
| water-flow | flowing river water, cool desaturated teal with small crisp elongated ripples flowing vertically, no shore |
| earth | trodden warm muted brown earth, tiny gravel, embedded stones and grass remnants, shared olive meadow midtones |
| earth-south | dry dark earth with subtle coal dust, tiny gravel and muted olive remnants, no large landmarks |

## Transparent decals prompt

> Use case: stylized-concept. Solace production transparent decal atlas decals.png, exactly 768x384, 8 columns by 4 rows equally spaced 96x96 cells, NO drawn grid or labels. 32 separate tiny top-down rendered miniature ground objects, each centered safely within its own cell with 12px empty gutter, transparent background throughout. Row 1: eight different small sage olive grass tufts and clover. Row 2 first four: four tiny wildflower clusters, remaining four: four grey brown pebble clusters. Row 3 first two: two small stones; remaining six: six leaf litter and tiny mushroom clusters. Row 4: eight reed clusters, wet bank stones and driftwood. Crisp sculpted painted finish matching miniature trees, upper-left light with small baked lower-right contact shadow. Sparse small objects, no ground squares, no text, no borders. Return saved local file path.

`transparent_background=true`; original alpha preserved during cell packing.

## Bank prompt

> Use case: stylized-concept. Solace production painted river bank strip bank.png. Wide horizontal seamless-left-to-right strip, 1920x192 desired. Strict top-down material, no horizon or perspective. Top half olive sage meadow/earth, bottom half cool muted teal shallow river water. Waterline exactly horizontal across middle, with crisp hand-painted dark soil lip, upper-left lit small irregular wet stones, lighter turquoise shallow band immediately below lip, fine roots and grass immediately above. Small details evenly distributed, no large landmarks, no flowers, no scenic composition, no text or borders, no blur. Rendered miniature finish with tiny dark contact outlines and sculpted highlights. Strip will be mapped along curved river contours by shader. Return local file path.

## Asset preparation

`prepare_assets.py` resamples sheets to the contract, uses periodic-plus-smooth decomposition to remove low-frequency wrap discontinuities while retaining painted high-frequency detail, and matches the outside texels. The bank is cropped around its waterline before horizontal wrap preparation. The decal atlas is packed cell by cell with alpha, preventing neighboring subjects from mixing. These are deterministic import preparations; no details are procedurally painted over the originals.
