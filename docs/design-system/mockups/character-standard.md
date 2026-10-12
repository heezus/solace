# Shared character standard

Status: **approved shared character standard** (2026-10-09), following [Claude’s relay of the owner’s approval](https://github.com/heezus/solace/pull/53#issuecomment-6084666694). Both agents read this page before character art or wiring. This page does not approve all characters in existing paintings.

## Approved decisions and application

The project owner requested a uniform character style. Claude [confirmed the shared-reference workflow](https://github.com/heezus/solace/pull/53#issuecomment-6063792211) and [relayed the owner's scale decisions](https://github.com/heezus/solace/pull/53#issuecomment-6068374707):

- Ordinary Kith and Lumen use the same **35 px** map height target at default zoom.
- Sela and other heroes are marginally taller. **Sela targets about 38 px**, and the [Sela proportion reference](../../art/character-standard/sela-candidate.png) is approved.
- A single model-sheet reference governs map, title and cutscenes.
- Existing 1586×992 cutscene originals are accepted for now; retain prompts and provenance for later touch-ups.

No global tile-scale, gameplay footprint or canon change is proposed. #93 stays held until its stills are checked against this approved sheet after #94 lands. A height change alone does not resolve different head/body proportions.

## Reference hierarchy

| Reference | Authoritative use | Limit |
|---|---|---|
| `art/rendered/walk.png`, standing frame 1 in each identity row | Current Kith miniature silhouette, camera, simple clothing and body proportions | Do not use photographic body proportions or a new cartoon style |
| `art/rendered/starfall-lumen-strangers.png`, regions 1 and 2 | Ordinary Lumen cloak, pale material and miniature silhouette | Current 24 px drawing size is superseded by the owner's 35 px target |
| [Sela study](../../art/lead-stranger/character-v2.png) | Sela's face, long pale-gold hair, ivory/gold/cyan clothing and accents | Identity reference; its longer body does not establish a different species-wide proportion system |
| `art/sprites/lumen_lead.png` | Currently wired Sela sprite and exact crop | Existing source needs proportion/camera review; it is not automatically approved by this page |
| [Kith title study](../../art/kith-study/character-v1.png) and title pair | Named foreground Kith identity and approved title composition | Do not substitute this individual for every Kith or apply foreground detail to map sprites |
| Art direction page 05 and Misty Highlands | Materials, atmosphere and coherent miniature finish | Earlier vector directions and archived experiments are concepts, not new production references |

Private likeness photos stay outside the repository. Use in-game character names in documentation.

## Shape and identity checks

Use the standing Kith and ordinary Lumen sources together as the proportion baseline. Compare crown, chin, shoulders, waist, knees and feet at equal displayed height. Do not stretch an image vertically to hide a mismatch. Use the approved Sela proportion reference for her anatomy and identity; assess future drawings beside both peoples before replacing art.

The approved image establishes Sela’s proportions visually; no separate numeric head-to-body ratio or tolerance has been adopted. Compare crown, chin, shoulders, waist, knees and feet directly against it. Changes to those proportions or facial style require review rather than an interpretation of a vague prompt.

Kith: earthy rust/cream/moss clothing, broad readable sleeves and boots, restrained accessories. Lumen: ivory/pale gold with small soft cyan accents, refined cloth, human faces. Sela: long pale-gold hair, warm expressive face, distinctive gold/cyan clasp and jewelry. Expression may change for story context; identity and proportions stay fixed. No faceless mask, glowing robot eyes or independently invented costume embellishments.

## Detail and presentation

| Use | Detail limit | Camera and staging |
|---|---|---|
| Map | Silhouette and broad face/clothing masses first; seams and jewelry must not become visual noise | Shared three-quarter miniature view, consistent feet anchor and upper-left material highlights |
| Portrait or title foreground | Add face/hair detail within the same face shapes and anatomy; preserve costume landmarks | Lower cinematic angle is allowed; match dusk ambient and scene light rather than adding a separate studio spotlight |
| Cutscene | Same miniatures seen closer, with richer lighting; no switch to realistic anatomy or a different cartoon family | Correct perspective size relative to others and buildings, middle 80% safe, faces/hands/action above calm dark caption foreground |

Body height is compared at equal depth in the scene. Perspective can change apparent screen height; it cannot change head/body ratio. Check characters together, never approve them only as isolated attractive paintings.

## Runtime contract

These are current code observations from main `d989e29`, corroborated by [Claude's contract](https://github.com/heezus/solace/pull/53#issuecomment-6063618827).

- Default tile: 48 world px. Zoom steps: 24/32/40/48/56/64/80 screen px per tile. Preserve logical footprints.
- Kith: `Rendered.kith`, 3 identity rows × 4 uniform 362×362 cells; cell height scales to 35 px. Bottom of the draw box is 3 px below the position point. Standing frame 1; walking 4 frames at 7 fps, one view mirrored horizontally. Preserve cell layout and feet across poses.
- Ordinary Lumen: `Rendered.stranger` uses 24×24 fit boxes today, at bottom-center feet. Sela replaces stranger 0 via `lead_sprite`, crop [277,92,524,1333]. One pose, no supported walk cycle. Claude wires the approved 35 px ordinary Lumen and about 38 px Sela targets after #94 merges; this documentation does not change code.
- Pack: 12×14 px overlay behind a Kith. Carried item sits above the head; verify both if the source silhouette changes.
- Most buildings are 1×1; Hearth is 2×2. Show a home and Hearth in scale reviews. Detailed cutscene anatomy must not force a gameplay scale change.
- Cutscenes: cover-fit, 7% push-in, bottom 34% caption area plus gradient. Review 1280×800 and 1600×900 crops; no baked text.
- Title: cover-fit, left 35% calm for the menu. Portrait slots remain optional and are not wired.

## Review evidence and gate

The [approved Sela proportion reference](../../art/character-standard/sela-candidate.png) retains its original alpha and built-in ImageGen prompt/provenance. The historical filename stays unchanged. The owner approved this image and the approximately 38 px Sela height, as relayed by Claude on 2026-10-09. It is the anatomy reference for subsequent Sela art; production assets remain unchanged in this documentation PR.

[Native scale comparison](../../art/character-standard/scale-review.png) shows the existing sources and approved height targets beside a home and Hearth. Its historical “candidate” labels record the review stage; the rightmost Sela reference is now approved. The older wired Sela remains visible for comparison and is not the approved proportion model.

Before any character replacement: link this page, identify exact source reference and role, inspect the figure at native size beside Kith/Lumen/buildings, compare enlarged anatomical landmarks and costume, then inspect the actual caption/menu framing. Show proposed proportion or hero-height changes to the owner; keep unaccepted art held. Claude flags contract conflicts in the mailbox before wiring. Codex updates this page and the decision log when a visual choice is accepted.
