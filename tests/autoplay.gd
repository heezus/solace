extends RefCounted
## A headless player for pacing. It plays the stone age through GameState the way a person would:
## it clicks resources by hand early on, crafts Flint Tools, sets Bronze Dawn as the research goal
## (the queue researches each tech on the way as soon as it's affordable), places huts next to what
## the next techs need, workshops by the Hearth, dwellings when the Kith run out of room, fields once
## Farming is in, and roads to far buildings once Paths & Haulers is in.
## play() returns {"won", "seconds", "log"}; run_tests.gd checks the time and prints it.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Research = preload("res://scripts/research.gd")
const Rules = preload("res://scripts/rules.gd")

const DT := 0.1
const THINK := 1.0  # seconds between decisions
## Clicks a second: brisk while gathering by hand is the main way to get anything, easing off once
## haulers carry for you.
const CLICKS_EARLY := 1.0
const CLICKS_LATE := 0.4
const RAW_TILE := {
	"wood": "tree",
	"stone": "rock",
	"flint": "gravel",
	"fiber": "grass",
	"clay": "clay",
	"berries": "berry",
	"grain": "grain",
}
## Which workshop makes each made good.
const MAKER := {"rope": "twine_post", "charcoal": "charcoal_pit", "brick": "kiln", "flour": "grindstone"}

var s: GameState
var clock := 0.0
var clicks := 0.0
var think := 0.0
var log: Array = []
var known := {}  # techs already logged
var trace := false  # log what the next tech is waiting on, every minute
var clicked := {}  # what the clicks went to since the last trace
var reach := {}  # tiles the Kith can walk to from the Hearth, refreshed each decision


func play(seed: int, max_seconds: float) -> Dictionary:
	s = GameState.new()
	s.generate(seed)
	Research.set_goal(s, "bronze_dawn")
	while clock < max_seconds and not s.won:
		s.tick(DT)
		clock += DT
		s.events.clear()
		_log_research()
		clicks += DT * (CLICKS_LATE if s.has_haulers() else CLICKS_EARLY)
		if trace and fmod(clock, 60.0) < DT - 0.001:
			_trace()
		think -= DT
		if think <= 0.0:
			think = THINK
			_decide()
		while clicks >= 1.0:
			clicks -= 1.0
			_click()
	return {"won": s.won, "seconds": clock, "log": log}


func _log_research() -> void:
	for tech in s.researched:
		if not known.has(tech):
			known[tech] = true
			log.append("%5.0f s  %s  (Kith %d)" % [clock, Data.TECHS[tech]["name"], s.kith.size()])


func _trace() -> void:
	var next: String = s.research_queue[0] if not s.research_queue.is_empty() else ""
	var missing := {}
	if next != "":
		var cost: Dictionary = Data.TECHS[next]["cost"]
		for id in cost:
			if s.inv.get(id, 0) < cost[id]:
				missing[id] = "%d/%d" % [s.inv.get(id, 0), cost[id]]
	log.append(
		(
			"%5.0f s  .. next %s missing %s  Kith %d, workers %d, clicks %s"
			% [clock, next, missing, s.kith.size(), _workers(), clicked]
		)
	)
	clicked = {}


# --- What we're short of -----------------------------------------------------


## Items the next few queued techs (and the next hut) still need, with made goods broken down into
## what they're made of.
func _short() -> Dictionary:
	if s.research_goal == "" and not s.won:
		Research.set_goal(s, "bronze_dawn")
	var want := {}
	for tech in s.research_queue.slice(0, 3):
		_want(want, Data.TECHS[tech]["cost"], 1)
	if s.building_unlocked("gatherers_hut") and _workers() < s.kith.size():
		_want(want, Data.BUILDINGS["gatherers_hut"]["cost"], 1)
	if _house_wanted():
		_want(want, Data.BUILDINGS["dwelling"]["cost"], 1)
	for type in _workshops_due():
		_want(want, Data.BUILDINGS[type]["cost"], 1)
	var tools: int = _workers() + 1 - s.tools_held() - s.inv.get("flint_tools", 0)
	if s.recipe_unlocked("flint_tools") and tools > 0:
		_want(want, Data.RECIPES["flint_tools"]["in"], mini(tools, 2))
	for made in ["flour", "brick", "charcoal", "rope"]:
		var n: int = want.get(made, 0) - s.inv.get(made, 0)
		if n > 0:
			_want(want, Data.BUILDINGS[MAKER[made]]["in"], n)
	var short := {}
	for id in want:
		var n: int = want[id] - s.inv.get(id, 0)
		if n > 0:
			short[id] = n
	if s.food_total() < s.kith.size() * 4.0:
		short["berries"] = short.get("berries", 0) + 10
	return short


## Made goods the whole route to Bronze Dawn still costs: they take a workshop and time, so the
## workshops go up as soon as they're unlocked.
func _route_need() -> Dictionary:
	var need := {}
	for tech in Rules.route_to("bronze_dawn", s.researched, Rules.visible_techs(s.shard_seen)):
		var cost: Dictionary = Data.TECHS[tech]["cost"]
		for id in cost:
			if MAKER.has(id):
				need[id] = need.get(id, 0) + cost[id]
	for made in ["flour", "brick", "charcoal", "rope"]:
		var left: int = need.get(made, 0) - s.inv.get(made, 0)
		var inputs: Dictionary = Data.BUILDINGS[MAKER[made]]["in"]
		for id in inputs:
			if MAKER.has(id) and left > 0:
				need[id] = need.get(id, 0) + left * inputs[id]
	return need


func _want(want: Dictionary, cost: Dictionary, times: int) -> void:
	for id in cost:
		want[id] = want.get(id, 0) + cost[id] * times


## What to gather by hand: the first queued tech that's missing something we can reach decides it
## (the most-missing raw good behind it), so the next tech comes as soon as it can.
func _next_click() -> String:
	var costs: Array = []
	if s.building_unlocked("gatherers_hut") and _workers() + _haulers_wanted() < s.kith.size():
		costs.append(Data.BUILDINGS["gatherers_hut"]["cost"])
	if _house_wanted():
		costs.append(Data.BUILDINGS["dwelling"]["cost"])
	for tech in s.research_queue:
		if s.requirements_met(tech):
			costs.append(Data.TECHS[tech]["cost"])
	for cost in costs:
		var want := {}
		_want(want, cost, 1)
		for made in ["flour", "brick", "charcoal", "rope"]:
			var n: int = want.get(made, 0) - s.inv.get(made, 0)
			if n > 0:
				_want(want, Data.BUILDINGS[MAKER[made]]["in"], n)
		var short := {}
		for id in want:
			if want[id] > s.inv.get(id, 0):
				short[id] = want[id] - s.inv.get(id, 0)
		var item := _most_short_raw(short)
		if item != "":
			return item
	return _most_short_raw(_short())


## The raw good we're shortest of that can be reached by hand right now.
func _most_short_raw(short: Dictionary) -> String:
	var best := ""
	for id in RAW_TILE:
		if _nearest_tile(RAW_TILE[id], s.camp_pos).x < 0:
			continue
		if short.has(id) and (best == "" or short[id] > short[best]):
			best = id
	return best


# --- Clicks ------------------------------------------------------------------


## One click: collect from a full building before haulers, craft a tool, or gather what's shortest.
func _click() -> void:
	if not s.has_haulers():
		for i in s.buildings.size():
			var b: Dictionary = s.buildings[i]
			var def: Dictionary = Data.BUILDINGS[b["type"]]
			var hungry := false
			if def["kind"] == "processor" and not b["paused"] and s.can_afford(def["in"]):
				for id in def["in"]:
					hungry = hungry or b["inbuf"].get(id, 0) < def["in"][id]
			if s.buffered(b["out"]) >= 5 or hungry:
				s.haul(i)
				return
	if s.recipe_unlocked("flint_tools") and s.tools_held() + s.inv.get("flint_tools", 0) < _workers() + 1:
		if s.inv.get("flint", 0) >= 2 and s.inv.get("wood", 0) >= 2 and s.craft("flint_tools"):
			return
	var item := _next_click()
	# Kith are born only with food to spare, so keep some while there's room for them.
	var room := s.kith.size() < s.housing()
	if s.food_total() < s.kith.size() * 2.0 + (Data.BIRTH_FOOD + 3.0 if room else 2.0):
		item = "berries"
	if item == "":
		item = "stone" if s.inv.get("stone", 0) < s.inv.get("wood", 0) else "wood"
	var p := _nearest_tile(RAW_TILE[item], s.camp_pos)
	if p.x >= 0:
		s.gather_by_hand(p)
		clicked[item] = clicked.get(item, 0) + 1


func _nearest_tile(tile: String, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == tile and s.fog.is_revealed(p) and not s.building_at.has(p):
				var d := Vector2(p).distance_to(Vector2(from))
				if d < best_d:
					best = p
					best_d = d
	return best


# --- Building ----------------------------------------------------------------


## Workshops the route needs that aren't built yet (and can be), so their cost gets gathered.
func _workshops_due() -> Array:
	var out: Array = []
	var later := _route_need()
	for made in MAKER:
		var type: String = MAKER[made]
		if later.get(made, 0) > s.inv.get(made, 0) and s.building_unlocked(type) and _count(type) == 0:
			out.append(type)
	return out


## Out of room, and short of hands for the buildings plus a couple spare.
func _house_wanted() -> bool:
	return s.kith.size() >= s.housing() and _workers() + _haulers_wanted() + 3 > s.kith.size()


## Once Paths & Haulers is in, keep a few Kith free to carry: one for every four buildings.
func _haulers_wanted() -> int:
	return 1 + int(_workers() / 4.0) if s.has_haulers() else 0


## A Storehouse by any workshop or hut far from a stockpile, so haulers fetch and drop off nearby.
func _place_storehouse() -> bool:
	for b in s.buildings:
		if not s.needs_worker(b):
			continue
		var depot: Vector2i = s._nearest_depot(b["pos"])
		if Vector2(depot).distance_to(Vector2(b["pos"])) > 6.0:
			var at: Vector2i = b["pos"]
			return _place_best("storehouse", func(p): return -Vector2(p).distance_to(Vector2(at)))
	return false


func _workers() -> int:
	var n := 0
	for b in s.buildings:
		if s.needs_worker(b):
			n += 1
	return n


func _count(type: String) -> int:
	var n := 0
	for b in s.buildings:
		if b["type"] == type:
			n += 1
	return n


## Huts whose range holds `item` (or open-grass huts, for Fiber).
func _huts_for(item: String) -> int:
	var n := 0
	for b in s.buildings:
		if b["type"] == "gatherers_hut" and item in b["gather_items"]:
			n += 1
	return n


## One placement a decision, most urgent first.
func _decide() -> void:
	_flood_reach()
	var short := _short()
	var later := _route_need()
	_pause_surplus(short, later)
	if _house_wanted() and s.food_total() >= s.kith.size() * 2.0 + Data.BIRTH_FOOD:
		if _place_near_hearth("dwelling"):
			return
	if s.has_haulers() and _place_storehouse():
		return
	if _explore(short):
		return
	if _water_wheel():
		return
	if _workers() + _haulers_wanted() >= s.kith.size() + 1:
		return
	if s.building_unlocked("gatherers_hut"):
		if _huts_for("berries") < 1 + int(s.kith.size() / 6.0):
			if _place_hut("berries"):
				return
		for item in ["wood", "stone", "fiber", "flint", "clay", "grain"]:
			var n: int = short.get(item, 0)
			var want := 0 if n <= 0 else 1 + mini(int(n / 30.0), 2)
			if item in ["wood", "stone"]:
				want = maxi(want, 1)
			if _huts_for(item) < want and _place_hut(item):
				return
	for made in MAKER:
		var n: int = short.get(made, 0)
		if s.has_haulers():  # before haulers every workshop costs clicks to feed, so only build what's due
			n = maxi(n, later.get(made, 0) - s.inv.get(made, 0))
		var type: String = MAKER[made]
		if n > 0 and s.building_unlocked(type) and _count(type) < 1 + mini(int(n / 30.0), 1):
			if _place_workshop(type):
				return
	if s.building_unlocked("field") and _count("field") < 8 and short.get("grain", 0) > 0 and _place_field():
		return
	if s.has_haulers() and not short.has("stone"):
		_lay_roads()


## When something we need lies only out in the fog (Clay on the river banks), build a hut at the
## edge of what we can see, on the side where it lies, to see farther.
func _explore(short: Dictionary) -> bool:
	for id in short:
		if not RAW_TILE.has(id) or _nearest_tile(RAW_TILE[id], s.camp_pos).x >= 0:
			continue
		var target := _nearest_hidden(RAW_TILE[id])
		if target.x >= 0:
			return _explore_to(target)
	return false


## Push the edge of what we can see toward `target`: a few road tiles once there are roads (each one
## lifts the fog around it), or a hut before that.
func _explore_to(target: Vector2i) -> bool:
	var score := func(p): return -Vector2(p).distance_to(Vector2(target))
	if not s.building_unlocked("road"):
		return _place_best("gatherers_hut", score)
	var laid := false
	for i in 3:
		if not _place_best("road", score):
			break
		laid = true
	return laid


## The river-bank grass tile nearest the Hearth, seen or not, for the Water Wheel.
func _nearest_bank() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == "grass" and s.touches_river(p) and not s.building_at.has(p):
				var d := Vector2(p).distance_to(Vector2(s.camp_pos))
				if d < best_d:
					best = p
					best_d = d
	return best


func _nearest_hidden(tile: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == tile:
				var d := Vector2(p).distance_to(Vector2(s.camp_pos))
				if d < best_d:
					best = p
					best_d = d
	return best


## Pause workshops whose goods pile up unneeded (and so stop eating their inputs), or that eat what
## the next Dwelling needs; resume them after.
func _pause_surplus(short: Dictionary, later: Dictionary) -> void:
	var saving := {}
	if _house_wanted():
		var house: Dictionary = Data.BUILDINGS["dwelling"]["cost"]
		for id in house:
			if s.inv.get(id, 0) < house[id]:
				saving[id] = true
	for i in s.buildings.size():
		var b: Dictionary = s.buildings[i]
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] != "processor":
			continue
		var made: String = def["out"].keys()[0]
		var surplus: bool = s.inv.get(made, 0) >= later.get(made, 0) + 10 and not short.has(made)
		for id in def["in"]:
			surplus = surplus or saving.has(id)
		if surplus != b["paused"]:
			s.set_paused(i, surplus)


func _place_near_hearth(type: String) -> bool:
	return _place_best(type, func(p): return -Vector2(p).distance_to(Vector2(s.camp_pos)))


## A hut where `item` is thickest in its range and little else is (open grass for Fiber).
func _place_hut(item: String) -> bool:
	var tile: String = RAW_TILE[item]
	return _place_best(
		"gatherers_hut",
		func(p):
			var mine := 0
			var other := 0
			for t in s.gather_tiles(p):
				if s.tile_at(t) == tile:
					mine += 1
				else:
					other += 1
			if item == "fiber":
				return -INF if mine + other > 0 else -Vector2(p).distance_to(Vector2(s.camp_pos))
			if mine == 0:
				return -INF
			return mine * 3.0 - other * 2.0 - Vector2(p).distance_to(Vector2(s.camp_pos))
	)


## Once the Water Wheel is researched, put one on the bank nearest the Hearth, exploring toward it
## first if the bank is still fogged.
func _water_wheel() -> bool:
	if not s.building_unlocked("water_wheel") or _count("water_wheel") > 0:
		return false
	return _place_wheel()


## A Water Wheel on the bank with room for workshops around it, near the Hearth; explore toward
## the nearest bank if none is in sight.
func _place_wheel() -> bool:
	if not s.can_afford(Data.BUILDINGS["water_wheel"]["cost"]):
		return false
	var radius: float = Data.BUILDINGS["water_wheel"]["radius"]
	var room_around := func(p):
		var n := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q: Vector2i = p + Vector2i(dx, dy)
				var open: bool = (
					s.tile_at(q) == "grass" and s.fog.is_revealed(q) and not s.building_at.has(q) and not s.roads.has(q)
				)
				if open and q != p and Vector2(q).distance_to(Vector2(p)) <= radius:
					n += 1
		return -INF if n < 2 else n * 2.0 - Vector2(p).distance_to(Vector2(s.camp_pos))
	if _place_best("water_wheel", room_around):
		return true
	var bank := _nearest_bank()
	return bank.x >= 0 and _explore_to(bank)


func _place_workshop(type: String) -> bool:
	if Data.BUILDINGS[type].get("needs_power", false):
		if _count("water_wheel") == 0:
			return false
		if not s.can_afford(Data.BUILDINGS[type]["cost"]):
			return false
		var placed := _place_best(
			type, func(p): return -Vector2(p).distance_to(Vector2(s.camp_pos)) if s.is_powered(p) else -INF
		)
		return placed or (_count("water_wheel") < 3 and _place_wheel())
	return _place_near_hearth(type)


## A Field within reach of a hut, so it gets harvested.
func _place_field() -> bool:
	return _place_best(
		"field",
		func(p):
			for b in s.buildings:
				if b["type"] == "gatherers_hut" and "grain" in b["gather_items"]:
					var d: Vector2i = (p - b["pos"]).abs()
					if maxi(d.x, d.y) <= s.hut_radius():
						return -Vector2(p).distance_to(Vector2(b["pos"]))
			return -INF
	)


## Every tile the Kith can walk to from the Hearth (the river blocks until it's bridged).
func _flood_reach() -> void:
	reach = {s.camp_pos: true}
	var todo: Array = [s.camp_pos]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for n in GameState.NEIGHBORS:
			var q: Vector2i = p + n
			if s.in_bounds(q) and not reach.has(q) and not s.astar.is_point_solid(q):
				reach[q] = true
				todo.append(q)


## Place `type` on the revealed tile with the best score (skipping -INF), if it can be afforded.
## Buildings go only where the Kith can walk; roads may push out from there.
func _place_best(type: String, score: Callable) -> bool:
	if not s.building_unlocked(type) or not s.can_afford(Data.BUILDINGS[type]["cost"]):
		return false
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if not reach.has(p) or s.placement_error(type, p) != "":
				continue
			var v: float = score.call(p)
			if v > best_score:
				best = p
				best_score = v
	if best.x < 0 or not s.place(type, best):
		return false
	log.append("%5.0f s    + %s at %s" % [clock, Data.BUILDINGS[type]["name"], best])
	return true


## Roads from each far worker building toward its stockpile, over grass, a few tiles a decision.
func _lay_roads() -> void:
	var budget := 3
	for b in s.buildings:
		if not s.needs_worker(b) or budget <= 0:
			continue
		var trip := s.trip_info(b["pos"])
		if not trip["ok"] or trip["seconds"] < 6.0:
			continue
		var path := s.astar.get_id_path(b["pos"], trip["depot"])
		for p in path:
			if budget <= 0 or s.inv.get("stone", 0) < 20:
				return
			if s.place("road", p):
				budget -= 1
