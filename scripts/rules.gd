extends RefCounted
## Small pure rules shared by the simulation, the UI and the auto-play test.

const Data = preload("res://scripts/data.gd")


## The tiles a drag from a to b covers: along the row first, then down the column.
static func line_tiles(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var x := a.x
	while x != b.x:
		out.append(Vector2i(x, a.y))
		x += signi(b.x - a.x)
	var y := a.y
	while y != b.y:
		out.append(Vector2i(b.x, y))
		y += signi(b.y - a.y)
	out.append(b)
	return out


## What a building gives back when torn down: half its cost, rounded down.
static func refund_of(type: String) -> Dictionary:
	var out := {}
	var cost: Dictionary = Data.BUILDINGS[type]["cost"]
	for id in cost:
		var n := floori(float(cost[id]) / 2.0)
		if n > 0:
			out[id] = n
	return out


## The techs still to research on the way to `tech`, parents before children, ending with `tech`.
## For an either-or, a parent already done ends it; otherwise it takes the branch with the shorter route.
## `researched` and `visible` map tech ids to true.
static func route_to(tech: String, researched: Dictionary, visible: Dictionary) -> Array:
	var out: Array = []
	_collect(tech, researched, visible, out)
	return out


static func _collect(tech: String, researched: Dictionary, visible: Dictionary, out: Array) -> void:
	if researched.has(tech) or tech in out:
		return
	var t: Dictionary = Data.TECHS[tech]
	for r in t["requires"]:
		_collect(r, researched, visible, out)
	var any: Array = t.get("requires_any", []).filter(func(r): return visible.has(r))
	if not any.is_empty() and not any.any(func(r): return researched.has(r)):
		var best: String = any[0]
		var best_n := 9999
		for r in any:
			var n := route_to(r, researched, visible).size()
			if n < best_n:
				best = r
				best_n = n
		_collect(best, researched, visible, out)
	out.append(tech)


## True when `tech`'s effect is built (its `stage` is not past Data.BUILT_STAGE): the only techs that can be researched.
static func tech_enabled(tech: String) -> bool:
	return int(Data.TECHS[tech].get("stage", 1)) <= Data.BUILT_STAGE


## The techs of era `era` (Data.TECHS `era`, 1 when it names none), in Data.TECH_ORDER.
static func era_techs(era: int) -> Array:
	return Data.TECH_ORDER.filter(func(t): return int(Data.TECHS[t].get("era", 1)) == era)


## Every tech the player can see: all of them once the Strange Stone is clicked, otherwise all but hidden ones.
static func visible_techs(shard_seen: bool) -> Dictionary:
	var out := {}
	for tech in Data.TECHS:
		if shard_seen or not Data.TECHS[tech].get("hidden", false):
			out[tech] = true
	return out


## The road tier building `type` lays: a road's own tier, the top tier for a Stone Bridge, 0 for the rest.
static func tier_of(type: String) -> int:
	var def: Dictionary = Data.BUILDINGS[type]
	return int(def.get("tier", Data.ROAD_SPEEDS.size() - 1 if def.get("stone", false) else 0))


## The road type that lays tier `tier` of a road (see Data.BUILDINGS `tier`).
static func road_type(tier: int) -> String:
	for type in Data.BUILD_ORDER:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["kind"] == "road" and int(def.get("tier", 0)) == tier:
			return type
	return "road"


## What is still owed for `cost` when `paid` has been spent already: the difference in each item, never below zero
## (what was paid in another item is not given back).
static func difference(cost: Dictionary, paid: Dictionary) -> Dictionary:
	var out := {}
	for id in cost:
		var owed: int = cost[id] - paid.get(id, 0)
		if owed > 0:
			out[id] = owed
	return out


## What building `type` costs on a tile: a Road on Rocks cuts a pass for PASS_COST (plus what its tier adds over a plain
## road), and laying over what stands there (`current`, a built_type of a road or bridge) costs only the difference
## from what it cost.
static func cost_at(type: String, tile: String, current := "") -> Dictionary:
	var cost: Dictionary = Data.BUILDINGS[type]["cost"]
	if current != "":
		return difference(cost, Data.BUILDINGS[current]["cost"])
	if Data.BUILDINGS[type]["kind"] == "road" and tile == "rock":
		var pass_cost: Dictionary = Data.PASS_COST.duplicate()
		var extra := difference(cost, Data.BUILDINGS["road"]["cost"])
		for id in extra:
			pass_cost[id] = pass_cost.get(id, 0) + extra[id]
		return pass_cost
	return cost


## The buildings a tech unlocks, in build order (Paths & Haulers gives the Road and the Wooden Bridge).
static func buildings_of(tech: String) -> Array:
	return Data.BUILD_ORDER.filter(func(type): return Data.BUILDINGS[type]["tech"] == tech)


## What is left of the stockpile `inv` after paying `cost`, for every item either holds (never below zero).
static func left_after(inv: Dictionary, cost: Dictionary) -> Dictionary:
	var out := {}
	for id in inv:
		out[id] = maxi(inv[id] - cost.get(id, 0), 0)
	for id in cost:
		if not out.has(id):
			out[id] = 0
	return out
