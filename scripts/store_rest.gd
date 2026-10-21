extends RefCounted
## Rest at a full store (Step 2). A road-linked hut or workshop whose every output good is at Data.STORAGE_FULL_SHARE of its cap or
## more finishes the cycle it is on, then rests: its worker stays, haulers neither empty it nor bring it inputs, and nothing it
## makes spills. It starts again when any output falls under Data.STORAGE_RESUME_SHARE of its cap. Homes, power, the Hearth, the
## Board, the Tool Bench and the trading posts are not affected. A food producer rests only while the Kith have no room to grow:
## births need food coming in (Economy.food_is_steady), and a full store of food that stopped the flow would stop them. Static,
## and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Roads = preload("res://scripts/roads.gd")


## True while building `b` rests. It only starts or stops at a cycle boundary (a workshop between cycles, a hut's worker at home),
## so a cycle that is under way is always finished. The state is kept in `b["resting"]`.
static func rests(s, b: Dictionary) -> bool:
	var goods := outputs(b)
	for id in goods:
		if Data.FOOD_VALUE.has(id) and s.people.kith.size() < s.town.housing():
			goods = []  # births need the food that comes in: a food producer rests only when there is no room to grow
	if goods.is_empty() or not Roads.automated(s, b):
		b["resting"] = false
		return false
	if not _at_boundary(s, b):
		return b.get("resting", false)
	var full := true
	var low := false
	for id in goods:
		var cap: int = s.economy.caps.get(id, 0)
		var share := float(s.economy.inv.get(id, 0)) / cap if cap > 0 else 0.0
		if share < Data.STORAGE_FULL_SHARE:
			full = false
		if share < Data.STORAGE_RESUME_SHARE:
			low = true
	b["resting"] = not low if b.get("resting", false) else full
	return b["resting"]


## The goods whose store decides whether `b` rests: a hut's focus, a workshop's output. None for the buildings that never rest.
static func outputs(b: Dictionary) -> Array:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"gatherer":
			return [b["focus"]] if b["focus"] != "" else []
		"processor":
			if def.has("makes") or def.get("trade", false):
				return []
			return Buildings.recipe_out(b).keys()
	return []


static func _at_boundary(s, b: Dictionary) -> bool:
	if Data.BUILDINGS[b["type"]]["kind"] == "gatherer":
		if b["worker"] < 0:
			return true
		var k: Dictionary = s.people.kith[b["worker"]]
		return k["phase"] == "home" and k["task"].is_empty()
	return b["progress"] <= 0.0
