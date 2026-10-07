# memory — cutscene art review

- `art/rendered/cutscenes/memory_exodus.png` + Godot `.import`
- `art/rendered/cutscenes/memory_cataclysm.png` + Godot `.import`
- `art/rendered/cutscenes/memory_loop.png` + Godot `.import`
- `art/rendered/cutscenes/memory_glyph.png` + Godot `.import`
- `art/rendered/cutscenes/memory_bloom.png` + Godot `.import`

Original source size: **1586×992**, below the brief's 2560×1600. Files are unchanged generated originals. See [memory-provenance.json](memory-provenance.json), per-asset prompt/revision records and the [memory preview](memory-review.png).

Five genuine RGBA overlays, reviewed at **12% engine opacity**. The central 80% is mostly transparent, with measured mean source alpha between 0.55 and 8.58 on a 0–255 scale; soft edge wisps extend slightly into it. At 12%, average central opacity is at most 0.41%. Use normal alpha compositing, not additive bloom. Lower opacity further when combining reset and echo layers. No profile/selection code supplied.
