extends RefCounted
## The whole simulation: map, stockpile, tech, buildings. No rendering here,
## so it can run headless in tests.

const Data = preload("res://scripts/data.gd")
const Fog = preload("res://scripts/fog.gd")
const Flows = preload("res://scripts/flows.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Goals = preload("res://scripts/goals.gd")
const Rules = preload("res://scripts/rules.gd")
const Research = preload("res://scripts/research.gd")

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
var fields: Dictionary = {}  # Vector2i -> true, grain tiles the Kith sowed
var shard_seen := false  # the player has clicked the Strange Stone, revealing hidden techs
## The Kith, each a person on the map:
## {pos: Vector2 (tile coords), path: Array of Vector2i, job: "" | "work" | "haul", building: int,
##  phase: String, timer: float, carry: Dictionary, task: Dictionary}
var kith: Array = []
var grow_timer := 0.0
var starve_timer := 0.0
var astar := AStarGrid2D.new()
var events: Array = []  # messages for the UI to show and clear
var fog := Fog.new()
var flows := Flows.new()  # what made and used each item lately, for the top bar rates
var research_goal := ""  # the tech the research queue is working toward, "" for none
var research_queue: Array = []  # the next techs on the way there, researched as soon as affordable


func _init() -> void:
	for id in Data.ITEM_ORDER:
		inv[id] = 0
	inv["berries"] = 10
	for id in ["wood", "stone", "flint", "berries"]:
		seen[id] = true


# --- Map ---------------------------------------------------------------------


func generate(seed_value: int) -> void:
	MapGen.generate(self, seed_value, WIDTH, HEIGHT)


func _set_tile(p: Vector2i, tile: String) -> void:
	if in_bounds(p):
		tiles[p.y * WIDTH + p.x] = tile


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < WIDTH and p.y < HEIGHT


func tile_at(p: Vector2i) -> String:
	if not in_bounds(p):
		return ""
	return tiles[p.y * WIDTH + p.x]


## How far something sees: Scouting adds to buildings and Kith alike.
func _sight(base: int) -> int:
	return base + (Data.SCOUTING_SIGHT if researched.has("scouting") else 0)


# --- Stockpile ---------------------------------------------------------------


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if inv.get(id, 0) < cost[id]:
			return false
	return true


func _pay(cost: Dictionary) -> void:
	for id in cost:
		inv[id] -= cost[id]


func add(id: String, amount: int) -> void:
	inv[id] = inv.get(id, 0) + amount
	seen[id] = true


func _hand_yield() -> int:
	return 2 if inv.get("flint_tools", 0) > 0 else 1


## Foraging doubles berries, whoever gathers them.
func _gather_mult(item: String) -> int:
	return 2 if item == "berries" and researched.has("foraging") else 1


func hut_radius() -> int:
	return Data.BUILDINGS["gatherers_hut"]["radius"] + (1 if researched.has("scouting") else 0)


func carry_cap() -> int:
	return Data.CARRY * (2 if researched.has("carrying_poles") else 1)


func food_value(id: String) -> float:
	if id == "flour" and researched.has("baking"):
		return Data.BAKED_FLOUR_FOOD
	if id == "berries" and researched.has("smoking"):
		return Data.SMOKED_BERRY_FOOD
	return Data.FOOD_VALUE[id]


## Seconds between births. Storytelling shortens it.
func _grow_time() -> float:
	return Data.GROW_TIME * (Data.STORYTELLING_GROW if researched.has("storytelling") else 1.0)


func gather_by_hand(p: Vector2i) -> String:
	if not fog.is_revealed(p):
		return ""
	var tile := tile_at(p)
	if tile == "shard":
		shard_seen = true
		return Data.SHARD_TEXT
	if tile == "":
		return ""
	var item: String = Data.TILES[tile]["yields"]
	if item == "":
		return ""
	var n := _hand_yield() * _gather_mult(item)
	add(item, n)
	flows.add(item, n, "hand")
	return "+%d %s" % [n, Data.ITEMS[item]["name"]]


# --- Tech --------------------------------------------------------------------


## Hidden techs (Star Lore) only show once the Strange Stone has been clicked.
func tech_visible(tech: String) -> bool:
	return shard_seen or not Data.TECHS[tech].get("hidden", false)


## How many requirements are still open. A `requires_any` list counts as one.
func missing_requirements(tech: String) -> int:
	var t: Dictionary = Data.TECHS[tech]
	var n := 0
	for r in t["requires"]:
		if not researched.has(r):
			n += 1
	var any: Array = t.get("requires_any", [])
	if not any.is_empty() and not any.any(func(r): return researched.has(r)):
		n += 1
	return n


func requirements_met(tech: String) -> bool:
	return tech_visible(tech) and missing_requirements(tech) == 0


func can_research(tech: String) -> bool:
	return not researched.has(tech) and requirements_met(tech) and can_afford(Data.TECHS[tech]["cost"])


func research(tech: String) -> bool:
	if not can_research(tech):
		return false
	_pay(Data.TECHS[tech]["cost"])
	researched[tech] = true
	if tech in ["paved_roads", "rafts"]:
		_refresh_walk_grid()
	if tech == "scouting":
		for b in buildings:
			fog.reveal(b["pos"], _sight(Data.SIGHT_BUILDING))
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
	_pay(r["in"])
	for id in r["in"]:
		flows.add(id, -r["in"][id], "craft")
	for id in r["out"]:
		add(id, r["out"][id])
		flows.add(id, r["out"][id], "craft")
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
	if not in_bounds(p):
		return "Off the map"
	if not fog.is_revealed(p):
		return "Unexplored: build or walk closer to see it"
	if building_at.has(p) or roads.has(p):
		return "Something is already there"
	if def["kind"] == "road":
		if tile_at(p) == "river":
			return "Roads can't cross the river: build a Wooden Bridge"
		if tile_at(p) != "grass":
			return "Roads go on grassland"
		return "" if can_afford(def["cost"]) else "Not enough materials"
	if def["kind"] == "bridge":
		if tile_at(p) != "river":
			return "Bridges go on river tiles"
		return "" if can_afford(def["cost"]) else "Not enough materials"
	if def["kind"] == "field":
		if tile_at(p) != "grass":
			return "Fields go on open grassland"
		return "" if can_afford(def["cost"]) else "Not enough materials"
	if not Data.TILES[tile_at(p)]["buildable"]:
		return "Build on open grassland"
	if def.get("needs_river", false) and not touches_river(p):
		return "Must touch the river"
	if def.get("needs_shard", false) and not _touches(p, "shard"):
		return "Must go next to the Strange Stone"
	if def.get("near_hearth", false) and not _near_hearth(p):
		return "Must be within %d tiles of the Hearth" % int(Data.HEARTH_RADIUS)
	if not can_afford(def["cost"]):
		return "Not enough materials"
	return ""


func place(type: String, p: Vector2i) -> bool:
	if placement_error(type, p) != "":
		return false
	_pay(Data.BUILDINGS[type]["cost"])
	var kind: String = Data.BUILDINGS[type]["kind"]
	if kind in ["road", "bridge"]:
		roads[p] = true  # a bridge is a road over the river
		_update_walk_cell(p)
		fog.reveal(p, _sight(Data.SIGHT_KITH))
	elif kind == "field":
		_set_tile(p, "grain")
		fields[p] = true
		_update_walk_cell(p)
	else:
		_place_building(type, p)
		fog.reveal(p, _sight(Data.SIGHT_BUILDING))
	return true


## Place along a dragged line; returns how many went down.
func place_line(type: String, line: Array) -> int:
	var n := 0
	for p in line:
		if place(type, p):
			n += 1
	return n


func _near_hearth(p: Vector2i) -> bool:
	return Vector2(p).distance_to(Vector2(camp_pos)) <= Data.HEARTH_RADIUS


## The type of whatever the player built at p (a building, road, bridge or field), or "".
func built_type(p: Vector2i) -> String:
	if building_at.has(p):
		return buildings[building_at[p]]["type"]
	if roads.has(p):
		return "bridge" if tile_at(p) == "river" else "road"
	if fields.has(p):
		return "field"
	return ""


## Tear down what stands at p for half its cost back. Its worker goes idle; whatever it held
## goes to the stockpile. The Hearth stays. Returns the refund, or {} if nothing was torn down.
func demolish(p: Vector2i) -> Dictionary:
	var type := built_type(p)
	if type == "" or Data.BUILDINGS[type]["kind"] == "camp":
		return {}
	var refund := Rules.refund_of(type)
	for id in refund:
		add(id, refund[id])
	if roads.has(p):
		roads.erase(p)
		_update_walk_cell(p)
	elif fields.has(p):
		fields.erase(p)
		_set_tile(p, "grass")
		_update_walk_cell(p)
	else:
		_remove_building(building_at[p])
	events.append("Tore down the %s" % Data.BUILDINGS[type]["name"])
	return refund


func _remove_building(i: int) -> void:
	var b: Dictionary = buildings[i]
	_release_worker(b)
	for id in b["out"]:
		add(id, b["out"][id])
	for id in b["inbuf"]:
		add(id, b["inbuf"][id])
	for k in kith:
		if not k["task"].is_empty() and k["task"].get("building", -1) == i:
			_drop_task(k)
			k["path"] = []
	buildings.remove_at(i)
	building_at.clear()
	for j in buildings.size():
		building_at[buildings[j]["pos"]] = j
	for k in kith:
		if k["job"] == "work" and k["building"] > i:
			k["building"] -= 1
		if k["task"].get("building", -1) > i:
			k["task"]["building"] -= 1


## Send a building's worker off the job: they drop what they carry at the stockpile and go idle.
func _release_worker(b: Dictionary) -> void:
	if b["worker"] < 0:
		return
	var k: Dictionary = kith[b["worker"]]
	for id in k["carry"]:
		add(id, k["carry"][id])
	k["carry"] = {}
	k["task"] = {}
	k["job"] = ""
	k["building"] = -1
	k["phase"] = ""
	k["timer"] = 0.0
	k["path"] = []
	b["worker"] = -1


## A paused building frees its worker and gets no deliveries until it's resumed.
func set_paused(i: int, on: bool) -> void:
	var b: Dictionary = buildings[i]
	b["paused"] = on
	if on:
		_release_worker(b)


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
		"field_extra": 0.0,  # Calendar's part-item bonus from Fields, paid out once it reaches 1
		"paused": false,
		"alert": "",  # a short warning for the pill under the building, "" when all is well
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
	var r := hut_radius()
	var found: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tile_at(p + Vector2i(dx, dy))
			if t != "" and t != "grass" and Data.TILES[t]["yields"] != "":
				found.append(p + Vector2i(dx, dy))
	return found


func touches_river(p: Vector2i) -> bool:
	return _touches(p, "river")


## True if a tile beside p (not diagonal) is `tile`.
func _touches(p: Vector2i, tile: String) -> bool:
	for n in NEIGHBORS:
		if tile_at(p + n) == tile:
			return true
	return false


func is_powered(p: Vector2i) -> bool:
	return _in_range_of("power", p)


## True if p is within the radius of any building of this kind.
func _in_range_of(kind: String, p: Vector2i) -> bool:
	for b in buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var bp: Vector2i = b["pos"]
		if def["kind"] == kind and Vector2(bp).distance_to(Vector2(p)) <= def["radius"]:
			return true
	return false


## How fast a building's worker works: Ochre speeds huts, a Standing Stone speeds everything near it.
func work_speed(b: Dictionary) -> float:
	var speed := 1.0
	if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and researched.has("ochre"):
		speed *= Data.OCHRE_SPEED
	if _in_range_of("aura", b["pos"]):
		speed *= Data.STANDING_STONE_SPEED
	return speed


## Seconds for one work cycle at this building.
func _work_time(b: Dictionary) -> float:
	return Data.BUILDINGS[b["type"]]["time"] / work_speed(b)


## Seconds for a hut worker to harvest `tile`. Irrigation halves it for Fields touching the river.
func _harvest_time(b: Dictionary, tile: Vector2i) -> float:
	var t := _work_time(b)
	if researched.has("irrigation") and fields.has(tile) and touches_river(tile):
		t /= 2.0
	return t


## How much one harvest of `tile` brings back. Stone Axe doubles Wood; Calendar adds a quarter
## to Fields, paid out as whole items as the building's share builds up.
func _harvest_amount(b: Dictionary, tile: Vector2i, item: String) -> int:
	var n := _gather_mult(item)
	if item == "wood" and researched.has("stone_axe"):
		n *= 2
	if fields.has(tile) and researched.has("calendar"):
		b["field_extra"] = b.get("field_extra", 0.0) + n * Data.CALENDAR_FIELD_BONUS
		if b["field_extra"] >= 1.0:
			b["field_extra"] -= 1.0
			n += 1
	return n


## 0 to 1: how far along the current work cycle is, for the progress bar.
func progress_frac(b: Dictionary) -> float:
	if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and b["worker"] >= 0:
		var k: Dictionary = kith[b["worker"]]
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		return clampf(k["timer"] / _harvest_time(b, tile), 0.0, 1.0)
	return clampf(b["progress"] / _work_time(b), 0.0, 1.0)


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
		total += inv.get(id, 0) * food_value(id)
	return total


# --- Walking -----------------------------------------------------------------


func _build_walk_grid() -> void:
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	_refresh_walk_grid()


func _refresh_walk_grid() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			_update_walk_cell(Vector2i(x, y))


func _update_walk_cell(p: Vector2i) -> void:
	var t := tile_at(p)
	astar.set_point_solid(p, t == "river" and not roads.has(p) and not researched.has("rafts"))
	astar.set_point_weight_scale(p, walk_cost(p))


## Relative time to cross a tile: roads are fast, forest and rocks are slow, rafting a river slower.
func walk_cost(p: Vector2i) -> float:
	if roads.has(p):
		return Data.WALK_COST["road"] / (2.0 if researched.has("paved_roads") else 1.0)
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
		"seen": Vector2i(-99, -99),  # the tile they last lifted the fog around
	}
	kith.append(k)


func housing() -> int:
	var total := 0
	for b in buildings:
		total += Data.BUILDINGS[b["type"]].get("housing", 0)
		if b["type"] == "dwelling" and researched.has("shelter"):
			total += 2
	return total


func needs_worker(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]]["kind"] in ["gatherer", "processor"]


## Staff buildings in the order they were built. Everyone else hauls (once researched) or waits at camp.
func _assign_jobs() -> void:
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if not needs_worker(b) or b["worker"] >= 0 or b["paused"]:
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
	if grow_timer >= _grow_time():
		grow_timer = 0.0
		_eat(Data.BIRTH_FOOD)
		_add_kith()
		events.append("A Kith was born")


# --- Simulation --------------------------------------------------------------


func tick(delta: float) -> void:
	if won:
		return
	flows.advance(delta)
	Research.tick(self)
	_assign_jobs()
	food_use = kith.size() * Data.FOOD_PER_KITH_PER_SEC * (0.75 if researched.has("preservation") else 1.0)
	var fed := _eat(food_use * delta)
	starving = not fed
	_grow(delta, fed)

	Goals.update(self)

	if fed:
		for k in kith:
			match k["job"]:
				"work":
					_tick_worker(k, delta)
				"haul":
					Haulers.tick(self, k, delta)
				_:
					_step(k, delta)
	for k in kith:
		var here := _tile_of(k)
		if here != k["seen"]:
			k["seen"] = here
			fog.reveal(here, _sight(Data.SIGHT_KITH))
	for b in buildings:
		b["unreachable"] = maxf(b["unreachable"] - delta, 0.0)
		_tick_building(b, delta, fed)


func _eat(need: float) -> bool:
	while food_credit < need:
		var id := _next_food()
		if id == "":
			return false
		inv[id] -= 1
		flows.add(id, -1, "kith")
		food_credit += food_value(id)
	food_credit -= need
	return true


## The first food in eating order the stockpile can spare, or "" if none.
func _next_food() -> String:
	for id in Data.EAT_ORDER:
		var keep := flour_reserve() if id == "flour" else 0
		if inv.get(id, 0) > keep:
			return id
	return ""


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
			var tile: Vector2i = k["task"].get("tile", b["pos"])
			k["timer"] += delta
			if k["timer"] >= _harvest_time(b, tile):
				k["timer"] = 0.0
				var item: String = Data.TILES[tile_at(tile)]["yields"] if tile != b["pos"] else "fiber"
				k["carry"] = {item: _harvest_amount(b, tile, item)}
				k["task"] = {}
				_walk_to(k, b["pos"])
				k["phase"] = "to_home"
		"to_home":
			if _step(k, delta):
				for id in k["carry"]:
					b["out"][id] = b["out"].get(id, 0) + k["carry"][id]
					flows.add(id, k["carry"][id], b["type"])
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
	b["alert"] = ""
	if not needs_worker(b):
		b["status"] = def.get("status", def["desc"])
		return
	if b["paused"]:
		_set_status(b, "Paused: its worker is free for other jobs", "Paused")
		return
	if b["worker"] < 0:
		_set_status(b, "No worker: more Kith needed (they grow with food and Dwellings)", "Idle: no free Kith")
		return
	if not fed:
		_set_status(b, "Hungry: bring food (berries, fish or flour)", "Hungry: no food")
		return
	if b["unreachable"] > 0.0:
		_set_status(b, "Cut off by water: build a Wooden Bridge (Paths & Haulers)", "Cut off: needs a bridge")
		return
	if def.get("needs_power", false) and not is_powered(b["pos"]):
		_set_status(b, "No power: build a Water Wheel nearby", "No power")
		return
	if not _worker_home(b):
		b["status"] = "Worker walking here"
		return
	if not _wants_to_work(b):
		_idle_reason(b, def)
		return
	if def["kind"] == "gatherer":
		var k: Dictionary = kith[b["worker"]]
		match k["phase"]:
			"to_tile":
				b["status"] = "Walking out to gather"
			"to_home":
				b["status"] = "Carrying %s home" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			_:
				b["status"] = "Working"
		return
	b["status"] = "Working"
	b["progress"] += delta
	if b["progress"] < _work_time(b):
		return
	b["progress"] = 0.0
	for id in def["in"]:
		b["inbuf"][id] -= def["in"][id]
		flows.add(id, -def["in"][id], b["type"])
	for id in def["out"]:
		b["out"][id] = b["out"].get(id, 0) + def["out"][id]
		flows.add(id, def["out"][id], b["type"])


func _set_status(b: Dictionary, status: String, alert: String) -> void:
	b["status"] = status
	b["alert"] = alert


## Why a staffed building is standing still: full, or short of an input.
func _idle_reason(b: Dictionary, def: Dictionary) -> void:
	if buffered(b["out"]) >= Data.BUFFER_CAP:
		if has_haulers():
			_set_status(b, "Full: waiting for a hauler", "Full: waiting for a hauler")
		else:
			_set_status(b, "Full: click to collect", "Full: click to collect")
		return
	var missing: Array = []
	for id in def.get("in", {}):
		if b["inbuf"].get(id, 0) < def["in"][id]:
			missing.append(Data.ITEMS[id]["name"])
	if missing.is_empty():
		b["status"] = "Idle"
		return
	var how := "click to load" if not has_haulers() else "waiting for a hauler"
	if has_haulers():
		for id in def["in"]:
			if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) < def["in"][id] and inv.get(id, 0) == 0:
				how = "stockpile is out"
	_set_status(b, "Needs %s (%s)" % [", ".join(missing), how], "Needs " + ", ".join(missing))


# --- Trips -------------------------------------------------------------------


## The walk from p to the nearest stockpile: {"ok": false} when water cuts it off, otherwise
## {"ok": true, "tiles": one-way steps, "seconds": there and back, "depot": Vector2i}.
func trip_info(p: Vector2i) -> Dictionary:
	var depot := _nearest_depot(p)
	if depot == p:
		return {"ok": true, "tiles": 0, "seconds": 0.0, "depot": depot}
	var was := astar.is_point_solid(p)
	astar.set_point_solid(p, false)
	var path := astar.get_id_path(p, depot)
	astar.set_point_solid(p, was)
	if path.is_empty():
		return {"ok": false, "tiles": 0, "seconds": 0.0, "depot": depot}
	var secs := 0.0
	for i in range(1, path.size()):
		secs += Vector2(path[i - 1]).distance_to(Vector2(path[i])) * walk_cost(path[i]) / Data.KITH_SPEED
	return {"ok": true, "tiles": path.size() - 1, "seconds": secs * 2.0, "depot": depot}
