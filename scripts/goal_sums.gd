extends RefCounted
## "At this rate" on a goal that needs goods (Step 9C-1): "Brick 34/90. At this rate: 4 min. One more Kiln: 2.5 min." The good that holds
## the goal longest is the one told. The rate is the top bar's net (made less used, over its window); "one more" adds a maker of the good
## at what a maker of its type makes now (or at its nominal rate when none stands), and counts it only when the good it eats can keep
## up: else the line names the input ("One more Kiln won't help: Clay is short."). Pure functions of the game state; changes nothing.

const Data = preload("res://scripts/data.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const Needs = preload("res://scripts/needs.gd")

const MIN_RATE := 0.05  # goods a minute below which a good is not rising
const KEEPS_UP := 0.5  # the share of a new maker's inputs that must be coming in for it to count


## The goods goal `g` asks for and the stock lacks: {item: still needed}, from its price now.
static func short(s, g: Dictionary) -> Dictionary:
	var cost := {}
	if g.has("tech"):
		cost = s.tech_tree.cost_of(g["tech"])
	elif g.has("building") and Data.BUILDINGS.has(g["building"]):
		cost = Data.BUILDINGS[g["building"]]["cost"]
	var out := {}
	for id in cost:
		var lacks: int = int(cost[id]) - int(s.economy.inv.get(id, 0))
		if lacks > 0:
			out[id] = lacks
	return out


## The sum line for goal `g`, "" when it needs no goods or every one is in the stockpile.
static func line(s, g: Dictionary) -> String:
	var lacking := short(s, g)
	if lacking.is_empty():
		return ""
	var item := _slowest(s, lacking)
	var need: int = int(s.economy.inv.get(item, 0)) + int(lacking[item])
	var name: String = Data.ITEMS[item]["name"]
	var net := _net(s, item)
	var text := "%s %d/%d." % [name, int(s.economy.inv.get(item, 0)), need]
	if net < MIN_RATE:
		return text + " At this rate: it is not rising." + _more(s, item, net, lacking[item])
	return text + " At this rate: %s." % minutes(float(lacking[item]) / net) + _more(s, item, net, lacking[item])


## The good of `lacking` that takes longest to arrive (one that is not rising takes forever).
static func _slowest(s, lacking: Dictionary) -> String:
	var best := ""
	var best_t := -1.0
	for id in lacking:
		var net := _net(s, id)
		var t := INF if net < MIN_RATE else float(lacking[id]) / net
		if t > best_t:
			best = id
			best_t = t
	return best


static func _net(s, item: String) -> float:
	return float(s.economy.flows.rate(item)) * 60.0


## " One more Kiln: 2.5 min." or " One more Kiln won't help: Clay is short." ("" when no maker of the good can be added).
static func _more(s, item: String, net: float, lacks: int) -> String:
	var type := _maker_type(s, item)
	if type == "":
		return ""
	var def: Dictionary = Data.BUILDINGS[type]
	var name: String = "hut" if def["kind"] == "gatherer" else String(def["name"])
	var added := _added_rate(s, type, item)
	if added <= 0.0:
		return ""
	if def["kind"] == "processor":
		var short_of := _input_short(s, def, item, added)
		if short_of != "":
			return " One more %s won't help: %s is short." % [name, Data.ITEMS[short_of]["name"]]
	var total := maxf(net, 0.0) + added
	return " One more %s: %s." % [name, minutes(float(lacks) / total)]


## The first maker type of `item` that can be built now (open), "" when none can.
static func _maker_type(s, item: String) -> String:
	if not Needs.makers_of(item).is_empty():
		for type in Needs.makers_of(item):
			if s.town.unlocked(type):
				return type
		return ""
	if s.town.unlocked("gatherers_hut") and _gathered(item):
		return "gatherers_hut"
	return ""


static func _gathered(item: String) -> bool:
	for t in Data.TILES:
		if Data.TILES[t]["yields"] == item:
			return true
	return false


## What one more of `type` would make of `item` a minute: what the ones standing make now, each, else the workshop's own rate.
static func _added_rate(s, type: String, item: String) -> float:
	var parts: Dictionary = s.economy.flows.parts(item)
	var standing := 0
	for b in s.town.buildings:
		if b["type"] == type and (Data.BUILDINGS[type]["kind"] != "gatherer" or b["focus"] == item):
			standing += 1
	if standing > 0 and parts.get(type, 0.0) > 0.0:
		return float(parts[type]) * 60.0 / standing
	var def: Dictionary = Data.BUILDINGS[type]
	if def.get("out", {}).has(item) and float(def.get("time", 0.0)) > 0.0:
		return float(def["out"][item]) * 60.0 / float(def["time"])
	return 0.0


## The input of a processor that could not keep up with one more of it making `added` a minute: its id, "" when they all can.
static func _input_short(s, def: Dictionary, item: String, added: float) -> String:
	var worst := ""
	var worst_cover := 1.0
	for id in def.get("in", {}):
		var ratio: float = float(def["in"][id]) / float(def["out"][item])
		var needed := added * ratio
		var coming := maxf(_net(s, id), 0.0)
		var cover := coming / needed if needed > 0.0 else 1.0
		if cover < KEEPS_UP and cover < worst_cover:
			worst = id
			worst_cover = cover
	return worst


## 4 minutes: "4 min", "2.5 min", "40 s".
static func minutes(t: float) -> String:
	if t < 1.0:
		return "%d s" % maxi(roundi(t * 60.0), 1)
	if t >= 10.0:
		return "%d min" % roundi(t)
	var shown := snappedf(t, 0.5)
	return ("%d min" % int(shown)) if is_equal_approx(shown, floorf(shown)) else "%.1f min" % shown
