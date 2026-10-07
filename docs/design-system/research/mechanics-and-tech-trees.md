# Research: tech trees and mechanics in comparable games

Status: **research, not decisions** (2026-09-30). Nothing here is canon until it lands in decision-log.md. Each pattern ends with where it would touch Solace.

Sources: Claude's knowledge of the games below, checked against Solace's design files as of 2026-09-30. Numbers from other games are approximate.

## Top recommendations
1. **Show the multiplier math, and make every bonus felt.** One line in the building panel: "Base 10/min x Tools 1.5 x Standing Stone 1.15 = 17/min". Replace bonuses under about +25% with a doubling or a new ability. (Factorio, Anno, Sid Meier's doubling rule.) Touches 09-tech-tree.md (Ochre, Megaliths) and the tools ladder in decision-log.md.
2. **Eurekas: doing a thing discounts or reveals a tech.** Star Lore already works this way. Extend it: build 3 Fields and Irrigation costs half. (Civ VI, Factorio 2.0 trigger techs, Satisfactory's MAM.) Touches 09-tech-tree.md.
3. **Pay for research with what the factory makes.** Each era's costs should use that era's own goods, so the tree and the production chains are one graph. (Factorio science packs, Dyson Sphere Program matrices.) Touches 10-bronze-dawn.md costs.
4. **Research board: focus view, a goal path and a queue.** Click a far tech to set it as a goal, and its whole missing chain lights and queues. (Civ VI, Factorio.) Touches mockups/tech-tree-v3.md, board B.
5. **One new terrain barrier per era, always signposted.** Locked terrain says which tech crosses it. (Civ, Satisfactory, Anno.) Touches 11-conventions.md #8 and 10-bronze-dawn.md.
6. **Each prestige reset automates the early game you just played.** (Antimatter Dimensions, Kittens Game, Against the Storm.) Touches the prestige table in 06-mechanics.md.

---

## 1. How the trees are structured

### Factorio: the factory pays for its own research
- Research costs science packs, and each pack color is a product of the factory at that tier. Red is simple, blue needs oil. So "can I research this" really asks "have I built that chain".
- Labs consume packs over time. Research is a steady drain on the factory, not a lump payment.
- Factorio 2.0 added **trigger techs**, which unlock by doing something (mining a new ore, crafting an item) rather than paying.
- Late game has **infinite research** (mining productivity and more) as an endless sink.
- **For Solace:** Bronze Dawn's cost (Brick, Flour, Rope, Stone) already follows this. Apply it tier by tier: column 3 techs should cost column 1 and 2 goods (Brick, Rope, Flour), not only Wood and Stone. In Bronze Dawn, tiers 3 to 5 should cost Copper and Bronze. Infinite research is a later, post-era idea.

### Dyson Sphere Program: color-coded research currencies
- Six matrix colors (blue, red, yellow, purple, green, white). Each is made from one tier of production. White needs all the others.
- Players always know which chain they're missing, because the color says so.
- **For Solace:** the five lanes already have hue families. An era's gate could need one "token" good per lane (Stone: Brick, Fiber: Rope, Land: Flour, Hearth: Charcoal, Lore: a new Lore good). Its icons would share the lane's color. The Bronze Dawn gate is close to this now.

### Civilization VI: eras, eurekas, and two parallel trees
- The tech tree runs left to right in era columns, with a second tree (civics) fed by a different currency (culture).
- **Eurekas and inspirations**: doing a related action (meeting a civ, building a quarry) pays about 40% of a tech's cost. Players learn the tree by playing, and it rewards varied play.
- A player can click any far tech, and the game queues the full path to it.
- **For Solace:**
  - Eurekas fit the "design, watch, progress" loop. Examples: build 3 Fields (Irrigation half price), click 5 river tiles by hand (Rafts half price), craft 10 Rope (Paths & Haulers half price). The card shows the hint before it's met: "Eureka: build 3 Fields".
  - The magic tree (06-mechanics.md) should be fed by its own currency, like civics. Shards or a Lumen resource would work. It shouldn't share the tech tree's costs, so the "second tree opens" moment feels like a new axis.

### Satisfactory: milestones, side research by analysis, and found recipes
- The HUB sells **milestones** you pick in any order within a tier. You pay by delivering parts, with a progress bar per part. Tiers open through Space Elevator phases, which are big deliveries.
- The **MAM** is side research: you analyze a strange thing found in the world (a mushroom, a crystal) and a new tree opens.
- **Hard drives** in crash sites unlock **alternate recipes**, a choice of 1 in 3. Exploring pays off in new ways to make things, not just more.
- **For Solace:**
  - The MAM is the Strange Stone and Star Lore pattern exactly. It validates the plan to grow the magic tree from found things.
  - Alternate recipes are a strong fit for fog of war (11-conventions.md #6). A ruin under fog could offer "Brick from Clay + Straw, no Charcoal". It gives exploration a reward that changes chains.
  - Delivery progress bars ("Brick 25/40") make big costs feel like a goal rather than a wall.

### Timberborn: research where you build
- Science points come from an Inventor building. Each building is unlocked from its own button in the build toolbar. There is no separate tree screen for most unlocks.
- **For Solace:** small side techs that only unlock one building could show the unlock inside the bottom bar tab, greyed, with "Unlock: 20 Science" on hover. The main tree keeps the big techs. That helps readability, since players see what's next where they already look. Worth trying on Bronze Dawn side techs only.

### Oxygen Not Included: a warning about flat trees
- ONI has a large tree and several research types (novice, advanced, and later ones), each made at a different station.
- Research types gate well, but the tree screen is wide and flat. Most players plan with the wiki.
- **Avoid:** a tree you must scroll to understand. Keep each era's tree on one screen, as 09-tech-tree.md does now (it fits 1280x800). Add eras as tabs, as 10-bronze-dawn.md plans, not one long map.

### Anno: population tiers instead of a tree
- Anno 1800 has almost no tech tree. Buildings unlock when enough residents reach the next tier, and residents upgrade when their needs are met.
- Chains are shallow but wide, and **ratios** matter (for example, farms per mill). Players memorize ratio charts.
- New regions (the New World) hold resources the home island can't make.
- **For Solace:**
  - Tin being far away (10-bronze-dawn.md) is Anno's New World idea at small scale, and it's good.
  - Show ratios in the building panel: "This Grindstone uses the Grain of 2 Fields." It removes the need for community spreadsheets.
  - A population gate is a possible later-era twist. For example, Iron Age techs could need a count of Kith in Dwellings as well as goods. That links housing (Thatched Roofs, Granaries) to progress.

### Against the Storm: drafts and roguelite meta
- Each settlement draws buildings from a random draft (pick 1 of 2 or 3). Rising pressure over time forces choices. A persistent city between runs holds permanent upgrades.
- **Avoid in the main tree:** random drafts fight Solace's authored, interdependent tree.
- **Use in prestige:** an Exodus run (06-mechanics.md) could draft a few starting blueprints, so each resettlement starts differently.

### Idle and incremental games
- **Antimatter Dimensions** stacks prestige layers (Infinity, Eternity, Reality). Each layer adds a currency, a new upgrade tree, and **autobuyers** that automate the clicking the last layer needed. Challenges are runs with a restriction that pay a permanent reward.
- **Kittens Game** is the closest analogue to Solace: stone age to space, with a science tree, resource caps and several reset layers. Storage caps are its main gate, since a tech can cost more than you can store until you build storage.
- **A Dark Room** and **Universal Paperclips** reveal UI in stages. The game gets bigger by showing new panels, and each phase changes what the player looks at.
- **For Solace:**
  - Prestige should automate the first era. Exodus could start with a Camp, 2 huts and a Twine Post placed, or with the stone age already researched. The early game is never re-clicked at the same pace.
  - The three resets (Exodus, Cataclysm, Time loop) can each be a "challenge" of the AD kind: a restriction that pays a permanent bonus. That fits the refugee choice deciding the layer.
  - Storage caps as a gate: the Storehouse could raise caps, and a cost above the cap would say "needs a Storehouse". This is a cheap way to add interdependence.
  - Revealing UI in stages matches 11-conventions.md. The magic tree tab should not exist in the UI until the ship lands.

---

## 2. Multipliers and tools

Solace now has the tools ladder (flint +50% with wear, Stone Axe x2 Wood, Bronze Tools +100%), plus Ochre +10%, Megaliths +15% in range, Calendar +25%, Irrigation x2, Smoking x2 food, Plough +50% and Bronze Ploughshare +50%.

### Patterns
- **Speed vs productivity (Factorio modules).** Speed gives more per minute from the same inputs rate. Productivity gives more output per input. Keeping them as two named kinds makes stacking easy to read. Solace tools are speed. Calendar and Plough are productivity (yield).
- **Add within a kind, multiply across kinds (common in incrementals).** Two speed bonuses add (+50% and +15% make +65%). Speed times yield multiplies. That keeps numbers from exploding, and it's easy to show.
- **The doubling rule (Sid Meier, via Soren Johnson).** When tuning, change by x2 or /2 first, then settle. Small bonuses (+10%) are rarely felt. Players remember "twice as fast".
- **Show the breakdown (Anno, Factorio, ONI tooltips).** Every rate shows its factors, so a player can see why one hut beats another.
- **Upkeep multipliers (Anno goods, Against the Storm tools).** A bonus that consumes something turns a one-off tech into a running chain. Solace already does this with tool wear, which is a good call.

### For Solace
- Ochre (+10% hut harvest) and Megaliths (+15% in range) are likely unfelt. Options: Ochre marks huts so their workers never idle for tools, or gives x2 on Berries. Megaliths could be +50% in a smaller radius, which makes placement a real puzzle. Tune after a playthrough, as 09-tech-tree.md says.
- Building panel line, as in recommendation 1. Group into Speed (Tools, Standing Stone) and Yield (Calendar, Irrigation, Plough).
- Irrigation is "x2 speed" on river fields and Calendar is "+25% yield", so they read as the same kind but aren't. Label them by kind on the card.

---

## 3. Production chains and interdependence

- **Chain depth grows by about one step per tier (Factorio, Satisfactory).** Solace stone age tops out at Grain to Flour to (Baking) food, which is 2 to 3 steps. Bronze Dawn reaches Ore to Copper to Bronze to Tools, which is 4. That's a good curve. Iron should be about 5 steps.
- **Cross-lane inputs create the web.** The best Solace chains take one input from each of two lanes (Kiln: Clay + Charcoal from Hearth). Keep that rule for new buildings, not only techs.
- **Byproducts (Satisfactory, ONI).** A second output that must go somewhere creates problems to solve. For example, the Smelter makes Slag, which Causeways could use as road fill. Use this sparingly. One byproduct per era is plenty.
- **Shared inputs create tension.** Charcoal feeds the Kiln and the Smelter. Flour is food and a research cost. That competition is where interesting bottlenecks come from, so keep one or two contested goods per era on purpose.
- **Ratio hints** (see Anno) keep this from feeling "janky".

---

## 4. Readability of dependency UIs

| Pattern | Seen in | Solace |
|---|---|---|
| Era columns, time runs left to right | Civ | Have it |
| Only the selected tech's links drawn strongly | Factorio 1.1 focus view | Board B's gold hover chains. Keep other links faint or hidden |
| Click a far tech to queue its whole path | Civ VI | Add. It answers "how do I get there?" |
| Research queue | Factorio, Civ | Add, 3 to 5 slots |
| "What's new" list of ready techs | Factorio, DSP | A small "Ready to research (3)" list beside the board |
| Locked cards show why ("Needs 2 more") | Civ | Have it |
| Unlocks shown as icons on the card | Civ, DSP | Board B has icons. Keep text to a single line |
| One tree screen per era, with tabs | Civ (eras), avoiding ONI | Planned in 10-bronze-dawn.md |
| A map overlay for systems (power, range) | ONI overlays | Water Wheel power and Standing Stone range as a toggleable overlay |

- **Avoid:** crossing lines. The project owner's feedback on the transit map was that lines "bleed/overflow and aren't readable". Every game above that reads well draws few lines at once.

---

## 5. Traversal and expansion gates

- **One new barrier per era (Civ, Satisfactory, Subnautica).** Civ gates ocean tiles behind Sailing and later techs. Satisfactory gates regions behind gear (gas masks, radiation suits). Each era opens terrain that was visible but closed.
- **Always signpost the lock (Civ).** Hovering deep water in Civ says which tech crosses it. The player sees the goal before the tech.
- **Distance as a cost (Factorio, Timberborn, Anno).** Belts, paths and ships make "far" a design problem, not only a wait.
- **For Solace:**
  - Stone age: rivers (Wooden Bridge, Rafts). Rocky ridges (mountain passes).
  - Bronze Dawn: the far tin (carts on roads, Causeways).
  - Later ideas: the sea (boats, and maybe where the ship lands), marsh, and deep forest. Each should be visible from the start and signposted.
  - Hover text on any blocked tile: "River. Crossed by a Wooden Bridge (Paths & Haulers) or Rafts." This extends 11-conventions.md #8, which already says cut-off things point at the bridge.
  - Fog should hide resources but show terrain edges, so players know there's more to find.

---

## 6. Patterns to avoid
- **Unfelt bonuses** (+5% to +15%). See section 2.
- **Beelining with nothing to do.** Civ players often wait on one tech. Side branches and eurekas give the wait something to do.
- **Numbers without new decisions** (idle inflation). Each era needs a new decision: where to put the far mine, which contested good to prioritize. Bigger numbers alone aren't enough.
- **Random drafts in the main tree** (Against the Storm). They're fine in prestige, but not in the authored tree.
- **Big flat trees** (ONI). See section 4.
- **Magic as a lane in the same tree.** Civ VI's second tree shows that a separate currency and screen makes it feel like a new axis.

---

## 7. Niche games: mechanics nobody expects (added 2026-09-30)

the project owner asked for games outside his library, looking for a new mechanic that isn't a genre copy. His library says what lands: automation, plus **deduction mysteries** (Obra Dinn, Roottrees are Dead, Blue Prince, The Operator) and **extraction runs** (Duckov, ZERO Sievert, DREDGE), and he likes it when genres blend (inspiration.md). The best niche ideas below blend automation with one of those.

| Game | The unusual mechanic | Solace idea |
|---|---|---|
| **Chants of Sennaar**, **Heaven's Vault** | You learn an unknown language by guessing what glyphs mean from context. The game confirms a set of guesses only once they're all right. | **Decipher the Lumen** (idea A) |
| **Autonauts** | You teach a bot a job by doing it yourself while it watches, and it repeats the recorded steps forever | **Teach by doing** (idea B) |
| **Cultist Simulator**, **Book of Hours** | Knowledge is a card that fades or has to be kept alive, and research means combining cards | **Stories that fade** (idea C) |
| **Outer Wilds**, **Idle Loops**, **Increlution** | Each loop resets everything except what you know. Knowledge is the only progress | **The Time loop keeps only knowledge** (idea D) |
| **Creeper World**, **Spirit Island** | The enemy is a fluid that spreads and piles up (Creeper). Land that's overloaded cascades its blight into its neighbors (Spirit Island) | **The Bloom as a tide** (idea E) |
| **Cookie Clicker** (the Grandmapocalypse) | A research line looks like a normal upgrade, then quietly turns the cozy game creepy. It's opt-in, and it can be reversed at a price | **Research that turns the world** (idea F) |
| **DREDGE** | Fishing is safe by day. At night the sea turns hostile, and your cargo grid limits what you bring home | **Expeditions** (idea G) |
| **Islanders**, **Dorfromantik** | Points come from what a building sits next to, so placement is the puzzle | Adjacency bonuses. Megaliths could work this way (section 2) |
| **Kynseed** | Your family ages and dies, and children inherit traits | Named Kith families with a trade that passes down |
| **Opus Magnum** | When you finish, histograms compare your solution's cost, speed and footprint | End-of-era report card comparing this run with your past runs |
| **Terra Nil** | A reverse city builder: you heal the land, then remove your own buildings | Exodus leaves the old region healing, and a later run can return to it |
| **Captain of Industry** | Unity, a second currency earned from a happy, well-run colony, pays for special edicts | A Hearth "Kinship" currency for one-off boosts |

### A. Decipher the Lumen (the strongest fit)
- The Kith call the refugees "the Starfallen" until they learn the name "Lumen". That's already canon, and it's a language-learning beat waiting to happen.
- The Lumen magic tree is written in Lumen glyphs. Trade, shards and Lumen visitors show glyphs in context (a glyph over their healer, a glyph on a crate of shards).
- The player guesses a meaning for each glyph. Guesses are confirmed in batches of 3, as in Obra Dinn. A confirmed glyph opens its magic node.
- It's research by deduction instead of by stockpile, which blends the project owner's two favorite kinds of game. How much you trade with the Lumen decides how much context you see, so it feeds the refugee choice that picks the prestige layer.
- Where: 06-mechanics.md (the magic tree), 03-world-lore.md (the Lumen).

### B. Teach by doing
- Instead of placing a hut and getting a generic worker, you gather Wood by hand near a spot a few times. A Kith who watched says "I can do that" and takes over.
- The first automation becomes a story moment (the Kith learn from you), not a menu choice.
- Later, recording works for chains: haul Clay to the Kiln twice, and a hauler learns the route.
- Where: 08-first-playable.md (hands, then huts), and the hauler logic.
- Risk: it can feel slow if you do it more than once or twice. Use it only for each new *kind* of job.

### C. Stories that fade
- Lore techs are stories. A story's bonus holds only while a Kith tells it at the Hearth at night, which uses one worker.
- If there aren't enough storytellers, the oldest story fades and its bonus is lost until it's retold.
- This makes the Lore lane an upkeep system (like tool wear) and ties it to population. It's also a quiet setup for the Time loop, where only stories survive.
- Where: 09-tech-tree.md (Lore lane), 11-conventions.md (an alert when a story fades).

### D. The Time loop keeps only knowledge
- It's the deepest prestige layer in 06-mechanics.md. The Outer Wilds rule: everything resets except what you *know*.
- What carries over: the map (no fog), glyph translations, hidden techs such as Star Lore, and the ship's landing site. There are no resources and no buildings.
- Each loop gets further because the player knows more, not because a number grew. That's the non-idle answer to prestige, and it's very Obra Dinn.

### E. The Bloom as a tide
- The Bloom is a height field that spreads across tiles like Creeper World's creeper. It flows downhill and piles up.
- Tiles that pass a threshold spill into their neighbors all at once (Spirit Island's cascade), so neglect snowballs.
- You push it back with fire, salt or Lumen magic, which gives each faction's tree a job against it.
- Where: 03-world-lore.md (the Bloom), and a later era.

### F. Research that turns the world
- A Lore branch after the ship lands looks like a normal boost, e.g. "Listen to the shards", +50% magic. Each step quietly changes the world: the sky tint, Kith dialogue, and a Bloom spore appearing.
- It's opt-in, the path to the Cataclysm reset, and it matches the tone of "hopeful, then ominous".

### G. Expeditions
- Send a small party into fog or Bloom land. They carry a limited pack grid (DREDGE) and must return before nightfall or the Bloom rises.
- Rewards are things the factory can't make: alternate recipes (section 1, Satisfactory), glyphs (idea A) and Bloom samples.
- This adds a risky "go out and get home" beat, which the project owner's extraction hours say he enjoys, without turning Solace into a shooter.

### Picks
If only one is built, build **A (Decipher the Lumen)**. It's new to the genre, it's canon already, and it uses deduction, which the project owner rates highest after automation. **D** is its natural partner for the Time loop. **B** is the only one that could change the stone age today.
