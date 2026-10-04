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


## The note for the top bar: the same, but the food note waits until it can matter, that is until a hut and a Dwelling
## stand (before that the food is not yet what holds the Kith back, and the bar's room is the Kith count's).
static func bar_note(s) -> String:
	if food_is_the_blocker(s) and not _hut_and_dwelling(s):
		return ""
	return note(s)


static func _hut_and_dwelling(s) -> bool:
	var hut := false
	var home := false
	for b in s.town.buildings:
		hut = hut or Data.BUILDINGS[b["type"]]["kind"] == "gatherer"
		home = home or b["type"] == "dwelling"
	return hut and home


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


# --- How close the food is to the next birth ---------------------------------------------------------------------------


## The Food readout's second line: where the next birth stands, in plain words. "" while there is nothing to add:
## starving or no room (the note beside the count says it), or before a hut and a Dwelling stand (as in bar_note).
## The states, in order: the buildings' food has not been counted for a whole window yet; it does not cover what
## everyone eats (says by how much, per minute); the stockpile is too small for a birth; the food is covering and the
## hold is counting up; a birth is on its way.
static func progress_text(s) -> String:
	if s.economy.starving or s.people.kith.size() >= s.town.housing() or not _hut_and_dwelling(s):
		return ""
	var eco = s.economy
	var window: int = eco.flows.hist.size()
	if window < Data.RATE_WINDOW:
		return Data.GROW_COUNTING % [window, Data.RATE_WINDOW]
	if not eco.food_covers_eating():
		return Data.GROW_NEEDS_MORE % _per_minute(maxf(eco.food_use - eco.food_supply(), 0.0))
	var stock_short: float = _stock_needed(s) - eco.food_total()
	if stock_short > 0.0:
		return Data.GROW_NEEDS_STOCK % ceili(stock_short)
	return _eta_text(s)


## "Steady food 12 of 35 s, then a Kith in about 47 s", or "Next Kith in about 8 s" once a birth is counting down.
static func _eta_text(s) -> String:
	var one: String = Data.PEOPLE["one"]
	var eco = s.economy
	var left_hold := maxf(Data.STEADY_SECONDS - eco.steady_held, 0.0)
	var wait := maxf(s.people.grow_time() - s.people.grow_timer, 0.0)
	if left_hold <= 0.0:
		return Data.GROW_NEXT % [one, seconds_text(wait)]
	return Data.GROW_STEADY % [int(eco.steady_held), int(Data.STEADY_SECONDS), one, seconds_text(left_hold + wait)]


## Food the stockpile must hold before a birth: a small reserve per person plus what a birth costs.
static func _stock_needed(s) -> float:
	return s.people.kith.size() * Data.BIRTH_RESERVE + Data.BIRTH_FOOD


## The tooltip's full version: what the buildings bring in against what everyone eats, per minute.
static func progress_tip(s) -> String:
	if not _hut_and_dwelling(s):
		return ""
	var eco = s.economy
	return Data.GROW_FLOW_TIP % [_per_minute(eco.food_supply()), Data.PEOPLE["many"], _per_minute(eco.food_use)]


## A food rate per second as a number of food a minute, to one place ("4.2").
static func _per_minute(per_second: float) -> String:
	return str(snappedf(per_second * 60.0, 0.1))


## "45 s" under a minute, else "2 min" (rounded up, since it is a wait).
static func seconds_text(seconds: float) -> String:
	return "%d s" % ceili(seconds) if seconds < 60.0 else "%d min" % ceili(seconds / 60.0)
