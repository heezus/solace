extends RefCounted
## Homes: dwelling tiers and their needs (design-system/17-needs-and-upgrades.md). A Dwelling stands at a tier (Dwelling,
## Homestead, Longhouse: Data.HOME_TIERS). Each tier asks the settlement for kinds of food (held in the stockpile, which
## the Kith eat from) and goods (carried into the home by haulers and used up slowly). A home looks at its needs every
## Data.HOME_CHECK_SECONDS, not every tick, so a late delivery is a warning and not a famine. Needs unmet only stall it:
## a home never drops a tier, and nobody leaves. It stops growing: it asks for no upgrade, and once its needs have lapsed
## (`met` run down to nothing) it houses only a Dwelling's worth, so no new Kith are born into it until they are met again.
## Static, and works on the Sim passed in, like Roads and Haulers.

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


## Seconds the home's needs must have been met (counted as in `look`) before it asks for its next tier.
static func after_of(b: Dictionary) -> float:
	return float(Data.HOME_TIERS[tier_of(b)]["after"])


## Seconds a scaffold stands, once the materials are in, before the home takes its next tier.
static func build_of(b: Dictionary) -> float:
	return float(Data.HOME_TIERS[tier_of(b)]["build"])


## What the home wants in its own stock, item -> amount, for the haulers to bring: two rounds of its tier's goods, and
## while it has asked to upgrade, the materials too.
static func wanted(b: Dictionary) -> Dictionary:
	var out := {}
	if not is_home(b):
		return out
	var goods: Dictionary = Data.HOME_TIERS[tier_of(b)]["goods"]
	for id in goods:
		out[id] = goods[id] * Data.HOME_GOOD_ROUNDS
	if b["site"] != "":
		var up := materials(b)
		for id in up:
			out[id] = out.get(id, 0) + up[id]
	return out


## The materials the home's next tier costs, item -> amount ({} at the top tier).
static func materials(b: Dictionary) -> Dictionary:
	return Data.HOME_TIERS[tier_of(b)]["up"]


## True when the home's stock holds every material of its next tier, beyond what its goods keep back.
static func materials_in(b: Dictionary) -> bool:
	var up := materials(b)
	var goods: Dictionary = Data.HOME_TIERS[tier_of(b)]["goods"]
	for id in up:
		if b["inbuf"].get(id, 0) < up[id] + goods.get(id, 0):
			return false
	return not up.is_empty()


## 0 to 1: how much of the next tier's materials the home holds (1 when they are all in).
static func fill(b: Dictionary) -> float:
	var up := materials(b)
	var need := 0
	var have := 0
	for id in up:
		need += up[id]
		have += mini(b["inbuf"].get(id, 0), up[id])
	return float(have) / float(need) if need > 0 else 1.0


## Homes at tier `tier` or above, plus those one below that have asked to reach it: what a cap on `tier` counts.
static func reaching(s, tier: int) -> int:
	var n := 0
	for b in s.town.buildings:
		if is_home(b) and (tier_of(b) >= tier or (tier_of(b) == tier - 1 and b["site"] != "")):
			n += 1
	return n


## The names of what `cost` asks for that `inv` is short of, "Bronze, Brick".
static func short_names(cost: Dictionary, inv: Dictionary) -> String:
	var names: Array = []
	for id in cost:
		if inv.get(id, 0) < cost[id]:
			names.append(Data.ITEMS[id]["name"])
	return ", ".join(names)


## Scaffolds standing now.
static func sites(s) -> int:
	var n := 0
	for b in s.town.buildings:
		if is_home(b) and b["site"] != "":
			n += 1
	return n


## True when the player's cap lets one more home reach `tier` (the cap counts that tier and above).
static func cap_allows(s, tier: int) -> bool:
	return reaching(s, tier) < s.town.home_cap(tier)


## What holds a home back from its next tier, in words, or "" when nothing does (it is on its way, or at the top).
## Needs first, then the player's cap, then a road for the haulers.
static func stalled(s, b: Dictionary) -> String:
	var tier := tier_of(b)
	if tier >= Data.HOME_TIERS.size() - 1 or b["site"] != "":
		return ""
	var st := status(s, b)
	if not st["met"]:
		return ", ".join(st["missing"])
	if b["met"] < after_of(b):
		return ""  # content, and counting toward the ask
	if not cap_allows(s, tier + 1):
		return Data.HOME_CAPPED % Data.HOME_NAMES[tier + 1]
	if sites(s) >= Data.HOME_SITES_AT_ONCE:
		return Data.HOME_BUSY % sites(s)
	if not s.economy.can_afford(materials(b)):
		return Data.HOME_NO_STOCK % short_names(materials(b), s.economy.inv)
	if not st["linked"]:
		return Data.HOME_MISSING_ROAD
	return ""


## Timers are kept to a thousandth, so a saved game reads back the very same numbers (sums of tenths drift).
static func _tidy(x: float) -> float:
	return snappedf(x, 0.001)


## One tick of a home (any other building is left alone): count up to the next look at its needs and take it, then
## move a scaffold along.
static func tick(s, b: Dictionary, delta: float) -> void:
	if not is_home(b):
		return
	b["check"] = _tidy(b["check"] + delta)
	while b["check"] >= Data.HOME_CHECK_SECONDS:
		b["check"] = _tidy(b["check"] - Data.HOME_CHECK_SECONDS)
		look(s, b)
	if b["site"] == "waiting" and materials_in(b):
		b["site"] = "building"
		b["site_t"] = 0.0
	if b["site"] == "building":
		b["site_t"] = _tidy(b["site_t"] + delta)
		if b["site_t"] >= build_of(b):
			finish(s, b)


## One look at a home's needs: `met` counts up by a check's length while they are met and down while they are not (never
## below 0, and never past twice the wait), so a missed delivery costs as long as it lasted and does not start it all again.
## Then the household uses its goods, once a round, and a home that has been content long enough asks to upgrade.
static func look(s, b: Dictionary) -> void:
	var step := Data.HOME_CHECK_SECONDS
	var ok: bool = status(s, b)["met"]
	b["met"] = clampf(b["met"] + (step if ok else -step), 0.0, after_of(b) * 2.0)
	b["content"] = ok or b["met"] > 0.0
	b["pantry"] = _tidy(b["pantry"] + step)
	if b["pantry"] >= Data.HOME_GOOD_SECONDS:
		b["pantry"] = _tidy(b["pantry"] - Data.HOME_GOOD_SECONDS)
		use_goods(s, b)
	if b["site"] == "waiting" and not cap_allows(s, tier_of(b) + 1):
		b["site"] = ""  # the player lowered the cap: the materials stay in the home, ready for later
	elif b["site"] == "" and stalled(s, b) == "" and b["met"] >= after_of(b) and can_ask(s, b):
		b["site"] = "waiting"
		b["site_t"] = 0.0


## True when a home could ask for its next tier now: there is one, the cap allows it and a road brings the haulers.
static func can_ask(s, b: Dictionary) -> bool:
	var tier := tier_of(b)
	return (
		tier < Data.HOME_TIERS.size() - 1
		and cap_allows(s, tier + 1)
		and sites(s) < Data.HOME_SITES_AT_ONCE
		and s.economy.can_afford(materials(b))
		and status(s, b)["linked"]
	)


## The household uses a round of its tier's goods, as much as the stock holds (it keeps back what an upgrade is waiting for).
static func use_goods(s, b: Dictionary) -> void:
	var goods: Dictionary = Data.HOME_TIERS[tier_of(b)]["goods"]
	var kept := materials(b) if b["site"] != "" else {}
	for id in goods:
		var n := mini(goods[id], b["inbuf"].get(id, 0) - kept.get(id, 0))
		if n > 0:
			b["inbuf"][id] -= n
			s.economy.note(id, -n, b["type"])


## The scaffold is done: the materials are used up and the home takes its next tier. It must show its needs for a while
## again before it asks for the one after.
static func finish(s, b: Dictionary) -> void:
	var up := materials(b)
	for id in up:
		b["inbuf"][id] = maxi(b["inbuf"].get(id, 0) - up[id], 0)
		s.economy.note(id, -up[id], b["type"])
	b["tier"] = tier_of(b) + 1
	b["site"] = ""
	b["site_t"] = 0.0
	b["met"] = 0.0
