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


## Every tech the player can see: all of them once the Strange Stone is clicked, otherwise all but hidden ones.
static func visible_techs(shard_seen: bool) -> Dictionary:
	var out := {}
	for tech in Data.TECHS:
		if shard_seen or not Data.TECHS[tech].get("hidden", false):
			out[tech] = true
	return out
