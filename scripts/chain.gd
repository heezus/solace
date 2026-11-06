extends RefCounted
## What stands between the player and a tech, said plainly (design-system/25-playtesting.md, "No silent gates"). A tech is out of view
## until the Kith have had every good it costs in their hands, so a locked building or a goal can wait on a tech nobody can see. This
## walks the tech's route from the first step and names the first thing that is not just a price to pay: a good never held, a gift,
## Lesson or deed not had; else the first price not yet met. It is built from the tech data, so no goal needs a hint of its own.
## Pure functions of the game state.

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")


## The sentence for what stands in the way of `tech` ("" when nothing does but time: every step is paid for or can be at once).
## "Grindstone needs Farming. Farming isn't in view yet: gather Grain by hand once to see it."
static func note(s, tech: String) -> String:
	var found := step(s, tech)
	if found.is_empty():
		return ""
	var named: String = Data.TECHS[tech]["name"]
	var at: String = Data.TECHS[found["tech"]]["name"]
	return ("%s needs %s. " % [named, at] if found["tech"] != tech else "") + found["line"]


## The first step on the way to `tech` that cannot just be paid for now: {"tech", "kind", "line"}, {} when none stands in the way.
## `kind` is "unseen" (a good never held), "needs" (a gift, Lesson or deed), "later" (a story moment opens it) or "short" (a price
## not yet met). The first of the first three on the route wins; else the first short one.
static func step(s, tech: String) -> Dictionary:
	if s.tech_tree.researched.has(tech):
		return {}
	var short := {}
	for t in Rules.route_to(tech, s.tech_tree.researched, s.tech_tree.visible_set()):
		if s.tech_tree.can_research(t):
			continue
		var why := _why(s, t)
		if why.is_empty():
			continue
		if why["kind"] != "short":
			return why
		if short.is_empty():
			short = why
	return short


## Why `t` cannot be paid for now, as {"tech", "kind", "line"}; {} when only its parents stand in its way (they are earlier on the route).
static func _why(s, t: String) -> Dictionary:
	var def: Dictionary = Data.TECHS[t]
	var name: String = def["name"]
	if not Rules.tech_enabled(t):
		return {"tech": t, "kind": "later", "line": "%s is not in this version yet." % name}
	if def.has("after") and not s.tech_tree.story_has.call(def["after"]):
		return {"tech": t, "kind": "later", "line": "%s opens later in the story." % name}
	var unseen := _unseen(s, def)
	if not unseen.is_empty():
		return {
			"tech": t,
			"kind": "unseen",
			"line":
			"%s isn't in view yet: get %s in your hands once (gather or make it) to see it." % [name, _list(unseen)]
		}
	var open: Array = s.tech_tree.open_needs(t)
	if not open.is_empty():
		return {"tech": t, "kind": "needs", "line": "%s needs %s." % [name, _list(open)]}
	if not s.tech_tree.requirements_met(t):
		return {}
	var lacking: Array = []
	var cost: Dictionary = s.tech_tree.cost_of(t)
	for id in cost:
		var have: int = s.economy.inv.get(id, 0)
		if have < cost[id]:
			lacking.append("%d %s%s" % [cost[id] - have, Data.ITEMS[id]["name"], _made_at(id)])
	if lacking.is_empty():
		return {}
	return {"tech": t, "kind": "short", "line": "%s: short of %s." % [name, ", ".join(lacking)]}


## The names of the goods `def` costs that the Kith have never held and the stockpile lacks.
static func _unseen(s, def: Dictionary) -> Array:
	var out: Array = []
	for id in def["cost"]:
		if not s.economy.seen.has(id) and s.economy.inv.get(id, 0) <= 0:
			out.append(Data.ITEMS[id]["name"])
	return out


## " (made at a Grindstone)" for a good a building makes, else "".
static func _made_at(id: String) -> String:
	for type in Data.BUILDINGS:
		if Data.BUILDINGS[type].get("out", {}).has(id):
			return " (made at a %s)" % Data.BUILDINGS[type]["name"]
	return ""


static func _list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


## Why `tech` cannot be discovered right now, in a sentence ("" when it can): the first of already learned, not built yet, out of view
## (a good never held), a gift, Lesson or deed not had, a parent tech not learned, a price not met.
static func refusal(s, tech: String) -> String:
	if s.tech_tree.researched.has(tech):
		return "%s is already discovered." % Data.TECHS[tech]["name"]
	var why := _why(s, tech)
	if not why.is_empty() and why["kind"] != "short":
		return why["line"]
	if not s.tech_tree.requirements_met(tech):
		var parents: Array = []
		for r in Data.TECHS[tech]["requires"]:
			if not s.tech_tree.researched.has(r):
				parents.append(Data.TECHS[r]["name"])
		var any: Array = Data.TECHS[tech].get("requires_any", [])
		if parents.is_empty() and not any.is_empty():
			parents.append("one of " + " or ".join(any.map(func(r): return Data.TECHS[r]["name"])))
		if not parents.is_empty():
			return "%s needs %s first." % [Data.TECHS[tech]["name"], _list(parents)]
		var deeper := step(s, tech)
		return deeper["line"] if not deeper.is_empty() else "%s is not in view yet." % Data.TECHS[tech]["name"]
	return why["line"] if not why.is_empty() else ""
