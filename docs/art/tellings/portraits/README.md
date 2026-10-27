# Three painted portraits

Transparent 1024×1280 PNGs in `art/rendered/portraits/`: `portrait_kin_elder`, `portrait_sela`, `portrait_bloom`, with Godot-generated imports. Chest-up, three-quarter painted busts; no text or backdrop. No UI, `.gd` or tests change. Claude chooses the existing scene/People/ending-card presentation after review. Optional calm/troubled variants are not part of this delivery.

Built-in imagegen created the portraits. Unmodified 1122×1402 RGBA originals are retained in `sources/`; runtime exports use aspect-preserving `sips -Z 1280`, producing exactly 1024×1280 with alpha retained. No repainting, masking or synthetic enlargement was used for export. Individual prompt JSON records include full prompts, reference roles and generated source basenames. `spec.json` contains both hashes, original/export dimensions and visible-alpha regions.

## Comparison and continuity

[Native comparison](native-comparison.png) checks 320×400 and 96×120 display sizes against dark green and ivory. These are documentation alpha/readability fixtures, not proposed UI and not wired screenshots. Transparent holes through the Bloom roots remain open. Shoulders/root tendrils may meet the canvas edge; faces and hair are retained. Run `preview.py` from the repository root with Pillow to regenerate the board/spec.

Sela follows the approved [Sela proportion/identity reference](../../character-standard/sela-candidate.png): warm expressive human face, long pale-gold hair, ivory/gold clothes, pale blue drape and gold/cyan clasp/earring landmarks, with a small glyph glow added at her collar as requested. The Hearthkeeper follows [the fireside painting in #165](https://github.com/heezus/solace/pull/165): grey hair/beard, kind tired eyes, practical traveller clothes, worn shawl and carved hearth stone. Bloom roots and buds follow the broken-world botanical family in #167; their negative spaces imply a sorrowful face, without a human figure or monster features. Only fictional project art supplies references; no personal photos or real-person likeness inputs.

Godot 4.7.2 import passes. Visual review and exact-head CI are required before Claude merges; this remains a draft. Palette and character decisions follow the owner's 2026-10-27 brief and the batch direction recorded with #165.
