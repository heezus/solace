# Decision Log

Newest at the top. Each entry: what we decided, why, and what it replaces.

| Date | Decision | Why | Replaces |
|---|---|---|---|
| 2026-09-29 | First playable: the stone-age loop plus a lite 9-node tech tree, ending at the Bronze Dawn era gate. See 08-first-playable.md. | Jon: "your pick with a lite tech tree". | — |
| 2026-09-29 | Art: clean vector in an Advance Wars-style look: flat saturated colors, bold outlines, chunky toy-like units, strong faction colors, a readable grid. | Jon chose vector and named Advance Wars as the look he loves; Claude can generate vector art itself. | — |
| 2026-09-29 | Engine: **Godot** (free, runs on Mac). | Claude is the primary builder; Godot scenes and scripts are plain text and tests can run headless. Unity and Bevy were considered. | — |
| 2026-09-29 | The greater enemy is **the Bloom**: a living, alien growth that consumes worlds. It completes the triad of machine (Kith), light/magic (Lumen) and life (Bloom), and can become a third tech tree later. | Jon wanted a thematic third element; he picked the biological/alien option. | — |
| 2026-09-29 | The player's people are **the Kith** (working name, may revisit). | Jon: "Kith is good for now." He likes short, real, earthy words; made-up fantasy names were rejected. | — |
| 2026-09-29 | The game's title is **Solace**, the same as the planet. | Jon's call. | — |
| 2026-09-29 | The star refugees call themselves **the Lumen**; the player's people call them **the Starfallen**. | Jon liked both and let Claude pick; using both adds an outsider-vs-insider layer. | — |
| 2026-09-29 | The planet is named **Solace**. | Jon's pick: hopeful at first, ironic once the ship lands. | — |
| 2026-09-29 | The player chooses how to treat the refugees (trade, conflict or a mix), and that choice steers which prestige layer they reach. | Jon picked "Your choice" on topic 12. | — |
| 2026-09-29 | Tone shifts as you climb: hopeful and curious in the stone age, turning ominous once the refugee ship lands and the hunters draw near. | Jon picked "Shifting"; it pairs with prestige resets. | — |
| 2026-09-29 | The star fell twice: shards fell ages ago (the rare magic traces), and the main refugee ship crashes mid-game (the major discovery). | Jon chose "both" on topic 10. | — |
| 2026-09-29 | The magic rivals came from a fallen star: refugees who wield magic, fleeing a greater enemy. That enemy is the future third adversary from space. | Jon: a star makes magic a rival and sets up a third adversary later. | Ley lines / ruins / living crystal options |
| 2026-09-29 | Prestige has three layered resets, chosen by progress and how much magic is in play: Exodus (low magic, carries knowledge), Cataclysm (magic overreach, relics survive), Time loop (deepest layer, only the player remembers). | Jon wanted all three depending on progress and magic; the ordering is our proposal. | — |
| 2026-09-29 | Plan for a prestige / reset system from the start. | Jon asked for it; he loves incremental and idle games. | — |
| 2026-09-29 | Magic appears only in small, sparing traces until a major discovery opens the magic tree. | Jon's call on when magic appears. | — |
| 2026-09-29 | The game starts in the stone age. | Jon's answer to topic 7: the longest climb. | — |
| 2026-09-29 | Perspective: top-down 2D. | Jon's answer to topic 6; also the most realistic scope for a first game. | — |
| 2026-09-29 | Tech progresses in eras, from simple beginnings to super advanced, Civ-style. | Jon asked for it; backed by 225h in Civilization V. | — |
| 2026-09-29 | The factory operates on a single planet. | Jon's answer to topic 5; it leaves room for a possible third, alien faction later. | — |
| 2026-09-29 | The player starts on the tech side. Magic is the strange discovery. | Jon's answer to topic 4. | — |
| 2026-09-29 | Magic and tech are rivals with separate tech trees. The player starts in one, discovers the other, and bridging them reshapes the tree. | Jon picked both "Rivals" and "Discovery" on topic 3. | — |
| 2026-09-29 | Setting: a blend of magic and technology. | Jon's answer to topic 2 ("Blend for sure"). | — |
| 2026-09-29 | Core genre: automation with a complicated, interdependent tech tree. Jon wants all three hooks: designing it, watching it run, and reaching the next stage. | His answer to topic 1; backed by 500+ hours in Factorio, Satisfactory and Timberborn. | — |
| 2026-09-29 | Shape the game one small topic at a time, using the Steam data as evidence. No full pitches up front. | Jon prefers a granular approach. | Early pitches (pitches.md) |
| 2026-09-29 | Keep a living design system in this folder as the source of truth for the game's universe. | Stay canonical as ideas pile up. | — |

## 2026-09-29: Playtest fixes (Jon's first playtest)
- **Population comes from food.** Kith grow while 3 food per Kith is stored (one every 15s) and leave when there is no food. Every hut or workshop needs one Kith. (Jon: "the amount of population should be based on food.")
- **Flour for research is never eaten.** The Kith keep back whatever flour an unresearched tech still needs.
- **Onboarding:** an 8-step goal panel, a labeled bottom bar, locked buttons that say what they need, tooltips that say what each item is for, and a color per tech with Needs and Leads to chips.
- **Next (Jon's ask):** distance matters. Kith walk to gather and haul, and hand-placed roads double their speed. Defaults: haulers go through the Camp, and Kith take jobs automatically.

## 2026-09-29: Branching tech tree v3 (was v2)
- Jon wants the tree "more intricate and branching" and drawn "with arrows". The design is in 09-tech-tree.md: 18 techs in 4 lanes, two parents from different lanes per tech, and one optional side branch (Pack Frames).
- Arrows follow the Solace visual design mockup: parent-colored lines, solid when met and dashed while needed, laid out as a map from left to right.

- v3, after Jon's "maybe just need more tech. Let's be creative. Tighten all of it":
  - 30 techs in 5 lanes. Lore (Storytelling, Ochre, Star Lore, Megaliths, Calendar) is the fifth lane.
  - 9 techs are optional side branches.
  - Star Lore is hidden and revealed by clicking the Strange Stone.
  - Two techs take either of two parents.
  - Bronze Dawn needs Grindstone, Storehouse, Roads, Granary and Calendar.

## 2026-09-30: Jon's standing answers and the Bronze Dawn era
- Jon: build the stone age plus the Bronze Dawn era. Tune a first stone-age run to about 20 minutes. Claude may merge PRs to main once CI is green. No sound yet.
- Bronze Dawn is designed in 10-bronze-dawn.md:
  - Themes are metal and distance: Copper is near, and Tin is rare and far away.
  - Seven new systems, one per tech: the map grows east under fog, ore, 2-Kith mines, smelting, carts, tool wear, and the Watchtower.
  - The era tree has 16 techs.
  - It ends on "The Falling Star", a cliffhanger before the Lumen crash. The crash itself is era 3.

## 2026-09-30: Visual design defaults (design thread)
- **Tech tree panel:** drawn as a transit map. Lanes are rows, tiers are columns, and arrows are routed orthogonally through channels. Unmet arrows rest as faint dashes, and hovering lights the full chain. Spec: mockups/tech-tree-v3.md.
- **HUD:** raw and made goods in fixed-width chips, food shown as time left, and a path drag tool with a ghost preview. The selection panel shows trip distance and time, and status pills point at their building. Spec: mockups/hud.md.
- **Sprites:** every stone-age v3 and Bronze Dawn piece exists as a 32px SVG in mockups/sprites/.
- **New tokens:** path, road, soil, fog, hill, copper, tin, bronze, positive, card-done, card-locked, gate and gate-bg.
- Claude picked these while Jon was away. He can revise any of them.

## 2026-09-30: Genre conventions pass (Jon's playtest 2)
- Jon: "so many ideas based on other games mechanics that are just things you come to expect." His specific asks: resource flow he can see, demolish, crossing water, fog of war, green and red +/- rates in the top bar, and a settlement center.
- 11-conventions.md lists 13 conventions in priority order, with Claude's defaults:
  - The Camp becomes the Hearth. Dwellings go within 6 tiles of it.
  - A Wooden Bridge on river tiles unlocks with Haulers. Roads no longer cross rivers.
  - Demolish refunds 50%.
  - Fog starts 6 tiles out from the Camp.
  - Autosave every 60s.
- This takes priority over new Bronze Dawn content.

## 2026-09-30: Playtest 2 visuals (design thread)
- Every good in the top bar shows its net rate underneath, green (+) or red (−). Hovering a good explains where it comes from and where it goes.
- Selecting a workshop draws animated flow arrows to and from the Hearth.
- The Camp becomes the **Hearth**, the settlement center. Dwellings must go within 5.5 tiles of it, and new Kith appear there.
- Fog of war clears within 9 tiles of any building.
- Demolish is a tool (X) and a panel button. It refunds half and leaves rubble briefly.
- Rivers block walking until Roads (bridges) or Rafts. Stepping Stones are only an idea.
- There are now two tech tree looks: A (the colorful transit map, the default) and B (a calmer research board with icons and gold hover chains). Jon picks.
- Spec: mockups/hud-playtest2.md.
- Reconciled with mockups/hud-playtest2.md (2026-09-30). The game uses these, and the spec's visuals are adopted otherwise:
  - **Hearth ring:** radius 6 tiles, not 5.5.
  - **River crossing:** a Wooden Bridge, drawn with tile_bridge_wood.svg and unlocked by Paths & Haulers. Rafts stays the late side tech. Stepping stones aren't used for now.
  - **Fog:** starts 6 tiles around the Hearth. Buildings reveal 3 tiles and Kith reveal 2, and Scouting adds 2 to both.
- The tech tree keeps Option A (transit map) until Jon picks.

## 2026-09-30: Playtest 3: tools as multipliers, a steady bottom bar, and research board B
- **Tools become the multiplier system.** Jon: flint tools felt "pointless after a while", but "a fun multiplier aspect" appealed to him.
  - Each working Kith takes one tool from the stockpile and works **+50% faster** while holding it.
  - A tool wears out after 40 jobs, so tools are a steady demand on flint and wood, not a one-off.
  - The top bar shows how many workers are equipped, e.g. "Tools 3/5 Kith".
  - Hand gathering keeps its x2.
  - This is the base of a multiplier ladder: Flint Tools, then Stone Axe (Wood x2), then Bronze Tools in era 2 (+100% and they last longer). Later upgrades stack on top the same way.
- **Traversal:**
  - Roads and a Wooden Bridge over the river.
  - **Mountain pass:** a road may be laid on a Rocks tile for 3 Stone. It clears the rock into a pass, so rocky ridges become shortcuts.
- **Bottom bar:**
  - Fixed-width buttons, so labels never shift with the numbers. Costs move to tooltips and the placement preview.
  - Grouped into tabs: Homes, Gathering, Workshops, Logistics, Lore. Craft by hand gets its own small group.
- **Tech tree:** Option B, the calm research board from mockups/tech-tree-v3.md, replaces the transit map. Jon said the lines "bleed/overflow and aren't readable".

## 2026-09-30: Adopted from the research thread (research/mechanics-and-tech-trees.md)
- **Adopted now:**
  - **Multiplier math shown in the building panel**, e.g. "10/min x Tools 1.5 x Standing Stone 1.15 = 17/min". Bonuses are grouped into Speed and Yield: they add within a group and multiply across groups. Ochre and Megaliths become x2 with a smaller radius or a narrower target, not small percentages.
  - **Research queue:** click a far tech to set it as the goal, and its missing chain is queued. The queue has 3 to 5 slots, plus a "Ready to research" list.
  - **Blocked tiles name their tech:** hovering the river says "Cross with a Wooden Bridge (Paths & Haulers)", and hovering rocks says "Cut a pass with a Road".
- **Next pass:**
  - **Eurekas:** a related action halves a tech's cost, with the hint shown on the card.
  - **Research paid for with each tier's own goods.**
- **Later:** prestige resets that automate the era you just finished.

## 2026-09-30: Tech tree v4 approved
Jon approved mockups/tech-tree-v4.md. It uses the board B style with sprite icons, rewires about 10 links so each prerequisite makes sense, and reorders the lanes to Fiber, Stone, Land, Hearth, Lore. The era gate moves to tier V. The code thread applies it to 09-tech-tree.md and the game.

## 2026-09-30: Knowledge is progress (agreed direction)
- Jon: "Awesome i love that progress idea. Except we do want the map to change." What the Kith know is the real progress, and each era adds one new way of learning. The details are in 12-knowledge-is-progress.md.
- **Stone age:** teach by doing, in its small version. The first time you do a job kind by hand (3 times), a Kith learns it and takes over. It will be built after the current polish PR.
- **Era 3:** deciphering the Lumen glyphs and expeditions.
- **Time loop:** the map is regenerated, and only knowledge carries over.

## 2026-09-30: Keeping the design system in sync
- Jon asked how the docs stay in sync. Rule: every new page, including those under mockups/ and research/, gets a link in README.md and an entry here the same day. README now indexes the mockups and research pages and has a current status line.

## 2026-09-30: Tech tree v4 built
- Built as a data change in `scripts/data.gd`: the 10 corrected links, lanes Fiber, Stone, Land, Hearth, Lore, the v4 columns, and the gate after Tier V. The board's lines route themselves from that data. 48 links, 11 of them skip a column, and the tests check that no line runs under a card.
- Stone Axe is now on the critical path, because Farming and the Water Wheel need it. Bronze Dawn needs 18 techs, and the other 10 are side branches. A test checks that the `side` tag matches.
- The board is 1492 px wide, so at 1280 px it scrolls sideways by about one tier and opens on the frontier. Stone Axe gets a drawn axe icon, and Baking keeps its bread icon.
- 09-tech-tree.md now documents v4 as built.

## 2026-09-30: Three perspectives (idea, not canon)
- 13-three-perspectives.md writes up Jon's "play as each faction" idea. It isn't canon yet. It asks two things of the code now:
  - Keep faction names and faction data in data files, not in engine code.
  - Keep a profile save (persistent knowledge) separate from each run's save.

## 2026-09-30: Stone age pacing tuned with a test bot
- A headless bot (`tests/autoplay.gd`) plays the stone age by the rules: it clicks by hand, researches the Bronze Dawn route in order, and builds huts, homes, workshops and roads as the chain needs them. The test suite runs it on maps 1 to 3 and fails if Bronze Dawn takes under 8 or over 25 simulated minutes.
- Target is 12 to 16 minutes. On maps 1 to 8 it now wins in 14.0 to 16.4 minutes, 15.2 on average. Before tuning it took over 25 minutes, held back by stone, clay and flour.
- Data changes in `scripts/data.gd`:
  - Masonry 40 → 25 Stone. Water Wheel 20 → 10 Stone. Grindstone 30 → 20 Stone. Paved Roads 60 → 40 Stone. Stone Axe 15 Flint + 20 Wood → 10 + 15.
  - Bronze Dawn: 40 Brick, 30 Flour, 40 Rope, 100 Stone → 30, 20, 30, 60.
  - Twine Post: 3 Fiber per Rope → 2. Kiln: 2 Clay per Brick → 1.
- Map: two gravel tiles now sit 4 tiles east of the Hearth, so flint is in sight at the start. The Stone Axe needs flint early.
- A real playtest should check the feel, since a human plays neither as fast nor as steadily as the bot.

## 2026-09-30: From Hands to Haulers (Jon's playtest 4)
- Jon: the clicking-to-automation jump felt disconnected. He asked to split techs into smaller pieces and to scale click yield and tech costs.
- 14-hands-to-haulers.md defines one arc per resource:
  - Hands: gather it by hand 10 times and a Kith learns it (teach by doing).
  - Taught: its hut unlocks.
  - Dispatched: click the hut to send one trip that brings back a bundle.
  - Automated: after Paths & Haulers the hut loops, and a click rushes a building.
- Click yield is base x tool x rank. Gathering and workshop techs get optional ranks I to III, each costing 2.5x the last. Tech costs scale by tier and are paid in the previous tier's goods.

## 2026-09-30: The Storehouse is its own tech (Jon's playtest 4)
- Jon: the tech tree "isn't following and unlocking items like a warehouse", and "i do like the warehouse idea and that will help with pacing". Paths & Haulers used to unlock the Storehouse without its card saying so, and nothing said the Dwelling needs no research.
- **Storehouse** is now a Tier IV tech in the Fiber lane. It needs Paths & Haulers and Masonry, unlocks the Storehouse building, and **Bronze Dawn needs it**, so it is on the critical path (19 techs). Bronze Dawn was picked over Paved Roads because "roads need a warehouse" doesn't read; "the settlement needs stores before bronze" does. Its cost follows Tier IV (see the tuning entry below).
- Paths & Haulers' card now reads "Road, Wooden Bridge".
- The **Dwelling stays free**, and the build bar marks it "Always available". Gating it behind Foraging would only add a step before the first home.
- A test now fails if a building or recipe names a tech that doesn't exist, can be placed before its tech, or is missing from its tech's card summary.
- 09-tech-tree.md is updated: 29 techs, 51 links.

## 2026-09-30: Hold to harvest
- Jon: "instead of a click to harvest its a hold to click... since its upgradable that might be better." You gather by holding on a tile, and a ring fills over it (1.0s base). Tools shorten the hold (Flint Tools 0.7s, Bronze Tools 0.4s) and ranks raise the yield. Learning a resource takes 10 harvests.
- Bug: the bottom-bar tabs shared the harvest click cooldown. UI clicks are never throttled.

## 2026-09-30: Job titles for Kith
- Jon: "Rename our workers to their appropriate jobs." Each working Kith now shows a job title: Woodcutter, Quarrier, Knapper, Forager, Thatcher, Reaper, Digger, Fisher, Collier, Roper, Potter, Miller or Hauler. The titles appear in tooltips, the building panel and the top bar job counts. "Kith" stays the people's name. The list is in 07-glossary.md.

## 2026-09-30: Architecture plan (Jon's question)
- Jon asked, thinking as a DV hardware engineer, whether to refactor into compartmentalized subsystems. Yes. 15-architecture.md defines 13 blocks with interfaces: Data, World, Economy, Research, Buildings, Kith, Pathing, Fog, Bonuses, Story, Sim, UI and Save/Profile.
- Rules: commands go down and events come up as signals, blocks never touch each other's variables, and faction names stay in data files.
- Testbench: a unit fixture per block, interface assertions, a signal monitor, the bot as the system-level test, and CI failing on any printed error.
- Refactor: 9 small steps, each its own PR. Step 0 records a golden snapshot (the bot's win time and a state hash on 3 seeds), and every later step must reproduce it exactly.
- Starts after the in-flight branch lands.

## 2026-09-30: Haulers need roads; window resize bug
- Jon: researching Roads and Haulers made haulers start working on their own, and he thinks hauling should require a road. Default: a hauler serves a building only if a road connects it to the Hearth or a Storehouse. A building with no link shows "Needs road". Written up in 14-hands-to-haulers.md.
- Bug: the game window seems to resize at random. The likely cause is the top or bottom bar wrapping as its text changes, which changes the map's fit scale. Fixed by giving the bars stable sizes.

## 2026-09-30: Fiber comes from Reeds
- Jon: "fiber might need its own resource. fold that in so its canonical." Fiber used to come from plain grass, the ground under everything, so it felt sourceless.
- **Reeds** are a new map resource. Reed beds grow in clusters on grass beside water. A Kith learns them by hand like any other resource, and the Thatcher in a Gatherer's Hut cuts them. Bare grass yields no fiber. The Twine Post stays the consumer.
- Map generation always places reeds within reach of the Hearth. A placeholder sprite is used until mockups/sprites/reeds.svg lands.
- Updated: 07-glossary.md, 08-first-playable.md, 11-conventions.md and 14-hands-to-haulers.md.

## 2026-09-30: Reeds become Flax
- Jon: "flax is better or something that isnt water specific." Reeds are renamed **Flax**, and the water requirement is dropped. Wild flax grows in clustered patches on open grassland, and map generation places it like berries. A flax patch is always within reach of the Hearth.
- Everything else stands: the Thatcher cuts flax for fiber, bare grass gives none, and the Twine Post is still the consumer. The sprite is mockups/sprites/flax.svg, replacing reeds.svg.

## 2026-09-30: Hands to Haulers as built, and the pacing retune
- Built on the `hands-to-haulers` branch from 14-hands-to-haulers.md: teach by doing (10 harvests), hut trips (a bundle of 3 harvests, up to 3 queued, shown as pips), automation after Paths & Haulers, rushing (a click finishes a working building's cycle, then a 5s cooldown), and hold to harvest.
- **Yield** is base x tool x rank. Flint Tools shorten the hold (1s to 0.7s) rather than multiplying yield, and the Stone Axe is x3 Wood.
- **Ranks II and III** are on nine techs, and each costs 2.5x the rank before:
  - Gathering techs add +1 to their item's base per rank: Foraging (Berries), Knapping (Flint), Masonry (Stone), Stone Axe (Wood), Farming (Grain), Ochre (Clay).
  - Workshop techs add +25% Speed at their workshop per rank: Cordage (Twine Post), Fire (Charcoal Pit), Pottery (Kiln).
  - 14 said later ranks would be cheaper. They cost more, so a rank is a choice, not a default.
- **Tech costs scale by tier.** Each tech's total cost sits in its tier's band: I 10–20, II 25–60, III 80–150, IV and V 200–400, Bronze Dawn 500–700. Made goods are only charged a tier or more after the tech that makes them. The full table is in 09-tech-tree.md.
- **Haulers need roads**, as built:
  - A building is linked when it touches a road whose network touches the Hearth or a Storehouse, or when it stands right beside one of them.
  - Haulers wait at a depot and walk that depot's roads only. An unlinked building shows "Needs road" and works as it did before Haulers.
  - Haulers favour stopped buildings (starved or full) at a third of the distance, so far huts aren't starved.
- **Roads cost 2 Wood**, not 1 Stone: a timber trackway. They can go through Forest, felling the trees. A pass through Rocks still costs 3 Stone.
  - Once roads were mandatory, they were eating the Stone every tier needs. And a hut in a forest clearing could never be linked.
- Other tuning:
  - Haulers carry 10, and 20 with Carrying Poles.
  - The Kiln and the Charcoal Pit make 2 per cycle.
  - Bronze Dawn costs 80 Brick, 60 Flour, 80 Rope, 100 Stone, 100 Charcoal and 160 Wood.
  - Every map now puts a 3-tile flax patch, a 3-tile berry patch and a 3-tile rock outcrop near the Hearth.
- **Pacing:** the bot lays roads to every hut and workshop. It wins on maps 1 to 8 in 13.6 to 18.2 simulated minutes, about 15.5 on average. Maps 1 and 5 are the slow ones: map 1 is short of stone, and map 5's clay is far off.
- **Not yet checked:** a human playtest of the feel.

## 2026-09-30: architecture refactor, steps 0 to 6
- **Every step is its own PR and must reproduce the golden snapshot** (win times 1053 s, 894 s and 857 s, same state hashes). Steps 0 to 6 all did, and were merged once CI was green.
- **Blocks are reached directly** (`state.tech_tree`, `state.town`, `state.people`, `state.story`) instead of through new GameState methods, because gdlint caps a class at 40 public methods. GameState keeps property pass-throughs for old callers until step 8.
- **Cross-block side effects stay in GameState**, in their old order (for example what happens when a tech completes, or when a building is torn down). They move only when a signal can carry them without changing event order.
- **Faction words moved to data.** The "eaten by" source, the leaving message and the tool-wear source are constants in `data/`, so block logic has no faction words.
- **Kith job titles moved** from the Workers module into the Kith block, since their inputs (what each Kith has learned, the buildings) live there.
- **Story is a listener.** It records story ids from signals (`tech_researched`, `learned`, `trip_started`, `shard_found`) and never calls another block. Blocks never call it.
- **Open for step 8:** the work cycle (`_tick_building` and friends) still lives in GameState because Bonuses, Hands, Roads and Workers take the whole GameState as an argument.

## 2026-09-30: architecture refactor, steps 7 and 8
- **Signals.** Research, Buildings and Kith emit signals (`tech_researched`, `built`, `demolished`, `born`, `left`, `learned`, `trip_started`, `announce`). `Sim._init` wires them in one place, with method references so nothing leaks. A small monitor in the tests asserts which signals fired.
- **Save.** A versioned run save and a separate profile save exist as plumbing only. The profile holds the story ids in order (the future Chronicle) and the items learned, nothing else. Dictionary order is kept in saves on purpose, because road networks and hauler picks depend on it.
- **Sim.** GameState was renamed `Sim` and reduced to ten commands. The work cycle moved to `work.gd`.
- **Golden.** The bot still wins at 1053 s, 894 s and 857 s on maps 1 to 3, with identical state hashes, after every step.

## 2026-09-30: look and scale approved
- **Jon approved mockups/look-and-scale.md** ("Apply it"): 48 px tiles, a 2x2 Hearth, Kith at 0.7 tile, a 1016x676 map viewport, fog without ghost icons, a warm cocoa and cream UI palette with four accents, a small ghost Demolish button and a Kith-orange Tech tree button.
- **Queue:** third PR, after the newcomer starvation fix (PR 1) and the UI/UX list (PR 2). Smarter maps run in parallel and rebase after PR 1.

## 2026-09-30: Look and scale approved
Jon approved mockups/look-and-scale.md after the newcomer playtest: 48 px tiles, a 2×2 Hearth, a bigger map viewport, warm cocoa and cream UI, and four accents (Kith orange, gold, moss, alert red). Fog shows no ghost icons. Design system tokens updated the same day.

## 2026-09-30: newcomer fixes, playtests 1 to 3 (PRs 15, 17, 18, 19)
- **Food warning and a steady top bar (PR 15).** The food warning fires 60 s before stock runs out (cleared at 120 s), a goal teaches berries, and the top bar has a fixed height with named chips so the map never moves.
- **A hut works one resource (PR 17).** Each Gatherer's Hut has a focus, preset to the truly nearest resource (food wins ties while food is short), with one click to change it. Why: a hut beside berries used to gather mostly wood. The range highlight, hover text and trip line show only the focus.
- **Growth needs steady food (PR 17, PR 19).** A new Kith needs stock of at least 2 x Kith plus a reserve, and food income over the last 30 s at least equal to what everyone eats. Hand-gather bursts do not count as income. Why: the Kith used to grow to the housing cap on the starting berries and then starve.
- **Click to send (PR 19).** A hut with no road only works when clicked. The goals, hut card and low-food toast now say so, and a pulsing "click" badge shows on a hut that is waiting. No free first trip was needed: both newcomer bots (one follows the goal text, one clicks only one of two huts) keep every Kith and never hit zero food on maps 1, 4 and 8. The margin for a player who clicks once and stops entirely is thin, so the playtester's rerun is the real check.
- **Road goal.** It needs Paths & Haulers researched and a road that really links a worker building to a depot. A building beside the Hearth no longer counts.
- **Haulers.** Idle haulers spread over every depot with road-linked buildings, because workshops around a Storehouse were never served (map 1 never won).
- **Golden re-pins** (separate commits): 743, 900, 817 s after PR 17, then 783, 992, 1005 s after PR 19. Bot pacing stays 13.0 to 18.4 min on maps 1 to 8.
- **UI/UX defaults (PRs 16 and 18).**
  - Build cards say what is missing in plain text ("Need 4 Wood", "Discover Gatherer's Hut") with sprite pips, and story cards stay hidden until revealed.
  - Building details live only in the docked Info panel, with Collect, Pause and Demolish pinned under its scroll area so a tall card can't hide them.
  - One verb, "Discover". "Hearth" replaces "camp" in player text.
  - Toasts stack, and a message log keeps them (L).
  - The research board opens on "Next steps" with a "Whole board" toggle, and opens whole once 8 or more techs are discovered. Hover lights one hop.
  - Skill toasts read "learned to gather flint".
- **Open:** idle Kith stack on the Hearth and hut workers vanish inside the hut (partly addressed by the Kith drawn beside their hut); the new look PR covers the rest.


## 2026-10-01: New look applied (branch `look`, base 92f711b)
- **Scale.** Tiles are 48 px. The Hearth is drawn 2x2 from hearth.svg at 96 px but keeps its one-tile sim footprint, so rules, balance and the golden (783, 992, 1005 s) are untouched. Kith are drawn at 1.5x the old sprite (about 0.7 tile tall). Fog draws flat warm land with a faint hatch, a one-tile soft edge and no ghost icons or diamond.
- **Map view.** At 48 px the 36x22 world is larger than the window, so the map now scrolls: arrow keys or WASD, middle-drag, mouse wheel zoom (32, 48 or 64 px, default 48), Home centres on the Hearth. Map text, pills and badges stay a constant screen size.
- **Palette.** Cocoa bars #3b2a24, panels #4a372e, cards #6a4c3b, cream text #f6ead7. Four accents: Kith orange #e76f51 (Tech tree, selected tabs, speed), gold #ffd166 (current goal, hover, ranges), moss #7fb069 (done, good), alert red #d64550 (warnings, Demolish while active). Grass #9bb85c, forest #3f7d3a, fog #5b5046. Radius 8, 2 px dark outlines.
- **Buttons.** Tech tree is the one filled button (Kith orange). Demolish is a small 40 px ghost icon at the far right of the build bar (new demolish_tool.svg) and turns red only while active.
- **Text.** Minimum 14 px everywhere in the HUD, and a layout-pass check enforces it. Resource chips show icon, count and rate with the name in the tooltip. Locked cards show only their reason.
- **Defaults taken where the spec was silent or inconsistent.**
  - The HUD bars are 113 px (top, reserved for the Kith block's three note lines at 14 px) and 108 px (bottom), not 52 and 72, because 14 px text and 13 goods do not fit in less. The map view is therefore about 1016x579, not 1016x676. The alert pills became 16 px red badges inside each tile, so they can never overlap.
  - "Kith at 0.7 tile" was read as the figure height, with a 1.5x sprite.
  - The mockup's "head bigger than body" is not in the SVG, so Kith keep their current proportions.
  - Camera, zoom and pan were added because the spec's tile size needs them. A one-line hint toast explains the keys.
  - The Hearth hover target and build ring use the 2x2 drawing, the sim still sees one tile.
- **Tests.** Play and layout passes updated only for intended geometry (scrolling view, view size, min text). Windows 1280x800, 1600x800 and 1100x700 all fit.

## 2026-10-02: playtests 4 and 5, smarter maps (PRs 20, 21, 22)
- **Famine fallback (PRs 20 and 21).** Idle Kith, and Kith whose hut only waits for a click, forage berries near the Hearth on their own when food would run out within 200 s (never in the first 120 s unless the warning is up; stops at 300 s of food). They walk up to 16 tiles. It keeps them fed, not growing: foraged and hand-gathered food never count as income. The click-once newcomer now never drops below the starting 10 berries on maps 1, 4 and 8, also with far berries. Jon's card on idle foraging was answered by building the recommended option.
- **Births need steady food.** The buildings' food must cover eating for a 35 s hold counted over a 30 s window, counted up while covered and down while not. One trip is never enough. The growth note says the fix: "research Paths & Haulers and link huts by road", then "a hut on a road feeds the Hearth on its own".
- **Warning.** It fires at 2 minutes of food left. Only the Food box ring flashes, and its words stay readable (4.5:1).
- **Click bubbles.** Food huts hide the bubble while food is comfortable. Other huts keep it, because before haulers only a click brings their goods.
- **Status pills** are placed in rows below, above and sideways and never overlap a pill, badge or building. With no room, the building draws a "!" and the alert stays on its card.
- **Goals panel** shows the current goal and the next one, with finished ones as a header count.
- **Smarter maps (PR 22).** A height map tilted toward one of eight directions, a river edge to edge from high to low (1 wide, then 2, sometimes a tributary or fork), a ridge of rock with gaps, wetness from the river, forest on wet ground, grain on low mid-wet land, berries at forest edges, flax on open grass, clay on the inside of bends and gravel on the outside. The Hearth sits on dry lowland near the river, with a floodplain for the Water Wheel. Maps are rerolled on a fixed seed sequence until fair, including at least 7 Rock and 8 Grain within 12 tiles. Pacing: maps 1 to 8 in 12.9 to 15.1 min, all 40 test seeds win in 12.4 to 17.3 min. Golden: 872, 854, 771 s.
- **Open question for Jon:** a player who builds Twine Posts before any hut can put every Kith in a job, so a hut stays unstaffed and growth stalls with no food income. The famine fallback and growth note still point at the fix. Say if a free Kith should always be kept for the first hut.


## 2026-10-02: playtest 6 polish (branch `polish-6`, base d7eec03)
- **Goals count.** The header was showing the index of the first undone goal, so skipping one early goal hid later progress ("Goals 1/22" after a hut, Dwelling, Pit and Post). It now counts every done goal in any order. The panel still points at the first goal not done.
- **Opening toasts.** One toast (the welcome line plus the camera keys) instead of two, and the toast stack now grows up from the bottom of the map view, so it no longer hides the forest at the top of the lit area.
- **Growth note.** The top bar's food note ("Needs steady food to grow...") waits until a hut and a Dwelling stand. Starving and "No room" show as before. The bar keeps its reserved three-line height. The building cards and the Kith tooltip are unchanged.
- **Build cards.** A locked card's reason starts beside the sprite (it was under it) and wraps to two lines at most, or shows just the tech name. The missing-items line is plain: "Need 10 Wood" or "Need Wood, Stone", then "Need 3 items"; no "+1" codes. The layout pass checks that card text never overlaps other text or the sprite.
- **Demolish** has a "Demolish" label next to the hammer and a tooltip: "Demolish: click a building to remove it (X). Refunds half."
- **Info panel.** An empty grass tile says it can be built on and lists what can be gathered within 3 tiles. The blank Hearth in playtest 6 was a capture artifact: the Hearth's blurb is on the docked card above the Info text, and the log only recorded the Info label. The layout pass already checks the blurb shows once.
- **Click bubble.** At 5:40 the famine fallback was on (food under 200 s, held until 300 s) and the berry hut's own worker was the forager, yet the bubble asked for a click because only the "comfortable food" case hid it. A food hut now also hides the bubble while its worker is foraging. Wood and stone huts still ask, since their goods only come by click. The pill sits 12 px above the hut, clear of the roof and the trip dots.
- **Golden** unchanged (872, 854, 771 s). No rules, balance or pacing changed.

## 2026-10-02: Bronze Dawn stage 1 built (branch `bronze-1`, base d7eec03 then eb4eaab)
Stage 1 of 2: the map grows, ore, mines, smelting, the first Bronze. Stage 2 (carts, tool wear, Bridge building, Trading Post, Watchtower, the era ending) is not built. Every default below was picked by Claude; tell me to change any.
- **Golden.** Stone age unchanged: 872, 854, 771 s with the same hashes (05d09dff01bf, dffbc0f5cfb6, f402714cca38). The growth waits one tick after Bronze Dawn, so the win-moment state is the stone age's last, and the hash lists a later era's goods only once there is some. A second golden (`tests/golden_bronze.json`) holds the game at the first Bronze on seeds 1 to 3: 1416, 1455 and 1560 s.
- **Pacing.** Bronze Dawn to first Bronze on maps 1 to 8: 9.1, 10.0, 13.1, 8.7, 10.1, 11.4, 8.9, 9.3 min (target about 8 to 12). Map 3 is the weak map (little stone, clay and charcoal) and is a minute over. Stone-age pacing on all 8 maps is still 12.9 to 15.1 min.
- **Growth.** The map doubles on the tick after Bronze Dawn is researched. The new strip is as wide and as tall as the stone map, made from the map's seed, with 14% forest and 5% rock. It starts under fog and the fog's size grows with it. Nothing is saved for it: a saved game regrows the same land from the state. The banner is a 14 s toast, with no win screen.
- **Ore.** Copper Hills: at least 14 tiles in 5 blobs, at least 8 of them within 10 columns of the west edge. Tin Stream: exactly 3 tiles in the north-east third of the strip (the last third across, the top third down). Fairness: at most 3 river tiles between the Hearth and the strip, 12 reroll tries on a fixed seed sequence. Worst case over 12 seeds is 1 crossing. Tin ends up 36 to 55 tiles from the Hearth.
- **Hand mining.** After Prospecting, a click on an ore tile takes 3 s for Copper Ore and 4 s for Tin (tools make it faster). Huts cannot gather ore and the Kith are not taught it (mine-only goods).
- **Mine.** On a Copper Hills or Tin Stream tile, two Kith (a worker and a mate), digs 2 ore per 5 s without walking, cost 80 Wood and 30 Stone. A mine with one Kith does not work.
- **Smelter.** 2 Copper Ore + 1 Charcoal -> 1 Copper in 5 s, cost 30 Stone and 40 Brick. **Crucible.** 3 Copper + 1 Tin -> 1 Bronze in 6 s, cost 50 Brick and 30 Stone. A bronze per cycle is a placeholder.
- **Tech effects.** Tally Sticks take 10% off tech costs only (at least 1 of an item, never fewer ranks) and the log shows counts. Plough: fields yield +50%. Kilns II: Brick x2 per firing, as a side tech. Costs were raised until the first Bronze took about 10 minutes, because a stone-age town has 54 to 64 Kith at the dawn: Prospecting 150 Wood, 190 Flint, 90 Rope; Tally Sticks 280 Wood, 110 Rope, 110 Clay; Plough 300 Wood, 260 Grain, 40 Clay; Mining 500 Wood, 40 Stone, 190 Rope; Smelting 170 Brick, 280 Charcoal, 60 Clay; Kilns II 200 Brick, 230 Clay, 200 Charcoal; Alloying 200 Brick, 260 Charcoal, 65 Copper.
- **Gated techs.** The Wheel, Causeways, Markets, Sky Watch, Bronze Tools, Granaries, Bronze Ploughshare, Star Charts and The Falling Star have parents, a card and a cost, but say "Needs the next update" and cannot be bought. Their costs are placeholders (for example Bronze Tools 20 Bronze, 20 Copper, 80 Charcoal; the gate keeps 60 Bronze, 100 Brick, 60 Flour, 40 Rope).
- **Tech panel.** One tab per era; the second is locked until Bronze Dawn and opens on its own when the land grows. The era-2 board has 6 columns including the gate.
- **Build bar.** The new buildings sit under a Metal tab.
- **Top bar.** Four new goods (Copper Ore, Tin, Copper, Bronze) need a third row of chips, one line each, because two rows would be wider than a 1280 px window. The bar is 130 px tall, up from 113, so the map view loses 17 px at 1280x800.
- **Art.** Sprites for the Mine, Smelter, Crucible, Copper Hills, Tin Stream and (for stage 2) Cart Shed, Bridge, Trading Post and the Wanderer were copied from the mockups at the new 48 px size. Placeholders to be redrawn: the ore tiles have vector fallbacks and the Tally Sticks icon is drawn in code.
- **Bot.** The era-2 test bot builds roads out to the fog's edge toward the copper, then the tin, bridges a river that blocks it, builds one Mine on the nearest Copper Hills, and puts the Smelter and Crucible by the Hearth. Maps with a river between the Hearth and the ore (seeds 1 and 42) need a bridge.
- **Open questions for Jon.** (1) Tin is 36 to 55 tiles away: is that too far, or exactly the puzzle? (2) Should hand mining skip the haul puzzle (it works as soon as the tile is seen)? (3) Map 3 sits at 13 min: raise its stone, or accept? (4) One Mine is enough for the bot; should a second Mine be needed for a decent pace?

## 2026-10-02: era 2 fairness and dawn onboarding (branch `era2-onboard`, base d5986bf)
From playtest 7 (the bot never found copper on the real random map, and a newcomer found the dawn confusing). Every default below was picked by Claude; tell me to change any.
- **How the real game picks its map.** `main.gd` calls `state.generate(randi())`: a random 32-bit seed per run. The east strip is made from that seed and rerolled on a fixed sequence of 12 attempts, the same for any seed. Stage 1 checked only seeds 1 to 40 and only that the stone map's east edge was reachable with at most 3 river tiles.
- **Root cause of the stall: the bot, not the map.** Seed 12 (a river bend with gravel banks, then a ridge of rocks) reproduces it: the bot laid road at the fog's edge nearest the copper, bridged on gravel (a bridge between two banks no road can go on joins nothing), and never laid road on rocks, so it stopped. A road can follow a way on every map tested. Before the fix, 1 of 33 extra seeds (9 to 40 and 87) never reached Bronze (seed 12); after, 0 of 33, with the first Bronze 7.5 to 13.2 min after the dawn (seed 11 is 17.1 min: a clay-poor map, resource-bound, not stuck). Seeds 1 to 8 are unchanged.
- **Fairness is now checked in the generator.** `MapEast.road_ways` prices the cheapest road from the Hearth to each ore over grass, forest, rocks (a pass, 3 Stone) and river (a bridge), never over gravel or clay. A strip whose ore needs more than 3 bridges, or has no road at all, is rerolled. On 700 seeds (1 to 300, and 400 random 32-bit ones) none failed, so no map moved and `tests/golden.json` and `tests/golden_bronze.json` are unchanged. Worst case: 3 bridges and 8 rock passes (24 Stone). `tests/tools/east_scan.gd` scans any number of seeds (`-- first count max_rivers [all] [random]`); the test suite runs 50 seeds and 8 large ones.
- **Bot.** After 90 s with no road nearer the ore, the era-2 bot plans a road over the whole map (the same prices) and lays its next three tiles each decision. Seeds that never stall play as before. Seed 12 is in the pacing test.
- **Dawn goals.** Nine short goals take over the Goals panel at Bronze Dawn, in any order, counter "Dawn goals n/9": discover Prospecting, find copper in the east, lay a road to the copper hills, Mining and a Mine, discover Smelting, build a Smelter, find tin, Alloying and a Crucible, make the first Bronze. The golden hash lists only the stone age's goals, so the pins stay.
- **Dawn.** One banner says it all (the discovery toast and the land toast are gone). A "Look east: copper >" button sits at the east edge of the map view until any copper is out of the fog, then points at the tin; one press puts the way in view (halfway between the end of the road and the ore), and nothing ever moves the camera by force. Home still returns to the Hearth.
- **Wording.** Locked era-2 tech cards read "Opens in a later age" (the constant only, so stage 2 can un-gate them without a merge fight).
- **Leftovers from PR 24.** A locked build card says "Discover it first" when its tech has the card's own name, the card in the side panel no longer has a second Demolish button (the bottom bar's is the tool), and the Goals list keeps both lines while an Info card is open, so its height is steady (the layout pass asserts it).
- **Open questions for Jon.** (1) Is 8 rock passes on the way to the ore too many for a newcomer, or is it a fine puzzle (a ridge to cut through)? (2) Should the road tool say so when a bridge's banks cannot take a road?

## 2026-10-02: Bronze Dawn stage 2 built (branch `bronze-2`, base d5986bf)
Stage 2 of 2: the nine gated techs now do something, the gate is gone, and the era ends at The Falling Star. Every default below was picked by Claude; tell me to change any.
- **Golden.** Stone age unchanged (872, 854, 771 s, same hashes). `tests/golden_bronze.json` did not move: the bot does not touch a cart, a causeway or a bronze tool before its first Bronze, and the hash hides era-2 goods while they are zero, so there was no re-pin commit. The pacing test now checks it at the moment the first Bronze is made.
- **Pacing (bot, maps 1 to 8).** First Bronze after Bronze Dawn: 9.1, 10.0, 13.1, 8.7, 10.1, 11.4, 8.9, 9.3 min (mean 10.1; seven of eight in 8 to 12, map 3 again the weak map). The Falling Star after the first Bronze: 10.7, 13.2, 18.1, 10.5, 10.9, 14.1, 9.2, 8.8 min (mean 12.0; target about 10 to 15, map 3 over). Bronze Dawn to the star is about 22 min on average, and a whole run about 36 min. The first pass of the bot took 20 to 26 min on some maps because it ran on one Smelter and starved the Crucible of Copper; it now builds three Smelters and two Crucibles after the first Bronze, as a player would. The nine techs' costs are the stage-1 numbers, unchanged.
- **Carts (The Wheel, Cart Shed).** A Cart Shed turns two haulers into carts (a second shed, two more). A cart carries twice a hauler's load (Carrying Poles count) and moves only on roads and stone bridges: off-road it waits where it stands, and it will not cross a wooden bridge. Cost 60 Wood, 20 Rope, 6 Copper.
- **Causeways and the Stone Bridge.** After Causeways a road costs 1 Stone and 1 Brick and walking on it is 5 times as fast. The Stone Bridge (6 Stone, 4 Brick a tile) is the river crossing that carts can use; the Wooden Bridge stays the cheap one. Passes through rocks cost the same as before. Roads turn stone-grey on the map.
- **Bronze Tools and wear.** Craft one from 1 Bronze and 2 Wood. Workers take a Bronze Tool before a Flint Tool: +100% speed against flint's +50%. A tool wears out after 200 jobs, with the message "A Bronze Tool wore out". The panel says how many uses are left, or what to craft. Old saves read as flint.
- **Bronze Ploughshare.** Fields give another +50% on top of the Plough. **Granaries.** One extra home for every 20 food in the stockpile, at most 30; it counts any food, flour included.
- **Trading Post (Markets).** Swaps 3 of one good for 1 of another in 10 s. The building panel has two lines, "Gives:" and "Gets:", and a click moves each on to the next good the stockpile has ever held; an unset post says so and does nothing. Haulers feed and empty it like a workshop. Cost 60 Wood, 20 Stone, 20 Brick.
- **Watchtower (Sky Watch).** Sees 9 tiles (the Hearth sees 6) and is where the Kith watch the sky: one sighting in the event log every 150 s, with lines in three moods (hopeful, uneasy, afraid) that follow how many of the era's 16 techs are learned. Cost 40 Stone, 30 Brick, 6 Copper. Sky Watch itself says once that the light is named the Wanderer.
- **Star Charts and the sky window.** From Sky Watch a small night-sky window appears in the side panel, under Goals: the Wanderer as a pale-cyan light that grows as the techs are learned. Star Charts draws a dotted path across it and the line under it says how far it has come ("a bright light, 40% of the way"). The top bar did not grow.
- **The Falling Star.** A card over a dimmed, paused map: "THE FALLING STAR. The Wanderer grows huge and bright over Solace, and the whole sky holds its breath. It is not a star. It is coming down." One button, "Keep building", resumes; the game goes on. The story id `star_falling` goes into the profile save (`user://profile.json`, written by `Profile.note_run`), never the run save. The Shard Cairn glows brighter as the Wanderer comes nearer (flavor only).
- **Top bar.** Bronze Tools became a fourth chip in the third row; chips are 114 px so the bar still fits 1280 px.
- **Tests.** `tests/stage2_tests.gd` (carts, causeways, bridge, tools and wear, ploughshare, granaries, Trading Post, picker) and `tests/sky_tests.gd` (sky, tower, charts, ending, profile, card). The `-- stage2` switch runs just those two.
- **Placeholders left.** The sky window draws the Wanderer as circles (the Wanderer sprite is not used yet); the Trading Post's picker is two text buttons, not icons; era-2 sprites are the mockups copied at 48 px; no sound anywhere; the era card has no art. The Granary sprite exists but there is no Granary building (the tech is a bonus).
- **Open questions for Jon.** (1) Should a cart with no road wait (now) or walk slowly off-road? (2) Is the Bronze Tool's +100% too strong next to flint's +50%, given a tool lasts 200 jobs? (3) Should a Trading Post keep its choice when the good runs out, or pause? (4) Is about 12 minutes from the first Bronze to the star right, or should the era run to the full 20? (5) Should the card wait for a keypress, or fade on its own?

## 2026-10-02: stone-age stall on random seeds (PR #29)
- **Report.** On 2 of 4 huge random seeds (4022250974, 3735928559) the stone-age pacing bot never reached Bronze Dawn: it researched Water Wheel and Grindstone but placed neither, so flour stayed at 0.
- **Root cause: the bot, not the map.** Both maps have land-reachable bank sites with room round them, so MapGen's wheel-room rule holds and no generator or placement rule changed. The bot's own hut-linking roads and dwellings filled the bank before the Water Wheel was researched. A player can place early or demolish a road.
- **Fix, in tests/autoplay.gd only.** With no site and nothing to explore, the bot takes any free bank tile, then tears down a bank road (not on a Hearth lane) for the wheel. A Grindstone with no powered spot tears down a road in range. Seeds 1 to 3 never reach it, so both goldens are unchanged.
- **Scan.** 180 random 32-bit seeds, 30 min limit: 4 stalls before (2.2%), 1 after (0.6%). Win times unchanged (750 to 1163 s, median 882 s).
- **Left over.** Seed 315413782: every Kith is in a building, none is free to haul, food income is 0 and Kith stop at 16. A bot overbuild; a human could pause huts. Not fixed.
- **Open question for Jon.** Should the real game warn or help when the Water Wheel is unlocked but the bank is full of roads?


## 2026-10-02: era 2 polish (playtest 8) (PR #30)
- A fresh-eyes bot played era 2 to the Falling Star and found four UI problems, fixed together as UI only (both goldens unchanged).
- The Falling Star card is now centred over the map view with only the map dimmed, never over the bars or side panel; the game stays paused behind it.
- The third top-bar row (Ore, Tin, Copper, Bronze, Tools): each chip shows the 24 px sprite, a short 14 px name and the count, with 6 px of room from the bar's edge. The per-second rate lives in the tooltip and hover panel; the bar is still 130 px and fits at 1280.
- The Bronze Dawn banner is two short sentences, keeping the Look east pointer.
- After the star falls, the Goals panel adds "The star is coming down. Keep building while you wait." under "All goals done." (counters unchanged, Dawn goals 9/9).
- New layout-pass checks cover the card's centring and clearance, the third row's names, sprite size and tooltip, and chip padding.

## 2026-10-03: design system moved into the repo
- Claude and Codex both edit it in `docs/design-system/` via PRs; the project-folder copy is retired. Decided by Jon.
- Sprites live only in `art/sprites/`. Codex owns art; Claude owns code and mechanics pages (06/09/10/11/14/15).

## 2026-10-03: Era 3 Starfall designed (PR #35)
- Claude wrote [16-starfall.md](16-starfall.md) after Jon agreed the starred picks. Design only, nothing built.
- Glyphs are the one new mechanic: scribes at a Glyph Wall copy glyphs automatically, the player only guesses meanings, and the game confirms 3 at a time. This keeps Jon's "no click chores" feedback.
- Expeditions are set and forget (pick a fog target and a pack, parties walk on roads, haulers resupply, standing orders), so roads stay the star.
- Shard Cairn built before the landing means guests and open trade; no cairn means wary outsiders and closed trade.
- Lumen choice is Jon's mix: a hidden trust meter moved by buildings and trade, plus three big choice moments. It leans toward a reset (Time loop, Exodus or Cataclysm) and is stored as `lumen_lean` in the profile save.
- Era runs about 20 minutes and ends on decoding the Bloom glyph and the first Bloom sign.

## 2026-10-03: top bar chips match across eras (PR #34)
- Claude, from Jon's playtest feedback: the third row (Ore, Tin, Copper, Bronze, Tools) did not match the others. It used a one-line chip (sprite, short name, count) with no rate, a 10 px gap and a 30 px row, where the stone-age rows use a fixed 80 px chip (sprite, count, rate under it) with a 3 px gap and 42 px rows.
- Every chip is now the same widget in every era: 24 px sprite, 18 px count, 14 px rate, 2 px padding, the same tooltip with the rate and the same hover panel. The name stays in the tooltip, as for the stone-age goods. The third row's chips sit under the first row's columns.
- The three rows are 38 px each (was 42, 42 and 30; a chip keeps 1 px above and below and the rate sits 2 px closer), so all three fit in the 130 px bar and are evenly spaced; it still fits at 1280 and 1100 wide.
- The era-2 sprites are wired and drawn at the same size, but they are thinner-outlined and Copper and Bronze share one shape. Requested a redraw from Codex in `docs/art/requests.md`; no code change is needed when it lands.
- Layout-pass checks now compare each era-2 chip with the first row's on size, sprite size, font sizes, padding, build, tooltip and column, and check the rows are evenly spaced.
