# Misty Highlands in Godot

Codex, 2026-10-04, PR #33. This pass implements the approved rendered miniature direction in the actual game. It retains the 48 px default, original placement cells, 2×2 Hearth, resource rules, simulation and saves.

## Implemented

- Transparent raster atlases replace map resources, core buildings, workshops, industry and all 18 item icons through the existing art interface. Legacy SVG fallbacks remain. New slots have Godot-generated import metadata.
- Trees, rocks, ore, plants, clay, dwellings, Gatherer's Huts and Hearths choose stable variants from map seed, coordinates and family. Three Kith appearances use stable names. Rendering never consumes simulation RNG.
- One cached world-space meadow surface replaces checkerboard ground. Connected riverbanks blend grass and water; roads join neighboring cells. A river crossing samples one bridge along its span instead of repeating end posts on every tile. Hidden rivers remain hidden until revealed.
- Four walking poses per Kith appearance animate at seven frames per second, with fixed cell anchors, side mirroring, existing work movement and actual carried-item icons. Cart operators draw the cart only when their gameplay state supplies it. Foliage moves subtly; working charcoal pits retain smoke.
- Placement ghosts, selection, gathering ranges, fog, camera zoom and UI callers keep their existing behavior. Terrain caching responds to road placement, discovery and world growth.

## Actual game captures

The screenshots below come directly from Godot's main scene, played by the existing pacing bot. They are gameplay renders rather than browser compositions. No decorative scenery or fabricated resource layout was added for these captures.

![Settlement at the existing 48 px scale](settlement-48px.png)
![Developed settlement at 48 px](settlement-developed-48px.png)
![Existing 64 px camera zoom for comparison](settlement-64px-comparison.png)

## Validation and limits

Visual regression tests cover deterministic variation, atlas bounds, cache reuse, road invalidation, discovery privacy, unchanged world data and independent simulation RNG. Full logic goldens, strict Godot warnings, lint, formatting, and graphical play/layout passes validate integration; final CI status lives on PR #33.

This is the first integrated pass. The four-pose walking loop is not a full directional animation rig. Fire is part of the generated Hearth art; full layered fire animation, directional work cycles and water-wheel rotation remain polish work. Unique workshops and industry currently have one appearance each. Grass sampling is continuous across logical tiles, but long-range texture repetition and the simple river/road masks can still be refined. Tile-based fog remains visible at the exploration frontier. No global tile-scale change was made.

Sources and exact generation prompts: [art/rendered](../../../../../art/rendered/README.md).
