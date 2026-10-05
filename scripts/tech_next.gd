extends RefCounted
## The rules behind "What to learn next": which techs can be discovered now, which one we suggest, and what the techs
## just behind them are waiting for. Pure functions of the game state, so the headless tests can check them.
## The words are in scripts/data/words.gd (NEXT_*, LOCKED_*, TECH_BLURBS).

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")
const Ui = preload("res://scripts/ui.gd")

const MAX_LOCKED := 6  # how many of the techs just behind are listed; the rest are counted


## The techs of `era` that can be discovered now: not discovered, built, in view, and everything they need is
## discovered (whether the stockpile can pay is another matter). In tree order, the ones that can be paid for first.
static func ready_now(s, era: int) -> Array:
	var out: Array = Rules.era_techs(era).filter(
		func(t):
			return (
				not s.tech_tree.researched.has(t)
				and Rules.tech_enabled(t)
				and s.tech_tree.tech_visible(t)
				and s.tech_tree.requirements_met(t)
			)
	)
	var paid: Array = out.filter(func(t): return s.tech_tree.can_research(t))
	var unpaid: Array = out.filter(func(t): return not s.tech_tree.can_research(t))
	return paid + unpaid


## The one we suggest among `techs` (the techs that can be discovered now), as {"tech", "why"}; {} when there are none.
## The rule, first match wins:
##   1. a tech on the way to the goal the player queued (the first one on that route);
##   2. a tech on the way to the first tech the opening Goals list still asks for;
##   3. the cheapest one the stockpile can pay for now (fewest items in all; ties go to tree order);
##   4. when none can be paid for, the one with the least still to gather (ties go to tree order).
## "why" is one plain line saying which of the four it was (Data.NEXT_WHY_*).
static func suggested(s, techs: Array) -> Dictionary:
	if techs.is_empty():
		return {}
	var seen := s.tech_tree.visible_set()
	var queued: String = s.tech_tree.goal
	if queued != "":
		var pick := _on_route(s, queued, techs, seen)
		if pick != "":
			return {"tech": pick, "why": _why(pick, queued, Data.NEXT_WHY_QUEUED, Data.NEXT_WHY_QUEUED_ROUTE)}
	var asked := goals_tech(s)
	if asked != "":
		var pick := _on_route(s, asked, techs, seen)
		if pick != "":
			return {"tech": pick, "why": _why(pick, asked, Data.NEXT_WHY_LIST, Data.NEXT_WHY_LIST_ROUTE)}
	var payable: Array = techs.filter(func(t): return s.tech_tree.can_research(t))
	if not payable.is_empty():
		return {"tech": _least(s, payable, false), "why": Data.NEXT_WHY_CHEAP}
	return {"tech": _least(s, techs, true), "why": Data.NEXT_WHY_CLOSE}


## The first tech the opening Goals list still asks for ("" when it asks for none, or is done).
static func goals_tech(s) -> String:
	var list: Array = s.story.goal_list()
	for i in range(s.story.current_goal(), list.size()):
		if not s.story.goals_done.has(list[i]["id"]) and list[i].has("tech"):
			return list[i]["tech"]
	return ""


## The first tech of the route to `target` that is among `techs` ("" when none of them is on the way).
static func _on_route(s, target: String, techs: Array, seen: Dictionary) -> String:
	for t in Rules.route_to(target, s.tech_tree.researched, seen):
		if t in techs:
			return t
	return ""


static func _why(pick: String, target: String, is_it: String, on_the_way: String) -> String:
	return is_it if pick == target else on_the_way % Data.TECHS[target]["name"]


## The tech among `techs` with the least to pay (`short` false: the whole price; true: what the stockpile still lacks).
static func _least(s, techs: Array, short: bool) -> String:
	var best := ""
	var best_n := 1 << 30
	for t in techs:
		var n := 0
		var cost: Dictionary = s.tech_tree.cost_of(t)
		for id in cost:
			n += maxi(int(cost[id]) - int(s.economy.inv.get(id, 0)), 0) if short else int(cost[id])
		if n < best_n or (n == best_n and Data.TECH_ORDER.find(t) < Data.TECH_ORDER.find(best)):
			best = t
			best_n = n
	return best


## The techs of `era` that are one step behind the ones that can be discovered now: not open yet, and every parent they
## wait for can be discovered now. In tree order. `techs` is ready_now(s, era).
static func locked_behind(s, era: int, techs: Array) -> Array:
	return Rules.era_techs(era).filter(
		func(t):
			return (
				not s.tech_tree.researched.has(t)
				and Rules.tech_enabled(t)
				and s.tech_tree.tech_visible(t)
				and not s.tech_tree.requirements_met(t)
				and _waits_only_on(s, t, techs)
			)
	)


## True when every parent `tech` still waits for is among `techs`; an either-or counts once any one of its parents is.
static func _waits_only_on(s, tech: String, techs: Array) -> bool:
	var def: Dictionary = Data.TECHS[tech]
	for r in def["requires"]:
		if not s.tech_tree.researched.has(r) and r not in techs:
			return false
	var any: Array = def.get("requires_any", []).filter(func(r): return s.tech_tree.tech_visible(r))
	if not any.is_empty() and not any.any(func(r): return s.tech_tree.researched.has(r) or r in techs):
		return false
	return true


## What `tech` still waits for, in words: "Fire", "Fire and Masonry", "one of Fire or Masonry".
static func needs_text(s, tech: String) -> String:
	var def: Dictionary = Data.TECHS[tech]
	var parts: Array = []
	for r in def["requires"]:
		if not s.tech_tree.researched.has(r):
			parts.append(Data.TECHS[r]["name"])
	var any: Array = def.get("requires_any", []).filter(func(r): return s.tech_tree.tech_visible(r))
	if not any.is_empty() and not any.any(func(r): return s.tech_tree.researched.has(r)):
		var names: Array = any.map(func(r): return Data.TECHS[r]["name"])
		parts.append(names[0] if names.size() == 1 else "one of " + " or ".join(names))
	return " and ".join(parts)


## What the stockpile still lacks for `tech`, in words ("3 Wood, 2 Stone"), "" when it has it all.
static func short_text(s, tech: String) -> String:
	return Ui.shortfall_text(s.economy.inv, s.tech_tree.cost_of(tech)).trim_prefix("need ")
