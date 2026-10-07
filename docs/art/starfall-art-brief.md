# Starfall art brief

For Codex, written by Claude on 2026-10-07 at Jon's ask. It gathers every picture the Starfall era (era 3, [page 16](../design-system/16-starfall.md)) needs, so one pass can cover the whole span. Stages 1 and 2 are playable on main with placeholders; stage 3 (three moments, the Warning, the ending, the first Bloom sign) is in review, and slots for what comes after are marked **later**. It covers the whole era: characters, buildings, materials, tech icons and cards. Jon brings Codex in himself; nothing here is urgent until he says go. Per-slot notes also live in [requests.md](requests.md).

## The mood
Starfall is **strangers and meaning**: hopeful at first, then ominous once the Bloom is felt. The Kith stay warm and earthy (the Misty Highlands look on main). The **Lumen** are the visitors: pale gold and soft cyan starlight (`lumen-glow`, about `#9fd8e8`), calm, a little unearthly, never sci-fi chrome. Their light is gentle and cool against the Kith's warm firelight. The **Bloom** (later) is magenta and sickly green, and only hinted at: a strange patch at the edge of the fog.

## How art gets into the game
Same as the overhaul: transparent PNG atlases, regions listed in `scripts/rendered_art.gd`, drawn code in `scripts/kith_art.gd` for things that are not buildings. Footprints are fixed by game rules; keep them. Placeholders are drawn today, so any slot can be replaced independently. A new region or sprite slot may need a small code change from Claude: ask in requests.md.

## The title screen (Jon, 2026-10-07)
The first thing the game shows. Claude is building the screen (title, save and zoom PR) with a drawn stand-in: a dusk over misty highland, a Kith fire, a pale cyan falling star and a faint magenta-and-green glow in the east. It picks up a painting by name, no code change: **`art/rendered/title.png`** (with its Godot `.import` file, like the other `art/rendered` PNGs). Jon likes the misty-highlands renderings made before (start from [the village, river and resource studies, the engine settlement captures and the blended regions](overhaul/misty-highlands/README.md)).
- One image, 16:10, about 2560x1600. It is scaled to cover the window, so keep the important parts away from the edges.
- The menu sits on the **left 440 px at 1280 wide** (about the left third): keep that side calm and darker so the name and three buttons read over it.
- Show the Kith first: a settlement with a warm hearth fire at dusk. Then three hints, none of them explained: a pale cyan star falling in the sky (the Lumen), and a faint magenta-and-green glow with thin reaching growth low on the eastern horizon (the Bloom). The Kith are the hero; the others are only a promise.
- No text in the image. The name and buttons are drawn by the game.

**Paste-ready message for Codex (Jon: copy this):**
> Jon wants a title screen painting for Solace. Read docs/art/starfall-art-brief.md, the section "The title screen". Start from the misty-highlands renderings we made before (docs/art/overhaul/misty-highlands). Make one 16:10 painted image, about 2560x1600, at art/rendered/title.png with its Godot .import file. A Kith settlement with a warm hearth fire in misty highland at dusk; a pale cyan star falling in the sky (the Lumen); and a faint magenta and green glow with thin reaching growth low on the eastern horizon (the Bloom), as hints only. Keep the left third calm and dark, because the menu sits there. No text in the image. The game loads the file by name, so no code change is needed. Work on a codex/ branch and open a PR.

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

## Materials and items (new goods and icons)
Starfall adds no new stockpile goods yet, so the existing item icons stay. What it does need:
- **Pack icons** for the Expedition Post's three packs (Light, Standard, Heavy), at the item-icon size (24 to 40 px), in the style of `art/rendered/items.png`: a small satchel, a loaded satchel, a full travel pack with a rolled blanket.
- **Shard** icon polish: the Strange Stone is the era's key material, and it shows up on cards, the Cairn and the Lumen's cloaks. A pale cyan glowing shard, readable small.
- **Later goods** the era's finds will bring (alternate recipes, Bloom samples): a Lumen cloth, a Lumen lamp cage (a shard in a cage), a Bloom sample (a bagged magenta growth). Not wired yet; draw them once Jon confirms they are wanted.

## Tech and research icons
Research cards use the illustration atlases (`research-symbols`, `research-landmarks`, 24 to 40 px). Starfall has no research-board techs yet; its progress is the glyph sets. These need icons, in the same carved, warm style:
| For | Icon |
|---|---|
| The four gifts read from glyph sets | **Shardlight** (a lit cairn), **Lumen Healer** (a leaf bundle on a cloth), **Starfruit** (a glowing berry), **Shardwork** (a shard bound in rope and bronze) |
| The Warning (set 6) | a small mark circled three times |
| The six glyph sets as headings | one small emblem each: the Name, Light, Body, Growth, Craft, the Warning |
| The third (magic) tech tab, **later** | about 14 techs, one icon each, drawn when the tab is built (Claude will list them then) |

## Cards and interface
- **Moment cards** (the Hunger, the Shards, the Warning, and the ending): each can carry a small vignette at the top, about 320x120. The Hunger: an empty bowl and a stranger's hand. The Shards: hands held out toward the Cairn. The Warning: a finger to lips against a dark east. The ending: the Bloom sign at the fog's edge.
- **Glyph Wall panel**: optional header ornaments; the marks themselves are code-drawn already.
- Keep to the current charcoal green, ivory and brass interface style.

## Slots coming in stage 3 (later)
- **Buildings still to come**: a **Guard Post** (a watch post the Lumen dislike), a **Lumen shrine** (shared, trust-building) and a **Trade stall** at the Camp. They are not built; say if you want to start on them early, and Claude will add the slots.
- **The sky streak and the landing**: a streak of fire across the sky, and the thump (the screen shake and a short flare are code; a streak sprite or a brief overlay is the ask).
- **Lumen walkers** at the Kith's 24 px size, if the strangers should walk and work: idle and walk at least.
- **Bloom sign**: a patch of strange magenta and green growth at the edge of the fog. Stage 3 draws a stand-in at the sign's tile; one small tile-sized sprite plus a few variants replaces it.
- **End card**: a still image for each of the three resets (Exodus, Cataclysm, Time loop). Page 16 lists what each means.
- **Shard-touched beasts and the beast cart** are canon-pending; skip until Jon approves.

## Keep to
- Flat footprints and anchors as on main, quiet ground behind dense objects, contact shadows like the rest of the overhaul.
- Light is a separate layer: glow in the art should be subtle, so the game can add and remove it.
- No text baked into pictures; names come from the game.

## Done when
Each slot above is replaced (or the ones Jon chooses), CI is green on a `codex/` branch, and the screens match the look of the other buildings in a real play pass.
