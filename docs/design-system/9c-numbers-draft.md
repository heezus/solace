# 9C numbers draft: rate gates and the Hearthfire (Game build, Nov 18)

Draft for the director's judgment. **Nothing here is built or merged.** It sits on branch `c9numbers` with the probe change (`rates_every_10s`). Numbers come from the bots' own runs on maps 1, 2 and 4 (main at a45bbd3, `tests/tools/pace.gd`, rate read from the flow view's own made figure) and from the fun-6 journalist's two runs (`playtests/fun-6/logs/gj-*`).

How to read the tables: **rate** = made a minute by buildings plus hand, over the flow window (30 s), as the flow view shows it. **Sustained** = every 10 s reading over 60 s is at or above R. **Gate time G** = era length for Stone Age, Bronze Dawn and Ironfall; for Livewire it is the minute the Skyward goal was met. **One maker** = what one standing building did in the bots' runs (median of what each good's rate was per working building at each gate: kiln 31 brick a minute, charcoal pit 50, grindstone 16 flour, twine post 19 rope, crucible 8 bronze, bloomery 15 iron, forge 7 steel, wire mill 13 wire). That is faster than the buildings' raw cycle (a kiln's 5 s cycle is 24 a minute) because tools and bonuses speed them up; a careful player has fewer tools, so treat these as the best case.


## The short version

- **Rule I propose for R:** the lower of (a) what the bots' machine sustained for 60 s by two minutes before today's gate, on the worst of maps 1, 2, 4 (rounded down), and (b) what the careful player's machine at that gate plus **one more maker** could do (80% of count + 1, at the bots' per-maker speed). Never below 80% of one maker. So a gate always asks for about one more building than a careful player had, and never more than the bots already had.
- **Bots:** with these R every bot meets every R at least 2 minutes before today's gate on maps 1, 2 and 4, with **one exception**: Stone Age flour on map 4 (met 12.8 min, gate 13.9, so 1.1 min before). The 25% piles are small enough not to matter. So the rate gates should not slow the bots (bar: bot eras 12 to 18 min).
- **A trap in the table:** for the Falling Star, Livewire and Skyward gates the bots meet brick, rope and flour R within the first 1 to 6 minutes of the era, because the machine they built in the era before is still running. For a bot the rate part of those gates costs nothing; it only bites a player who let the machine fall behind. That is the intent, but it means the *pile* (25%) and the tech chain still set the bots' era times.
- **Careful players** (fun-6 journalist, run 1 / run 2): Stone Age gate had 1 and 3 kilns, Bronze Dawn 4 and 4, Ironfall 4 and 4. The gaps that R would show them: **bronze** (1 crucible in run 1), **flour** (1 grindstone), **wire** (1 wire mill in run 1), **steel** (1 forge in run 1). Those are the goods that held their eras (Ironfall 47.0 and 39.1 min).
- **Not measured:** map 4 Livewire and the Skyward gate on map 4 (the bot run is still going; the table is marked pending). Skyreach has no bot run at all; its numbers below are carried over from the Skyward gate.
- **Stone and Wood** stay piles (huts gather them, and Goal first already keeps a floor of 40). I would rate-gate only goods a workshop makes. Say if you want Wood and Stone rated too.

## Bronze Dawn gate (era: stone age; tech cost 90 brick, 150 charcoal, 60 flour, 80 rope, 60 stone, 60 wood)

Gate time G by map: map 1 17.4 min, map 2 13.1 min, map 4 13.9 min. Careful player (fun-6): run 1 43.2 min, run 2 20.8 min.

| Good | Pile today | Pile at 25% | Bot sustained by G-2 (map 1 / 2 / 4) | R from bots | R from careful machine +1 | **Proposed R** | Bot first meets R (map 1 / 2 / 4) vs G | Makers for R | Careful machine at the gate: makers = a min at bot speed (run 1 / run 2) |
|---|---|---|---|---|---|---|---|---|---|
| brick | 90 | 23 | 60 / 72 / 44 | 40 | 45 | **40** | 13.7 vs 17.4 / 8.7 vs 13.1 / 10.8 vs 13.9 | 2 kiln (one does 31) | 1 = 31 / 3 = 93 |
| charcoal | 150 | 38 | 72 / 68 / 92 | 65 | 80 | **65** | 10.2 vs 17.4 / 9.2 vs 13.1 / 10.3 vs 13.9 | 2 charcoal pit (one does 50) | 1 = 50 / 3 = 150 |
| flour | 60 | 15 | 24 / 18 / 0 | 1 | 25 | **12** | 14.8 vs 17.4 / 10.8 vs 13.1 / 12.8 vs 13.9 | 1 grindstone (one does 16) | 1 = 16 / 2 = 32 |
| rope | 80 | 20 | 74 / 52 / 98 | 50 | 45 | **45** | 8.7 vs 17.4 / 7.5 vs 13.1 / 10.8 vs 13.9 | 3 twine post (one does 19) | 2 = 38 / 3 = 57 |
| stone | 60 | keep 60 | gathered by huts | | | no rate gate, stays a pile | | | |
| wood | 60 | keep 60 | gathered by huts | | | no rate gate, stays a pile | | | |

## The Falling Star gate (era: bronze dawn; tech cost 100 brick, 60 bronze, 60 flour, 40 rope)

Gate time G by map: map 1 16.3 min, map 2 19.1 min, map 4 17.0 min. Careful player (fun-6): run 1 78.0 min, run 2 46.0 min.

| Good | Pile today | Pile at 25% | Bot sustained by G-2 (map 1 / 2 / 4) | R from bots | R from careful machine +1 | **Proposed R** | Bot first meets R (map 1 / 2 / 4) vs G | Makers for R | Careful machine at the gate: makers = a min at bot speed (run 1 / run 2) |
|---|---|---|---|---|---|---|---|---|---|
| brick | 100 | 25 | 172 / 112 / 200 | 110 | 120 | **110** | 6.1 vs 16.3 / 14.7 vs 19.1 / 6.3 vs 17.0 | 4 kiln (one does 31) | 4 = 124 / 4 = 124 |
| bronze | 60 | 15 | 26 / 28 / 28 | 25 | 12 | **12** | 11.9 vs 16.3 / 14.5 vs 19.1 / 13.1 vs 17.0 | 2 crucible (one does 8) | 1 = 8 / 3 = 24 |
| flour | 60 | 15 | 42 / 48 / 66 | 40 | 25 | **25** | 0.9 vs 16.3 / 3.4 vs 19.1 / 10.9 vs 17.0 | 2 grindstone (one does 16) | 1 = 16 / 2 = 32 |
| rope | 40 | 10 | 88 / 112 / 100 | 85 | 75 | **75** | 0.9 vs 16.3 / 4.8 vs 19.1 / 1.2 vs 17.0 | 4 twine post (one does 19) | 4 = 76 / 5 = 95 |

## Livewire gate (era: ironfall; tech cost 60 brick, 70 iron, 40 rope, 50 steel)

Gate time G by map: map 1 19.1 min, map 2 16.2 min, map 4 15.4 min. Careful player (fun-6): run 1 141.6 min, run 2 97.9 min.

| Good | Pile today | Pile at 25% | Bot sustained by G-2 (map 1 / 2 / 4) | R from bots | R from careful machine +1 | **Proposed R** | Bot first meets R (map 1 / 2 / 4) vs G | Makers for R | Careful machine at the gate: makers = a min at bot speed (run 1 / run 2) |
|---|---|---|---|---|---|---|---|---|---|
| brick | 60 | 15 | 172 / 120 / 200 | 120 | 120 | **120** | 1.3 vs 19.1 / 12.7 vs 16.2 / 1.9 vs 15.4 | 4 kiln (one does 31) | 4 = 124 / 4 = 124 |
| iron | 70 | 18 | 56 / 52 / 56 | 50 | 45 | **45** | 15.8 vs 19.1 / 12.8 vs 16.2 / 11.9 vs 15.4 | 3 bloomery (one does 15) | 3 = 45 / 3 = 45 |
| rope | 40 | 10 | 94 / 66 / 114 | 65 | 75 | **65** | 5.7 vs 19.1 / 10.3 vs 16.2 / 4.6 vs 15.4 | 4 twine post (one does 19) | 4 = 76 / 5 = 95 |
| steel | 50 | 13 | 18 / 12 / 20 | 12 | 11 | **11** | 16.3 vs 19.1 / 13.9 vs 16.2 / 13.0 vs 15.4 | 2 forge (one does 7) | 1 = 7 / 2 = 14 |

## Skyward gate (era: livewire; tech cost 100 brick, 60 iron, 72 steel, 120 wire)

Gate time G by map: map 1 15.6 min, map 2 11.9 min, map 4 pending. Careful player (fun-6): run 1 171.6 min, run 2 109.5 min.

| Good | Pile today | Pile at 25% | Bot sustained by G-2 (map 1 / 2 / 4) | R from bots | R from careful machine +1 | **Proposed R** | Bot first meets R (map 1 / 2 / 4) vs G | Makers for R | Careful machine at the gate: makers = a min at bot speed (run 1 / run 2) |
|---|---|---|---|---|---|---|---|---|---|
| brick | 100 | 25 | 172 / 116 / - | 115 | 95 | **95** | 0.9 vs 15.6 / 0.9 vs 11.9 / - | 4 kiln (one does 31) | 3 = 93 / 4 = 124 |
| iron | 60 | 15 | 72 / 80 / - | 70 | 45 | **45** | 0.9 vs 15.6 / 0.9 vs 11.9 / - | 3 bloomery (one does 15) | 3 = 45 / 3 = 45 |
| steel | 72 | 18 | 38 / 24 / - | 24 | 16 | **16** | 1.6 vs 15.6 / 7.2 vs 11.9 / - | 3 forge (one does 7) | 2 = 14 / 2 = 14 |
| wire | 120 | 30 | 46 / 42 / - | 40 | 20 | **20** | 8.4 vs 15.6 / 5.3 vs 11.9 / - | 2 wire mill (one does 13) | 1 = 13 / 3 = 39 |

## Skyreach stages and the other big builds

Only piles over 60 of one good follow the rule. Nothing else in the build list has a pile that big (Factory Floor is 60 Brick, Scorcher 80 Brick, Living Ground 120 Brick, Generator 80 Brick: left as piles, they are one-off buys).

| Stage | Pile today | Rate gate (R a minute for 60 s) | Pile at 25% | Notes |
|---|---|---|---|---|
| Stage 1 | 30 Steel, 400 Stone | Steel **16** | Steel 8; Stone stays 400 | stone is gathered, so it stays a pile |
| Stage 2 | 120 Wire, 4 Shards | Wire **20** | Wire 30; Shards stay 4 | Shards are chipped by hand |
| Stage 3 | 30 Steel, 60 Wire, 200 Brick, 120 Rope, 120 Copper, 3 Shards | Brick **95**, Rope **65**, Copper **24** (2 smelters), Wire 20, Steel 16 | Brick 50, Rope 30, Copper 30, Wire 15, Steel 8 | one gate at a time, as the era card gives them |

These come from the Skyward gate's rates plus one smelter pair for Copper; **there is no bot or careful-player run of Skyreach to measure them against**, so treat them as a placeholder until fun-7 plays it. The sky opening already tops the stores up to 100 Wire and 30 Steel (`floor` in the Skyreach data), which would meet the Wire and Steel piles at once.

## 9C-3: the Hearthfire sink

**Worth table** (what one unit counts for when it goes into the fire). Raw goods count 1 (food counts by what it feeds: berries and grain 1, fish and Starfruit 2); a made good counts the worth of what it eats divided by what comes out, plus 25% for the work.

| Good | Worth | Good | Worth |
|---|---|---|---|
| Wood, Stone, Fiber, Clay, Grain, Berries, Charcoal | 1 | Copper | 9 |
| Brick | 1.5 | Iron | 11 |
| Fish, Starfruit, Flint | 2 | Wire | 11 |
| Rope, Flour | 2.5 | Steel | 32 |
| Coal, Copper Ore, Tin, Iron Ore | 3 | Bronze | 38 |
| Shard | 20 | Shardwork | 53 |

**Tiers** (cumulative worth given in this telling; each tier is +3% work speed, five tiers, so +15% at most):

| Tier | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Worth to give, this tier | 600 | 900 | 1500 | 2000 | 3000 |
| Worth given in all | 600 | 1500 | 3000 | 5000 | 8000 |

**Why these sizes.** The bots end a Bronze Dawn with 6,000 to 10,000 worth of unspent surplus (about 370 to 530 a minute), a Starfall with about 15,000 and an Ironfall with 17,000 to 21,000, counting net stock growth plus what spilled at the cap (map 1, 2, 4, main). So a bot fills tier 1 in about 2 minutes of its surplus and tier 5 inside one era. The fun-5 and fun-6 careful players run a machine of roughly half the bots' size in kilns, grindstones and crucibles (the counts in the gate tables), and make less of everything at the bots' speed. I have no surplus ledger for them, so this is an estimate: perhaps 100 to 300 worth a minute of surplus, which is tier 1 in 3 to 6 minutes and tier 5 across most of a telling. That is the gradient I was aiming for: growing the machine past the gate always pays, and it pays most to the player who builds more.

**Rules that go with it** (as the spec has them): always open, never required, pauses when the current goal is short of that good (the same test Goal first uses, so the two never fight), and the basic-goods floor of 40 applies to it too.

**What it does to the bars.** If the bots feed the Hearthfire (they should: "bots in era N know everything from eras 1 to N-1"), they reach +15% work speed by Starfall, so Starfall, Ironfall and Livewire get about 13% shorter for bots. Ironfall (15 to 19 min today) would land at 13 to 17, inside the 12 to 18 bar, but Livewire to Skyward (12 to 16 today) would land at 10 to 14, under the 12 floor on two maps. I would not give the bots the Hearthfire until you have judged the numbers; say if you want them to use it and I will re-run the bars.

## Where the careful players stood (fun-6 journalist)

| Era | Run 1 | Run 2 | Bots (maps 1 / 2 / 4) |
|---|---|---|---|
| Stone Age | 43.3 | 20.8 | 17.4 / 13.1 / 13.9 |
| Bronze Dawn | 34.7 | 25.2 | 16.3 / 19.1 / 17.0 |
| Starfall | 16.7 | 12.8 | 14.3 / 14.0 / 13.7 |
| Ironfall | 47.0 | 39.1 | 19.1 / 16.2 / 15.4 |
| Livewire (to Skyward) | 30.0 | 11.6 | 15.6 / 11.9 / pending |

The aim of 15 to 25 minutes for a careful player is already met in Starfall and in run 2's Stone Age, Bronze Dawn and Livewire. The two that are not are **Ironfall** (47.0 and 39.1) and **run 1's Stone Age and Bronze Dawn** (43.3 and 34.7: the hand gathering and the missing first hut, which the first-hut-free change in PR B addresses). Rate gates push the *machine*; they do not touch the Ironfall causes in the fun-6 verdict (clay and brick for the Bloomery, fuel, wrong hints), which the fun-6 fixes address.

## What I need from you

1. **R rule:** is "lower of bots' sustained rate and careful machine plus one maker" the rule you want? Or do you want R = the bots' number alone (a bigger ask of careful players: brick 110 a minute at the Falling Star needs four kilns all running)?
2. **Stone and Wood** stay piles: yes or no?
3. **Stone Age flour on map 4** (meets only 1.1 min before the gate): accept, or raise the flour pile instead?
4. **Hearthfire for the bots:** on or off in the bars?
5. **Skyreach:** accept placeholders until fun-7 plays it?
