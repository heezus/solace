extends RefCounted
## Why the population is not growing, and what to do about it: the note beside the Kith count in the top bar, the
## tooltip that gives the exact rule, and the pointer on a building that is waiting for more Kith. Static, and works
## on the Sim passed in. The one place that words it, so the bar, the tooltip, the goals and the building cards all
## say the same thing. The rule itself is Kith.food_ready_for_birth; this only explains it.

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")


## The note beside the count, or "" when nothing blocks growth (and nothing to say about food).
static func note(s) -> String:
	if s.economy.starving:
		return Data.NOTE_STARVING
	if s.people.kith.size() >= s.town.housing():
		return Data.NOTE_NO_ROOM
	if not s.people.food_ready_for_birth():
		return Data.GROW_NOTE_FOOD + ": " + fix(s)
	return ""


## What would make the food steady, for where the player is: before Paths & Haulers, after it with no hut on a road,
## and with a hut already on a road (more of them).
static func fix(s) -> String:
	if not s.tech_tree.researched.has("haulers"):
		return Data.GROW_FIX_NO_HAULERS
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and Roads.automated(s, b):
			return Data.GROW_FIX_MORE
	return Data.GROW_FIX_ROAD


## True when food, not room, is what stops the next birth.
static func food_is_the_blocker(s) -> bool:
	return not s.economy.starving and s.people.kith.size() < s.town.housing() and not s.people.food_ready_for_birth()


## The exact rule, for the hover tooltip.
static func rule() -> String:
	return Data.GROW_RULE % [int(Data.STEADY_SECONDS), Data.RATE_WINDOW]


## A pointer for a building's card while food is what stops the Kith growing, else "".
static func hint(s) -> String:
	return Data.GROW_HINT % fix(s) if food_is_the_blocker(s) else ""


## A status for a building whose worker has not come: more people are needed, and how to get them.
static func waiting_for_kith(s, job: String) -> String:
	var text: String = Data.NO_WORKER_STATUS % [job, Data.PEOPLE["many"]]
	var more := hint(s)
	return text + (". " + more if more != "" else "")
