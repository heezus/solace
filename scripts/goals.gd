extends RefCounted
## The opening checklist (Data.GOALS). Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")


## Mark every goal that's met now. Goals stay done after that, even once the items are spent.
static func update(s) -> void:
	for g in Data.GOALS:
		if not s.goals_done.has(g["id"]) and goal_met(s, g):
			s.goals_done[g["id"]] = true


## A goal is met when its `tech` is researched or its `building` stands; the rest are checked by id.
static func goal_met(s, g: Dictionary) -> bool:
	if g.has("tech"):
		return s.researched.has(g["tech"])
	if g.has("building"):
		return _has_building(s, g["building"])
	match g["id"]:
		"learn_wood":
			return s.knows("wood")
		"learn_stone":
			return s.knows("stone") and s.knows("flint")
		"trip":
			return "first_trip" in s.story_events or s.has_haulers()
		"rush":
			return s.rushes > 0
		"tools":
			return s.hand_tools
		"berries":
			for b in s.buildings:
				if "berries" in b["gather_items"]:
					return true
		"road":
			return s.roads.size() >= 5
		"grind":
			for b in s.buildings:
				if b["type"] == "grindstone" and s.is_powered(b["pos"]):
					return true
	return false


## Index into Data.GOALS of the first goal not yet done, or GOALS.size() when all are.
static func current_goal(s) -> int:
	for i in Data.GOALS.size():
		if not s.goals_done.has(Data.GOALS[i]["id"]):
			return i
	return Data.GOALS.size()


static func _has_building(s, type: String) -> bool:
	for b in s.buildings:
		if b["type"] == type:
			return true
	return false
