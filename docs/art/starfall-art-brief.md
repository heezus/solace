# Starfall art brief

For Codex, written by Claude on 2026-10-07 at Jon's ask. It gathers every picture the Starfall era (era 3, [page 16](../design-system/16-starfall.md)) needs, so one pass can cover the whole span. Stages 1 and 2 are playable on main with placeholders; stage 3 is not built yet, so its slots are marked **later**. Jon brings Codex in himself; nothing here is urgent until he says go. Per-slot notes also live in [requests.md](requests.md).

## The mood
Starfall is **strangers and meaning**: hopeful at first, then ominous once the Bloom is felt. The Kith stay warm and earthy (the Misty Highlands look on main). The **Lumen** are the visitors: pale gold and soft cyan starlight (`lumen-glow`, about `#9fd8e8`), calm, a little unearthly, never sci-fi chrome. Their light is gentle and cool against the Kith's warm firelight. The **Bloom** (later) is magenta and sickly green, and only hinted at: a strange patch at the edge of the fog.

## How art gets into the game
Same as the overhaul: transparent PNG atlases, regions listed in `scripts/rendered_art.gd`, drawn code in `scripts/kith_art.gd` for things that are not buildings. Footprints are fixed by game rules; keep them. Placeholders are drawn today, so any slot can be replaced independently. A new region or sprite slot may need a small code change from Claude: ask in requests.md.

## Slots playable now (stages 1 and 2)
| Slot | Footprint | Now | What it should be |
|---|---|---|---|
| `glyph_wall` | 2x1 | borrows a workshop sprite | A smooth stone wall with a few scratched marks. Calm, readable, a little glow in the grooves. |
| `lumen_camp` | 2x2 | borrows a building sprite | A small tent camp by its own fire, soft cyan light, objects that look carried from far away. |
| `expedition_post` | 1x1 | borrows the Watchtower | A trail outpost: pack rack, lantern, a trail marker. Warm Kith timber. |
| The Wreck (`KithArt.draw_wreck`) | about 2x1 | drawn in code | A broken hull in grass, embers and a few wisps of smoke. Hidden by fog until a party arrives. |
| The three strangers (`KithArt.draw_strangers`) | Kith size (24 px) | Kith figures with a glow | Small Lumen figures: slimmer, pale cloaks, a faint glow. They stand still at the settlement edge. |
| Party pack (optional) | on walking Kith | none | A small pack on the two Kith of an expedition, so a party reads as travellers. |
| Glyph marks | 24 px symbols | drawn by `scripts/glyph_mark.gd` | 20 simple strokes, one per word. Optional: the code-drawn marks already work. |

Do not change the Shard Cairn sprite: it gets a glow layer in code when set 2 is read.

## Slots coming in stage 3 (later)
- **The sky streak and the landing**: a streak of fire across the sky, and the thump (the screen shake and a short flare are code; a streak sprite or a brief overlay is the ask).
- **Lumen walkers** at the Kith's 24 px size, if the strangers should walk and work: idle and walk at least.
- **Trade**: a small market or exchange look at the Lumen Camp (a stall, goods), if trade needs its own sprite.
- **Bloom sign**: a patch of strange magenta and green growth at the edge of the fog. It does nothing yet; one small tile-sized sprite plus a few variants.
- **End card**: a still image for each of the three resets (Exodus, Cataclysm, Time loop). Page 16 lists what each means.
- **Shard-touched beasts and the beast cart** are canon-pending; skip until Jon approves.

## Keep to
- Flat footprints and anchors as on main, quiet ground behind dense objects, contact shadows like the rest of the overhaul.
- Light is a separate layer: glow in the art should be subtle, so the game can add and remove it.
- No text baked into pictures; names come from the game.

## Done when
Each slot above is replaced (or the ones Jon chooses), CI is green on a `codex/` branch, and the screens match the look of the other buildings in a real play pass.
