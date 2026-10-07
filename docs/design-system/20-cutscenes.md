# Cutscenes: one story across the eras

Proposal (Claude, 2026-10-07, on the project owner's ask): a few short, skippable painted sequences that tie the eras into one telling, so a run reads as a story and not as stages pushed together. Codex paints the stills; the engine plays them. Nothing here is built. It builds on [18 Roadmap](18-roadmap.md) (the arc), [16 Starfall](16-starfall.md) (Sela and the moments) and [05 Art direction](05-art-direction.md) (the Misty Highlands look).

## The idea in one line
Every sequence is the same voice, the Kith's own telling: plain, earthy, a little wry, never more than three short lines on a still. A sequence is 2 to 4 painted stills with a slow push-in or fade between them. No voice and no sound, since there is no sound yet. Esc, Space or a click skips it, and a setting can turn them all off.

## The story spine
The Kith make a home. A light falls. Strangers come out of the fog and the Kith choose how to meet them. With iron the Kith learn to open what the strangers carried, and the thing that hunted the strangers across the stars follows, slowly. The run ends in a reset, and each reset is a told ending that sends the Kith back to the first fire, remembering.

Rules that keep it one story:
- Each sequence answers "what changed for the Kith", not "what did we build". A new building or tech is never the subject.
- Sela and the Lumen come back by name; the Bloom is only ever signs, a tide, then arrival, as in [18](18-roadmap.md).
- The tone shifts exactly as canon says: hopeful first, ominous after the star falls ([03](03-world-lore.md)). Resets return to hope, with a small wrongness the Kith now know.
- Nothing here changes canon. Anything that would goes to [open-questions](open-questions.md) first.

## How it meets what Codex already paints
Draft PR #73 (moment vignettes) paints single header images for the Hunger, Shards and Warning cards and the Starfall end card, tile-sized Bloom signs, and "arrival presentation" art. Those stay as they are: a **vignette** is one picture on a choice card the player is answering. A **cutscene** is a full-screen sequence between play and choices. They share people and places, so Sela's look, the Bloom signs and the arrival art are reused as cutscene stills, not painted twice. If #73's arrival art is accepted, it becomes the first still of `first_contact`.

## The sequences
Ids are stable (the Chronicle can record them, [13](13-three-perspectives.md)). "Trigger" is an existing Story id or era event.

| Id | When | Stills | Lines (a still per row) |
|---|---|---|---|
| `opening` | New game, after the title | 3 | "Solace was quiet when the Kith came." / "They raised a fire and called the place home." / "Nothing yet told them they were not alone." (a faint cyan point low in the sky) |
| `bronze_dawn` | Bronze Dawn is discovered | 3 | "Copper and tin, and a new color in the fire." / "The roads reached farther than anyone had walked." / "East, under the fog, something waited." |
| `falling_star` | Before the "Falling Star" card, end of Bronze Dawn | 4 | "A star came down." / "The Kith watched it fall. Nobody spoke." / "It landed beyond the hills." / "In the morning, the silence began." |
| `first_contact` | The strangers arrive (`guests` or `wary` variant of the first two stills) | 3 | wary: "Three strangers came out of the fog, and stopped." guests: "Three strangers came to the Cairn, as guests." / "The tall one smiled anyway." / "She tapped her chest and said a word, and waited." |
| `starfall_end` | The Starfall ending, after the choice is made; the last still has three variants by Lumen lean | 3 | "The ship would not fly again." / "What the Lumen carried, the Kith began to read." / neighbours: "They would be neighbours." enemies: "They kept their distance." allies: "They stopped counting whose fire it was." |
| `ironfall` | Ironfall is entered | 3 | "Iron, and a way to open things." / "The Lumen showed what their ship was made of." / "At the edge of the fog, something was growing." |
| `bloom_sign` | The first Bloom patch is seen | 2 | "It was not there yesterday." / "Sela stopped smiling. She knew what it was." |
| `livewire` | Livewire is entered | 3 | "Light without fire." / "The growth came slowly, and did not stop." / "So the Kith began to give their machines orders." |
| `skyreach` | Skyreach is entered | 3 | "The Kith learned to read the sky." / "What hunted the Lumen across the stars had followed." / "It was not coming to fight. It was coming to stay." |
| `reset_exodus` | Exodus | 3 | "Pack what you know." / "Leave the fire lit for whoever follows." / "A new valley. The same people." |
| `reset_cataclysm` | Cataclysm | 3 | "The magic reached too far, and the world broke." / "The Kith woke in the ruins." / "They dug. Some of it was theirs." |
| `reset_loop` | Time loop | 3 | "The morning came again." / "Only the Kith remembered." / "The fire was lit. They knew what was coming." |

After any reset the next run's `opening` plays in full, with one added still: the Hearth with a small mark of what carried, and no new line.

Phases, so art and code can run ahead of the eras:
- **A (the eras that exist):** `opening`, `bronze_dawn`, `falling_star`, `first_contact`, `starfall_end` (16 stills plus 3 variant stills: a second `first_contact` 1 for the guests version, and two more `starfall_end` 3 for the other leans; 19 images in all).
- **B (with Ironfall stage 1):** `ironfall`, `bloom_sign` (5 stills).
- **C (later):** `livewire`, `skyreach` and the three resets.

## Rules for the stills
- 2560x1600 (16:10, the title's ratio), original painted PNGs in `art/rendered/cutscenes/<id>_<n>.png` (`n` from 1), plus the Godot import file. Compose the subject in the middle 80%: the player pans and pushes in 6 to 8% over the still.
- Leave the bottom third calm and darker, since the lines sit there. No text in any image; the lines are drawn by the game.
- The same Misty Highlands light as the title: warm hearth against a cool dusk, cyan only for the Lumen, magenta and green only for the Bloom, and only as hints until Livewire.
- Sela's look follows [the art brief](../art/starfall-art-brief.md); the Kith and Lumen use the traveller kit's clothing so they match the map.

## How it plays (engine, not built)
- `Data.CUTSCENES` holds, per id: the trigger, the lines, the art paths and the pan. A `CutscenePlayer` control draws a still, a dark gradient and the lines, fades between stills and pauses the simulation while it runs.
- It listens to `Story.recorded` and to era changes, so no gameplay code changes. Each id plays once per run.
- **Art not painted yet is fine:** with a missing image the sequence shows the lines over a dark panel with the fade, so the story ships first and the paintings drop in later by name.
- Skippable at any point, and the pause menu gets a "Cutscenes" on/off. A skip still records the story id.
- Every run plays every sequence in full, so no seen-list is needed. The on/off setting lives in a tiny file apart from the run save (`user://profile.json`, the start of the profile save from [13](13-three-perspectives.md)).

## Open (defaults stand until the project owner says otherwise)
- **Replays.** *Decided (the project owner, 2026-10-07):* every run plays every sequence in full. Skip is always there, and the pause menu can turn them all off.
- **Wiring.** *Default:* Phase A rides along with the Ironfall stage 1 PR; Codex paints in the meantime and the lines-over-dark fallback covers the gap.
