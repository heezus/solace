extends RefCounted
## Homes: dwelling tiers and their needs (design-system/17-needs-and-upgrades.md). A Dwelling stands at a tier (Dwelling,
## Homestead, Longhouse: Data.HOME_TIERS). Each tier asks the settlement for kinds of food (held in the stockpile, which
## the Kith eat from) and goods (carried into the home by haulers and used up slowly). A home looks at its needs every
## Data.HOME_CHECK_SECONDS, not every tick, so a late delivery is a warning and not a famine. Needs unmet only stall it:
## a home never drops a tier. Static, and works on the Sim passed in, like Roads and Haulers.

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")


## True for a building that stands at a tier (a Dwelling).
static func is_home(b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]]["kind"] == "house"


## The tier a home stands at, 0 for a Dwelling.
static func tier_of(b: Dictionary) -> int:
	return clampi(int(b.get("tier", 0)), 0, Data.HOME_TIERS.size() - 1)


## What the building is called now: its tier's name for a home, its own name for the rest.
static func name_of(b: Dictionary) -> String:
	return Data.HOME_NAMES[tier_of(b)] if is_home(b) else Data.BUILDINGS[b["type"]]["name"]


## Kith the home houses at its tier (Shelter's share is added by Buildings.housing).
static func housing_of(b: Dictionary) -> int:
	return int(Data.HOME_TIERS[tier_of(b)]["housing"])


## The food kinds the stockpile holds enough of, in Data.FOOD_VALUE order.
static func foods_held(s) -> Array:
	var out: Array = []
	for id in Data.FOOD_VALUE:
		if s.economy.inv.get(id, 0) >= Data.HOME_FOOD_STOCK:
			out.append(id)
	return out


## What the home's tier asks of the settlement, and how it stands: {"tier", "foods_have", "foods_need", "food_kinds"
## (what is held), "goods" (a list of {"item", "need", "have"}: the home's own stock), "met", "missing" (words for
## what is short), "linked" (a road brings goods here)}. Pure: it reads, never changes.
static func status(s, b: Dictionary) -> Dictionary:
	var tier := tier_of(b)
	var def: Dictionary = Data.HOME_TIERS[tier]
	var kinds := foods_held(s)
	var need_foods: int = def["foods"]
	var missing: Array = []
	if kinds.size() < need_foods:
		var more := need_foods - kinds.size()
		missing.append(Data.HOME_MISSING_FOOD_ONE if more == 1 else Data.HOME_MISSING_FOOD % more)
	var goods: Array = []
	var short := {}
	for id in def["goods"]:
		var have: int = b["inbuf"].get(id, 0)
		goods.append({"item": id, "need": def["goods"][id], "have": have})
		if have < def["goods"][id]:
			short[id] = def["goods"][id] - have
	var linked: bool = s.tech_tree.researched.has("haulers") and Roads.linked(s, b)
	if not short.is_empty():
		for id in short:
			missing.append(Data.HOME_MISSING_GOOD % [short[id], Data.ITEMS[id]["name"]])
		if not s.tech_tree.researched.has("haulers"):
			missing.append(Data.HOME_MISSING_HAULERS)
		elif not linked:
			missing.append(Data.HOME_MISSING_ROAD)
	return {
		"tier": tier,
		"foods_have": kinds.size(),
		"foods_need": need_foods,
		"food_kinds": kinds,
		"goods": goods,
		"met": missing.is_empty(),
		"missing": missing,
		"linked": linked,
	}


## One tick of a home (any other building is left alone): count up to the next look at its needs, and take it.
static func tick(s, b: Dictionary, delta: float) -> void:
	if not is_home(b):
		return
	b["check"] += delta
	while b["check"] >= Data.HOME_CHECK_SECONDS:
		b["check"] -= Data.HOME_CHECK_SECONDS
		look(s, b)


## One look at a home's needs: `met` counts up by a check's length while they are met and down while they are not (never
## below 0, and never past twice the wait), so a missed delivery costs as long as it lasted and does not start it all again.
static func look(s, b: Dictionary) -> void:
	var step := Data.HOME_CHECK_SECONDS
	var ok: bool = status(s, b)["met"]
	b["met"] = clampf(b["met"] + (step if ok else -step), 0.0, Data.HOME_UPGRADE_AFTER * 2.0)
