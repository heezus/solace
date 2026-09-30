extends RefCounted
## The whole simulation: map, stockpile, tech, buildings. No rendering here,
## so it can run headless in tests.
## The blocks never call each other to report: they emit signals, and _init below is the one place that
## connects them (Story listens, the message queue listens).

## The player clicked the Strange Stone (it reveals the hidden techs). Story listens.
signal shard_found

const Data = preload("res://scripts/data.gd")
const Fog = preload("res://scripts/fog.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Economy = preload("res://scripts/economy.gd")
const Flows = preload("res://scripts/flows.gd")
const World = preload("res://scripts/world.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Kith = preload("res://scripts/kith.gd")
const Story = preload("res://scripts/story.gd")
const Research = preload("res://scripts/research.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Hands = preload("res://scripts/hands.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")

const WIDTH := World.WIDTH
const HEIGHT := World.HEIGHT
const NEIGHBORS := World.NEIGHBORS

var won := false
var hand_tools := false  # you've made a Flint Tool, so hand gathering is doubled for good
var shard_seen := false  # the player has clicked the Strange Stone, revealing hidden techs
var hand_counts: Dictionary = {}  # item -> times harvested by hand
## Hold to harvest: the tile being held, seconds held so far, and 0 to 1 of the current harvest.
var harvest_tile := Vector2i(-1, -1)
var harvest_held := 0.0
var harvest_frac := 0.0
var rushes := 0  # buildings rushed so far
var ranks: Dictionary = {}  # tech -> rank bought on its card (2 or 3); a researched tech is rank 1
var events: Array = []  # messages for the UI to show and clear
var fog := Fog.new()
var tech_set: Dictionary = {}  # the researched techs, built first: Economy and Research both hold this one set (use `researched`)
var world := World.new()  # the map: tiles, camp and shard positions, roads and fields
var pathing := Pathing.new(world, _has_tech)  # the walking grid and A*; it reads `world` and the techs
var economy := Economy.new(tech_set)  # stockpile, food and flows; it reads the techs but never writes them
## Techs: what is researched, requirements, the goal and the queue. It pays through `economy`.
var tech_tree := Research.new(economy, tech_set, _hidden_shown)
## The buildings that stand on the map, the rules for placing and tearing them down, power and housing.
## It builds through `world` and `economy`, asks `tech_tree` what is unlocked and reads the fog.
var town := Buildings.new(world, economy, tech_tree, fog.is_revealed)
## The people: the Kith, who they are, how many, what they work at and where they walk. They read `world`,
## `pathing`, `town` and `tech_tree`, eat through `economy`, and report messages through _announce.
var people := Kith.new(world, pathing, economy, tech_tree, town)
## The story moments and the opening checklist. It listens to the other blocks' signals (see _init).
var story := Story.new()

# Pass-throughs to the Story block, for callers not yet moved to `story`.
var story_events: Array:  # stable ids from Data.STORY_EVENTS, in the order they happened
	get:
		return story.events
var goals_done: Dictionary:  # goal id -> true
	get:
		return story.goals_done

# Pass-throughs to the World and Pathing blocks, for callers not yet moved to `world` and `pathing`.
var tiles: Array:  # flat array of tile ids, index = y * WIDTH + x
	get:
		return world.tiles
var camp_pos: Vector2i:
	get:
		return world.camp_pos
	set(value):
		world.camp_pos = value
var shard_pos: Vector2i:
	get:
		return world.shard_pos
	set(value):
		world.shard_pos = value
var roads: Dictionary:  # Vector2i -> true
	get:
		return world.roads
var fields: Dictionary:  # Vector2i -> true, grain tiles the Kith sowed
	get:
		return world.fields
var astar: AStarGrid2D:
	get:
		return pathing.astar

# Pass-throughs to the Buildings block, for callers not yet moved to `town`.
var buildings: Array:  # each: {type, pos, progress, inbuf, out, status, gather_items, gather_index, worker, ...}
	get:
		return town.buildings
var building_at: Dictionary:  # Vector2i -> index into buildings
	get:
		return town.building_at
var road_rev: int:  # bumped whenever roads or buildings change, so Roads rebuilds its networks
	get:
		return town.road_rev
	set(value):
		town.road_rev = value
var road_net: Dictionary:  # Roads' cache of the road networks and which buildings they link
	get:
		return town.road_net
	set(value):
		town.road_net = value

# Pass-throughs to the Kith block, for callers not yet moved to `people`.
var kith: Array:  # each a person on the map: {pos, path, job, building, phase, timer, carry, task, name, tool, ...}
	get:
		return people.kith
var born: int:  # people named so far, for the next name
	get:
		return people.births
var learned: Dictionary:  # item -> name of the person who learned to gather it by watching you
	get:
		return people.learned_by

# Pass-throughs to the Research block, for callers not yet moved to `tech_tree`.
var researched: Dictionary:
	get:
		return tech_tree.researched
var research_goal: String:  # the tech the research queue is working toward, "" for none
	get:
		return tech_tree.goal
var research_queue: Array:  # the next techs on the way there, researched as soon as affordable
	get:
		return tech_tree.queue

# Pass-throughs to the Economy block, for callers not yet moved to `economy`.
var inv: Dictionary:
	get:
		return economy.inv
var seen: Dictionary:  # items the player has ever held, so the top bar keeps showing them
	get:
		return economy.seen
var food_credit: float:
	get:
		return economy.food_credit
	set(value):
		economy.food_credit = value
var starving: bool:
	get:
		return economy.starving
	set(value):
		economy.starving = value
var food_use: float:  # food eaten per second right now
	get:
		return economy.food_use
var flows: Flows:
	get:
		return economy.flows


## Wire the blocks together. Every signal connection in the game is here, so it is all in one place.
func _init() -> void:
	tech_tree.tech_researched.connect(story.on_tech_researched)
	people.learned.connect(story.on_learned)
	people.trip_started.connect(story.on_trip_started)
	shard_found.connect(story.on_shard_found)
	people.announce.connect(_announce)


# --- Map ---------------------------------------------------------------------


## Make a new map and set the camp up on it: the Hearth, the first sight of the land and the first Kith.
func generate(seed_value: int) -> void:
	world.generate(seed_value)
	fog.setup(world.width, world.height)
	town.add_building("camp", world.camp_pos)
	pathing.build()
	fog.reveal(world.camp_pos, Data.SIGHT_START)
	people.found(Data.KITH_START)


func in_bounds(p: Vector2i) -> bool:
	return world.in_bounds(p)


func tile_at(p: Vector2i) -> String:
	return world.tile_at(p)


## How far something sees: Scouting adds to buildings and Kith alike.
func _sight(base: int) -> int:
	return base + (Data.SCOUTING_SIGHT if researched.has("scouting") else 0)


# --- Stockpile ---------------------------------------------------------------


func can_afford(cost: Dictionary) -> bool:
	return economy.can_afford(cost)


func _pay(cost: Dictionary) -> void:
	economy.pay(cost)


func add(id: String, amount: int) -> void:
	economy.add(id, amount)


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


func hut_radius() -> int:
	return town.hut_radius()


func food_value(id: String) -> float:
	return economy.food_value(id)


func gather_by_hand(p: Vector2i) -> String:
	if not fog.is_revealed(p):
		return ""
	var tile := tile_at(p)
	if tile == "shard":
		shard_seen = true
		shard_found.emit()
		return Data.SHARD_TEXT
	if tile == "":
		return ""
	var item: String = Data.TILES[tile]["yields"]
	if item == "":
		return ""
	var n := harvest_yield(item)
	add(item, n)
	economy.note(item, n, "hand")
	Hands.teach(self, item)
	return "+%d %s" % [n, Data.ITEMS[item]["name"]]


# --- Tech --------------------------------------------------------------------


## Hidden techs (Star Lore) only show once the Strange Stone has been clicked.
func tech_visible(tech: String) -> bool:
	return tech_tree.tech_visible(tech)


## How many requirements are still open. A `requires_any` list counts as one.
func missing_requirements(tech: String) -> int:
	return tech_tree.missing_requirements(tech)


func requirements_met(tech: String) -> bool:
	return tech_tree.requirements_met(tech)


func can_research(tech: String) -> bool:
	return tech_tree.can_research(tech)


func research(tech: String) -> bool:
	if not tech_tree.research(tech):
		return false
	_tech_done(tech)
	return true


## What a finished tech sets off in the rest of the game (Research only reports that it finished).
func _tech_done(tech: String) -> void:
	if tech in ["paved_roads", "rafts"]:
		pathing.refresh()
	if tech == "scouting":
		for b in buildings:
			fog.reveal(b["pos"], _sight(Data.SIGHT_BUILDING))
	events.append("Discovered %s" % Data.TECHS[tech]["name"])
	if tech == "haulers":
		for b in buildings:
			b["trips"] = 0  # huts loop on their own from now on
	if tech == "bronze_dawn":
		won = true


## Connected to Kith.announce: tell the player something (the UI shows and clears `events`).
func _announce(message: String) -> void:
	events.append(message)


## Read-only view for the Research block: are hidden techs on show yet?
func _hidden_shown() -> bool:
	return shard_seen


## Read-only view for the Pathing block: is this tech researched?
func _has_tech(tech: String) -> bool:
	return researched.has(tech)


func has_haulers() -> bool:
	return researched.has("haulers")


# --- Buildings ---------------------------------------------------------------


func building_unlocked(type: String) -> bool:
	return town.unlocked(type)


## Returns "" if the building can go here, otherwise the reason it can't.
func placement_error(type: String, p: Vector2i) -> String:
	return town.placement_error(type, p)


## Build at p and set off what that does elsewhere: the fog lifts and the walking grid updates.
func place(type: String, p: Vector2i) -> bool:
	var done := town.place(type, p)
	if done.is_empty():
		return false
	var cleared: String = done["cleared"]
	if cleared == "rock":
		events.append("Cut a pass through the rocks")
	elif cleared == "tree":
		events.append("Felled the trees for a road")
	var kind: String = done["kind"]
	if kind in ["road", "bridge"]:
		pathing.update_cell(p)
		fog.reveal(p, _sight(Data.SIGHT_KITH))
	elif kind == "field":
		pathing.update_cell(p)
	else:
		fog.reveal(p, _sight(Data.SIGHT_BUILDING))
	return true


## Place along a dragged line; returns how many went down.
func place_line(type: String, line: Array) -> int:
	var n := 0
	for p in line:
		if place(type, p):
			n += 1
	return n


## The type of whatever the player built at p (a building, road, bridge or field), or "".
func built_type(p: Vector2i) -> String:
	return town.built_type(p)


## Tear down what stands at p for half its cost back. Its worker goes idle; whatever it held
## goes to the stockpile. The Hearth stays. Returns the refund, or {} if nothing was torn down.
func demolish(p: Vector2i) -> Dictionary:
	var done := town.demolish(p)
	if done.is_empty():
		return {}
	var index: int = done["index"]
	if index < 0:
		pathing.update_cell(p)  # a road or field went
	else:
		_remove_building(index)
	var type: String = done["type"]
	events.append("Tore down the %s" % Data.BUILDINGS[type]["name"])
	return done["refund"]


func _remove_building(i: int) -> void:
	var b: Dictionary = buildings[i]
	people.release_worker(b)
	for id in b["out"]:
		add(id, b["out"][id])
	for id in b["inbuf"]:
		add(id, b["inbuf"][id])
	people.drop_tasks_at(i)
	town.remove_at(i)
	people.shift_buildings_after(i)


## A paused building frees its worker and gets no deliveries until it's resumed.
func set_paused(i: int, on: bool) -> void:
	town.set_paused(i, on)
	if on:
		people.release_worker(buildings[i])


## Resource tiles a Gatherer's Hut at p would work.
func gather_tiles(p: Vector2i) -> Array:
	return town.gather_tiles(p)


func touches_river(p: Vector2i) -> bool:
	return world.touches_river(p)


func is_powered(p: Vector2i) -> bool:
	return town.is_powered(p)


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
		var k: Dictionary = people.kith[b["worker"]]
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		return clampf(k["timer"] / _harvest_time(b, tile), 0.0, 1.0)
	return clampf(b["progress"] / _work_time(b), 0.0, 1.0)


func buffered(dict: Dictionary) -> int:
	return Buildings.buffered(dict)


## Carry by hand: empty the building's output and load its inputs from the stockpile.
func haul(index: int) -> void:
	town.haul(index)


func food_total() -> float:
	return economy.food_total()


## Relative time to cross a tile: roads are fast, forest and rocks are slow, rafting a river slower.
func walk_cost(p: Vector2i) -> float:
	return pathing.walk_cost(p)


## How many Kith the buildings house.
func housing() -> int:
	return town.housing()


func needs_worker(b: Dictionary) -> bool:
	return Buildings.needs_worker(b)


# --- Simulation --------------------------------------------------------------


func tick(delta: float) -> void:
	if won:
		return
	economy.advance(delta)
	for tech in tech_tree.tick():
		_tech_done(tech)
	people.assign_jobs()
	var fed := economy.feed(people.kith.size(), delta)
	people.grow(delta, fed)

	story.update(self)

	if fed:
		for k in people.kith:
			match k["job"]:
				"work":
					Workers.tick(self, k, delta)
				"haul":
					Haulers.tick(self, k, delta)
				_:
					people.step(k, delta)
	for k in people.kith:
		var here := Kith.tile_of(k)
		if here != k["seen"]:
			k["seen"] = here
			fog.reveal(here, _sight(Data.SIGHT_KITH))
	for b in buildings:
		town.tick_timers(b, delta)
		_tick_building(b, delta, fed)
		if has_haulers() and needs_worker(b) and not b["paused"] and not Roads.linked(self, b):
			var a: String = b["alert"]
			if a == "" or a.begins_with("Full") or a.begins_with("Needs"):
				b["alert"] = "Needs road"  # it still works by clicks, but no hauler serves it


## Flour kept back for research, so buildings don't eat the Bronze Dawn cost.
func flour_reserve() -> int:
	return economy.flour_reserve()


func _tick_building(b: Dictionary, delta: float, fed: bool) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	b["alert"] = ""
	if not needs_worker(b):
		b["status"] = def.get("status", def["desc"])
		return
	if b["paused"]:
		town.set_status(b, "Paused: its %s is free for other jobs" % people.building_job(b), "Paused")
		return
	if b["worker"] < 0:
		town.set_status(
			b,
			(
				"No %s yet: more %s needed (they grow with food and Dwellings)"
				% [people.building_job(b), Data.PEOPLE["many"]]
			),
			"Idle: no free %s" % Data.PEOPLE["one"]
		)
		return
	if not fed:
		town.set_status(b, "Hungry: bring food (berries, fish or flour)", "Hungry: no food")
		return
	if b["unreachable"] > 0.0:
		town.set_status(b, "Cut off by water: build a Wooden Bridge (Paths & Haulers)", "Cut off: needs a bridge")
		return
	if def.get("needs_power", false) and not is_powered(b["pos"]):
		town.set_status(b, "No power: build a Water Wheel nearby", "No power")
		return
	if not people.worker_home(b):
		b["status"] = "%s walking here" % people.title_of(people.kith[b["worker"]])
		return
	if not town.wants_to_work(b):
		Workers.idle_reason(self, b, def)
		return
	if def["kind"] == "gatherer":
		var k: Dictionary = people.kith[b["worker"]]
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
				if not people.knows_any(b["pos"]):
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
	people.wear(b)
	for id in def["in"]:
		b["inbuf"][id] -= def["in"][id]
		economy.note(id, -def["in"][id], b["type"])
	for id in def["out"]:
		b["out"][id] = b["out"].get(id, 0) + def["out"][id]
		economy.note(id, def["out"][id], b["type"])
