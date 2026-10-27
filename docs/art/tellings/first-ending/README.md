# First telling: Skyward and the fireside

Four original 1586×992 built-in imagegen paintings, at the exact runtime stems in `art/rendered/cutscenes/`: `skyward_end_1`, `skyward_end_2`, `skyward_end_3`, `fireside_1`. No baked text. Godot 4.7.2 generated their imports. Claude owns subsequent wiring and merging; no `.gd`, tests, UI or overlay changes are included.

Each `*-prompt.json` records the full final prompt, reference roles and generated source basename. [spec.json](spec.json) records original dimensions and SHA-256 hashes. Generated pixels are copied unchanged; no enlargement, background removal or paint reconstruction was used. References are project paintings and the approved fictional [Sela/Kith standard](../../../design-system/mockups/character-standard.md), with no personal photos or real-person likeness inputs.

## Native review

[Full-size comparison](native-comparison.png) places all four 1280×800 production-player captures beside the existing Phase B Sela/Kith captures. Individual `*-player.png` files retain native size; [wide fireside](fireside_1-wide-player.png) checks the 1600×900 crop. Review text is drawn by the existing production player, never in the originals. Faces, mast lamp, horizon glow and Sela's hand survive cover-fit and near-final push-in; the caption gradient remains necessary over Sela's darker costume and mast footing.

Captures use a temporary adaptation of the existing `docs/art/ironfall/phase-b/preview.gd` harness, selecting `skyward_end` and `fireside` instead of the Phase B sequences. The player and test files are unchanged. The comparison is native player evidence, not a screenshot of a completed run.

## Art decisions and handoff

The cliffhanger keeps the town warm and inhabited, the Bloom low on the southern horizon, and Sela quietly promising another chance. The Hearthkeeper wears the Kith traveller family with a worn shawl and carved hearth-stone pendant; four children listen beneath faint stars. No new canonical glyph is introduced by the decorative stone spiral.

The owner's 2026-10-27 brief accepts 1586×992 and authorizes these previously held Skyward story images. Skyreach buildings and UI remain held. Existing `skyward_end` and `fireside` entries already load these names. Review the originals, native framing and exact-head CI before Claude merges; this PR stays draft for visual review.
