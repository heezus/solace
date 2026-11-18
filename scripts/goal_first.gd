extends RefCounted
## Goal first (fun playtest 6: 33 to 48 chores in Ironfall, pausing and resuming Kilns, Pits and Smelters so they do not starve the
## goal). A workshop whose goods nothing open is short of holds, when what it eats is what the goal, the research queue or the
## recipes down to them are short of: "Holding: Copper goes to the goal first". It is paused the way the player's Pause does it
## (its worker is freed, no hauler serves it) and runs again by itself the moment its own good is wanted or the good it eats is no
## longer short. Wood, Stone, Fiber, Clay and food are never drawn below a floor of 40 by a workshop that makes what is not wanted.
## The bots' own rule (tests/autoplay_ironfall.gd) is this one, so bots and players play alike. Pure functions of the game state.

const Data = preload("res://scripts/data.gd")
const Needs = preload("res://scripts/needs.gd")

const FLOOR := 40  # of a basic good the stores keep for the goal, away from a workshop whose goods nothing needs
const DEEP := 40  # of a good down the recipes (a Kiln's Clay) the stores hold before it counts as no longer short
const MARGIN := 10  # a held workshop runs again once its own good is this far below what holds it
const RESERVE := 20  # of its own good the stores hold before a workshop that makes what nothing needs rests
const EVERY := 1.0  # game seconds between looks
const BASIC := ["wood", "stone", "fiber", "clay"]
const HOLDING := "Holding: %s goes to the goal first. It runs again by itself."
const HOLDING_FLOOR := "Holding: the stores keep %s above %d for the goal. It runs again by itself."
const PILL := "Holding"


## The goods the goal in front of the player, the queued techs and the recipes down to them ask for: {good: what the stores must
## hold before it is no longer short}. A good the goal's own price lists asks for its price; a good further down asks for DEEP.
static func asked(s) -> Dictionary:
	var out := {}
	var todo: Array = []
	var list: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	var costs: Array = []
	if at < list.size():
		var g: Dictionary = list[at]
		if g.has("tech"):
			costs.append(s.tech_tree.cost_of(g["tech"]))
		elif g.has("building") and Data.BUILDINGS.has(g["building"]):
			costs.append(Data.BUILDINGS[g["building"]]["cost"])
	for tech in s.tech_tree.queue:
		costs.append(s.tech_tree.cost_of(tech))
	for cost in costs:
		for id in cost:
			out[id] = maxi(int(out.get(id, 0)), int(cost[id]))
			todo.append(id)
	var seen := {}
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		for type in Needs.makers_of(id):
			for input in Data.BUILDINGS[type].get("in", {}):
				if not out.has(input):
					out[input] = DEEP
				todo.append(input)
	return out


## The reason building `b` should hold now ("" when it should run), given `asked` (from `asked`).
static func reason(s, b: Dictionary, asked_goods: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def["kind"] != "processor" or def.get("out", {}).is_empty() or b.has("relic"):
		return ""
	if b.get("goal_free", false):
		return ""
	var held: bool = String(b.get("goal_hold", "")) != ""
	var slack := MARGIN if held else 0
	var inv: Dictionary = s.economy.inv
	var wanted := false
	for made in def["out"]:
		if asked_goods.has(made) and int(inv.get(made, 0)) < maxi(int(asked_goods[made]) - slack, 1):
			wanted = true
	if wanted:
		return ""
	var own: String = def["out"].keys()[0]
	if int(inv.get(own, 0)) < RESERVE - slack:
		return ""
	for id in def.get("in", {}):
		if asked_goods.has(id) and int(inv.get(id, 0)) < int(asked_goods[id]):
			return HOLDING % Data.ITEMS[id]["name"]
		if id in BASIC and int(inv.get(id, 0)) < FLOOR:
			return HOLDING_FLOOR % [Data.ITEMS[id]["name"], FLOOR]
	return ""


## Look at every workshop: hold the ones that should, run again the ones whose reason has passed. A workshop the player paused by
## hand is left as it is. Call once a game second.
static func update(s) -> void:
	var asked_goods := asked(s) if s.goal_first else {}
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		var held: bool = String(b.get("goal_hold", "")) != ""
		if held and not b["paused"]:
			b["goal_hold"] = ""  # the player pressed Resume: the hold is theirs to lift
			b["goal_free"] = true
			held = false
		if b["paused"] and not held:
			continue
		var why := reason(s, b, asked_goods) if s.goal_first else ""
		if why != "" and not held:
			b["goal_hold"] = why
			s.set_paused(i, true)
		elif why == "" and held:
			b["goal_hold"] = ""
			s.set_paused(i, false)
		elif why != "":
			b["goal_hold"] = why
