# Character source audit

Shared spec: [character standard](../../design-system/mockups/character-standard.md).

![Current and proposed map sizes, with enlarged source audit](scale-review.png)

Godot renders the existing assets unchanged. Current Kith use the production function; Lumen/Sela show current 24 px and proposed 35/38 px fit targets. The lower row enlarges the same source textures to expose anatomy differences. This does not normalize Sela's proportions or approve her exact hero height.

Run Godot with `--path . --script docs/art/character-standard/preview.gd`. No production code, art originals, private photos or import metadata are changed.

One [Sela candidate](sela-candidate.png) tests shorter miniature anatomy against the existing sources, also at 38 px. It is not approved production art. Its built-in ImageGen prompt, source basename and measured alpha bounds are retained in the adjacent JSON files. Camera and costume detail still require review; no game sprite is replaced.
