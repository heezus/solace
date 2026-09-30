extends RefCounted
## The Buildings block: every building that stands on the map, in the order it was built, and the rules for
## putting one down and tearing one down. It holds the list (`buildings`, and `building_at` to find one by
## tile), the placement rules, the refund, pausing, power and aura range, housing and the status text a
## building shows. Roads and fields are World data, but they are built and torn down here too, since the
## rules and the cost are the same as for a building.
## It reads the World (tiles, roads, the camp), pays through the Economy and asks the Research block what is
## unlocked. Whether a tile has been seen comes in as a read-only callable: is_revealed.call(p) -> bool.
## It never reaches into another block. What a placement or a demolition sets off elsewhere (the fog lifting,
## a walking cell refreshing, a worker freed, a Kith's task dropped) is not done here: place() and demolish()
## report what they did, and their owner does the rest. A building's work cycle needs the Kith, the haulers
## and the Bonuses, so that stays with the owner too.
## GameState owns one and passes its old building methods and variables through to it.
## Signals: built(type, pos) when place() puts a building, road, bridge or field down, and demolished(type, pos)
## when demolish() takes one away (the Hearth goes down through add_building and is not announced).

signal built(type: String, pos: Vector2i)
signal demolished(type: String, pos: Vector2i)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Research = preload("res://scripts/research.gd")
const Rules = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world.gd")

const _POINTS := ["pos"]  # the building entries that are tile positions (saved as [x, y])

## each: {type, pos, progress, inbuf, out, status, gather_items, gather_index, worker, ...}
var buildings: Array = []
var building_at: Dictionary = {}  # Vector2i -> index into buildings
var road_rev := 0  # bumped whenever roads or buildings change, so Roads rebuilds its networks
var road_net: Dictionary = {}  # Roads' cache of the road networks and which buildings they link
var _world: World
var _economy: Economy
var _research: Research
var _is_revealed: Callable  # (Vector2i) -> bool: has the fog lifted there?


func _init(world: World, economy: Economy, research: Research, is_revealed: Callable) -> void:
	_world = world
	_economy = economy
	_research = research
	_is_revealed = is_revealed


# --- Placement ---------------------------------------------------------------


func unlocked(type: String) -> bool:
	var tech: String = Data.BUILDINGS[type]["tech"]
	return tech == "" or _research.unlocked(tech)


## Returns "" if the building can go here, otherwise the reason it can't.
func placement_error(type: String, p: Vector2i) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	if not unlocked(type):
		return "Not discovered yet"
	if not _world.in_bounds(p):
		return "Off the map"
	if not _is_revealed.call(p):
		return "Unexplored: build or walk closer to see it"
	if building_at.has(p) or _world.roads.has(p):
		return "Something is already there"
	var tile := _world.tile_at(p)
	if def["kind"] == "road":
		if tile == "river":
			return "Roads can't cross the river: build a Wooden Bridge"
		if tile not in ["grass", "rock", "tree"]:
			return "Roads go on grassland or through Forest, or cut a pass through Rocks"
		return "" if _economy.can_afford(Rules.cost_at(type, tile)) else "Not enough materials"
	if def["kind"] == "bridge":
		if tile != "river":
			return "Bridges go on river tiles"
		return "" if _economy.can_afford(def["cost"]) else "Not enough materials"
	if def["kind"] == "field":
		if tile != "grass":
			return "Fields go on open grassland"
		return "" if _economy.can_afford(def["cost"]) else "Not enough materials"
	if not Data.TILES[tile]["buildable"]:
		return "Build on open grassland"
	if def.get("needs_river", false) and not _world.touches_river(p):
		return "Must touch the river"
	if def.get("needs_shard", false) and not _world.touches(p, "shard"):
		return "Must go next to the Strange Stone"
	if def.get("near_hearth", false) and not near_hearth(p):
		return "Must be within %d tiles of the Hearth" % int(Data.HEARTH_RADIUS)
	if not _economy.can_afford(def["cost"]):
		return "Not enough materials"
	return ""


func near_hearth(p: Vector2i) -> bool:
	return Vector2(p).distance_to(Vector2(_world.camp_pos)) <= Data.HEARTH_RADIUS


## The type of whatever the player built at p (a building, road, bridge or field), or "".
func built_type(p: Vector2i) -> String:
	if building_at.has(p):
		return buildings[building_at[p]]["type"]
	if _world.roads.has(p):
		return "bridge" if _world.tile_at(p) == "river" else "road"
	if _world.fields.has(p):
		return "field"
	return ""


## Build `type` at p if placement_error allows: pay for it and put it in the World (a road on Rocks or Forest
## clears the tile first). Returns {} when it can't go here, otherwise {"kind": the building's kind,
## "cleared": "rock" or "tree" when a road cut through one, else ""}. The owner lifts the fog, refreshes the
## walking cell and tells the player.
func place(type: String, p: Vector2i) -> Dictionary:
	if placement_error(type, p) != "":
		return {}
	var tile := _world.tile_at(p)
	_economy.pay(Rules.cost_at(type, tile))
	road_rev += 1
	var kind: String = Data.BUILDINGS[type]["kind"]
	var cleared := ""
	if kind in ["road", "bridge"]:
		if tile in ["rock", "tree"]:
			cleared = tile
			_world.set_tile(p, "grass")  # a mountain pass, or the trees felled for the road
		_world.add_road(p)  # a bridge is a road over the river
	elif kind == "field":
		_world.add_field(p)
	else:
		add_building(type, p)
	built.emit(type, p)
	return {"kind": kind, "cleared": cleared}


## Put a new building on the list, free and unchecked (the Hearth goes down this way).
func add_building(type: String, p: Vector2i) -> void:
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
			b["gather_items"].append(Data.TILES[_world.tile_at(t)]["yields"])
	building_at[p] = buildings.size()
	buildings.append(b)


## How far a Gatherer's Hut reaches: Scouting adds a tile.
func hut_radius() -> int:
	return Data.BUILDINGS["gatherers_hut"]["radius"] + (1 if _research.unlocked("scouting") else 0)


## Resource tiles a Gatherer's Hut at p would work.
func gather_tiles(p: Vector2i) -> Array:
	return _world.gather_tiles(p, hut_radius())


# --- Demolishing -------------------------------------------------------------


## Tear down what stands at p for half its cost back. The refund goes to the stockpile, and a road or field is
## taken off the World. Returns {} when there is nothing to tear down (the Hearth stays), otherwise
## {"type", "refund", "index"}. For a building, "index" is its place in the list and it is still there: the
## owner frees its worker and whatever points at it, then calls remove_at(index). For a road or field the
## index is -1 and the job is done.
func demolish(p: Vector2i) -> Dictionary:
	var type := built_type(p)
	if type == "" or Data.BUILDINGS[type]["kind"] == "camp":
		return {}
	var refund := Rules.refund_of(type)
	for id in refund:
		_economy.add(id, refund[id])
	road_rev += 1
	var index := -1
	if _world.roads.has(p):
		_world.remove_road(p)
	elif _world.fields.has(p):
		_world.remove_field(p)
	else:
		index = building_at[p]
	demolished.emit(type, p)
	return {"type": type, "refund": refund, "index": index}


## Drop building `i` from the list and renumber the ones after it.
func remove_at(i: int) -> void:
	buildings.remove_at(i)
	building_at.clear()
	for j in buildings.size():
		building_at[buildings[j]["pos"]] = j


# --- State and range ---------------------------------------------------------


## A paused building gets no new worker and no deliveries until it is resumed. Freeing the worker it has
## is the owner's job.
func set_paused(i: int, on: bool) -> void:
	buildings[i]["paused"] = on


## The two lines a building shows: its status text and its short alert pill.
func set_status(b: Dictionary, status: String, alert: String) -> void:
	b["status"] = status
	b["alert"] = alert


func is_powered(p: Vector2i) -> bool:
	return in_range_of("power", p)


## True if p is within the radius of any building of this kind.
func in_range_of(kind: String, p: Vector2i) -> bool:
	for b in buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var bp: Vector2i = b["pos"]
		if def["kind"] == kind and Vector2(bp).distance_to(Vector2(p)) <= def["radius"]:
			return true
	return false


## How many Kith the buildings house (Shelter adds room to every Dwelling).
func housing() -> int:
	var total := 0
	for b in buildings:
		total += Data.BUILDINGS[b["type"]].get("housing", 0)
		if b["type"] == "dwelling" and _research.unlocked("shelter"):
			total += 2
	return total


# --- Work --------------------------------------------------------------------


## True for the buildings a Kith staffs.
static func needs_worker(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]]["kind"] in ["gatherer", "processor"]


## Carry by hand: empty the building's output into the stockpile and load its inputs from the stockpile.
func haul(index: int) -> void:
	var b: Dictionary = buildings[index]
	for id in b["out"]:
		_economy.add(id, b["out"][id])
	b["out"].clear()
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "processor":
		for id in def["in"]:
			var want: int = def["in"][id] * 2 - b["inbuf"].get(id, 0)
			var take: int = mini(want, _economy.inv.get(id, 0))
			if take > 0:
				_economy.pay({id: take})
				b["inbuf"][id] = b["inbuf"].get(id, 0) + take


## How many items a building's input or output buffer holds in all.
static func buffered(dict: Dictionary) -> int:
	var total := 0
	for id in dict:
		total += dict[id]
	return total


## Would a worker standing at this building have something to do: room to put the goods, and (for a
## workshop) the inputs and the power?
func wants_to_work(b: Dictionary) -> bool:
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


## Count the building's timers down by `delta` seconds: how long "can't reach" shows, and the rush cooldown.
func tick_timers(b: Dictionary, delta: float) -> void:
	b["unreachable"] = maxf(b["unreachable"] - delta, 0.0)
	b["rush_cd"] = maxf(b["rush_cd"] - delta, 0.0)


# --- Save --------------------------------------------------------------------


## Every building in the order it was built, and the road revision, as JSON-safe values. The road network
## cache (`road_net`) is not saved: Roads rebuilds it from the roads and buildings when it is next asked.
func to_dict() -> Dictionary:
	var list: Array = []
	for b in buildings:
		list.append(_building_to_dict(b))
	return {"buildings": list, "road_rev": road_rev}


## Restore what to_dict wrote, in place, and rebuild `building_at`. The road cache is dropped.
func from_dict(d: Dictionary) -> void:
	buildings.clear()
	building_at.clear()
	for saved in d.get("buildings", []):
		var b := _building_from_dict(saved)
		building_at[b["pos"]] = buildings.size()
		buildings.append(b)
	road_rev = int(d.get("road_rev", 0))
	road_net = {}


static func _building_to_dict(b: Dictionary) -> Dictionary:
	var out := Codec.with_points(b, _POINTS)
	for key in ["inbuf", "out", "incoming"]:
		out[key] = Codec.int_dict(b[key])
	out["gather_items"] = Codec.strings(b["gather_items"])
	return out


static func _building_from_dict(d: Dictionary) -> Dictionary:
	var b := Codec.from_points(d, _POINTS)
	for key in ["inbuf", "out", "incoming"]:
		b[key] = Codec.int_dict(d[key])
	b["gather_items"] = Codec.strings(d["gather_items"])
	for key in ["progress", "unreachable", "field_extra", "rush_cd"]:
		b[key] = float(d[key])
	for key in ["gather_index", "worker", "trips"]:
		b[key] = int(d[key])
	return b
