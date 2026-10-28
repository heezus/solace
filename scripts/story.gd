extends RefCounted
## The Story block: the story moments that have happened (`events`, stable ids from Data.STORY_EVENTS, in the
## order they happened, for a future profile save) and the checklist (`goals_done`, from Data.GOALS, and from
## Data.GOALS_ERA2 once Bronze Dawn is discovered, Data.GOALS_ERA3 once the star falls, Data.GOALS_ERA4 once Ironfall
## begins and Data.GOALS_ERA5 once Livewire does: goal_list() is the one in force).
## It listens: the owner connects the other blocks' signals to the on_* methods below, so no block calls
## Story and Story never calls a block. record(id) notes a moment once. A goal is met when its `tech` is
## researched or its `building` stands, and the rest are checked by id against the Sim handed to
## goal_met() and update() (it is only read, never kept). Faction words are in Data, not spelled here.
## Sim owns one, reached as `sim.story`.
## Signal: recorded(id) fires the first time each story id is recorded.

signal recorded(id: String)

const CardText = preload("res://scripts/card_text.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Land = preload("res://scripts/land.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Power = preload("res://scripts/power.gd")

## The story moments that open an era after the stone age, in order: Bronze Dawn, the Starfall (the star falls), Ironfall, Livewire.
const ERA_OPENINGS := ["bronze_dawn", "star_falling", Data.IRONFALL_EVENT, Data.LIVEWIRE_BEGUN]

var events: Array = []  # story ids, in the order they happened
## The first cairn went up before the Falling Star fell: a run flag, saved, that a future first contact will read.
var cairn_before_landing := false
## Era-opening story id -> the game minute it was first seen (Story.update), saved, for the Chronicle's minutes per era.
var stamps: Dictionary = {}
var goals_done: Dictionary = {}  # goal id -> true; goals stay done once met, even after the items are spent
var south_note := ""  # why the south is not held now (Gate.note), for the goal's words
var south_lost := false  # the south was held and is not now
## True while an era card is up (the owner sets it, never saved): the era after it begins the tick after it is put away.
var card_up := false
var _ore_tiles: Dictionary = {}  # tile id -> its positions in the grown land (see _ore)
var _ore_width := 0
var _south_was := false  # the south was held at the last update


## True once the story moment `id` has happened.
func has_event(id: String) -> bool:
	return events.has(id)


## Note a story moment once, by its id in Data.STORY_EVENTS.
func record(id: String) -> void:
	assert(Data.STORY_EVENTS.has(id), "unknown story event " + id)
	if id in events:
		return
	events.append(id)
	recorded.emit(id)


# --- Listeners (connected by the owner) --------------------------------------


## Research.tech_researched: the techs listed in Data.STORY_TECHS are story moments.
func on_tech_researched(tech: String) -> void:
	if Data.STORY_TECHS.has(tech):
		record(Data.STORY_TECHS[tech])


## Kith.learned: the first thing anyone learns by watching.
func on_learned(_item: String, _who: String) -> void:
	record("first_lesson")


## Kith.trip_started: the first hut trip sent by hand.
func on_trip_started() -> void:
	record("first_trip")


## Sim.shard_found: the Strange Stone was clicked.
func on_shard_found() -> void:
	record("shard_found")


## Buildings.built: the first cairn is a story moment, and if the Falling Star has not fallen it sets the flag.
func on_built(type: String, _pos: Vector2i) -> void:
	if Data.BUILDINGS[type]["kind"] != "cairn" or events.has("cairn_raised"):
		return
	cairn_before_landing = not events.has("star_falling")
	record("cairn_raised")


# --- The checklist -----------------------------------------------------------


## Mark every goal that's met now. Goals stay done after that, even once the items are spent.
func update(s) -> void:
	var lists: Array = [Data.GOALS]
	if goal_list() != Data.GOALS:
		lists.append(goal_list())  # the stone age's stay checked: its last goal is met by the dawn itself
	if goal_list() == Data.GOALS_ERA5:
		lists.append(Data.GOALS_ERA4)  # and so do Ironfall's: its gate is met by the card that opens Livewire
	for list in lists:
		for g in list:
			if not goals_done.has(g["id"]) and goal_met(s, g):
				goals_done[g["id"]] = true
	if goal_list() == Data.GOALS_ERA5 and not s.tech_tree.researched.has("skyward"):
		_hold_south(s)
	# After the goals, so the era's last one (the Warning read) is ticked while its list is still in force.
	if s.starfall.ended and s.starfall.pending == "":
		record(Data.IRONFALL_EVENT)  # the Starfall is over and its card is put away: Ironfall begins
	if events.has(Data.LIVEWIRE_EVENT) and not card_up and not events.has(Data.LIVEWIRE_BEGUN):
		record(Data.LIVEWIRE_BEGUN)  # the Wires Hum card is put away: Livewire begins
		_chart_seam(s)
	for id in ERA_OPENINGS:
		if events.has(id) and not stamps.has(id):
			stamps[id] = snappedf(s.seasons.time / 60.0, 0.1)


## The minutes each era the run has reached took, the stone age first, the last one running to `total` minutes: [] for a run whose
## openings were not stamped (a save from before they were kept).
func era_minutes(total: float) -> Array:
	var starts := [0.0]
	for id in ERA_OPENINGS:
		if stamps.has(id):
			starts.append(float(stamps[id]))
		elif events.has(id):
			return []
	var out: Array = []
	for i in starts.size():
		var end: float = starts[i + 1] if i + 1 < starts.size() else total
		out.append(snappedf(maxf(end - starts[i], 0.0), 0.1))
	return out


## The south goal is not a latch: Skyward asks for the south held at the moment it is bought (Gate.south_held), so the goal
## un-ticks when the Bloom or the fuel takes that away, and the log says why.
func _hold_south(s) -> void:
	var held: bool = s.gate.south_held()
	south_note = "" if held else s.gate.note("south_held")
	if held:
		if south_lost:
			s.events.append(Data.SOUTH_LINES["held"])
		south_lost = false
	else:
		goals_done.erase("south_held")
		if _south_was:
			south_lost = true
			s.events.append(Data.SOUTH_LINES["lost"] % south_note)
	_south_was = held


## The charts lift the fog off the nearest seam nobody has seen, and the log says which way it lies.
func _chart_seam(s) -> void:
	var p: Vector2i = s.world.unseen_seam_tile(s.world.camp_pos, s.fog)
	if p.x < 0:
		return
	s.fog.reveal(p, Data.LIVEWIRE_CHART_RADIUS)
	var d := Vector2(p - s.world.camp_pos)
	s.events.append(Data.LIVEWIRE_CHART_LINE % [CardText.compass(d), roundi(d.length())])


## The checklist in force: the stone age's, and the second era's once Bronze Dawn is discovered.
func goal_list() -> Array:
	if Data.LIVEWIRE_BEGUN in events:
		return Data.GOALS_ERA5
	if Data.IRONFALL_EVENT in events:
		return Data.GOALS_ERA4
	if "star_falling" in events:
		return Data.GOALS_ERA3
	return Data.GOALS_ERA2 if "bronze_dawn" in events else Data.GOALS


## A goal's words. "{cost}" in them is the goal tech's real cost (Data.TECHS), so a gate's numbers can't drift from the tech's.
func goal_text(g: Dictionary) -> String:
	var text: String = g["text"]
	if g.has("tech") and "{cost}" in text:
		var parts: Array = []
		var cost: Dictionary = Data.TECHS[g["tech"]]["cost"]
		for id in cost:
			parts.append("%d %s" % [cost[id], Data.ITEMS[id]["name"]])
		text = text.replace("{cost}", ", ".join(parts))
	if g["id"] == "south_held" and south_note != "" and not goals_done.has("south_held"):
		text = (Data.SOUTH_LINES["goal_lost"] if south_lost else Data.SOUTH_LINES["now"]) % [text, south_note]
	return text


## A goal is met when its `tech` is researched or its `building` stands; the rest are checked by id.
func goal_met(s, g: Dictionary) -> bool:
	if g.has("tech"):
		return s.tech_tree.researched.has(g["tech"])
	if g.has("building"):
		return _has_building(s, g["building"])
	match g["id"]:
		"learn_wood":
			return s.people.knows("wood")
		"learn_berries":
			return s.people.knows("berries")
		"learn_stone":
			return s.people.knows("stone") and s.people.knows("flint")
		"flax":
			return s.hand_counts.get("fiber", 0) > 0 or s.people.knows("fiber")
		"trip":
			return "first_trip" in events or s.tech_tree.researched.has("haulers")
		"rush":
			return s.rushes > 0
		"tools":
			return s.hand_tools
		"berries":
			for b in s.town.buildings:
				if b["focus"] == "berries":
					return true
		"road":
			# a road tile that really links a building (Paths & Haulers unlocks roads); standing beside the
			# Hearth is not a road
			if not s.tech_tree.researched.has("haulers"):
				return false
			for b in s.town.buildings:
				if Buildings.needs_worker(b) and Roads.road_linked(s, b):
					return true
		"grind":
			for b in s.town.buildings:
				if b["type"] == "grindstone" and s.town.is_powered(b["pos"]):
					return true
		"find_copper":
			return _ore_seen(s, "copper_hills")
		"find_tin":
			return _ore_seen(s, "tin_stream")
		"copper_road":
			return _road_beside_ore(s, "copper_hills")
		"first_bronze":
			return s.economy.inv.get("bronze", 0) > 0
		"strangers_come", "first_set", "wreck_found", "moments_answered", "warning_read":
			return _starfall_goal_met(s, g["id"])
		"first_teardown", "find_coal", "find_iron", "iron_mine", "first_iron", "rail_laid", "first_steel":
			return _ironfall_goal_met(s, g["id"])
	return _livewire_goal_met(s, g["id"])


## The Starfall goals (Data.GOALS_ERA3) that are not about a building.
func _starfall_goal_met(s, id: String) -> bool:
	match id:
		"strangers_come":
			return s.starfall.arrived()
		"first_set":
			return s.starfall.locked.has(Data.GLYPH_SETS[1]["id"])
		"wreck_found":
			return s.starfall.wreck_found
		"moments_answered":
			return s.starfall.answered.size() >= Data.MOMENT_ORDER.size()
	return s.starfall.ended


## The era 4 goals (Data.GOALS_ERA4) that are about the land, the metal and the Rail.
func _ironfall_goal_met(s, id: String) -> bool:
	match id:
		"first_teardown":
			return s.teardown.lessons.size() > 0
		"find_coal":  # seen in the fog, or already in the stores (a run that starts with coal in hand)
			return _ore_seen(s, "coal_seam") or s.economy.inv.get("coal", 0) > 0 or s.economy.seen.has("coal")
		"find_iron":
			return (
				_ore_seen(s, "iron_hills")
				or s.economy.inv.get("iron_ore", 0) > 0
				or s.economy.seen.has("iron_ore")
				or s.economy.inv.get("iron", 0) > 0
			)
		"iron_mine":
			return s.town.buildings.any(func(b): return b["type"] == "mine" and b.get("ore", "") == "iron_ore")
		"rail_laid":
			return s.world.road_tiers.values().has(Data.RAIL_TIER)
		"first_steel":
			return s.economy.made_ever.has("steel")
	return s.economy.inv.get("iron", 0) > 0


## The era 5 goals (Data.GOALS_ERA5) that are about the net, the Wire and the orders.
func _livewire_goal_met(s, id: String) -> bool:
	match id:
		"poles_laid":
			return Power.poles_joined(s)
		"net_machine":
			return Power.working_net(s)
		"wire_made":
			return s.economy.made_ever.has("wire")
		"first_order":
			return s.livewire.orders.any(func(o): return o["target"] != "")
		"order_fired":
			return s.livewire.orders.any(func(o): return o["fired"] >= 0.0)
		"burnt_clear":
			return not s.tide.burnt.is_empty()
		"orders_written", "south_held":
			return s.gate.deed(id)
	return false


## Index into goal_list() of the first goal not yet done, or its size when all are.
func current_goal() -> int:
	var list := goal_list()
	for i in list.size():
		if not goals_done.has(list[i]["id"]):
			return i
	return list.size()


## How many goals are done, in any order: skipping one early goal never hides the later ones.
func done_count() -> int:
	var n := 0
	for g in goal_list():
		if goals_done.has(g["id"]):
			n += 1
	return n


## The ore tiles of one kind, found once per size of the map (the land grows only once, and ore is never laid later).
func _ore(s, tile: String) -> Array:
	if _ore_width != s.world.width * 1000 + s.world.height:  # the land grows east, then south
		_ore_width = s.world.width * 1000 + s.world.height
		_ore_tiles = {}
	if not _ore_tiles.has(tile):
		_ore_tiles[tile] = Land.ore_tiles(s, tile)
	return _ore_tiles[tile]


func _ore_seen(s, tile: String) -> bool:
	return _ore(s, tile).any(func(p): return s.fog.is_revealed(p))


## A road tile laid beside an ore tile of this kind: the way a Mine there is served.
func _road_beside_ore(s, tile: String) -> bool:
	for p in _ore(s, tile):
		for n in Land.SIDES:
			if s.world.roads.has(p + n):
				return true
	return false


func _has_building(s, type: String) -> bool:
	for b in s.town.buildings:
		if b["type"] == type:
			return true
	return false


# --- Save --------------------------------------------------------------------


## The story ids in order and the goals met so far, as JSON-safe values.
func to_dict() -> Dictionary:
	return {
		"events": events.duplicate(),
		"goals_done": Codec.keys(goals_done),
		"cairn_before_landing": cairn_before_landing,
		"stamps": stamps.duplicate(),
	}


## Restore what to_dict wrote. `recorded` is not emitted: these moments already happened in the saved run.
func from_dict(d: Dictionary) -> void:
	events = Codec.strings(d.get("events", []))
	goals_done = Codec.to_set(d.get("goals_done", []))
	cairn_before_landing = bool(d.get("cairn_before_landing", false))
	stamps = {}
	var saved = d.get("stamps", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for id in ERA_OPENINGS:
			if saved.has(id) and typeof(saved[id]) in [TYPE_INT, TYPE_FLOAT]:
				stamps[id] = float(saved[id])
