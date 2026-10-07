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

## Character: the lead stranger (Jon, 2026-10-07)
Jon's friend Briana asked to be in the game, and Jon made her one of the three Lumen who walk out of the fog: the **lead stranger**, the first of them to trust the Kith and the face of the trust choices. The in-game name is pending Jon's pick (Briana, or a Lumen name close to it); call the slot `lead-stranger` either way. This section is the whole spec. **No photos are in the repo.** Jon can hand reference photos to Codex himself, and the words below are enough on their own.

**Who she is.** Warm, playful, quick to tease, perceptive and confident. Glamorous at first glance, goofy, affectionate and loyal once she trusts you. She notices how people feel before they say it. Sweet one moment, mischievous the next; never cold, never prim.

**Her look, in the game's stylized miniature style (Misty Highlands, a chunky toy-like figure, not a likeness study):**
- A woman in her mid-30s, athletic and fit, with a bright, expressive face and a warm smile. Long blonde hair, worn loose and a little wind-caught (it sits well with the Lumen's pale gold).
- Polished and stylish Lumen clothing: a flattering pale cloak or long coat over clean, fitted layers, in cream, pale gold and soft cyan. Jewellery-like accents (a collar clasp, a bracelet, ear drops) in pale gold with a soft cyan glint. Sophisticated and expensive-looking, not formal and not armoured.
- Tasteful and friendly. She is glamorous because she carries herself well, not because of what she shows: full-length clothing, no exposed midriff, nothing suggestive. A confident stance and a smile do the work.
- Readable at sprite size: the hair silhouette (long, pale gold) and the cyan-and-gold accents are what tell her apart from the other two Lumen at 24 px.

**Slots (all optional, in this order):**
1. **Figure at 24 px** (`lead-stranger`): the same four poses and foot anchor as the other pale-cloaked Lumen from the traveller kit, replacing one of the three stranger variants. She is the one who stands nearest the Hearth.
2. **Portrait** (`lead-stranger-portrait`): head and shoulders, about 160x160 on a transparent or softly vignetted ground, for the moment cards (the Hunger, the Shards, the Warning). A warm smile as the default, with an optional second frame, worried, for the Warning.
3. **Alternate title screen** (`art/rendered/title_briana.png`, about 2560x1600, same composition rules as `title.png`: the left 440 px at 1280 wide calm and dark for the menu): the same Misty Highlands scene with the lead stranger in it, stepping out of the fog toward the Kith fire, the cyan falling star above and the faint Bloom glow in the east. With both paintings on disk the title picks one at random on launch; with only `title.png` it shows that. Same import rule as the title.
4. **Card header** (optional): the same figure at about 320x120 with a soft Lumen glow, if the portrait is not enough.

**Paste-ready message for Codex (Jon pastes it):**

> Codex, a new character for the Starfall art pass. Jon's friend Briana is in the game as the lead Lumen stranger (name pending). Please read the section "Character: the lead stranger" in docs/art/starfall-art-brief.md and do three things in the Misty Highlands miniature style: (1) a 24 px figure `lead-stranger` in the traveller kit's four poses, long pale-gold hair, cream and pale-gold cloak, cyan-and-gold jewellery accents; (2) a head-and-shoulders portrait `lead-stranger-portrait`, about 160x160, warm smile, with an optional worried frame; (3) an alternate full title screen `art/rendered/title_briana.png`, about 2560x1600, same composition rules as title.png (left 440 px at 1280 wide calm and dark for the menu), with her stepping out of the fog toward the Kith fire; (4) a 320x120 card header if the portrait alone is not enough. Keep her tasteful and friendly: stylized, full-length clothing, nothing suggestive. Jon may give you reference photos; use them only as a loose guide to hair, smile and mood, not as a likeness study, and do not commit the photos to the repo. Small PR, assets and a README only; Claude wires the code.

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
- **Stage 4 buildings (built, stand-ins in the game)**: a **Guard Post** (a watch post the Lumen dislike), a **Shared Shrine** (both peoples leave something, trust-building) and a **Lumen Market** (a trade stall by the Camp). Keys `guard_post`, `shared_shrine`, `lumen_market`; each is 1x1 on the Lore tab.
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
