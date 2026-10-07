# Cutscene art brief (Phase A)

The design is [page 20](../design-system/20-cutscenes.md): short, skippable sequences of painted stills that tie the eras into one story. This brief is the whole spec for Phase A, the five sequences for the eras that already exist. Phase B (`ironfall`, `bloom_sign`) follows with Ironfall; Phase C (`livewire`, `skyreach`, the three resets) is later.

## The look
- The Misty Highlands painting of the title: the same light, brushwork and palette. Warm hearth firelight against cool dusk. Cyan only for the Lumen and the falling star. Magenta and green (the Bloom) are not in Phase A except as nothing at all.
- 2560x1600 (16:10) original PNGs, no text in the image. Compose the subject in the middle 80% (the game pushes in 6 to 8% over each still), and keep the bottom third calm and darker, where the lines sit.
- People are the game's chunky, toy-like miniatures seen from a slightly lower, more cinematic angle than the map. The Kith wear the traveller kit's clothing. Sela is the tall Lumen with long pale hair from [the character brief](starfall-art-brief.md); the other two Lumen match the map sprites.
- Save as `art/rendered/cutscenes/<id>_<n>.png` with Godot import files. The game loads by name, so no code change is needed to drop one in.

## The stills (19)
| File | What is in it |
|---|---|
| `opening_1` | Dawn mist over empty highlands, a few stones, nobody yet |
| `opening_2` | Kith hands setting the Hearth stones, a first small fire |
| `opening_3` | The Hearth at dusk, the sky clear; very low on the horizon one faint cyan point |
| `bronze_dawn_1` | Molten bronze poured into a mould, a new gold-green glow in the fire |
| `bronze_dawn_2` | A hand cart on a long road heading east toward fog |
| `bronze_dawn_3` | The fog edge in the east under a pale star high above |
| `falling_star_1` | A night sky with a bright cyan streak |
| `falling_star_2` | Kith on a hill, cyan light on their faces, silent |
| `falling_star_3` | Far beyond the hills a glow and a rising smoke column |
| `falling_star_4` | The quiet Hearth at first light, the fire low |
| `first_contact_1` (wary) | Three pale-cloaked figures at the edge of the fog, stopped, far away |
| `first_contact_1_guests` | The same three arriving beside a standing Shard Cairn, close and unhurried |
| `first_contact_2` | Sela waving, a bright open smile, the other two behind her |
| `first_contact_3` | Sela tapping her chest, speaking, waiting; the Kith leaning in |
| `starfall_end_1` | The broken crash hull in the grass, embers on its ribs |
| `starfall_end_2` | Kith and Lumen at the glyph wall, reading marks together |
| `starfall_end_3_neighbours` | Two small fires side by side, a path between them |
| `starfall_end_3_enemies` | Guard posts lit, the Lumen camp apart at the edge of the light |
| `starfall_end_3_allies` | One shared fire, Kith and Lumen hands together at the wall |

## Paste-ready message for Codex
> Codex, a new art batch for Solace: cutscene stills. Please read docs/art/cutscene-art-brief.md and docs/design-system/20-cutscenes.md. Paint the 19 Phase A stills in the table (Misty Highlands title look, 2560x1600, no text in the image, subject in the middle 80%, bottom third calm and darker), save them as art/rendered/cutscenes/<id>_<n>.png with their Godot import files, and keep Sela as in docs/art/starfall-art-brief.md. Please reuse your arrival and Bloom-sign art from #73 where they fit rather than painting them twice. Small PRs are fine, a few stills each; Claude wires the code. Work on a codex/ branch and open a PR.
