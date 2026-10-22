# The Lumen: separate markets, a Wall that keeps its secrets, a word for trust

Status: **built** (2026-10-19, PR J). Mechanics page, so Claude owns it. From Jon's playtest notes: "what is the difference between a Lumen Market and a Trading Post, they should be faction specific", "the Glyph Wall gives too large a hint with the theme of each set", "those should come up in a random order" and "should there be a trust meter?"

## Two markets, two sets of goods
- **Trading Post** (the Markets tech, 3 for 1, every 10 seconds): swaps Kith goods, which means every good the people have held except a Shard.
- **Lumen Market** (opens once the Lumen would trade, 2 for 1, every 8 seconds, 60 Wood, 30 Stone, 20 Rope): swaps only the strangers' own goods. There is no "glyph lore" item to trade, so the list is **Shard, Coal, Wire and Steel** (data: `trade_only` on the building).
- A Market saved before the split with Kith goods set loads with nothing chosen, and the picker only offers what the building trades.

## The Glyph Wall keeps its secrets
- An unread set is called **"Set 2 of 6"** with its marks copied. Its theme (Light, Body, Growth and the rest), its icon and its gift appear only when it is read.
- The Name always comes first and the Warning always last (the ending waits on it). The four sets between are shuffled by a fixed scramble of where the ship came down, so a map keeps its order and gameplay random numbers are never touched. The marks of each set also come in a scrambled order. Before the star falls there is no wreck, so the order is the one in the data.

## A word for trust
- The Lumen Market's panel shows **"The Lumen are: Wary / Curious / Friendly / Close"** with a small bar, once the name is read. Below 20 is Wary, below 35 Curious, below 70 Friendly, then Close. The number stays hidden.
- A step of trust of a whole point or more floats over the Hearth ("+6 trust"); the slow trickles do not.
