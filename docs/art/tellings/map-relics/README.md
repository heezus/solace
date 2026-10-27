# New-telling ruins and relics

Ten original transparent PNGs in `art/rendered/`, with Godot-generated imports. Claude wires the regions after review. No `.gd`, test, UI or overlay changes.

| Family | Exact stems | Intended display |
|---|---|---|
| Kith rubble | `ruins`, `ruins_2` | 1×1, 46 px fit inside 48 px cell |
| Cleared footprint | `ruins_cleared` | 1×1, flat swept stone/ash |
| Sleeping growth | `bloom_dormant` | 1×1, closed dull buds, no emitted glow |
| Excavation | `relic_dig` | 1×1, dig cuts and cyan glint |
| Ancient hull fragments | `first_wreck`, `first_wreck_2` | 1×1, upright and fallen-rib variants |
| Relic icons | `relic_everburning_forge`, `relic_old_lantern`, `relic_founders_cart` | 20 px |

## Sources and regions

Built-in imagegen supplied each original; pixels and alpha are copied unchanged. Adjacent JSON files retain full prompts, reference roles and generated source basenames, including corrections that flatten the cleared ground and make the second hull silhouette distinct. `spec.json` records actual sizes, SHA-256 hashes and `[x,y,width,height]` source-pixel regions. Regions use alpha >8 bounds with 2 px padding; fit preserving aspect ratio. Do not stretch to a square or include large transparent canvas margins. Use the painted colour, with no placeholder tint.

These are separate textures, not packed atlases: `ruins.png` and `first_wreck.png` are the primary variants; `_2` is the second variant in each family. Future selection must use stable tile identity, independent of gameplay RNG, as the repository art contract requires. Footprints remain 1×1; clearing/buildability, excavation, relic effects and region wiring belong to Claude.

## Native review

[Native comparison](native-comparison.png) shows new map subjects at 46 px inside 48 px cells and at 96 px inspection size, beside 35 px existing Kith and the Bloomery. Existing Bloom Tide and recent Wreck are normalized to the same fit for material comparison, not a proposed change to their runtime footprints. Relics are shown at 20/32/64 px over dark green and ivory. `preview.py` regenerates the documentation board/spec from the repository root with Pillow. This is a source composite, not a claim that the assets are wired.

Rubble reads separately from the flat cleared ash. Dormant growth keeps the existing Bloom family with closed buds, quieter leaves and no glow. Deep moss/vines and absent embers distinguish the first hull from the recent crash; the variants have different profiles. Icons retain flame, cyan core, and wheel/handle silhouettes at 20 px. References use existing fictional project art only; no personal photos or real-person likeness inputs.

Godot 4.7.2 import passes. Local lint/format, strict warnings, full logic tests and scripted input play-through pass on the shared unchanged code baseline. Visual review and exact-head CI remain required before Claude merges; draft for review. The owner's 2026-10-27 batch direction is recorded with #165; UI, overlays and other Skyreach era art remain held.
