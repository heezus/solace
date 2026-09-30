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
const Bonuses = preload("res://scripts/bonuses.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Hands = preload("res://scripts/hands.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")

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
var road_rev := 0  # bumped whenever roads or buildings change, so Roads rebuilds its networks
var road_net: Dictionary = {}  # Roads' cache of the road networks and which buildings they link
var fields: Dictionary = {}  # Vector2i -> true, grain tiles the Kith sowed
var hand_tools := false  # you've made a Flint Tool, so hand gathering is doubled for good
var shard_seen := false  # the player has clicked the Strange Stone, revealing hidden techs
var hand_counts: Dictionary = {}  # item -> times harvested by hand
## Hold to harvest: the tile being held, seconds held so far, and 0 to 1 of the current harvest.
var harvest_tile := Vector2i(-1, -1)
var harvest_held := 0.0
var harvest_frac := 0.0
var rushes := 0  # buildings rushed so far
var born := 0  # Kith named so far, for the next name
var learned: Dictionary = {}  # item -> name of the Kith who learned to gather it by watching you
var ranks: Dictionary = {}  # tech -> rank bought on its card (2 or 3); a researched tech is rank 1
## Stable ids from Data.STORY_EVENTS, in the order they happened (for a future profile save).
var story_events: Array = []
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


## What one harvest of `item` by hand gives: base x tool x rank (Hands.harvest_yield).
func harvest_yield(item: String) -> int:
	return Hands.harvest_yield(self, item)


## Hold the mouse on tile p for `delta` more seconds (real time, not game speed). The ring fills over
## Hands.hold_time; when it's full the tile is harvested and the ring starts again. Moving to another
## tile starts over. Returns the harvest's text when one completes, else "".
func hold_harvest(p: Vector2i, delta: float) -> String:
	if p != harvest_tile:
		release_harvest()
		harvest_tile = p
	var item := Hands.item_at(self, p)
	if item == "":
		harvest_frac = 0.0
		return ""
	var need := Hands.hold_time(self, item)
	harvest_held += delta
	if harvest_held < need:
		harvest_frac = harvest_held / need
		return ""
	harvest_held -= need
	harvest_frac = harvest_held / need
	return gather_by_hand(p)


## Let go: the ring empties.
func release_harvest() -> void:
	harvest_tile = Vector2i(-1, -1)
	harvest_held = 0.0
	harvest_frac = 0.0


## True once a Kith has learned to gather `item` by watching you (Data.LEARN_CLICKS clicks).
func knows(item: String) -> bool:
	return learned.has(item)


## Note a story moment once, by its id in Data.STORY_EVENTS.
func record_story(id: String) -> void:
	assert(Data.STORY_EVENTS.has(id), "unknown story event " + id)
	if id not in story_events:
		story_events.append(id)


## A worker without a tool takes one from the stockpile.
func _equip(k: Dictionary) -> void:
	if k["tool"] <= 0 and inv.get("flint_tools", 0) > 0:
		inv["flint_tools"] -= 1
		flows.add("flint_tools", -1, "kith")
		k["tool"] = Data.TOOL_JOBS


## One job done: the worker's tool wears a little, and they pick up a new one when it breaks.
func _wear(b: Dictionary) -> void:
	if b["worker"] < 0:
		return
	var k: Dictionary = kith[b["worker"]]
	if k["tool"] > 0:
		k["tool"] -= 1
		if k["tool"] == 0:
			events.append("A Flint Tool wore out")
	_equip(k)


func hut_radius() -> int:
	return Data.BUILDINGS["gatherers_hut"]["radius"] + (1 if researched.has("scouting") else 0)


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
		record_story("shard_found")
		return Data.SHARD_TEXT
	if tile == "":
		return ""
	var item: String = Data.TILES[tile]["yields"]
	if item == "":
		return ""
	var n := harvest_yield(item)
	add(item, n)
	flows.add(item, n, "hand")
	Hands.teach(self, item)
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
	if tech == "haulers":
		record_story("haulers")
		for b in buildings:
			b["trips"] = 0  # huts loop on their own from now on
	if tech == "bronze_dawn":
		won = true
		record_story("bronze_dawn")
	return true


func has_haulers() -> bool:
	return researched.has("haulers")


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
		if tile_at(p) not in ["grass", "rock"]:
			return "Roads go on grassland, or cut a pass through Rocks"
		return "" if can_afford(Rules.cost_at(type, tile_at(p))) else "Not enough materials"
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
	_pay(Rules.cost_at(type, tile_at(p)))
	road_rev += 1
	var kind: String = Data.BUILDINGS[type]["kind"]
	if kind in ["road", "bridge"]:
		if tile_at(p) == "rock":
			_set_tile(p, "grass")  # a mountain pass: the rock is cut away
			events.append("Cut a pass through the rocks")
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
	road_rev += 1
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
	k["trip"] = false
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
		"trips": 0,  # hut trips queued by clicking it, before Paths & Haulers (the one under way counts)
		"rush_cd": 0.0,  # seconds until it can be rushed again
	}
	if Data.BUILDINGS[type]["kind"] == "gatherer":
		for t in gather_tiles(p):
			b["gather_items"].append(Data.TILES[tile_at(t)]["yields"])
	building_at[p] = buildings.size()
	buildings.append(b)


## Resource tiles a Gatherer's Hut at p would work.
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


## How fast a building's worker works: the Speed group (a Flint Tool in hand, a Standing Stone next door).
func work_speed(b: Dictionary) -> float:
	return Bonuses.speed(self, b)


## Seconds for one work cycle at this building.
func _work_time(b: Dictionary) -> float:
	return Data.BUILDINGS[b["type"]]["time"] / work_speed(b)


## Seconds for a hut worker to harvest `tile`. Irrigation halves it for Fields touching the river.
func _harvest_time(b: Dictionary, tile: Vector2i) -> float:
	var t := _work_time(b)
	if researched.has("irrigation") and fields.has(tile) and touches_river(tile):
		t /= 2.0
	return t


## A hut's bundle of `item`, before any Calendar share.
func _bundle_size(b: Dictionary, item: String) -> int:
	return roundi(Data.BUNDLE * harvest_yield(item) * Bonuses.building_yield(self, b, item))


## How much one harvest of `tile` brings back: a bundle, Data.BUNDLE times your click yield for the item
## (so tools and ranks count), times the Yield bonuses only huts get (Ochre on Clay). Calendar adds a
## quarter to Fields, paid out as whole items as the building's share builds up.
func _harvest_amount(b: Dictionary, tile: Vector2i, item: String) -> int:
	var n := _bundle_size(b, item)
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
		"tool": 0,  # jobs left on the Flint Tool they hold, 0 for none
		"trip": false,  # a hut worker out on a clicked trip, carrying the bundle to the stockpile
		"name": _next_name(),
	}
	kith.append(k)


## The next name from Data.PEOPLE_NAMES, with " II", " III"... once each name is taken.
func _next_name() -> String:
	var names: Array = Data.PEOPLE_NAMES
	var n: int = born
	born += 1
	var round_no := int(float(n) / names.size()) + 1
	return names[n % names.size()] + ("" if round_no == 1 else " " + Data.RANK_NAMES[mini(round_no, 3)])


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
		_equip(k)
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
	if t.has("kind"):
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
	events.append("A %s left in search of food" % Data.PEOPLE["one"])


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
		events.append(Data.BORN_EVENT % Data.PEOPLE["one"])


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
					Workers.tick(self, k, delta)
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
		b["rush_cd"] = maxf(b["rush_cd"] - delta, 0.0)
		_tick_building(b, delta, fed)
		if has_haulers() and needs_worker(b) and not b["paused"] and not Roads.linked(self, b):
			var a: String = b["alert"]
			if a == "" or a.begins_with("Full") or a.begins_with("Needs"):
				b["alert"] = "Needs road"  # it still works by clicks, but no hauler serves it


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
		_set_status(b, "Paused: its %s is free for other jobs" % Workers.building_job(self, b), "Paused")
		return
	if b["worker"] < 0:
		_set_status(
			b,
			(
				"No %s yet: more %s needed (they grow with food and Dwellings)"
				% [Workers.building_job(self, b), Data.PEOPLE["many"]]
			),
			"Idle: no free %s" % Data.PEOPLE["one"]
		)
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
		b["status"] = "%s walking here" % Workers.title_of(self, kith[b["worker"]])
		return
	if not _wants_to_work(b):
		Workers.idle_reason(self, b, def)
		return
	if def["kind"] == "gatherer":
		var k: Dictionary = kith[b["worker"]]
		match k["phase"]:
			"to_tile":
				b["status"] = "Walking out to gather"
			"to_home" when k["carry"].is_empty():
				b["status"] = "Walking home"
			"to_home":
				b["status"] = "Carrying %s home" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			"to_depot":
				b["status"] = "Carrying %s to the stockpile" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			"home":
				if not Workers.knows_any(self, b["pos"]):
					b["status"] = "Knows nothing here yet: gather by hand %dx to teach it" % Data.LEARN_CLICKS
				elif not Roads.automated(self, b) and b["trips"] <= 0:
					b["status"] = "Waiting: click to send a trip" + Workers.road_note(self, b)
				else:
					b["status"] = "Working"
			_:
				b["status"] = "Working"
		return
	b["status"] = "Working"
	b["progress"] += delta
	if b["progress"] < _work_time(b):
		return
	_finish_cycle(b)


## A workshop's cycle is done: it uses its inputs and makes its goods.
func _finish_cycle(b: Dictionary) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	b["progress"] = 0.0
	_wear(b)
	for id in def["in"]:
		b["inbuf"][id] -= def["in"][id]
		flows.add(id, -def["in"][id], b["type"])
	for id in def["out"]:
		b["out"][id] = b["out"].get(id, 0) + def["out"][id]
		flows.add(id, def["out"][id], b["type"])


func _set_status(b: Dictionary, status: String, alert: String) -> void:
	b["status"] = status
	b["alert"] = alert


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
