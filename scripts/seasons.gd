extends RefCounted
## Seasons of Strain (design-system/24-balance.md, pick 1): every few minutes a pressure arrives and the people must answer a
## question with no right answer. The answer lasts the season. The schedule and the kind come from the clock and the map's seed, never
## the game's random numbers, so every bot and playtest of a map meets the same seasons. Sim owns one, reached as `sim.seasons`.
## The effects are small switches the other blocks read: `speed_factor`, `tide_pace` and `keeps_buildings`; the Economy's own fields
## (`eat_factor`, `births_paused`, `forage_call`, `forage_mult`) are set here every tick.

const Data = preload("res://scripts/data.gd")

var time := 0.0  # game seconds since the run began
var next_at := Data.SEASON_FIRST  # when the next one arrives
var phase := "idle"  # "idle", "pending" (the card waits for an answer) or "active"
var kind := ""  # the season now pending or active
var answer := -1  # which option was picked (0 or 1)
var left := 0.0  # seconds of the active season still to run
var count := 0  # seasons that have arrived this run
var last := ""  # the kind before this one, so one never comes twice running
var _waited := 0.0  # seconds a card has waited unanswered
var _burn := 0.0  # seconds to the next unit of fuel burnt in a cold snap


func tick(s, delta: float) -> void:
	time += delta
	match phase:
		"idle":
			if time >= next_at and s.economy.food_total() >= Data.FOOD_SHORT_STOCK:  # never on a town already short of food
				_arrive(s)
		"pending":
			_waited += delta
			if _waited >= Data.SEASON_AUTO:
				choose(s, 0)
		"active":
			left -= delta
			_burn_fuel(s, delta)
			if left <= 0.0:
				_end(s)
	_set_economy(s)


## The kinds that could come now: Lean always; the Cold snap from Bronze Dawn on; the Surge once the tide has begun.
func eligible(s) -> Array:
	var out: Array = ["lean"]
	if s.story.has_event("bronze_dawn"):
		out.append("cold")
	if s.tide.begun:
		out.append("surge")
	return out.filter(func(k): return k != last or out.size() == 1)


func _arrive(s) -> void:
	var kinds := eligible(s)
	count += 1
	var pick := absi(count * 7919 + s.world.map_seed + 31) % kinds.size()
	kind = kinds[pick]
	phase = "pending"
	answer = -1
	_waited = 0.0
	next_at = (
		time
		+ Data.SEASON_EVERY
		+ float(absi(count * 104729 + s.world.map_seed) % (2 * Data.SEASON_JITTER + 1) - Data.SEASON_JITTER)
	)


## The player's answer (index into the season's two options): the season is on for Data.SEASON_LENGTH seconds.
func choose(s, index: int) -> void:
	if phase != "pending":
		return
	answer = clampi(index, 0, 1)
	phase = "active"
	left = Data.SEASON_LENGTH
	_burn = 0.0
	if kind == "surge" and answer == 1:
		var paid := mini(Data.SURGE_COAL, s.economy.inv.get("coal", 0))
		s.economy.inv["coal"] -= paid
		s.economy.note("coal", -float(paid), "season")
	s.events.append(Data.SEASONS[kind]["told"])


func _end(s) -> void:
	s.events.append(Data.SEASONS[kind]["over"])
	last = kind
	phase = "idle"
	kind = ""
	answer = -1


## Cold snap, answer 0: the town burns a unit of fuel every few seconds (Charcoal first, then Coal).
func _burn_fuel(s, delta: float) -> void:
	if kind != "cold" or answer != 0:
		return
	_burn += delta
	if _burn < Data.COLD_BURN_SECONDS:
		return
	_burn -= Data.COLD_BURN_SECONDS
	for id in ["charcoal", "coal"]:
		if s.economy.inv.get(id, 0) > 0:
			s.economy.inv[id] -= 1
			s.economy.note(id, -1.0, "season")
			return


## Push the Economy's season switches: they are derived from this block every tick, so they are not saved with it.
func _set_economy(s) -> void:
	var on := phase == "active"
	s.economy.eat_factor = Data.RATION_EAT if on and kind == "lean" and answer == 0 else 1.0
	s.economy.births_paused = on and kind == "lean" and answer == 0
	s.economy.forage_call = on and kind == "lean" and answer == 1
	s.economy.forage_mult = Data.FORAGE_MULT if on and kind == "lean" and answer == 1 else 1


## The share of its pace a building works at now: food buildings in a lean season, any workshop in a huddle.
func speed_factor(_s, b: Dictionary) -> float:
	if phase != "active":
		return 1.0
	if kind == "lean" and _makes_food(b):
		return Data.LEAN_PACE
	if kind == "cold" and answer == 1 and Data.BUILDINGS[b["type"]]["kind"] == "processor":
		return Data.HUDDLE_PACE
	return 1.0


## True for a building whose work is food: a Hut set to a food, a field of grain, or a workshop that makes a food.
func _makes_food(b: Dictionary) -> bool:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "gatherer":
		return Data.FOOD_VALUE.has(b["focus"])
	if def["kind"] == "field":
		return def.get("crop", "") == "grain"
	for id in def.get("out", {}):
		if Data.FOOD_VALUE.has(id):
			return true
	return false


## How fast the tide's clock runs: faster in a Bloom surge that was let come.
func tide_pace() -> float:
	return Data.SURGE_PACE if phase == "active" and kind == "surge" and answer == 0 else 1.0


## True while a Bloom surge that was let come is on: nothing is lost to overgrowth in it.
func keeps_buildings() -> bool:
	return phase == "active" and kind == "surge" and answer == 0


func to_dict() -> Dictionary:
	return {
		"time": time,
		"next_at": next_at,
		"phase": phase,
		"kind": kind,
		"answer": answer,
		"left": left,
		"count": count,
		"last": last,
		"waited": _waited,
		"burn": _burn,
	}


func from_dict(d: Dictionary) -> void:
	time = float(d.get("time", 0.0))
	next_at = float(d.get("next_at", Data.SEASON_FIRST))
	phase = String(d.get("phase", "idle"))
	kind = String(d.get("kind", ""))
	answer = int(d.get("answer", -1))
	left = float(d.get("left", 0.0))
	count = int(d.get("count", 0))
	last = String(d.get("last", ""))
	_waited = float(d.get("waited", 0.0))
	_burn = float(d.get("burn", 0.0))
