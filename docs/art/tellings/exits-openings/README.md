# Three endings, three beginnings

Six original 1586×992 painted stills in `art/rendered/cutscenes/`: `ending_exodus_1`, `ending_cataclysm_1`, `ending_loop_1`, `next_land_1`, `next_ruins_1`, `next_valley_1`. Godot-generated imports accompany the exact stems; Claude wires them after review. No `.gd`, tests, UI or overlays change.

The full prompts, reference roles and generated source basenames are in adjacent JSON records; `spec.json` supplies dimensions and SHA-256 hashes. Built-in imagegen supplied every original; pixels are copied unchanged. The loop correction reduces Sela to a dark remembered silhouette. References are fictional project art and the approved Sela/Kith standard; no personal photos or real-person likeness inputs.

Exodus carries plans, bundles and wooden carts past the old town's lights. Cataclysm cracks the same town terrace with cyan Lumen magic, pushing the magenta/green horizon away. Time loop doubles the sky and settlement around a pale ring above the Hearth. Exodus arrives among unfamiliar rounded hills; Cataclysm returns to the reference town terrace, now grass-covered rubble and small dormant buds; Time loop wakes a Kith in a different valley.

## Review and handoff

`*-player.png` are native 1280×800 captures of the existing production cutscene player with an isolated manually supplied still list and a **sample caption**, not newly wired story data. `next_valley_1-wide-player.png` checks 1600×900. `native-comparison.png` places the six captures beside existing Phase B Sela/Kith images at their native pixel size. The temporary harness adapts `docs/art/ironfall/phase-b/preview.gd`; it is not committed and changes no production or test script.

Faces, hands and ring silhouette remain above the caption zone through cover-fit and near-final push-in. The foremost Exodus traveller can be trimmed at the outer edge; the central cart group and long procession remain fully readable. Source paintings contain no text. Godot 4.7.2 import/capture passes; exact-head CI and visual review remain required before Claude merges. Draft for review.
