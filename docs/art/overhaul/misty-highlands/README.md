# Misty Highlands: rendered tile kit

2026-10-04, Codex. **Proposal and documentation-only raster studies.** Jon prefers the miniature diorama rendering, misty highlands / twilight atmosphere, and sturdy stylized Kith. The earlier three SVG directions did not capture that intent. Production remains unchanged.

## Actual game constraints

Reviewed Jon's 39-second gameplay recording: approximately 100 Kith, dense resource clusters, many adjacent buildings, orthogonal roads and bridges, continuous hauling, gathering ranges, and blocked placement feedback. The first scenic clearings failed to represent this density. This kit is assembled on a 24×16 orthogonal tile map, with a 48 px default and a 64 px comparison. Camera crops rather than scaling the whole map down. Every resource and building occupies explicit tile cells; the Hearth remains 2×2.

![Village at 48 px tiles](village-48px.png)
![River district at 48 px tiles](river-48px.png)
![Resource district at 64 px tiles](resources-64px.png)

## Kit

![Generated transparent atlas](sprite-atlas.png)

The atlas contains tree, stone, berries, blue-flowered fiber, grain, clay, copper ore, cottage, Gatherer's Hut, Hearth, Kith, and bridge. Grass, road earth and water are separate ground textures. Road earth is clipped to neighbor-connected orthogonal paths in the browser study. These are generated with the built-in image-generation tool; exact prompts are in [prompts.json](prompts.json). Original outputs are retained unmodified. Sprite rectangles are browser presentation metadata, not exported production sprites.

Direction: dimensional thatch and timber, sculpted mossy stone, cool green ground, readable warm clothing and fire. Keep the square placement model; avoid decorative square object plates. Quiet ground supports dense objects. Scale is still an evaluation, not an approved engine change.

## Limits and next production work

- This is an art test, not an engine screenshot or a Godot playtest. The map is representative, not reconstructed from a save.
- The accompanying browser prototype has 64 illustrative road-following haulers, selection, fake resource-state toggles, placement previews, grid/fog toggles, and camera navigation. It does not implement gameplay. Kith uses one translated pose; there is no validated walk cycle or directional animation.
- Kiln, water wheel, harvested states and riverbank transitions remain simplified placeholders; road edges still use a simple geometric mask. The generated atlas has imperfect cell spacing and a three-quarter camera despite the more overhead prompt. Camera consistency, alpha edges, repeated variants, resource depletion semantics and spritesheet layout need a controlled production pass.
- Grass and water were requested seamless; exact edge continuity has not been proven. The browser tests repetition only. Production needs matched edge and corner tiles and a repeat/seam check.
- Production is currently SVG-only. Raster imports, an atlas loader or rendered spritesheets require a reviewed pipeline change by Claude; these PNGs are isolated under the parent `.gdignore`. Do not copy them into `art/sprites/`.
- Treat animations as separate aligned directional sheets: shared anchors and sizes, restrained walk/work motion, separate fire/smoke, and reduced-motion support. Lighting and fog should remain separate layers rather than baked into every sprite.

The interactive study lives in the conversation. These source images and scale screenshots make the proposal reviewable without exporting the conversation surface into the game repository.

## Validation

Browser preview checks passed: assets loaded, pause holds, resource state toggles, occupied placement is blocked in the illustrative preview, camera navigation, 48/64 px sizing, grid/fog controls, no script errors, and no horizontal overflow at 338 px content width. No engine behavior or imports changed. CI status is reported on the PR.
