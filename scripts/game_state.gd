extends RefCounted
## The whole simulation: map, stockpile, tech, buildings. No rendering here,
## so it can run headless in tests.

const Data = preload("res://scripts/data.gd")

const WIDTH := 36
const HEIGHT := 22
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var tiles: Array = []  # flat array of tile ids, index = y * WIDTH + x
var inv: Dictionary = {}
var researched: Dictionary = {}
var buildings: Array = []  # each: {type, pos, progress, inbuf, out, status, gather_items, gather_index}
var building_at: Dictionary = {}  # Vector2i -> index into buildings
var camp_pos := Vector2i.ZERO
var shard_pos := Vector2i(-1, -1)
var food_credit := 5.0
var won := false
var starving := false
var food_use := 0.0  # food eaten per second right now
var seen: Dictionary = {}  # items the player has ever held, so the top bar keeps showing them
var goals_done: Dictionary = {}
var events: Array = []  # messages for the UI to show and clear


func _init() -> void:
	for id in Data.ITEM_ORDER:
		inv[id] = 0
	inv["berries"] = 10
	for id in ["wood", "stone", "flint", "berries"]:
		seen[id] = true


# --- Map ---------------------------------------------------------------------


func generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	tiles.clear()
	tiles.resize(WIDTH * HEIGHT)
	tiles.fill("grass")

	# A meandering river down the right third of the map, with gravel and clay banks.
	var rx := int(WIDTH * 0.7)
	for y in HEIGHT:
		rx = clampi(rx + rng.randi_range(-1, 1), int(WIDTH * 0.6), WIDTH - 4)
		_set_tile(Vector2i(rx, y), "river")
		_set_tile(Vector2i(rx + 1, y), "river")
		for side in [Vector2i(rx - 1, y), Vector2i(rx + 2, y)]:
			var roll := rng.randf()
			if roll < 0.25:
				_set_tile(side, "gravel")
			elif roll < 0.5:
				_set_tile(side, "clay")

	_scatter(rng, "tree", 7, 3, 0.75)
	_scatter(rng, "rock", 5, 2, 0.7)
	_scatter(rng, "berry", 4, 1, 0.8)
	_scatter(rng, "grain", 4, 2, 0.7)

	# Clear the Camp and the ground around it.
	camp_pos = Vector2i(int(WIDTH / 3.0), int(HEIGHT / 2.0))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := camp_pos + Vector2i(dx, dy)
			if in_bounds(p) and tile_at(p) != "river":
				_set_tile(p, "grass")
	# Guarantee every resource near the Camp so the opening never stalls.
	_set_tile(camp_pos + Vector2i(-3, -1), "tree")
	_set_tile(camp_pos + Vector2i(-3, 0), "tree")
	_set_tile(camp_pos + Vector2i(3, 2), "rock")
	_set_tile(camp_pos + Vector2i(-2, 3), "berry")
	_set_tile(camp_pos + Vector2i(2, -3), "grain")
	_place_building("camp", camp_pos)

	# One ancient star shard, far from home.
	for attempt in 200:
		var p := Vector2i(rng.randi_range(1, WIDTH - 2), rng.randi_range(1, HEIGHT - 2))
		if tile_at(p) == "grass" and p.distance_to(camp_pos) > 10 and not building_at.has(p):
			_set_tile(p, "shard")
			shard_pos = p
			break


func _scatter(rng: RandomNumberGenerator, tile: String, count: int, radius: int, density: float) -> void:
	for i in count:
		var c := Vector2i(rng.randi_range(0, WIDTH - 1), rng.randi_range(0, HEIGHT - 1))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var p := c + Vector2i(dx, dy)
				if in_bounds(p) and tile_at(p) == "grass" and rng.randf() < density:
					_set_tile(p, tile)


func _set_tile(p: Vector2i, tile: String) -> void:
	if in_bounds(p):
		tiles[p.y * WIDTH + p.x] = tile


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < WIDTH and p.y < HEIGHT


func tile_at(p: Vector2i) -> String:
	if not in_bounds(p):
		return ""
	return tiles[p.y * WIDTH + p.x]


# --- Stockpile ---------------------------------------------------------------


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if inv.get(id, 0) < cost[id]:
			return false
	return true


func pay(cost: Dictionary) -> void:
	for id in cost:
		inv[id] -= cost[id]


func add(id: String, amount: int) -> void:
	inv[id] = inv.get(id, 0) + amount
	seen[id] = true


## "need 10 Clay, 3 Rope" for whatever the stockpile is short of, or "" if affordable.
func shortfall_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		var short: int = cost[id] - inv.get(id, 0)
		if short > 0:
			parts.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return "" if parts.is_empty() else "need " + ", ".join(parts)


func hand_yield() -> int:
	return 2 if inv.get("flint_tools", 0) > 0 else 1


func gather_by_hand(p: Vector2i) -> String:
	var tile := tile_at(p)
	if tile == "shard":
		return Data.SHARD_TEXT
	if tile == "":
		return ""
	var item: String = Data.TILES[tile]["yields"]
	if item == "":
		return ""
	var n := hand_yield()
	add(item, n)
	return "+%d %s" % [n, Data.ITEMS[item]["name"]]


# --- Tech --------------------------------------------------------------------


func requirements_met(tech: String) -> bool:
	for r in Data.TECHS[tech]["requires"]:
		if not researched.has(r):
			return false
	return true


func can_research(tech: String) -> bool:
	return not researched.has(tech) and requirements_met(tech) and can_afford(Data.TECHS[tech]["cost"])


func research(tech: String) -> bool:
	if not can_research(tech):
		return false
	pay(Data.TECHS[tech]["cost"])
	researched[tech] = true
	events.append("Discovered %s" % Data.TECHS[tech]["name"])
	if tech == "bronze_dawn":
		won = true
	return true


func has_haulers() -> bool:
	return researched.has("haulers")


# --- Crafting ----------------------------------------------------------------


func recipe_unlocked(recipe: String) -> bool:
	return researched.has(Data.RECIPES[recipe]["tech"])


func craft(recipe: String) -> bool:
	var r: Dictionary = Data.RECIPES[recipe]
	if not recipe_unlocked(recipe) or not can_afford(r["in"]):
		return false
	pay(r["in"])
	for id in r["out"]:
		add(id, r["out"][id])
	return true


# --- Buildings ---------------------------------------------------------------


func building_unlocked(type: String) -> bool:
	var tech: String = Data.BUILDINGS[type]["tech"]
	return tech == "" or researched.has(tech)


## Returns "" if the building can go here, otherwise the reason it can't.
func placement_error(type: String, p: Vector2i) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	if not building_unlocked(type):
		return "Not discovered yet"
	if not in_bounds(p) or building_at.has(p):
		return "Something is already there"
	if not Data.TILES[tile_at(p)]["buildable"]:
		return "Build on open grassland"
	if def.get("needs_river", false) and not touches_river(p):
		return "Must touch the river"
	if not can_afford(def["cost"]):
		return "Not enough materials"
	return ""


func place(type: String, p: Vector2i) -> bool:
	if placement_error(type, p) != "":
		return false
	pay(Data.BUILDINGS[type]["cost"])
	_place_building(type, p)
	return true


func _place_building(type: String, p: Vector2i) -> void:
	var b := {
		"type": type,
		"pos": p,
		"progress": 0.0,
		"inbuf": {},
		"out": {},
		"status": "",
		"gather_items": [],
		"gather_index": 0,
	}
	if Data.BUILDINGS[type]["kind"] == "gatherer":
		for t in gather_tiles(p):
			b["gather_items"].append(Data.TILES[tile_at(t)]["yields"])
		if b["gather_items"].is_empty():
			b["gather_items"].append("fiber")  # nothing else nearby: it cuts grass
	building_at[p] = buildings.size()
	buildings.append(b)


## Resource tiles a Gatherer's Hut at p would work (grass only if there is nothing else).
func gather_tiles(p: Vector2i) -> Array:
	var r: int = Data.BUILDINGS["gatherers_hut"]["radius"]
	var found: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tile_at(p + Vector2i(dx, dy))
			if t != "" and t != "grass" and Data.TILES[t]["yields"] != "":
				found.append(p + Vector2i(dx, dy))
	return found


func touches_river(p: Vector2i) -> bool:
	for n in NEIGHBORS:
		if tile_at(p + n) == "river":
			return true
	return false


func is_powered(p: Vector2i) -> bool:
	for b in buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var bp: Vector2i = b["pos"]
		if def["kind"] == "power" and Vector2(bp).distance_to(Vector2(p)) <= def["radius"]:
			return true
	return false


func buffered(dict: Dictionary) -> int:
	var total := 0
	for id in dict:
		total += dict[id]
	return total


## Carry by hand: empty the building's output and load its inputs from the stockpile.
func haul(index: int) -> void:
	var b: Dictionary = buildings[index]
	for id in b["out"]:
		add(id, b["out"][id])
	b["out"].clear()
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "processor":
		for id in def["in"]:
			var want: int = def["in"][id] * 2 - b["inbuf"].get(id, 0)
			var take: int = mini(want, inv.get(id, 0))
			if take > 0:
				inv[id] -= take
				b["inbuf"][id] = b["inbuf"].get(id, 0) + take


func food_total() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		total += inv.get(id, 0) * Data.FOOD_VALUE[id]
	return total


# --- Simulation --------------------------------------------------------------


func tick(delta: float) -> void:
	if won:
		return
	if has_haulers():
		for i in buildings.size():
			haul(i)

	var active := 0
	for b in buildings:
		if _wants_to_work(b):
			active += 1
	food_use = active * Data.FOOD_PER_BUILDING_PER_SEC
	var fed := _eat(food_use * delta)
	starving = not fed

	for g in Data.GOALS:
		if not goals_done.has(g["id"]) and goal_met(g["id"]):
			goals_done[g["id"]] = true

	for b in buildings:
		_tick_building(b, delta, fed)


func _eat(need: float) -> bool:
	while food_credit < need:
		if inv.get("berries", 0) > 0:
			inv["berries"] -= 1
			food_credit += Data.FOOD_VALUE["berries"]
		elif inv.get("flour", 0) > flour_reserve():
			inv["flour"] -= 1
			food_credit += Data.FOOD_VALUE["flour"]
		else:
			return false
	food_credit -= need
	return true


## Flour kept back for research, so buildings don't eat the Bronze Dawn cost.
func flour_reserve() -> int:
	var keep := 0
	for tech in Data.TECHS:
		if not researched.has(tech):
			keep += Data.TECHS[tech]["cost"].get("flour", 0)
	return keep


# --- Goals -------------------------------------------------------------------


func has_building(type: String) -> bool:
	for b in buildings:
		if b["type"] == type:
			return true
	return false


func goal_met(id: String) -> bool:
	match id:
		"gather":
			return inv["wood"] >= 10 and inv["stone"] >= 10 and inv["flint"] >= 5 or researched.has("knapping")
		"knapping":
			return researched.has("knapping")
		"tools":
			return inv.get("flint_tools", 0) > 0
		"hut_tech":
			return researched.has("gatherers_hut")
		"hut":
			return has_building("gatherers_hut")
		"berries":
			for b in buildings:
				if "berries" in b["gather_items"]:
					return true
			return false
		"charcoal":
			return has_building("charcoal_pit")
		"twine":
			return has_building("twine_post")
		"haulers":
			return researched.has("haulers")
		"kiln":
			return has_building("kiln")
		"wheel":
			return has_building("water_wheel")
		"grind":
			for b in buildings:
				if b["type"] == "grindstone" and is_powered(b["pos"]):
					return true
			return false
		"bronze":
			return won
	return false


## Index into Data.GOALS of the first goal not yet done, or GOALS.size() when all are.
func current_goal() -> int:
	for i in Data.GOALS.size():
		if not goals_done.has(Data.GOALS[i]["id"]):
			return i
	return Data.GOALS.size()


func _wants_to_work(b: Dictionary) -> bool:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"gatherer":
			return buffered(b["out"]) < Data.BUFFER_CAP
		"processor":
			if def.get("needs_power", false) and not is_powered(b["pos"]):
				return false
			for id in def["in"]:
				if b["inbuf"].get(id, 0) < def["in"][id]:
					return false
			return buffered(b["out"]) < Data.BUFFER_CAP
	return false


func _tick_building(b: Dictionary, delta: float, fed: bool) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "camp" or def["kind"] == "power":
		b["status"] = def["desc"]
		return
	if not _wants_to_work(b):
		b["status"] = _idle_reason(b, def)
		return
	if not fed:
		b["status"] = "Hungry: bring berries or flour"
		return
	b["status"] = "Working"
	b["progress"] += delta
	if b["progress"] < def["time"]:
		return
	b["progress"] = 0.0
	if def["kind"] == "gatherer":
		var items: Array = b["gather_items"]
		var item: String = items[b["gather_index"] % items.size()]
		b["gather_index"] += 1
		b["out"][item] = b["out"].get(item, 0) + 1
	else:
		for id in def["in"]:
			b["inbuf"][id] -= def["in"][id]
		for id in def["out"]:
			b["out"][id] = b["out"].get(id, 0) + def["out"][id]


func _idle_reason(b: Dictionary, def: Dictionary) -> String:
	if buffered(b["out"]) >= Data.BUFFER_CAP:
		return "Full: click to collect" if not has_haulers() else "Full"
	if def.get("needs_power", false) and not is_powered(b["pos"]):
		return "No power: build a Water Wheel nearby"
	var missing: Array = []
	for id in def.get("in", {}):
		if b["inbuf"].get(id, 0) < def["in"][id]:
			missing.append(Data.ITEMS[id]["name"])
	if missing.is_empty():
		return "Idle"
	var how := "click to load" if not has_haulers() else "stockpile is out"
	return "Needs %s (%s)" % [", ".join(missing), how]
