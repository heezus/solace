extends RefCounted
## Sim: the whole simulation, with no rendering, so it runs headless in tests. It is a thin owner. It holds
## one of each block (`fog`, `world`, `pathing`, `economy`, `tech_tree`, `town`, `people`, `story`) and
## nothing else about the map, the stockpile, the techs, the buildings or the Kith: callers reach a block
## through its name (`sim.economy.inv`, `sim.world.tile_at(p)`). What stays here is what no single block
## can do: the commands that touch several blocks at once (`place`, `demolish`, `research`,
## `gather_by_hand`...), the few flags of the run itself, and the tick order:
##   1. Land.grow_if_due (the tick after Bronze Dawn, the map doubles east), economy.advance the stockpile's clocks,
##      then tech_tree.tick (each finished tech runs `_tech_done`)
##   2. people.assign_jobs, economy.feed and people.grow, then story.update (the checklist and the story moments)
##   3. every Kith takes a step (Forage in a famine, else Workers, Haulers or a plain walk), and what they now see is revealed
##   4. every building takes its turn (Workers.tick_building), then the "Needs road" alert
## The work cycle is in Work, Bonuses, Hands, Roads, Workers and Haulers: static modules that take the Sim.
## The blocks never call each other to report: they emit signals, and _init connects them (Story listens, the message queue listens).

## The player clicked the Strange Stone (it reveals the hidden techs). Story listens.
signal shard_found

const Data = preload("res://scripts/data.gd")
const Fog = preload("res://scripts/fog.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Economy = preload("res://scripts/economy.gd")
const World = preload("res://scripts/world.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Kith = preload("res://scripts/kith.gd")
const Story = preload("res://scripts/story.gd")
const Research = preload("res://scripts/research.gd")
const Hands = preload("res://scripts/hands.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")
const Forage = preload("res://scripts/forage.gd")
const Land = preload("res://scripts/land.gd")

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
## The researched techs, built first: Economy and Research both hold this one set (it is `tech_tree.researched`).
var tech_set: Dictionary = {}
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


## Wire the blocks together. Every signal connection in the game is here, so it is all in one place.
func _init() -> void:
	tech_tree.tech_researched.connect(story.on_tech_researched)
	people.learned.connect(story.on_learned)
	people.trip_started.connect(story.on_trip_started)
	shard_found.connect(story.on_shard_found)
	people.announce.connect(_announce)
	economy.food_low.connect(_on_food_low)


# --- Map ---------------------------------------------------------------------


## Make a new map and set the camp up on it: the Hearth, the first sight of the land and the first Kith.
func generate(seed_value: int) -> void:
	world.generate(seed_value)
	fog.setup(world.width, world.height)
	town.add_building("camp", world.camp_pos)
	pathing.build()
	fog.reveal(world.camp_pos, Data.SIGHT_START)
	people.found(Data.KITH_START)


## How far something sees: Scouting adds to buildings and Kith alike.
func _sight(base: int) -> int:
	return base + (Data.SCOUTING_SIGHT if tech_tree.researched.has("scouting") else 0)


# --- Working by hand ---------------------------------------------------------


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


## Harvest tile p by hand: the item goes to the stockpile and the Kith watching learn from it. The Strange
## Stone gives its text and tells Story instead.
func gather_by_hand(p: Vector2i) -> String:
	if not fog.is_revealed(p):
		return ""
	var tile := world.tile_at(p)
	if tile == "shard":
		shard_seen = true
		shard_found.emit()
		return Data.SHARD_TEXT
	if tile == "":
		return ""
	var item: String = Data.TILES[tile]["yields"]
	if item == "" or (Data.TILES[tile].has("tech") and not tech_tree.researched.has(Data.TILES[tile]["tech"])):
		return ""  # nothing to gather, or ore before Prospecting
	var n := Hands.harvest_yield(self, item)
	economy.add(item, n)
	economy.note(item, n, Data.FLOW_HAND_SOURCE)
	Hands.teach(self, item)
	return "+%d %s" % [n, Data.ITEMS[item]["name"]]


# --- Tech --------------------------------------------------------------------


## Research `tech` and set off what that does elsewhere (see _tech_done).
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
		for b in town.buildings:
			fog.reveal(b["pos"], _sight(Data.SIGHT_BUILDING))
	events.append(Data.DISCOVERED_EVENT % Data.TECHS[tech]["name"])
	if tech == "haulers":
		for b in town.buildings:
			b["trips"] = 0  # huts loop on their own from now on
	if tech == "bronze_dawn":
		won = true  # the stone age is won; the game goes on (the land grows east on the next tick)


## Connected to Kith.announce: tell the player something (the UI shows and clears `events`).
func _announce(message: String) -> void:
	events.append(message)


## Connected to Economy.food_low: the early warning, before anyone leaves.
func _on_food_low() -> void:
	events.append(Data.FOOD_LOW_EVENT % Data.PEOPLE["many"])


## Read-only view for the Research block: are hidden techs on show yet?
func _hidden_shown() -> bool:
	return shard_seen


## Read-only view for the Pathing block: is this tech researched?
func _has_tech(tech: String) -> bool:
	return tech_tree.researched.has(tech)


# --- Buildings ---------------------------------------------------------------


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
	var b: Dictionary = town.buildings[i]
	people.release_worker(b)
	for id in b["out"]:
		economy.add(id, b["out"][id])
	for id in b["inbuf"]:
		economy.add(id, b["inbuf"][id])
	people.drop_tasks_at(i)
	town.remove_at(i)
	people.shift_buildings_after(i)


## A paused building frees its worker and gets no deliveries until it's resumed.
func set_paused(i: int, on: bool) -> void:
	town.set_paused(i, on)
	if on:
		people.release_worker(town.buildings[i])


# --- Simulation --------------------------------------------------------------


func tick(delta: float) -> void:
	Land.grow_if_due(self)
	economy.advance(delta)
	for tech in tech_tree.tick():
		_tech_done(tech)
	people.assign_jobs()
	var fed := economy.feed(people.kith.size(), delta)
	people.grow(delta, fed)
	story.update(self)

	if fed:
		for k in people.kith:
			if Forage.tick(self, k, delta):
				continue
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
	for b in town.buildings:
		town.tick_timers(b, delta)
		Workers.tick_building(self, b, delta, fed)
		if (
			tech_tree.researched.has("haulers")
			and Buildings.needs_worker(b)
			and not b["paused"]
			and not Roads.linked(self, b)
		):
			var a: String = b["alert"]
			if a == "" or a.begins_with("Full") or a.begins_with("Needs"):
				b["alert"] = "Needs road"  # it still works by clicks, but no hauler serves it
