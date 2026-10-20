# Crises: Seasons of Strain, rebuilt

Status: **built** (2026-10-19, PR I). Mechanics page, so Claude owns it. It answers Jon's playtest note "the crises are repetitive and I am not sure the punishments are actually happening".

## What was wrong
- Only three kinds existed, and the stone age had one (a lean season every time).
- "Let it come" in a Bloom surge cost nothing, "Hold it back" cost nothing without Coal, the Huddle (four fifths of workshop pace) was too small to see, and a lean season cost 45 to 110 food over 90 seconds, which a growing town shrugs off.
- Nothing said what a season cost.

## The rules now
- **Seven kinds, each from its era**: Lean season and Fever (stone age), Cold snap (Bronze Dawn), Bloom surge (once the tide has begun), Blight (the Falling Star), Bad vein (Ironfall), Storm on the wires (Livewire). Later eras keep the earlier kinds.
- **A kind comes once before any comes again.** The pool is the kinds this era has met, minus the ones already seen in this round. When the round is used up it starts over, and the last kind never comes twice running. The order comes from the clock and the map seed, never gameplay random numbers, so every bot and playtest of a map meets the same seasons.
- **Every answer is a real price.** Each kind has two answers; both are in `scripts/data/seasons.gd` as small data (a pace per group, an eating share, births, foraging, tide pace, a cost, a drain, a share the Bloom takes). Costs ask for the first alternative the stores can pay in full (Coal, else Wood; Iron, else Wood) and take what exists otherwise; the stores never go under.
- **The numbers are shown.** The toast that opens a season stays for its whole length and says what it cost ("It cost 20 Coal."), each unit a season takes floats up over the Hearth ("-1 Charcoal"), and when the season ends the toast says the whole bill ("The cold snap has passed. It cost 45 Charcoal in all.").

| Kind | Answer 1 | Answer 2 |
| --- | --- | --- |
| Lean season | Ration: eat a quarter less, no births; food buildings at 45% | Forage: idle hands forage twice as much; food buildings at 45% |
| Fever | Tend the sick: eat a quarter more | Push on: every building at 70% |
| Cold snap | Burn fuel: 1 Charcoal (else Coal, else Wood) every 2 s, 45 in all | Huddle: every workshop at 65% |
| Bloom surge | Let it come: tide 1.5 times as fast, no building lost, the Bloom takes a fifth of the raw goods | Hold it back: spend 20 Coal (or 40 Wood) |
| Blight | Wait it out: fields at 40% | Treat the rows: 40 Wood, fields at 75% |
| Bad vein | Prop the shafts: 40 Wood (or 10 Iron), mines at 80% | Dig round it: mines at 50% |
| Storm | Shelter: every building at 55% | Brave it: 20 Iron (or 60 Wood), every building at 90% |

## Left out
- A Skyreach kind. Era 6 does not exist yet.
- Deaths. A season may stop births but never kills a Kith.
