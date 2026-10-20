extends RefCounted
## What a player is handed at a stage start (design-system/21-stage-starts.md). The bots that make the starts pause a building
## whenever its goods are in surplus, so a start used to arrive with dozens of buildings paused and most Kith idle. Here every
## paused building is put back to work, and then, once Paths & Haulers is known, the most overstocked workshops and huts are
## paused again, only until a third of the Kith are free to haul: with every Kith in a job the haulers are too few for the map
## and the whole economy crawls (a retest played it with 16 haulers and iron came at a sixth of the pace).

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")

## The share of the Kith kept free to haul once haulers are known.
const HAULER_SHARE := 0.35


## Resume what the bot paused, give a third of the Kith back to hauling, and take up the roads no building uses. Changes only
## paused flags, who works where and unused road tiles.
static func tidy(s) -> void:
	_prune_roads(s)
	var resumed: Array = []
	for i in s.town.buildings.size():
		if s.town.buildings[i]["paused"]:
			s.set_paused(i, false)
			resumed.append(i)
	s.people.assign_jobs()
	if not s.tech_tree.researched.has("haulers"):
		return
	var want := ceili(s.people.kith.size() * HAULER_SHARE)
	var order := resumed.filter(func(i): return _stocked(s, s.town.buildings[i]) > 0)
	order.sort_custom(func(a, b): return _stocked(s, s.town.buildings[a]) > _stocked(s, s.town.buildings[b]))
	for i in order:
		if hauling(s) >= want:
			break
		s.set_paused(i, true)
		s.people.assign_jobs()


## How many Kith are hauling now.
static func hauling(s) -> int:
	var n := 0
	for k in s.people.kith:
		if k["job"] == "haul":
			n += 1
	return n


## What the stockpile holds of what building `b` makes (a hut's focus, a workshop's output), 0 for a building that makes no stock.
static func _stocked(s, b: Dictionary) -> int:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "gatherer":
		return s.economy.inv.get(b["focus"], 0) if b["focus"] != "" else 0
	if def["kind"] == "processor" and def.has("out") and not def["out"].is_empty():
		return s.economy.inv.get(def["out"].keys()[0], 0)
	return 0


## The bots lay a lattice of roads to reach everything; a town a person built has the roads its buildings use. Keeps every road
## tile on the way from a linked building to its depot, and every bridge and rail, and takes up the rest. If that would unlink a
## building that was linked, nothing is changed.
static func _prune_roads(s) -> void:
	var keep := Roads.needed_tiles(s)
	var linked: Array = []
	for b in s.town.buildings:
		if Roads.linked(s, b):
			linked.append(b)
	var removed := {}
	for p in s.world.roads.keys():
		if keep.has(p) or s.world.tile_at(p) == "river" or s.world.stone_bridges.has(p):
			continue
		var tier: int = s.world.road_tier(p)
		if tier == Data.RAIL_TIER:
			continue
		removed[p] = tier
		s.world.remove_road(p)
	s.town.road_rev += 1
	for b in linked:
		if not Roads.linked(s, b):  # a route the walk did not take was the only link: put every tile back
			for p in removed:
				s.world.roads[p] = true
				s.world.set_road_tier(p, removed[p])
			s.town.road_rev += 1
			return
	for p in removed:
		s.pathing.update_cell(p)
