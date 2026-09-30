extends RefCounted
## Working by hand (design-system/14-hands-to-haulers.md): what a click gives, teach by doing (a Kith
## who watches you gather a resource Data.LEARN_CLICKS times learns to gather it), and crafting.
## Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Ranks = preload("res://scripts/ranks.gd")


## One click on a resource tile: base x tool x rank. The base is 1 plus one per rank bought beyond I on
## the item's gathering tech; the best tool that applies multiplies it (Flint Tools x2 once you've made
## one, Stone Axe x3 on Wood); then the item's Yield bonuses that aren't tied to a kind of building
## (Foraging on Berries).
static func click_yield(s, item: String) -> int:
	var parts: Array = []
	for bonus in Bonuses.active(s, {"type": "camp", "pos": s.camp_pos, "worker": -1}, item):
		if bonus["group"] == "yield" and not Data.BONUSES[bonus["id"]].has("kinds"):
			parts.append(bonus)
	return roundi((1 + Ranks.item_bonus(s, item)) * click_tool(s, item) * Bonuses.total(parts, "yield"))


## The best click tool for `item`: 1 with none.
static func click_tool(s, item: String) -> int:
	var best := 1
	for id in Data.CLICK_TOOLS:
		var t: Dictionary = Data.CLICK_TOOLS[id]
		if t.has("item") and t["item"] != item:
			continue
		if t.get("crafted", false) and not s.hand_tools:
			continue
		if t.has("tech") and not s.researched.has(t["tech"]):
			continue
		best = maxi(best, t["mult"])
	return best


## Count a click toward teaching `item`; at Data.LEARN_CLICKS the next Kith in Data.PEOPLE_NAMES learns it.
static func teach(s, item: String) -> void:
	s.hand_counts[item] = s.hand_counts.get(item, 0) + 1
	if s.knows(item) or s.hand_counts[item] < Data.LEARN_CLICKS:
		return
	var who: String = Data.PEOPLE_NAMES[s.learned.size() % Data.PEOPLE_NAMES.size()]
	s.learned[item] = who
	s.events.append("%s can gather %s now" % [who, Data.ITEMS[item]["name"]])
	s.record_story("first_lesson")


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
