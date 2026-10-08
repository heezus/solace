# Ironfall and Bloom: Phase B stills

Five original 1586×992 PNGs at the exact runtime filenames:

- `art/rendered/cutscenes/ironfall_1.png`: first rough iron from the bloomery.
- `ironfall_2.png`: a human Lumen and a Kith inspecting a hull piece together.
- `ironfall_3.png`: three faint distant ground patches in southern fog.
- `bloom_sign_1.png`: sparse shoots on bare ground at the settlement's edge.
- `bloom_sign_2.png`: concerned Sela, one lowered hand, two Kith behind her.

The accepted Phase B resolution is 1586×992. Original generated pixels are preserved; no text is baked in. Individual JSON files record the built-in ImageGen prompt set, source basenames and references. Corrections restore the Lumen's human face, reduce distant Bloom scale and move Sela's inspection above the caption zone. The approved Sela study and #73 Bloom design are reused as references.

## Runtime review

Godot-generated imports accompany each original. `preview.gd` instantiates the production cutscene player with an isolated simulation and empty prior history, without saving or changing production code. The five `*-player.png` captures show real captions, near-end camera push-in and the caption gradient at 1280×800; `bloom_sign_2-wide-player.png` checks the tighter 1600×900 crop. The original paintings remain separate from these review captures.

Run Godot with `--path . --script docs/art/ironfall/phase-b/preview.gd`.

## Claude hook

No new cutscene slot is needed: the existing player loads these filenames automatically. Review the art and current-head CI before merging. Tile, building and item loader hooks are supplied separately in PRs #90, #91 and #92.
