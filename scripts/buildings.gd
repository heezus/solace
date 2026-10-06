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
## and the Bonuses, so it is in scripts/work.gd and scripts/workers.gd, which take the Sim.
## Sim owns one, reached as `sim.town`.
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
## The entries of a building that hold the people at work in it, as indexes into the Kith list: the first, and for a
## building with a `crew` of 2 (a Mine) the second. -1 for nobody.
const CREW_SLOTS := ["worker", "mate"]

## each: {type, pos, progress, inbuf, out, status, gather_items, focus, gather_index, worker, ...}
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
	if building_at.has(p):
		return "Something is already there"
	var tile := _world.tile_at(p)
	if _world.roads.has(p):
		var upgrade := upgrade_error(type, p)
		if upgrade != "":
			return upgrade
		return "" if _economy.can_afford(cost_here(type, p)) else "Not enough materials"
	if def["kind"] == "road":
		if tile == "river":
			return "Roads can't cross the river: build a Wooden Bridge"
		if tile not in ["grass", "rock", "tree"]:
			return "Roads go on grassland or through Forest, or cut a pass through Rocks"
		return "" if _economy.can_afford(cost_here(type, p)) else "Not enough materials"
	if def["kind"] == "bridge":
		if tile != "river":
			return "Bridges go on river tiles"
		return "" if _economy.can_afford(def["cost"]) else "Not enough materials"
	if def["kind"] == "field":
		if tile != "grass":
			return "Fields go on open grassland"
		return "" if _economy.can_afford(def["cost"]) else "Not enough materials"
	if def.has("on_tiles"):
		if tile not in def["on_tiles"]:
			return "Must stand on " + " or ".join(def["on_tiles"].map(func(t): return Data.TILES[t]["name"]))
	elif not Data.TILES[tile]["buildable"]:
		return "Build on open grassland"
	if def.get("needs_river", false) and not _world.touches_river(p):
		return "Must touch the river"
	if def.get("needs_shard", false) and not _world.touches(p, "shard"):
		return "Must go next to the Strange Stone"
	if def.get("near_hearth", false) and not near_hearth(p):
		return "Must be within %d tiles of the Hearth" % int(Data.HEARTH_RADIUS)
	if not _economy.can_afford(price(type)):
		return "Not enough materials"
	return ""


## What `type` costs at p now: a road costs what its tile asks (a pass through Rocks costs more), and a road or bridge
## laid over one that stands there costs only the difference.
func cost_here(type: String, p: Vector2i) -> Dictionary:
	if Data.BUILDINGS[type]["kind"] in ["road", "bridge"]:
		return Rules.cost_at(type, _world.tile_at(p), built_type(p) if _world.roads.has(p) else "")
	return price(type)


## How many of building `type` stand.
func copies(type: String) -> int:
	var n := 0
	for b in buildings:
		if b["type"] == type:
			n += 1
	return n


## What the next building of `type` costs: its listed price, with 15% more for each production copy already standing
## (never past 4 times, see Rules.price). Homes, roads, bridges and the rest stay flat.
func price(type: String) -> Dictionary:
	return Rules.price(type, copies(type))


## Why `type` can't be laid over the road or bridge already at p, or "" when it upgrades it: a higher road tier over a
## lower one, a Stone Bridge over a Wooden Bridge. Everything else (the same tier, a worse one, a building) is refused.
func upgrade_error(type: String, p: Vector2i) -> String:
	var kind: String = Data.BUILDINGS[type]["kind"]
	var river := _world.tile_at(p) == "river"
	if kind == "road" and not river:
		var here := _world.road_tier(p)
		if Rules.tier_of(type) > here:
			return ""
		return (
			"Already a %s" % Data.BUILDINGS[type]["name"]
			if here == Rules.tier_of(type)
			else "A better road is already here"
		)
	if kind == "bridge" and river:
		if _world.stone_bridges.has(p):
			return "Already a Stone Bridge"
		if Data.BUILDINGS[type].get("stone", false):
			return ""
		return "Already a bridge"
	return "Something is already there"


func near_hearth(p: Vector2i) -> bool:
	return Vector2(p).distance_to(Vector2(_world.camp_pos)) <= Data.HEARTH_RADIUS


## The type of whatever the player built at p (a building, road, bridge or field), or "".
func built_type(p: Vector2i) -> String:
	if building_at.has(p):
		return buildings[building_at[p]]["type"]
	if _world.roads.has(p):
		if _world.stone_bridges.has(p):
			return "stone_bridge"
		return "bridge" if _world.tile_at(p) == "river" else Rules.road_type(_world.road_tier(p))
	if _world.fields.has(p):
		return "field"
	if _world.flax_fields.has(p):
		return "flax_field"
	return ""


## Build `type` at p if placement_error allows: pay for it and put it in the World (a road on Rocks or Forest
## clears the tile first). Returns {} when it can't go here, otherwise {"kind": the building's kind,
## "cleared": "rock" or "tree" when a road cut through one, else ""}. The owner lifts the fog, refreshes the
## walking cell and tells the player.
func place(type: String, p: Vector2i, focus := "") -> Dictionary:
	if placement_error(type, p) != "":
		return {}
	var tile := _world.tile_at(p)
	_economy.pay(cost_here(type, p))
	road_rev += 1
	var kind: String = Data.BUILDINGS[type]["kind"]
	var cleared := ""
	if kind in ["road", "bridge"]:
		if tile in ["rock", "tree"]:
			cleared = tile
			_world.set_tile(p, "grass")  # a mountain pass, or the trees felled for the road
		if Data.BUILDINGS[type].get("stone", false):
			_world.add_stone_bridge(p)
		else:
			_world.add_road(p, Rules.tier_of(type))  # a bridge is a road over the river
	elif kind == "field":
		if Data.BUILDINGS[type].get("crop", "") == "flax":
			_world.add_flax_field(p)
		else:
			_world.add_field(p)
	else:
		add_building(type, p)
		if focus != "":
			set_focus(building_at[p], focus)  # a hut set to work something in reach as it went down; else the default
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
		"gather_items": [],  # what was in reach when it was built (a hut works only its `focus`)
		"focus": "",  # the one item a Gatherer's Hut gathers, "" for none (see default_focus)
		"gather_index": 0,
		"worker": -1,  # index into kith, or -1
		"mate": -1,  # the second person of a building that needs two (see CREW_SLOTS), or -1
		"ore": "",  # what a Mine digs: the item its tile yields, "" for any other building
		"give": "",  # what a Trading Post gives up (Data.TRADE_GIVE of it), "" for none yet
		"get": "",  # ...and what it gets for it (Data.TRADE_GET of it)
		"make": "",  # the tool a Tool Bench is making now (a Data.RECIPES id), "" for any other building
		"claimed": false,  # a hauler is on its way to empty it
		"incoming": {},  # inputs haulers are carrying here
		"unreachable": 0.0,  # seconds left to show "can't reach"
		"field_extra": 0.0,  # Calendar's part-item bonus from Fields, paid out once it reaches 1
		"paused": false,
		"alert": "",  # a short warning for the pill under the building, "" when all is well
		"trips": 0,  # hut trips queued by clicking it, before Paths & Haulers (the one under way counts)
		"rush_cd": 0.0,  # seconds until it can be rushed again
		"tier": 0,  # a home's tier (Data.HOME_TIERS): 0 Dwelling, 1 Homestead, 2 Longhouse
		"check": 0.0,  # seconds since a home last looked at its needs (scripts/homes.gd)
		"met": 0.0,  # seconds its needs have been met, counted up and down by those looks
	}
	if Data.BUILDINGS[type].has("dig"):
		b["ore"] = Data.TILES[_world.tile_at(p)]["yields"]
	if Data.BUILDINGS[type].has("makes"):
		b["make"] = Data.BUILDINGS[type]["makes"][0]
	if Data.BUILDINGS[type]["kind"] == "gatherer":
		for t in gather_tiles(p):
			b["gather_items"].append(Data.TILES[_world.tile_at(t)]["yields"])
		b["focus"] = default_focus(p)
	building_at[p] = buildings.size()
	buildings.append(b)


## How far a Gatherer's Hut reaches: Scouting adds a tile.
func hut_radius() -> int:
	return Data.BUILDINGS["gatherers_hut"]["radius"] + (1 if _research.unlocked("scouting") else 0)


## Resource tiles a Gatherer's Hut at p would work.
func gather_tiles(p: Vector2i) -> Array:
	return _world.gather_tiles(p, hut_radius())


## The items a Gatherer's Hut at p could be set to work: what its reach holds, in Data.ITEM_ORDER.
func focus_options(p: Vector2i) -> Array:
	var seen := {}
	for t in gather_tiles(p):
		seen[Data.TILES[_world.tile_at(t)]["yields"]] = true
	return Data.ITEM_ORDER.filter(func(id): return seen.has(id))


## What a new hut at p works: the item of the resource tile nearest it (huts stand on open grass, so the one it
## was put next to), however many tiles of something else are in reach. At the same distance a hut goes to food
## while the stockpile is short (Data.FOOD_SHORT_STOCK, or the food warning is up), else to the item first in
## Data.ITEM_ORDER, so the choice never depends on chance. "" when nothing is in reach.
func default_focus(p: Vector2i) -> String:
	var near := {}
	for t in gather_tiles(p):
		var item: String = Data.TILES[_world.tile_at(t)]["yields"]
		near[item] = minf(near.get(item, INF), Vector2(t).distance_to(Vector2(p)))
	var order: Array = Data.ITEM_ORDER.duplicate()
	if _economy.low or _economy.food_total() < Data.FOOD_SHORT_STOCK:
		order = Data.ITEM_ORDER.filter(func(id): return Data.FOOD_VALUE.has(id))
		order += Data.ITEM_ORDER.filter(func(id): return not Data.FOOD_VALUE.has(id))
	var best := ""
	for item in order:
		if near.has(item) and (best == "" or near[item] < near[best] - 0.001):
			best = item
	return best


## The tiles in reach of hut `b` that hold its focus: the only ones it walks out to.
func focus_tiles(b: Dictionary) -> Array:
	return tiles_of(b["pos"], b["focus"])


## The tiles in reach of a hut at p that hold `item` ("" gives none).
func tiles_of(p: Vector2i, item: String) -> Array:
	return gather_tiles(p).filter(func(t): return item != "" and Data.TILES[_world.tile_at(t)]["yields"] == item)


## What the hut at p works, or what a new one there would: the tiles to show for its range.
func focus_at(p: Vector2i) -> String:
	return buildings[building_at[p]]["focus"] if building_at.has(p) else default_focus(p)


## Set hut i to work `item`. False when that isn't something in its reach.
func set_focus(i: int, item: String) -> bool:
	var b: Dictionary = buildings[i]
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or item not in focus_options(b["pos"]):
		return false
	b["focus"] = item
	b["gather_index"] = 0
	return true


## Move hut i on to the next item in its reach (around to the first). Returns the new focus, "" when
## there is none to choose.
func cycle_focus(i: int) -> String:
	var b: Dictionary = buildings[i]
	var options := focus_options(b["pos"])
	if options.is_empty():
		return ""
	set_focus(i, options[(options.find(b["focus"]) + 1) % options.size()])
	return b["focus"]


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
	elif _world.flax_fields.has(p):
		_world.remove_flax_field(p)
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


## The share off every tech that the standing buildings give: the best single one (0 to 1), so two cairns count as one.
func research_discount() -> float:
	var best := 0.0
	for b in buildings:
		best = maxf(best, float(Data.BUILDINGS[b["type"]].get("research_discount", 0.0)))
	return best


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
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "house":
			total += int(Data.HOME_TIERS[b["tier"]]["housing"])  # a home houses what its tier does
		else:
			total += def.get("housing", 0)
		if b["type"] == "dwelling" and _research.unlocked("shelter"):
			total += 2
	return total + granary_homes()


## The homes Granaries add: one for every Data.GRANARY_FOOD food in the stockpile, up to Data.GRANARY_HOMES.
func granary_homes() -> int:
	if not _research.unlocked("granaries"):
		return 0
	return mini(floori(_economy.food_total() / Data.GRANARY_FOOD), Data.GRANARY_HOMES)


## How many Cart Sheds stand, and so how many haulers pull hand carts (Data.CARTS_PER_SHED each).
func carts_allowed() -> int:
	var n := 0
	for b in buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "shed":
			n += Data.CARTS_PER_SHED
	return n


# --- Work --------------------------------------------------------------------


## True for the buildings a Kith staffs.
static func needs_worker(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]]["kind"] in ["gatherer", "processor"]


## How many people building `b` needs at work: 1, or its `crew`.
static func crew_size(b: Dictionary) -> int:
	return int(Data.BUILDINGS[b["type"]].get("crew", 1))


## The CREW_SLOTS building `b` has, in order.
static func crew_slots(b: Dictionary) -> Array:
	return CREW_SLOTS.slice(0, crew_size(b))


## True when every place at building `b` is taken.
static func is_staffed(b: Dictionary) -> bool:
	for slot in crew_slots(b):
		if b[slot] < 0:
			return false
	return true


## What a cycle at `b` makes: the building's `out`, for a Mine its `dig` of the ore on its tile, for a Trading Post
## what it is set to get, for a Tool Bench the tool it is making.
static func recipe_out(b: Dictionary) -> Dictionary:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def.has("makes"):
		return Data.RECIPES[b["make"]]["out"]
	if def.has("dig"):
		return {b["ore"]: def["dig"]}
	if def.get("trade", false):
		return {b["get"]: Data.TRADE_GET} if is_trading(b) else {}
	return def["out"]


## What a cycle at `b` uses: the building's `in`, for a Trading Post what it is set to give, for a Tool Bench what
## its tool takes.
static func recipe_in(b: Dictionary) -> Dictionary:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def.has("makes"):
		return Data.RECIPES[b["make"]]["in"]
	if def.get("trade", false):
		return {b["give"]: Data.TRADE_GIVE} if is_trading(b) else {}
	return def.get("in", {})


## True for a Trading Post that has been told what to give and what to get.
static func is_trading(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]].get("trade", false) and b["give"] != "" and b["get"] != ""


## Tell Trading Post `i` to swap `gives` for `gets` ("" for one not chosen yet). False when it isn't a Trading Post, or
## the two are one good, or either is not a good. What it had loaded of the old good goes back to the stockpile.
func set_trade(i: int, gives: String, gets: String) -> bool:
	var b: Dictionary = buildings[i]
	if not Data.BUILDINGS[b["type"]].get("trade", false) or (gives == gets and gives != ""):
		return false
	for id in [gives, gets]:
		if id != "" and not Data.ITEMS.has(id):
			return false
	for id in b["inbuf"]:
		_economy.add(id, b["inbuf"][id])
	b["inbuf"].clear()
	b["give"] = gives
	b["get"] = gets
	b["progress"] = 0.0
	return true


## Carry by hand: empty the building's output into the stockpile and load its inputs from the stockpile.
func haul(index: int) -> void:
	var b: Dictionary = buildings[index]
	for id in b["out"]:
		_economy.add(id, b["out"][id])
	b["out"].clear()
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] == "processor":
		var recipe := recipe_in(b)
		for id in recipe:
			var want: int = recipe[id] * 2 - b["inbuf"].get(id, 0)
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
			if def.get("trade", false) and not is_trading(b):
				return false
			var recipe := recipe_in(b)
			for id in recipe:
				if b["inbuf"].get(id, 0) < recipe[id]:
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
		if not saved.has("focus") and Data.BUILDINGS[b["type"]]["kind"] == "gatherer":
			b["focus"] = default_focus(b["pos"])  # a save from before huts had a focus: pick as a new hut would
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
	b["focus"] = String(d.get("focus", ""))
	for key in ["progress", "unreachable", "field_extra", "rush_cd"]:
		b[key] = float(d[key])
	for key in ["gather_index", "worker", "trips"]:
		b[key] = int(d[key])
	b["mate"] = int(d.get("mate", -1))  # a save from before the Mine has no second place
	b["tier"] = clampi(int(d.get("tier", 0)), 0, Data.HOME_TIERS.size() - 1)  # a save from before dwelling tiers has every home at the first
	b["check"] = float(d.get("check", 0.0))
	b["met"] = float(d.get("met", 0.0))
	b["ore"] = String(d.get("ore", ""))
	b["give"] = String(d.get("give", ""))
	b["get"] = String(d.get("get", ""))
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	b["make"] = String(d.get("make", def["makes"][0] if def.has("makes") else ""))
	return b
