extends RefCounted
## Seasons of Strain (design-system/24-balance.md, pick 1): every few minutes a pressure arrives and the people must answer a
## question with no right answer. The answer lasts the season. The schedule and the kind come from the clock and the map's seed, never
## the game's random numbers, so every bot and playtest of a map meets the same seasons. Sim owns one, reached as `sim.seasons`.
## The effects are small switches the other blocks read: `speed_factor`, `tide_pace` and `keeps_buildings`; the Economy's own fields
## (`eat_factor`, `births_paused`, `forage_call`, `forage_mult`) are set here every tick. Each kind comes once before any comes again
## (`used`), and what a season takes is counted in `spent` and told in numbers when it ends (design-system/27-crises.md).

const Data = preload("res://scripts/data.gd")

var time := 0.0  # game seconds since the run began
var next_at := Data.SEASON_FIRST  # when the next one arrives
var phase := "idle"  # "idle", "pending" (the card waits for an answer) or "active"
var kind := ""  # the season now pending or active
var answer := -1  # which option was picked (0 or 1)
var left := 0.0  # seconds of the active season still to run
var count := 0  # seasons that have arrived this run
var last := ""  # the kind before this one, so one never comes twice running
var used: Array = []  # the kinds that have come since the pool last ran out
var spent := {}  # item -> units this season has cost so far (paid, burnt or taken)
var pops: Array = []  # short texts the map floats over the Hearth ("-1 Charcoal"); main takes them every frame
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
	push_to_economy(s)


## The era the run is in: 1 the stone age, 2 Bronze Dawn, 3 the Falling Star, 4 Ironfall, 5 Livewire.
func era(s) -> int:
	if s.story.has_event(Data.LIVEWIRE_BEGUN):
		return 5
	if s.story.has_event(Data.IRONFALL_EVENT):
		return 4
	if s.story.has_event("star_falling"):
		return 3
	return 2 if s.story.has_event("bronze_dawn") else 1


## The kinds this era could meet, in a fixed order: each comes once its era is in, the Surge once the tide has begun.
func pool(s) -> Array:
	var e := era(s)
	var out: Array = []
	for k in Data.SEASONS:
		var def: Dictionary = Data.SEASONS[k]
		if def["era"] <= e and (def.get("needs", "") != "tide" or s.tide.begun):
			out.append(k)
	return out


## The kinds that could come now: the pool minus the ones that came since it last ran out (and minus the last one, so a kind never
## comes twice running when another could). When every kind has come, the round starts over.
func eligible(s) -> Array:
	var all := pool(s)
	var fresh: Array = all.filter(func(k): return not used.has(k))
	if fresh.is_empty():
		used = []
		fresh = all.filter(func(k): return k != last or all.size() == 1)
	return fresh


func _arrive(s) -> void:
	var kinds := eligible(s)
	count += 1
	var pick := absi(count * 7919 + s.world.map_seed + 31) % kinds.size()
	kind = kinds[pick]
	used.append(kind)
	phase = "pending"
	answer = -1
	_waited = 0.0
	spent = {}
	next_at = (
		time
		+ Data.SEASON_EVERY
		+ float(absi(count * 104729 + s.world.map_seed) % (2 * Data.SEASON_JITTER + 1) - Data.SEASON_JITTER)
	)


## The player's answer (index into the season's two options): the season is on for Data.SEASON_LENGTH seconds. What the answer costs
## up front is paid now and told.
func choose(s, index: int) -> void:
	if phase != "pending":
		return
	answer = clampi(index, 0, 1)
	phase = "active"
	_waited = 0.0  # a spent wait is not kept: stray float digits do not survive a save
	left = Data.SEASON_LENGTH
	_burn = 0.0
	spent = {}
	var o := option()
	_pay(s, o.get("cost", []))
	if o.has("takes"):
		_take(s, float(o["takes"]))
	s.events.append(Data.SEASONS[kind]["told"] + ("" if spent.is_empty() else " It cost " + spent_text() + "."))


## The answer in force: the picked option of the pending or active season, {} when none.
func option() -> Dictionary:
	if kind == "" or answer < 0:
		return {}
	return Data.SEASONS[kind]["options"][answer]


## "20 Coal", or "12 Wood and 5 Fiber": what the season has cost so far.
func spent_text() -> String:
	var parts: Array = []
	for id in spent:
		parts.append("%d %s" % [spent[id], Data.ITEMS[id]["name"]])
	return " and ".join(parts) if parts.size() < 3 else ", ".join(parts)


## Pay the first alternative the stores can meet in full, else the last one as far as the stores go.
func _pay(s, alternatives: Array) -> void:
	if alternatives.is_empty():
		return
	var chosen: Dictionary = alternatives[alternatives.size() - 1]
	for alt in alternatives:
		var enough := true
		for id in alt:
			enough = enough and s.economy.inv.get(id, 0) >= alt[id]
		if enough:
			chosen = alt
			break
	for id in chosen:
		_lose(s, id, mini(int(chosen[id]), int(s.economy.inv.get(id, 0))))


## The Bloom takes `share` of each raw good in the stores.
func _take(s, share: float) -> void:
	for id in Data.SURGE_GOODS:
		var n := int(float(s.economy.inv.get(id, 0)) * share)
		if n > 0:
			_lose(s, id, n)


## Take `n` of `id` from the stores for the season, count it and float it over the Hearth.
func _lose(s, id: String, n: int) -> void:
	if n <= 0:
		return
	s.economy.inv[id] = int(s.economy.inv.get(id, 0)) - n
	s.economy.note(id, -float(n), "season")
	spent[id] = int(spent.get(id, 0)) + n
	pops.append("-%d %s" % [n, Data.ITEMS[id]["name"]])
	if pops.size() > 12:  # nothing draws them in a headless run: keep the list short
		pops.pop_front()


func _end(s) -> void:
	s.events.append(Data.SEASONS[kind]["over"] + ("" if spent.is_empty() else " It cost " + spent_text() + " in all."))
	last = kind
	left = 0.0
	phase = "idle"
	kind = ""
	answer = -1
	spent = {}


## An answer that burns fuel: the town burns a unit every few seconds (the first fuel with any stock).
func _burn_fuel(s, delta: float) -> void:
	var fuels: Array = option().get("drain", [])
	if fuels.is_empty():
		return
	_burn += delta
	if _burn < Data.COLD_BURN_SECONDS:
		return
	_burn -= Data.COLD_BURN_SECONDS
	for id in fuels:
		if s.economy.inv.get(id, 0) > 0:
			_lose(s, id, 1)
			return


## Push the Economy's season switches: they are derived from this block every tick (and once after a load), so they are not saved with it.
func push_to_economy(s) -> void:
	var o := option() if phase == "active" else {}
	s.economy.eat_factor = float(o.get("eat", 1.0))
	s.economy.births_paused = o.get("births", false)
	s.economy.forage_call = o.get("forage", false)
	s.economy.forage_mult = Data.FORAGE_MULT if o.get("forage", false) else 1


## The share of its pace a building works at now: the kind's and the answer's paces for each group the building is in.
func speed_factor(_s, b: Dictionary) -> float:
	if phase != "active":
		return 1.0
	var def: Dictionary = Data.SEASONS[kind]
	var o := option()
	var factor := 1.0
	for g in _groups(b):
		factor *= float(def["pace"].get(g, 1.0)) * float(o.get("pace", {}).get(g, 1.0))
	return factor


## The pace groups building b is in: food, workshops (a processor), fields, mines, and every building.
func _groups(b: Dictionary) -> Array:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var out: Array = ["all"]
	if _makes_food(b):
		out.append("food")
	if def["kind"] == "processor":
		out.append("workshops")
	if def["kind"] == "field":
		out.append("fields")
	if b["type"] in Data.MINE_TYPES:
		out.append("mines")
	return out


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
	return float(option().get("tide", 1.0)) if phase == "active" else 1.0


## True while a Bloom surge that was let come is on: nothing is lost to overgrowth in it.
func keeps_buildings() -> bool:
	return phase == "active" and option().get("keeps", false)


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
		"used": used,
		"spent": spent,
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
	used = d.get("used", [])
	spent = {}
	for id in d.get("spent", {}):
		spent[String(id)] = int(d["spent"][id])
	_waited = float(d.get("waited", 0.0))
	_burn = float(d.get("burn", 0.0))
