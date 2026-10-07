# Phase A cutscene painting review

Twenty-four original built-in imagegen outputs: nineteen story stills and five transparent memory layers. Exact loading IDs follow [the art brief](../cutscene-art-brief.md); Claude owns playback, captions, branching and profile selection.

## Review batches

| Batch | Files | Preview |
|---|---:|---|
| [Opening](opening.md) | 3 | [Caption/push-in board](opening-review.png) |
| [Bronze Dawn](bronze.md) | 3 | [Caption/push-in board](bronze-review.png) |
| [Falling Star](falling.md) | 4 | [Caption/push-in board](falling-review.png) |
| [First Contact](contact.md) | 4 | [Caption/push-in board](contact-review.png) |
| [Starfall endings](endings.md) | 5 | [Caption/push-in board](endings-review.png) |
| [Memory layers](memory.md) | 5 | [12% opacity composite board](memory-review.png) |

Each batch is a separate PR into main; no gameplay or renderer edits. Review boards are documentation fixtures, not screenshots of a wired cutscene player. Text and gradients appear only in those boards, never in the source paintings.

## Resolution remains below the brief

**All original outputs are 1586×992, not the requested 2560×1600.** The built-in generator returned this size even when asked for the larger master. Originals are retained unchanged; no synthetic enlargement is described as new painted detail. Draft review can proceed, but the exact master-resolution criterion remains open. Per-batch dimensions and SHA-256 provenance record the actual files.

## Visual contract

The approved Misty Highlands title supplies materials, light and landscape language. Sela follows the standalone character study: long pale hair, white/pale-gold clothing, soft cyan and small jewelry accents. The other two visitors wear the existing pale traveller kit. Kith retain rust, cream, moss and practical leather, without Lumen clasps.

Story focal points remain visible at the fixture's 8% centered push-in. Quiet, darker foregrounds support the bottom caption area. Close character scenes still need the engine's dark caption gradient, as page 20 specifies. No baked text, UI, Bloom growth or magenta appears in Phase A story paintings. Decorative wall strokes do not replace the code's canonical glyph marks.

The #73 arrival atlas is a transparent meteor/impact presentation, not a complete cinematic arrival scene. Its design is reused as the Falling Star reference, while the existing strangers/camp/wall/wreck assets guide their cinematic counterparts. The #73 Bloom-sign design is reused for the memory overlay; it is excluded from first-run story paintings.

## Native review

Godot 4.7.2 generated all texture imports. `preview.gd` renders only documentation boards and changes no saves, simulation or production code. Run it for one available batch:

```sh
godot --path . --script docs/art/cutscenes/preview.gd -- opening
```

Replace `opening` with `bronze`, `falling`, `contact`, `endings` or `memory`. Boards use deterministic SubViewport sizes, a centered 8% crop, and a demonstration lower-third gradient. Memory previews use 12% opacity over the existing title painting; that background's star and Bloom hint belong to the title, not the overlay.

Final prompts and revision prompts are beside each batch. Provenance uses generated source basenames only; personal reference photos and local account paths are excluded.

