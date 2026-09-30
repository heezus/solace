extends RefCounted
## Tech ranks I to III (design-system/14-hands-to-haulers.md). Rank I is the tech itself; ranks II and
## III are optional buys on the same card, each costing Data.RANK_COST_STEP times the rank before.
## A tech has ranks when Data.TECHS gives it a `rank` entry: {"item": id} adds 1 to that item's click
## base per rank beyond I, {"building": type} is +25% Speed there (the BONUSES "rank_<type>" entry).
## Ranks are side progress: Bronze Dawn never needs them. Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")


## 0 before the tech is researched, 1 once it is, then 2 or 3 as ranks are bought on its card.
static func rank(s, tech: String) -> int:
	if not s.researched.has(tech):
		return 0
	return s.ranks.get(tech, 1)


static func has_ranks(tech: String) -> bool:
	return Data.TECHS[tech].has("rank")


## What rank `r` (2 or 3) costs: Data.RANK_COST_STEP times the rank before it, from the tech's own cost.
static func cost(tech: String, r: int) -> Dictionary:
	var out := {}
	var base: Dictionary = Data.TECHS[tech]["cost"]
	for id in base:
		out[id] = roundi(base[id] * pow(Data.RANK_COST_STEP, r - 1))
	return out


## The next rank's cost, or {} when there is none to buy.
static func next_cost(s, tech: String) -> Dictionary:
	var r := rank(s, tech)
	if not has_ranks(tech) or r < 1 or r >= Data.MAX_RANK:
		return {}
	return cost(tech, r + 1)


static func can_buy(s, tech: String) -> bool:
	var c := next_cost(s, tech)
	return not c.is_empty() and s.can_afford(c)


static func buy(s, tech: String) -> bool:
	if not can_buy(s, tech):
		return false
	s._pay(next_cost(s, tech))
	s.ranks[tech] = rank(s, tech) + 1
	s.events.append("%s rank %s" % [Data.TECHS[tech]["name"], Data.RANK_NAMES[s.ranks[tech]]])
	return true


## Ranks beyond I on the gathering tech for `item`: each adds 1 to the click base.
static func item_bonus(s, item: String) -> int:
	var n := 0
	for tech in Data.TECHS:
		if Data.TECHS[tech].get("rank", {}).get("item", "") == item:
			n += maxi(rank(s, tech) - 1, 0)
	return n


## "+1 Wood a click" or "+25% Kiln speed": what each rank beyond I adds.
static func effect_text(tech: String) -> String:
	var r: Dictionary = Data.TECHS[tech].get("rank", {})
	if r.has("item"):
		return "+1 %s a click" % Data.ITEMS[r["item"]]["name"]
	if r.has("building"):
		var bonus: Dictionary = Data.BONUSES["rank_" + r["building"]]
		return "+%d%% %s speed" % [roundi(bonus["add"] * 100.0), Data.BUILDINGS[r["building"]]["name"]]
	return ""
