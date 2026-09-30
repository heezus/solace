extends RefCounted
## The Economy block: the stockpile, food and eating, and the item flows behind the top bar's rates.
## It stands alone: it never reaches into another block. What it needs from outside comes in at
## construction (the researched techs, a read-only view) or as an argument (how many mouths to feed).
## Sim owns one, reached as `sim.economy`.
## Signal: food_low fires once when the food would run out within Data.FOOD_WARN_SECONDS (see `low`).

signal food_low

const Data = preload("res://scripts/data.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Flows = preload("res://scripts/flows.gd")

var inv: Dictionary = {}  # item id -> count
var seen: Dictionary = {}  # items ever held, so the top bar keeps showing them
var food_credit := 5.0  # food already eaten but not yet used up: eating takes whole items
var starving := false  # the last feed found no food to eat
## The early warning is up: food_low has fired and the food hasn't yet recovered to last Data.FOOD_CLEAR_SECONDS.
## Not saved: a loaded game works it out again on its first feed.
var low := false
var food_use := 0.0  # food eaten per second right now
var flows := Flows.new()  # what made and used each item lately
var _techs: Dictionary  # researched tech ids (a view of the Research block's set, never written here)


func _init(researched: Dictionary = {}) -> void:
	_techs = researched
	for id in Data.ITEM_ORDER:
		inv[id] = 0
	inv["berries"] = Data.START_BERRIES
	for id in ["wood", "stone", "flint", "berries"]:
		seen[id] = true


# --- Stockpile ---------------------------------------------------------------


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if inv.get(id, 0) < cost[id]:
			return false
	return true


## Take `cost` out of the stockpile. Callers check can_afford first: this doesn't (see try_pay).
func pay(cost: Dictionary) -> void:
	for id in cost:
		inv[id] -= cost[id]


## Pay only if the whole cost is covered. Returns false, and takes nothing, when it isn't.
func try_pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	pay(cost)
	return true


func add(id: String, amount: int) -> void:
	inv[id] = inv.get(id, 0) + amount
	seen[id] = true


# --- Food --------------------------------------------------------------------


## What one item of `id` is worth as food. Baking and Smoking make flour and berries worth more.
func food_value(id: String) -> float:
	if id == "flour" and _techs.has("baking"):
		return Data.BAKED_FLOUR_FOOD
	if id == "berries" and _techs.has("smoking"):
		return Data.SMOKED_BERRY_FOOD
	return Data.FOOD_VALUE[id]


## All the food in the stockpile, in food units.
func food_total() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		total += inv.get(id, 0) * food_value(id)
	return total


## Feed `mouths` for `delta` seconds: sets food_use (Preservation cuts it) and the starving flag.
## Returns true when everyone ate.
func feed(mouths: int, delta: float) -> bool:
	food_use = mouths * Data.FOOD_PER_KITH_PER_SEC * (0.75 if _techs.has("preservation") else 1.0)
	var fed := eat(food_use * delta)
	starving = not fed
	_watch_food()
	return fed


## Food made per second by anything but the player's own hands (huts, the Fishing Weir, the Grindstone), in
## food units, over the flow window. The player answers a warning by gathering, so that doesn't count here.
func food_income() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		var by_source := flows.parts(id)
		for source in by_source:
			if source != "hand" and by_source[source] > 0.0:
				total += by_source[source] * food_value(id)
	return total


## Food made per second, in food units, over the whole flow window (Data.RATE_WINDOW seconds, so a stretch
## with little history counts as little): everything but eating, that is huts, haulers, fields, the Fishing
## Weir, the Grindstone and the player's hands while they are gathering. A stockpile is not income.
func food_supply() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		var by_source := flows.parts_over(id, float(Data.RATE_WINDOW))
		for source in by_source:
			if source != Data.FLOW_EAT_SOURCE and by_source[source] > 0.0:
				total += by_source[source] * food_value(id)
	return total


## True when the food coming in over the window at least covers what the people eat right now: the
## rule that lets the population grow (a big stockpile alone never does).
func food_is_steady() -> bool:
	return food_supply() - food_use >= 0.0


## How long the food lasts, in seconds: the stockpile plus the credit already taken from it, against what
## the Kith eat less what the buildings bring in. INF when the food is not going down.
func seconds_of_food() -> float:
	return _runway(food_use - food_income())


func _runway(drain: float) -> float:
	return (food_total() + food_credit) / drain if drain > 0.0 else INF


## Raise the early warning when the food is about to run out; lower it once it would last longer again.
## (The buildings' income is only worked out when the food is short: it walks the flow window.)
func _watch_food() -> void:
	var gross := _runway(food_use)
	if not low and gross < Data.FOOD_WARN_SECONDS and seconds_of_food() < Data.FOOD_WARN_SECONDS:
		low = true
		food_low.emit()
	elif low and (gross >= Data.FOOD_CLEAR_SECONDS or seconds_of_food() >= Data.FOOD_CLEAR_SECONDS):
		low = false


## Eat `need` food units, taking whole items in eating order as the credit runs out.
## Returns false when the stockpile can't cover it.
func eat(need: float) -> bool:
	while food_credit < need:
		var id := _next_food()
		if id == "":
			return false
		inv[id] -= 1
		flows.add(id, -1, Data.FLOW_EAT_SOURCE)
		food_credit += food_value(id)
	food_credit -= need
	return true


## The first food in eating order the stockpile can spare, or "" if none.
func _next_food() -> String:
	for id in Data.EAT_ORDER:
		var keep := flour_reserve() if id == "flour" else 0
		if inv.get(id, 0) > keep:
			return id
	return ""


## Flour kept back for research, so eating doesn't take the Bronze Dawn cost.
func flour_reserve() -> int:
	var keep := 0
	for tech in Data.TECHS:
		if not _techs.has(tech):
			keep += Data.TECHS[tech]["cost"].get("flour", 0)
	return keep


# --- Flows -------------------------------------------------------------------


## Note `amount` of `item` made (positive) or used up (negative) by `source`.
func note(item: String, amount: float, source: String) -> void:
	flows.add(item, amount, source)


## Move the flow window on by `delta` seconds.
func advance(delta: float) -> void:
	flows.advance(delta)


## Net change of `item` per second over the window.
func rate(item: String) -> float:
	return flows.rate(item)


## Per-second rate of `item` by source.
func parts(item: String) -> Dictionary:
	return flows.parts(item)


# --- Save --------------------------------------------------------------------


## Everything the block holds as JSON-safe values (the researched techs are the Research block's, not written).
func to_dict() -> Dictionary:
	return {
		"inv": Codec.int_dict(inv),
		"seen": Codec.keys(seen),
		"food_credit": food_credit,
		"starving": starving,
		"food_use": food_use,
		"flows": flows.to_dict(),
	}


## Restore what to_dict wrote, in place (other blocks may hold `inv` and `seen`). An item the save doesn't
## list counts as none, so a save from before an item was added still loads.
func from_dict(d: Dictionary) -> void:
	inv.clear()
	inv.merge(Codec.int_dict(d.get("inv", {})))
	for id in Data.ITEM_ORDER:
		if not inv.has(id):
			inv[id] = 0
	seen.clear()
	seen.merge(Codec.to_set(d.get("seen", [])))
	food_credit = float(d.get("food_credit", 0.0))
	starving = bool(d.get("starving", false))
	food_use = float(d.get("food_use", 0.0))
	flows.from_dict(d.get("flows", {}))
