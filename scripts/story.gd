extends RefCounted
## The Story block: the story moments that have happened (`events`, stable ids from Data.STORY_EVENTS, in the
## order they happened, for a future profile save) and the opening checklist (`goals_done`, from Data.GOALS).
## It listens: the owner connects the other blocks' signals to the on_* methods below, so no block calls
## Story and Story never calls a block. record(id) notes a moment once. A goal is met when its `tech` is
## researched or its `building` stands, and the rest are checked by id against the Sim handed to
## goal_met() and update() (it is only read, never kept). Faction words are in Data, not spelled here.
## Sim owns one, reached as `sim.story`.
## Signal: recorded(id) fires the first time each story id is recorded.

signal recorded(id: String)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")

var events: Array = []  # story ids, in the order they happened
var goals_done: Dictionary = {}  # goal id -> true; goals stay done once met, even after the items are spent


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


# --- The checklist -----------------------------------------------------------


## Mark every goal that's met now. Goals stay done after that, even once the items are spent.
func update(s) -> void:
	for g in Data.GOALS:
		if not goals_done.has(g["id"]) and goal_met(s, g):
			goals_done[g["id"]] = true


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
	return false


## Index into Data.GOALS of the first goal not yet done, or GOALS.size() when all are.
func current_goal() -> int:
	for i in Data.GOALS.size():
		if not goals_done.has(Data.GOALS[i]["id"]):
			return i
	return Data.GOALS.size()


func _has_building(s, type: String) -> bool:
	for b in s.town.buildings:
		if b["type"] == type:
			return true
	return false


# --- Save --------------------------------------------------------------------


## The story ids in order and the goals met so far, as JSON-safe values.
func to_dict() -> Dictionary:
	return {"events": events.duplicate(), "goals_done": Codec.keys(goals_done)}


## Restore what to_dict wrote. `recorded` is not emitted: these moments already happened in the saved run.
func from_dict(d: Dictionary) -> void:
	events = Codec.strings(d.get("events", []))
	goals_done = Codec.to_set(d.get("goals_done", []))
