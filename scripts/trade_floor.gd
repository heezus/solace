extends RefCounted
## The floor under what a Trading Post or Lumen Market gives (fun playtest 3): a standing swap drained Steel from 159 to 25 while the
## goal in front of the player wanted it. The floor is the larger of what the player set ("Keeps at least") and what the goal in front
## of them still asks for of that good (`hold`, set each tick by Workers.tick_building).

const Data = preload("res://scripts/data.gd")

const KEEPS := "Keeps at least: %d"  # a floor under what the swap gives
const KEEPS_TIP := "Click to raise the floor. The swap never takes this good below it."
const KEEP_STEPS := [0, 25, 50, 100, 200, 400]
const AT_FLOOR := "Waiting at the floor: keeping %d %s%s"  # the number, the good, the reason
const GOAL_REASON := " for the goal in front of you"


## The least the swap leaves of the good it gives.
static func of(b: Dictionary) -> int:
	return maxi(int(b["keep"]), int(b.get("hold", 0)))


## Set the player's floor on building `i` of `town`; false when it is not a market.
static func set_keep(town, i: int, amount: int) -> bool:
	if i < 0 or i >= town.buildings.size() or not Data.BUILDINGS[town.buildings[i]["type"]].get("trade", false):
		return false
	town.buildings[i]["keep"] = maxi(amount, 0)
	return true


## The floor after `current` in KEEP_STEPS, round to the first after the last.
static func next_keep(current: int) -> int:
	for n in KEEP_STEPS:
		if n > current:
			return n
	return KEEP_STEPS[0]
