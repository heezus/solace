extends RefCounted
## The famine fallback. When the stockpile would run out within Data.FOOD_FAMINE_SECONDS (Economy.famine), every Kith
## with nothing to do goes out and picks berries by themselves: one who has no job, and the worker of a hut that is
## only waiting for a click. They walk to the nearest bush by the Hearth, pick for
## Data.FORAGE_TIME seconds, carry Data.FORAGE_YIELD berries to the nearest stockpile and go again, until the
## famine is over (the warning has come down, or their hut was clicked). It is a slow trickle: enough to keep the
## people fed, and it is noted under Data.FLOW_FORAGE_SOURCE, which is not food income, so it never makes anyone
## be born. Static, and works on the Sim passed in. A forager's state is in the Kith's own fields (phase "forage_*",
## and `task` = {kind: "forage", tile}), so it is saved with them.

const Data = preload("res://scripts/data.gd")
const Hands = preload("res://scripts/hands.gd")
const Roads = preload("res://scripts/roads.gd")


## One step for Kith `k`: returns true when they are foraging (so the caller leaves them alone this tick).
static func tick(s, k: Dictionary, delta: float) -> bool:
	if String(k["phase"]).begins_with("forage"):
		_step(s, k, delta)
		return true
	return s.economy.famine and eligible(s, k) and _start(s, k)


## True for a Kith with nothing to do: no job, or the worker of a gatherer hut that waits for a click.
static func eligible(s, k: Dictionary) -> bool:
	match k["job"]:
		"":
			return true
		"work":
			return k["phase"] == "home" and k["carry"].is_empty() and waiting(s, s.town.buildings[k["building"]])
	return false


## A gatherer hut that only works on clicked trips and has none queued.
static func waiting(s, b: Dictionary) -> bool:
	return (
		Data.BUILDINGS[b["type"]]["kind"] == "gatherer"
		and not b["paused"]
		and b["trips"] <= 0
		and not Roads.automated(s, b)
	)


## The nearest bush to the Hearth within Data.FORAGE_RADIUS that can be picked, or Vector2i(-1, -1).
static func bush(s) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var camp: Vector2i = s.world.camp_pos
	var r: int = Data.FORAGE_RADIUS
	for y in range(camp.y - r, camp.y + r + 1):
		for x in range(camp.x - r, camp.x + r + 1):
			var p := Vector2i(x, y)
			if not s.world.in_bounds(p) or Hands.item_at(s, p) != Data.FORAGE_ITEM:
				continue
			var d := Vector2(p).distance_to(Vector2(camp))
			if d < best_d and d <= r:
				best = p
				best_d = d
	return best


static func _start(s, k: Dictionary) -> bool:
	var tile := bush(s)
	if tile.x < 0 or not s.people.walk_to(k, tile):
		return false
	k["phase"] = "forage_out"
	k["task"] = {"kind": "forage", "tile": tile}
	k["timer"] = 0.0
	if not s.economy.forage_told:
		s.economy.forage_told = true
		s.events.append(Data.FORAGE_EVENT % Data.PEOPLE["many"])
	return true


static func _step(s, k: Dictionary, delta: float) -> void:
	if not s.economy.famine or (k["job"] == "work" and not waiting(s, s.town.buildings[k["building"]])):
		_end(s, k)
		return
	match k["phase"]:
		"forage_out":
			if s.people.step(k, delta):
				k["phase"] = "forage_pick"
				k["timer"] = 0.0
		"forage_pick":
			k["timer"] += delta
			if k["timer"] < Data.FORAGE_TIME:
				return
			k["carry"] = {Data.FORAGE_ITEM: Data.FORAGE_YIELD}
			if (
				Hands.item_at(s, k["task"]["tile"]) != Data.FORAGE_ITEM
				or not s.people.walk_to(k, s.people.nearest_depot(k["task"]["tile"]))
			):
				_end(s, k)
				return
			k["phase"] = "forage_back"
		"forage_back":
			if s.people.step(k, delta):
				_deliver(s, k)
				if not (s.economy.famine and eligible_after_trip(s, k) and _start(s, k)):
					_end(s, k)


## Still free to go out again after a trip: a hut worker is (they are still "on" their hut, so `eligible` can't say).
static func eligible_after_trip(s, k: Dictionary) -> bool:
	return k["job"] == "" or waiting(s, s.town.buildings[k["building"]])


static func _deliver(s, k: Dictionary) -> void:
	for id in k["carry"]:
		s.economy.add(id, k["carry"][id])
		s.economy.note(id, k["carry"][id], Data.FLOW_FORAGE_SOURCE)
	k["carry"] = {}


## Stop foraging: hand in what they carry, then walk back to the hut they work, or the Hearth.
static func _end(s, k: Dictionary) -> void:
	_deliver(s, k)
	k["task"] = {}
	k["timer"] = 0.0
	if k["job"] == "work":
		k["phase"] = "to_site"
		k["path"] = []
	else:
		k["phase"] = ""
		s.people.walk_to(k, s.world.camp_pos)
