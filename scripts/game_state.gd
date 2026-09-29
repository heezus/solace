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
var buildings: Array = []  # each: {type, pos, progress, inbuf, out, status, gather_items, gather_index, worker, ...}
var building_at: Dictionary = {}  # Vector2i -> index into buildings
var camp_pos := Vector2i.ZERO
var shard_pos := Vector2i(-1, -1)
var food_credit := 5.0
var won := false
var starving := false
var food_use := 0.0  # food eaten per second right now
var seen: Dictionary = {}  # items the player has ever held, so the top bar keeps showing them
var goals_done: Dictionary = {}
var roads: Dictionary = {}  # Vector2i -> true
## The Kith, each a person on the map:
## {pos: Vector2 (tile coords), path: Array of Vector2i, job: "" | "work" | "haul", building: int,
##  phase: String, timer: float, carry: Dictionary, task: Dictionary}
var kith: Array = []
var grow_timer := 0.0
var starve_timer := 0.0
var astar := AStarGrid2D.new()
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
	_build_walk_grid()
	kith.clear()
	for i in Data.KITH_START:
		_add_kith()

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
	if not in_bounds(p) or building_at.has(p) or roads.has(p):
		return "Something is already there"
	if def["kind"] == "road":
		if tile_at(p) != "grass" and tile_at(p) != "river":
			return "Roads go on grassland or across the river"
		return "" if can_afford(def["cost"]) else "Not enough materials"
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
	if Data.BUILDINGS[type]["kind"] == "road":
		roads[p] = true
		_update_walk_cell(p)
	else:
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
		"worker": -1,  # index into kith, or -1
		"claimed": false,  # a hauler is on its way to empty it
		"incoming": {},  # inputs haulers are carrying here
		"unreachable": 0.0,  # seconds left to show "can't reach"
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


# --- Walking -----------------------------------------------------------------


func _build_walk_grid() -> void:
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in HEIGHT:
		for x in WIDTH:
			_update_walk_cell(Vector2i(x, y))


func _update_walk_cell(p: Vector2i) -> void:
	var t := tile_at(p)
	astar.set_point_solid(p, t == "river" and not roads.has(p))
	astar.set_point_weight_scale(p, walk_cost(p))


## Relative time to cross a tile: roads are fast, forest and rocks are slow.
func walk_cost(p: Vector2i) -> float:
	if roads.has(p):
		return Data.WALK_COST["road"]
	return Data.WALK_COST.get(tile_at(p), 1.0)


func _tile_of(k: Dictionary) -> Vector2i:
	var pos: Vector2 = k["pos"]
	return Vector2i(roundi(pos.x), roundi(pos.y))


## Set a Kith walking to `to`. Returns false if there's no way there.
func _walk_to(k: Dictionary, to: Vector2i) -> bool:
	var from := _tile_of(k)
	if from == to:
		k["path"] = []
		return true
	if astar.is_point_solid(from):
		astar.set_point_solid(from, false)  # standing on a tile that was just blocked: allow stepping off
	var path := astar.get_id_path(from, to)
	_update_walk_cell(from)
	if path.is_empty():
		return false
	path.remove_at(0)
	k["path"] = Array(path)
	return true


## Move along the path. Returns true once there.
func _step(k: Dictionary, delta: float) -> bool:
	var budget := delta
	while budget > 0.0 and not k["path"].is_empty():
		var next: Vector2i = k["path"][0]
		var speed: float = Data.KITH_SPEED / walk_cost(next)
		var pos: Vector2 = k["pos"]
		var dist := pos.distance_to(Vector2(next))
		if dist <= speed * budget:
			k["pos"] = Vector2(next)
			budget -= dist / speed
			k["path"].remove_at(0)
		else:
			k["pos"] = pos.move_toward(Vector2(next), speed * budget)
			budget = 0.0
	return k["path"].is_empty()


# --- The Kith ------------------------------------------------------------------


func _add_kith() -> void:
	var k := {
		"pos": Vector2(camp_pos),
		"path": [],
		"job": "",
		"building": -1,
		"phase": "",
		"timer": 0.0,
		"carry": {},
		"task": {},
	}
	kith.append(k)


func housing() -> int:
	var total := 0
	for b in buildings:
		total += Data.BUILDINGS[b["type"]].get("housing", 0)
	return total


func idle_kith() -> int:
	var n := 0
	for k in kith:
		if k["job"] != "work":
			n += 1
	return n


func needs_worker(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]]["kind"] in ["gatherer", "processor"]


## Staff buildings in the order they were built. Everyone else hauls (once researched) or waits at camp.
func _assign_jobs() -> void:
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if not needs_worker(b) or b["worker"] >= 0:
			continue
		var pick := -1
		for j in kith.size():
			if kith[j]["job"] == "":
				pick = j
				break
		if pick < 0:
			for j in kith.size():
				if kith[j]["job"] == "haul":
					pick = j
					break
		if pick < 0:
			break
		var k: Dictionary = kith[pick]
		_drop_task(k)
		k["job"] = "work"
		k["building"] = i
		k["phase"] = "to_site"
		b["worker"] = pick
		_walk_to(k, b["pos"])
	for k in kith:
		if k["job"] == "" and has_haulers():
			k["job"] = "haul"
			k["phase"] = ""


## Put back whatever a hauler was carrying or had promised, so nothing is lost when plans change.
func _drop_task(k: Dictionary) -> void:
	for id in k["carry"]:
		add(id, k["carry"][id])
	k["carry"] = {}
	var t: Dictionary = k["task"]
	if not t.is_empty():
		var b: Dictionary = buildings[t["building"]]
		if t["kind"] == "pickup":
			b["claimed"] = false
		elif t["kind"] == "deliver":
			b["incoming"][t["item"]] = b["incoming"].get(t["item"], 0) - t["amount"]
	k["task"] = {}


func _remove_kith() -> void:
	var gone := kith.size() - 1
	for j in kith.size():
		if kith[j]["job"] != "work":
			gone = j
	var k: Dictionary = kith[gone]
	_drop_task(k)
	if k["job"] == "work":
		buildings[k["building"]]["worker"] = -1
	kith.remove_at(gone)
	for b in buildings:
		if b["worker"] > gone:
			b["worker"] -= 1
	events.append("A Kith left in search of food")


func _grow(delta: float, fed: bool) -> void:
	if not fed:
		starve_timer += delta
		grow_timer = 0.0
		if starve_timer >= Data.STARVE_TIME and kith.size() > 1:
			starve_timer = 0.0
			_remove_kith()
		return
	starve_timer = 0.0
	if kith.size() >= housing() or food_total() < kith.size() * 2 + Data.BIRTH_FOOD:
		grow_timer = 0.0
		return
	grow_timer += delta
	if grow_timer >= Data.GROW_TIME:
		grow_timer = 0.0
		_eat(Data.BIRTH_FOOD)
		_add_kith()
		events.append("A Kith was born")


## Why the population isn't growing, for the UI. "" when it is.
func growth_note() -> String:
	if starving:
		return "Starving: no berries or flour"
	if kith.size() >= housing():
		return "No room: build a Dwelling"
	if food_total() < kith.size() * 2 + Data.BIRTH_FOOD:
		return "Needs %d spare food to grow" % int(kith.size() * 2 + Data.BIRTH_FOOD)
	return ""


# --- Simulation --------------------------------------------------------------


func tick(delta: float) -> void:
	if won:
		return
	_assign_jobs()
	food_use = kith.size() * Data.FOOD_PER_KITH_PER_SEC
	var fed := _eat(food_use * delta)
	starving = not fed
	_grow(delta, fed)

	for g in Data.GOALS:
		if not goals_done.has(g["id"]) and goal_met(g["id"]):
			goals_done[g["id"]] = true

	if fed:
		for k in kith:
			match k["job"]:
				"work":
					_tick_worker(k, delta)
				"haul":
					_tick_hauler(k, delta)
				_:
					_step(k, delta)
	for b in buildings:
		b["unreachable"] = maxf(b["unreachable"] - delta, 0.0)
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


## A worker walks to their building. Hut workers then walk out to each resource tile and carry it home.
func _tick_worker(k: Dictionary, delta: float) -> void:
	var b: Dictionary = buildings[k["building"]]
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match k["phase"]:
		"to_site":
			if k["path"].is_empty() and _tile_of(k) != b["pos"] and not _walk_to(k, b["pos"]):
				b["unreachable"] = 1.0
				return
			if _step(k, delta):
				k["phase"] = "home"
		"home":
			if def["kind"] != "gatherer" or buffered(b["out"]) >= Data.BUFFER_CAP:
				return
			var target := _next_gather_tile(k, b)
			if target == b["pos"]:
				k["phase"] = "harvest"  # nothing reachable: cut grass by the hut
			else:
				k["task"] = {"tile": target}
				k["phase"] = "to_tile"
		"to_tile":
			if _step(k, delta):
				k["phase"] = "harvest"
		"harvest":
			k["timer"] += delta
			b["progress"] = k["timer"]
			if k["timer"] >= def["time"]:
				k["timer"] = 0.0
				b["progress"] = 0.0
				var tile: Vector2i = k["task"].get("tile", b["pos"])
				var item: String = Data.TILES[tile_at(tile)]["yields"] if tile != b["pos"] else "fiber"
				k["carry"] = {item: 1}
				k["task"] = {}
				_walk_to(k, b["pos"])
				k["phase"] = "to_home"
		"to_home":
			if _step(k, delta):
				for id in k["carry"]:
					b["out"][id] = b["out"].get(id, 0) + k["carry"][id]
				k["carry"] = {}
				k["phase"] = "home"


## The next tile in the hut's rotation the worker can reach, or the hut itself if none.
func _next_gather_tile(k: Dictionary, b: Dictionary) -> Vector2i:
	var tiles := gather_tiles(b["pos"])
	for _attempt in tiles.size():
		var t: Vector2i = tiles[b["gather_index"] % tiles.size()]
		b["gather_index"] += 1
		if _walk_to(k, t):
			return t
	return b["pos"]


func _tick_hauler(k: Dictionary, delta: float) -> void:
	if k["task"].is_empty():
		if not _find_haul_task(k) and k["path"].is_empty() and _tile_of(k) != _nearest_depot(_tile_of(k)):
			_walk_to(k, _nearest_depot(_tile_of(k)))
		_step(k, delta)
		return
	if not _step(k, delta):
		return
	var t: Dictionary = k["task"]
	var b: Dictionary = buildings[t["building"]]
	match k["phase"]:
		"to_pickup":
			var left := Data.CARRY
			for id in b["out"].keys():
				var n: int = mini(b["out"][id], left)
				if n > 0:
					k["carry"][id] = k["carry"].get(id, 0) + n
					b["out"][id] -= n
					left -= n
				if b["out"][id] == 0:
					b["out"].erase(id)
			b["claimed"] = false
			k["task"] = {"kind": "dropoff", "building": t["building"]}
			_walk_to(k, _nearest_depot(_tile_of(k)))
			k["phase"] = "to_depot"
		"to_depot":
			for id in k["carry"]:
				add(id, k["carry"][id])
			k["carry"] = {}
			k["task"] = {}
		"to_stock":
			var n: int = mini(t["amount"], inv.get(t["item"], 0))
			b["incoming"][t["item"]] -= t["amount"] - n
			t["amount"] = n
			if n == 0:
				k["task"] = {}
				return
			inv[t["item"]] -= n
			k["carry"] = {t["item"]: n}
			if not _walk_to(k, b["pos"]):
				b["unreachable"] = 2.0
				_drop_task(k)
				return
			k["phase"] = "to_drop"
		"to_drop":
			b["inbuf"][t["item"]] = b["inbuf"].get(t["item"], 0) + t["amount"]
			b["incoming"][t["item"]] -= t["amount"]
			k["carry"] = {}
			k["task"] = {}


## Pick the closest useful trip: empty a building's output, or bring a processor its inputs.
func _find_haul_task(k: Dictionary) -> bool:
	var here := _tile_of(k)
	var best := {}
	var best_d := INF
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if not needs_worker(b) or b["unreachable"] > 0.0:
			continue
		var d := Vector2(here).distance_to(Vector2(b["pos"]))
		if d >= best_d:
			continue
		if buffered(b["out"]) > 0 and not b["claimed"]:
			best = {"kind": "pickup", "building": i}
			best_d = d
			continue
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		for id in def.get("in", {}):
			var want: int = def["in"][id] * 2 - b["inbuf"].get(id, 0) - b["incoming"].get(id, 0)
			var n := mini(mini(want, inv.get(id, 0)), Data.CARRY)
			if n > 0:
				best = {"kind": "deliver", "building": i, "item": id, "amount": n}
				best_d = d
				break
	if best.is_empty():
		return false
	var b: Dictionary = buildings[best["building"]]
	var to: Vector2i = b["pos"] if best["kind"] == "pickup" else _nearest_depot(here)
	if not _walk_to(k, to):
		b["unreachable"] = 2.0
		return false
	k["task"] = best
	if best["kind"] == "pickup":
		b["claimed"] = true
		k["phase"] = "to_pickup"
	else:
		b["incoming"][best["item"]] = b["incoming"].get(best["item"], 0) + best["amount"]
		k["phase"] = "to_stock"
	return true


## The Camp or Storehouse closest to p.
func _nearest_depot(p: Vector2i) -> Vector2i:
	var best := camp_pos
	var best_d := Vector2(p).distance_to(Vector2(camp_pos))
	for b in buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "depot":
			var d := Vector2(p).distance_to(Vector2(b["pos"]))
			if d < best_d:
				best = b["pos"]
				best_d = d
	return best


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
		"dwelling":
			return has_building("dwelling")
		"road":
			return roads.size() >= 5
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


## Worker standing at their building, ready to work it.
func _worker_home(b: Dictionary) -> bool:
	return b["worker"] >= 0 and kith[b["worker"]]["phase"] != "to_site"


func _tick_building(b: Dictionary, delta: float, fed: bool) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if not needs_worker(b):
		b["status"] = def["desc"]
		return
	if b["worker"] < 0:
		b["status"] = "No worker: more Kith needed (they grow with food and Dwellings)"
		return
	if not fed:
		b["status"] = "Hungry: bring berries or flour"
		return
	if b["unreachable"] > 0.0:
		b["status"] = "The Kith can't reach it. Lay a Road across the river"
		return
	if def.get("needs_power", false) and not is_powered(b["pos"]):
		b["status"] = "No power: build a Water Wheel nearby"
		return
	if not _worker_home(b):
		b["status"] = "Worker walking here"
		return
	if not _wants_to_work(b):
		b["status"] = _idle_reason(b, def)
		return
	if def["kind"] == "gatherer":
		var k: Dictionary = kith[b["worker"]]
		match k["phase"]:
			"to_tile":
				b["status"] = "Walking out to gather"
			"harvest":
				b["status"] = "Working"
			"to_home":
				b["status"] = "Carrying %s home" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			_:
				b["status"] = "Working"
		return
	b["status"] = "Working"
	b["progress"] += delta
	if b["progress"] < def["time"]:
		return
	b["progress"] = 0.0
	for id in def["in"]:
		b["inbuf"][id] -= def["in"][id]
	for id in def["out"]:
		b["out"][id] = b["out"].get(id, 0) + def["out"][id]


func _idle_reason(b: Dictionary, def: Dictionary) -> String:
	if buffered(b["out"]) >= Data.BUFFER_CAP:
		return "Full: click to collect" if not has_haulers() else "Full: waiting for a hauler"
	if def.get("needs_power", false) and not is_powered(b["pos"]):
		return "No power: build a Water Wheel nearby"
	var missing: Array = []
	for id in def.get("in", {}):
		if b["inbuf"].get(id, 0) < def["in"][id]:
			missing.append(Data.ITEMS[id]["name"])
	if missing.is_empty():
		return "Idle"
	var how := "click to load" if not has_haulers() else "waiting for a hauler"
	if has_haulers():
		for id in def["in"]:
			if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) < def["in"][id] and inv.get(id, 0) == 0:
				how = "stockpile is out"
	return "Needs %s (%s)" % [", ".join(missing), how]
