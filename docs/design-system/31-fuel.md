# 31. Fuel (Step 3)

Contract rule 3 ([30](30-era-contracts.md)): running out of a finite good slows an era, never stops it. Coal is finite, and Ironfall's Bloomeries and Forges and Livewire's Boilers, Generators and Scorchers all burn it. Before this step the metal works stood still the moment the seams ran dry, with Wood in the stores and Charcoal Pits idle.

## The rule
- A **Bloomery**, a **Forge** and a **Factory Floor** copying one burn one Coal **or** one Charcoal a batch.
- On **Coal** a batch takes its normal time (Bloomery 9 s, Forge 8 s). On **Charcoal** it takes twice as long (`CHARCOAL_SLOW`, 2.0).
- Every one has a **Fuel** button on its card: **Auto** (default), **Coal**, **Charcoal**. Auto burns Coal while the stores hold more than `FUEL_RESERVE` (40), else Charcoal, so the Boilers, Generators and Scorchers keep a little. A fuel the building holds, or has on the way, stays its fuel until it is burnt.
- Haulers bring the fuel the building burns now (`Haulers.stock_wanted` reads `Buildings.recipe_in`, which swaps Coal for Charcoal through `Fuel.swap`).
- The status says it: "Smelting on Charcoal: half speed (Coal is low)" on Auto, "... half speed" when the player chose Charcoal. The card's fuel line names what it burns and the Auto reserve.
- **Boilers, Generators and Scorchers take Coal or Charcoal too (2026-10-23, director's Step 4 follow-up).** Keeping them Coal-only broke contract rule 3: when the seams ran dry the Generators went cold and the Scorchers could not burn, so the Bloom won (the Shard Dynamo is no way out, it sits behind a Lumen lesson). One fuel unit a burn either way; a Charcoal lasts half as long (a Generator on Charcoal uses a unit every 12.5 s instead of 25, a Scorcher clears 2 tiles on 1 Charcoal instead of 4). Same Fuel button, same Auto rule, status "Burning Charcoal: twice the fuel (Coal is low)". A building with neither says "Coal or Charcoal". Seam sizes, other recipes and prices are unchanged.
- **The Livewire coal gift is gone.** The +600 coal added when the Wires Hum card is put away (`LIVEWIRE_COAL_GIFT`, `World.deepen_seams`) and the seam text that went with it are removed: Charcoal is the cushion now.

## Where it lives
`scripts/fuel.gd` (burns, is_fed, choose, update, swap, slow, burn_seconds, status, line, cycle), `scripts/steam.gd` and `Tide.tick_scorcher` (the fed buildings take the fuel they burn now), `scripts/fuel_picker.gd` (the card's button). The `fuel` setting and `fuel_now` are kept only on Bloomery, Forge and Floor dicts and saved with them (a save from before has them filled in on load), so the stone age and Bronze Dawn states, and the goldens, do not change. `Economy.made_on` counts output by fuel for the baseline; it is not saved.

## Bots
The Ironfall and Livewire bots ask for Charcoal when the Coal in the stores is under twice the reserve and the gate still needs Steel (`FUEL_CHARCOAL_CAP`, 200), so the ordinary Charcoal Pit rules build the Pits. No hand-made stock.

The Livewire bot also asks for Charcoal for its engines when the Coal is under twice the reserve (`CHARCOAL_FOR_ENGINES`, 300), and places its Scorcher `SCORCHER_AHEAD` (3) tiles from the Bloom's nearest ground on the net, moving it if nothing has come in reach for `SCORCHER_WAIT` (5 min, at most 3 times).

## What the baseline reads
Per era: Iron and Steel made on each fuel (`made_on_coal`, `made_on_charcoal`), seconds a Bloomery or Forge sat with its recipe in hand but not its fuel while the stores held Wood (`fuel_starved_s`, longest stretch `fuel_starved_longest_s`), Charcoal Pits standing (start and end), seconds Wood was under 10 (`wood_short_s`), goods spilled. `pace.gd baseline noseams` empties every seam when Ironfall starts, a test variant only (never a balance run): the bar is that Ironfall then runs at least 3 min slower, or the Charcoal factor goes to 3x.

Livewire rows also read the seconds power sat at zero while the stores held Wood (`power_zero_with_wood_s`, longest stretch `power_zero_with_wood_longest_s`) and the units burnt by engines and Scorchers by building and kind (`fuel_burned`).
