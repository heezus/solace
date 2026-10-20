# Two roads: what stops a player from refusing the Lumen

Status: **built** (2026-10-20, Jon's "yes go ahead"; designed 2026-10-19). Mechanics and canon page, so Claude owns it and the project owner has the last word. It answers Jon's playtest question "what stops a player from wanting to go against them? It seems implied that you would always want to help", and his pick of "Two roads" from four options.

## The problem
Every gift costs nothing and trust only rises, so the Lumen are free money and the only open question is how fast. The Guard Post lowers trust but buys nothing the player wants, and the era's ending (allies, neighbours, enemies) is a label, not a road.

## The rule
Each of the four gifts has a **Kith twin**: the same kind of help, done the Kith way, which the player can only earn by **refusing the gift**. When a set is read the player picks one road for that gift, once.

| Set | Lumen gift (as now) | Kith twin (new) | What it costs the Kith |
| --- | --- | --- | --- |
| Light | Shardlight: gatherers near a Cairn work 25% faster | **Cairnfire**: the same 25% near a Cairn, from a standing fire | 1 Charcoal a minute per Cairn |
| Body | Lumen Healer: tools last 40% longer, births 20% sooner | **Bonesetter's rule**: the same two effects, a standing rule | 1 Berry a minute |
| Growth | Starfruit: berries near a Cairn yield 50% more | **Orchard**: the same yield near any Dwelling | 40 Wood, once |
| Craft | Shardwork: workshops near a Cairn work 25% faster | **Smith's Rule**: the same 25% for workshops beside a Smelter | 1 Charcoal a minute per Smelter |

- **Accepting** is as today: +6 trust, no cost.
- **Refusing** says so aloud (a short Kith line), costs **4 trust** and unlocks the twin as a building or a standing effect that must be paid for. The strangers answer in their own way: they keep their distance, trade less, and never open the Lumen Market if all four are refused.
- The player may mix roads. The count of refusals sets the era's lean (Data.LEANS): none is allies, some is neighbours, all four is enemies, instead of trust alone. The Guard Post stays a tool for that road.
- The ending card names the road taken and the Warning's last question changes with it.

## Why it holds
- Accepting is cheap and fast; refusing is slower and costlier but self-reliant, and it keeps Cairn-less towns viable. A player who wants to win alone has a real path.
- It reuses the existing bonus switches (`Data.BONUSES`), so most of the work is four buildings or standing effects and the picker card.

## Open questions for the project owner
- Should refusing make the Lumen turn hostile later (raids, Bloom help withheld), or only distant? Canon-wise this is a bigger change.
- Are four gifts too many choices at once? The cards could come one per set as it is read, as proposed.

## As built
- **No new buildings.** The twins are standing effects, paid from the stores, so no new art was needed. The Bonesetter and the Orchard were buildings in the first sketch; a Forge belongs to Ironfall, so Smith's Rule uses a Smelter, which every Starfall town has.
- **The card.** Reading a gift's set puts a card up (Light, Body, Growth, Craft, one at a time, the game paused behind it): take the gift (+6 trust, as before) or keep to the Kith way (-4 trust). Until it is answered the gift does nothing. The first set (the name) and the Warning ask nothing.
- **The price.** A twin burns its upkeep at the start of every minute (Data.TWIN_EVERY); if the stores cannot pay it goes out, says so, and relights when they can. The Orchard is paid in full once, and waits for its Wood. A twin whose building is missing (no Cairn, no Smelter) simply waits.
- **The lean.** Any refusal caps the lean at neighbours; refusing all four makes enemies whatever the trust, and the Lumen never open their Market. The ending card says how many roads the Kith kept, and the Warning's question gains a line.
- **Techs** that wait on a gift (Ironfall's) wait only on the set being read, not on the gift being taken, so refusing never locks the research.
- **Old saves and dev starts** that have a gift set read with no road count as taking the gift.
- Still open for Jon: whether refusing should make the Lumen turn hostile later (raids, Bloom help withheld).
