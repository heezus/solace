extends RefCounted
## Every tuning number: how fast, how many, how far. Change the feel of the game here.
## Read through the `Data` facade (scripts/data.gd).

## Harvest a resource by hand this many times and a watching Kith learns it: huts may then gather it.
const LEARN_CLICKS := 10
## A hut trip brings back a bundle: this many times your harvest yield for that resource.
const BUNDLE := 3
## Trips a hut can have queued before Paths & Haulers (the one under way counts).
const TRIP_QUEUE := 3
## Clicking a working building finishes its cycle now, then it can't be rushed for this long.
const RUSH_COOLDOWN := 5.0
## Gathering by hand is a hold: a ring fills over the tile for HOLD_TIME seconds, then the harvest pops,
## and it repeats while you hold. A harvest's yield is base x tool x rank.
const HOLD_TIME := 1.0
## Hand tools: the best one that applies counts for each part. `hold` shortens the hold (seconds),
## `mult` multiplies the yield. `crafted` needs a Flint Tool made once, `tech` a researched tech
## (Bronze Tools is era 2's slot), `item` limits it to one resource.
const HAND_TOOLS := {
	"flint_tools": {"name": "Flint Tools", "hold": 0.7, "crafted": true},
	"stone_axe": {"name": "Stone Axe", "mult": 3, "tech": "stone_axe", "item": "wood"},
	"bronze_tools": {"name": "Bronze Tools", "hold": 0.4, "tech": "bronze_tools"},
}

## Food each Kith eats per second.
const FOOD_PER_KITH_PER_SEC := 0.02
## Berries in the stockpile at the start. Three Kith eat about 3.6 a minute; the second goal has the player
## hand-gather more, and the food warning (below) comes before the pantry is bare.
const START_BERRIES := 10
## The food warning goes up (a toast, and the Food readout flashes red) when the stockpile would run out within
## this many seconds at the current eating rate, and comes down again once it would last FOOD_CLEAR_SECONDS.
const FOOD_WARN_SECONDS := 120.0
const FOOD_CLEAR_SECONDS := 180.0
## Famine: once the warning is up and the food would run out within this many seconds, Kith with nothing to do
## forage by themselves (see scripts/forage.gd) until the warning comes down again.
const FOOD_FAMINE_SECONDS := 60.0
## ...and they stop once it would last this long (well past FOOD_CLEAR_SECONDS, so the famine does not flicker on and off).
const FOOD_FORAGE_END_SECONDS := 300.0
## A forager picks FORAGE_YIELD of FORAGE_ITEM, FORAGE_TIME seconds a pick, from a bush within FORAGE_RADIUS tiles of the
## Hearth, and walks it to the nearest stockpile. A slow trickle beside a hut, enough to keep the people fed and never
## enough to grow (foraged food is not steady income).
const FORAGE_ITEM := "berries"
const FORAGE_RADIUS := 12
const FORAGE_TIME := 4.0
const FORAGE_YIELD := 2
## Food in the stockpile under this counts as short: a new hut that could work food or something else at the same
## distance works the food.
const FOOD_SHORT_STOCK := 30.0
const KITH_START := 3
## A new Kith is born every GROW_TIME seconds while there is room and steady food. Birth costs BIRTH_FOOD.
const GROW_TIME := 12.0
const BIRTH_FOOD := 5.0
## A birth also needs this much food in the stockpile for each person already there, and food coming in
## steadily (Economy.food_is_steady): what the buildings bring (not hand-gathering) over the last
## RATE_WINDOW seconds must cover what everyone eats.
const BIRTH_RESERVE := 2.0
## ...and it must have covered them for this long without a break. Longer than RATE_WINDOW on purpose: one delivery
## stays in the window for RATE_WINDOW seconds, so a single trip can never pass for steady food.
const STEADY_SECONDS := 45.0
## After this long with no food, one Kith leaves.
const STARVE_TIME := 20.0
## Tiles per second on open ground. Roads double it; forest and rocks halve it.
const KITH_SPEED := 2.0
## Items a hauler carries per trip.
const CARRY := 10

## Dwellings must stand within this many tiles of the Hearth (the Camp), where the Kith are born.
const HEARTH_RADIUS := 6.0

## How far each thing lets the Kith see, in tiles. Scouting adds SCOUTING_SIGHT to buildings and Kith.
const SIGHT_START := 6
const SIGHT_BUILDING := 3
const SIGHT_KITH := 2
const SCOUTING_SIGHT := 2

## Rates in the top bar are averaged over this many seconds.
const RATE_WINDOW := 30
## The flow source that eating is noted under (the top bar's hover panel shows it as "Eaten by ...").
const FLOW_EAT_SOURCE := "kith"
## The flow source the player's own hand-gathering is noted under (it is not food income for growth).
const FLOW_HAND_SOURCE := "hand"
## The flow source idle Kith foraging in a famine are noted under (not food income, like the hand).
const FLOW_FORAGE_SOURCE := "forage"
## The flow source a worker taking a Flint Tool from the stockpile is noted under.
const FLOW_TOOL_SOURCE := "kith"

## Tech bonuses Sim applies.
const STORYTELLING_GROW := 0.75  # grow time multiplier

## Work multipliers (scripts/bonuses.gd). "speed" shortens work cycles, "yield" multiplies each harvest.
## They add within a group and multiply across groups. Optional keys: `tech` (needs it researched),
## `kinds` (building kinds it applies to), `types` (building types), `item` (only harvests of that item),
## `rank_of` (a tech's ranks: `add` per rank bought beyond I).
## The Stone Axe is a hand tool (HAND_TOOLS): huts get it through their bundle, which is based on a harvest.
## "tools" applies while the worker holds a Flint Tool, "standing_stone" next to a Standing Stone.
const BONUSES := {
	"tools": {"name": "Flint Tools", "group": "speed", "add": 0.5, "kinds": ["gatherer", "processor"]},
	"standing_stone": {"name": "Standing Stone", "group": "speed", "add": 1.0, "kinds": ["gatherer", "processor"]},
	"foraging": {"name": "Foraging", "group": "yield", "add": 1.0, "tech": "foraging", "item": "berries"},
	"ochre": {"name": "Ochre", "group": "yield", "add": 1.0, "tech": "ochre", "item": "clay", "kinds": ["gatherer"]},
	# Ranks II and III on workshop techs: +25% Speed each, at that workshop only (`rank_of`, `types`).
	"rank_twine_post":
	{"name": "Cordage", "group": "speed", "add": 0.25, "rank_of": "cordage", "types": ["twine_post"]},
	"rank_charcoal_pit": {"name": "Fire", "group": "speed", "add": 0.25, "rank_of": "fire", "types": ["charcoal_pit"]},
	"rank_kiln": {"name": "Pottery", "group": "speed", "add": 0.25, "rank_of": "pottery", "types": ["kiln"]},
}
## A Flint Tool lasts this many jobs (harvests or work cycles) in a worker's hands.
const TOOL_JOBS := 40
const CALENDAR_FIELD_BONUS := 0.25  # extra yield from Fields
