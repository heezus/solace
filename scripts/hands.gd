extends RefCounted
## Working by hand (design-system/14-hands-to-haulers.md): what a hold-to-harvest gives and how long it
## takes, teach by doing (a Kith who watches you harvest a resource Data.LEARN_CLICKS times learns to
## gather it), and crafting. Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Ranks = preload("res://scripts/ranks.gd")


## One harvest by hand: base x tool x rank. The base is 1 plus one per rank bought beyond I on the
## item's gathering tech; the best yield tool that applies multiplies it (Stone Axe x3 on Wood); then the
## item's Yield bonuses that aren't tied to a kind of building (Foraging on Berries).
static func harvest_yield(s, item: String) -> int:
	var parts: Array = []
	for bonus in Bonuses.active(s, {"type": "camp", "pos": s.camp_pos, "worker": -1}, item):
		if bonus["group"] == "yield" and not Data.BONUSES[bonus["id"]].has("kinds"):
			parts.append(bonus)
	var mult := 1
	for t in _tools(s, item):
		mult = maxi(mult, t.get("mult", 1))
	return roundi((1 + Ranks.item_bonus(s, item)) * mult * Bonuses.total(parts, "yield"))


## Seconds of holding for one harvest of `item`: Data.HOLD_TIME, or the shortest hold a tool gives.
static func hold_time(s, item: String) -> float:
	var t_min := Data.HOLD_TIME
	for t in _tools(s, item):
		t_min = minf(t_min, t.get("hold", Data.HOLD_TIME))
	return t_min


## The hand tools that apply to `item` now.
static func _tools(s, item: String) -> Array:
	var out: Array = []
	for id in Data.HAND_TOOLS:
		var t: Dictionary = Data.HAND_TOOLS[id]
		if t.has("item") and t["item"] != item:
			continue
		if t.get("crafted", false) and not s.hand_tools:
			continue
		if t.has("tech") and not s.researched.has(t["tech"]):
			continue
		out.append(t)
	return out


## What holding on `p` would harvest: its item, or "" (fog, a building or road on it, nothing to gather).
static func item_at(s, p: Vector2i) -> String:
	if not s.fog.is_revealed(p) or s.building_at.has(p) or s.roads.has(p) or s.tile_at(p) == "":
		return ""
	return Data.TILES[s.tile_at(p)]["yields"]


## How many Kith hold a Flint Tool.
static func tools_held(s) -> int:
	var n := 0
	for k in s.kith:
		if k["tool"] > 0:
			n += 1
	return n


## Count a harvest toward teaching `item`; at Data.LEARN_CLICKS the next Kith in Data.PEOPLE_NAMES learns it.
static func teach(s, item: String) -> void:
	s.hand_counts[item] = s.hand_counts.get(item, 0) + 1
	if s.people.knows(item) or s.hand_counts[item] < Data.LEARN_CLICKS:
		return
	var who: String = (
		s.kith[s.learned.size() % s.kith.size()]["name"]
		if not s.kith.is_empty()
		else Data.NAMELESS % Data.PEOPLE["one"]
	)
	s.people.learn(item, who)
	var job: Dictionary = Data.HUT_JOBS.get(item, {"title": "Gatherer", "craft": "gathering"})
	s.events.append("%s learned %s. %s the %s" % [who, job["craft"], who, job["title"]])


# --- Crafting by hand ----------------------------------------------------------


static func recipe_unlocked(s, recipe: String) -> bool:
	return s.researched.has(Data.RECIPES[recipe]["tech"])


static func craft(s, recipe: String) -> bool:
	var r: Dictionary = Data.RECIPES[recipe]
	if not recipe_unlocked(s, recipe) or not s.can_afford(r["in"]):
		return false
	s._pay(r["in"])
	for id in r["in"]:
		s.flows.add(id, -r["in"][id], "craft")
	for id in r["out"]:
		s.add(id, r["out"][id])
		s.flows.add(id, r["out"][id], "craft")
	if r["out"].has("flint_tools"):
		s.hand_tools = true
	return true
