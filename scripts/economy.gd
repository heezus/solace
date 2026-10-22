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
const Rules = preload("res://scripts/rules.gd")
const Storage = preload("res://scripts/storage.gd")

var inv: Dictionary = {}  # item id -> count
var seen: Dictionary = {}  # items ever held, so the top bar keeps showing them
var food_credit := 5.0  # food already eaten but not yet used up: eating takes whole items
var starving := false  # the last feed found no food to eat
## The early warning is up: food_low has fired and the food hasn't yet recovered to last Data.FOOD_CLEAR_SECONDS.
## Not saved: a loaded game works it out again on its first feed.
var low := false
## The famine is on: the food would run out within Data.FOOD_FAMINE_SECONDS, so idle people forage (scripts/forage.gd).
## It comes down once the food would last Data.FOOD_FORAGE_END_SECONDS. Not saved, like `low`.
var famine := false
var forage_told := false  # the player has been told about this famine's foraging; not saved
var famine_card_shown := false  # the run's one famine card has been put up (saved: a loaded run does not see it twice)
var steady_held := 0.0  # seconds the buildings' food has covered what everyone eats, without a break
var food_use := 0.0  # food eaten per second right now
var flows := Flows.new()  # what made and used each item lately
## The most of each good the stockpile holds (scripts/storage.gd; Sim sets it every tick). Empty means no limit, as in a bare
## Economy. A good over its cap is never taken down: a stage start or a test may put more in than a delivery could.
var caps: Dictionary = {}
var spilled := 0  # goods lost over the cap this run, for the scorecards; not saved
var spilled_of: Dictionary = {}  # the same by good, for the baseline; not saved
## Seasons of Strain switches (scripts/seasons.gd sets them every tick, so they are not saved): how much of the usual the people eat,
## whether births wait, whether idle hands forage even without a famine, and how many times as much a foraging trip brings.
var eat_factor := 1.0
var births_paused := false
var forage_call := false
var forage_mult := 1
var _caps_key := -1  # refresh_caps's last count of Storehouses and techs
var _rot: Dictionary = {}  # good -> the part of an item that has spoiled but not yet been taken
var _techs: Dictionary  # researched tech ids (a view of the Research block's set, never written here)
var _steady_second := -1  # the flow-window second `_steady_ok` was worked out in
var _steady_ok := false  # the window is full and its food covers what everyone eats (worked out once a second)


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


## Put `amount` of `id` in the stockpile. What would not fit under the cap is lost (`spilled`).
func add(id: String, amount: int) -> void:
	var have: int = inv.get(id, 0)
	var room: int = caps.get(id, 1 << 30) - have
	if amount > room:
		spilled += amount - maxi(room, 0)
		spilled_of[id] = spilled_of.get(id, 0) + amount - maxi(room, 0)
		amount = maxi(room, 0)
	inv[id] = have + amount
	seen[id] = true


## Work the caps out from the Storehouses among `buildings` and the techs learned (scripts/storage.gd). Called every tick; it only
## does the sums again when the number of Storehouses or of techs has changed.
func refresh_caps(buildings: Array) -> void:
	var storehouses := 0
	for b in buildings:
		if b["type"] == "storehouse":
			storehouses += 1
	var key := storehouses * 1000 + _techs.size()
	if key == _caps_key:
		return
	_caps_key = key
	caps = {}
	for id in Data.ITEM_ORDER:
		caps[id] = Storage.capacity(id, storehouses, _techs)


## Give goods back that were the player's own (a refund, a workshop's loaded inputs): nothing spills.
func give_back(id: String, amount: int) -> void:
	inv[id] = inv.get(id, 0) + amount
	seen[id] = true


## True when `id` is within Data.STORAGE_FULL_SHARE of its cap, so the chip says "full".
func is_full(id: String) -> bool:
	return caps.has(id) and inv.get(id, 0) >= int(caps[id] * Data.STORAGE_FULL_SHARE)


## Food spoils slowly (Data.SPOIL_GOODS): a share of the stock above Data.SPOIL_FLOOR goes each minute, half as much with
## Preservation. The small stock the people live on is never taxed. It shows in the flows as "spoil".
func spoil(delta: float) -> void:
	var share := Data.SPOIL_PER_MINUTE / 60.0 * (0.5 if _techs.has("preservation") else 1.0)
	for id in Data.SPOIL_GOODS:
		var over: int = inv.get(id, 0) - Data.SPOIL_FLOOR
		if over <= 0:
			_rot[id] = 0.0
			continue
		# Kept to millionths, so a saved game reads back the very same number.
		_rot[id] = snappedf(_rot.get(id, 0.0) + over * share * delta, 0.000001)
		var gone := mini(int(_rot[id]), over)
		if gone > 0:
			_rot[id] = snappedf(_rot[id] - gone, 0.000001)
			inv[id] -= gone
			flows.add(id, -float(gone), "spoil")


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
	food_use = mouths * Data.FOOD_PER_KITH_PER_SEC * (0.75 if _techs.has("preservation") else 1.0) * eat_factor
	var fed := eat(food_use * delta)
	spoil(delta)
	starving = not fed
	_watch_steady(delta)
	_watch_food()
	return fed


## Food made per second by anything but the player's own hands and idle foragers (huts, the Fishing Weir, the
## Grindstone), in food units, over the flow window. The player answers a warning by gathering and the famine
## fallback by foraging, so neither counts here: the warning stays up until the stockpile itself has recovered.
func food_income() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		var by_source := flows.parts(id)
		for source in by_source:
			if not _not_income(source) and by_source[source] > 0.0:
				total += by_source[source] * food_value(id)
	return total


## Food made per second, in food units, over the whole flow window (Data.RATE_WINDOW seconds, so a stretch
## with little history counts as little): what the buildings make (huts and their haulers, fields, the Fishing
## Weir, the Grindstone). The player's own hands are not income and neither is the stockpile: a burst of
## hand-gathering is a spike, and growth waits for food that keeps coming without the player.
func food_supply() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		var by_source := flows.parts_over(id, float(Data.RATE_WINDOW))
		for source in by_source:
			if source != Data.FLOW_EAT_SOURCE and not _not_income(source) and by_source[source] > 0.0:
				total += by_source[source] * food_value(id)
	return total


## Food made by hand or by idle foragers is not income: the player's own hands and a famine fallback never make
## the population grow.
static func _not_income(source: String) -> bool:
	return source == Data.FLOW_HAND_SOURCE or source == Data.FLOW_FORAGE_SOURCE


## The rule that lets the population grow, and the note beside the Kith count says the same thing: the food the
## buildings make over the whole flow window (Data.RATE_WINDOW seconds, all of it elapsed) has covered what
## everyone eats for Data.STEADY_SECONDS (counting up while it does and down while it does not, so a short dip in
## a long run of output does not start it all again, but output covered only half the time never gets there). A big
## stockpile never does, a burst of hand-gathering doesn't, and neither does a single trip: its bundle stays in the
## window for only RATE_WINDOW seconds, less than the hold.
func food_is_steady() -> bool:
	return steady_held >= Data.STEADY_SECONDS


## True while the buildings' food over the whole window (all of it elapsed) covers what everyone eats right now.
## One step of the growth rule (see food_is_steady).
func food_covers_eating() -> bool:
	return flows.hist.size() >= Data.RATE_WINDOW and (food_supply() - food_use >= 0.0 or _a_food_store_is_nearly_full())


## True when a food good's store is at the share a resting producer starts again at or more: its producers rest
## (scripts/store_rest.gd), so no food comes in, and none is needed.
func _a_food_store_is_nearly_full() -> bool:
	for id in Data.FOOD_VALUE:
		if caps.has(id) and inv.get(id, 0) >= int(caps[id] * Data.STORAGE_RESUME_SHARE):
			return true
	return false


## Keep `steady_held`: the window's food is only weighed once a second, when the flow window closes one.
func _watch_steady(delta: float) -> void:
	var second := floori(flows.clock)
	if second != _steady_second:
		_steady_second = second
		_steady_ok = food_covers_eating()
	steady_held = snappedf(
		clampf(steady_held + (delta if _steady_ok else -delta), 0.0, Data.STEADY_SECONDS * 2.0), 0.01
	)


## How long the food lasts, in seconds: the stockpile plus the credit already taken from it, against what
## the Kith eat less what the buildings bring in. INF when the food is not going down.
func seconds_of_food() -> float:
	return _runway(food_use - food_income())


func _runway(drain: float) -> float:
	return (food_total() + food_credit) / drain if drain > 0.0 else INF


## True once per run, when a famine is on past the player's own opening (Data.FORAGE_OPENING_SECONDS): the owner puts the
## famine card up and the game waits behind it. Later famines are left to the Food readout and the chips.
func take_famine_card() -> bool:
	if famine_card_shown or not famine or forage_call or flows.clock < Data.FORAGE_OPENING_SECONDS:
		return false
	famine_card_shown = true
	return true


## Raise the early warning when the food is about to run out; lower it once it would last longer again.
## (The buildings' income is only worked out when the food is short: it walks the flow window.)
func _watch_food() -> void:
	var gross := _runway(food_use)
	if not low and gross < Data.FOOD_WARN_SECONDS and seconds_of_food() < Data.FOOD_WARN_SECONDS:
		low = true
		food_low.emit()
	elif low and (gross >= Data.FOOD_CLEAR_SECONDS or seconds_of_food() >= Data.FOOD_CLEAR_SECONDS):
		low = false
	if forage_call:
		famine = true  # a lean season answered with foraging: idle hands go out at once
	elif famine and (gross >= Data.FOOD_FORAGE_END_SECONDS or seconds_of_food() >= Data.FOOD_FORAGE_END_SECONDS):
		famine = false
		forage_told = false
	elif (
		not famine
		and (low or flows.clock >= Data.FORAGE_OPENING_SECONDS)
		and gross < Data.FOOD_FAMINE_SECONDS
		and seconds_of_food() < Data.FOOD_FAMINE_SECONDS
	):
		famine = true


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


## Flour kept back for research, so eating doesn't take the Bronze Dawn cost. A tech that can't be researched yet
## (its effect isn't built) keeps nothing back, and neither does a later era's tech while that era has not begun.
func flour_reserve() -> int:
	var keep := 0
	for tech in Data.TECHS:
		if int(Data.TECHS[tech].get("era", 1)) > 1 and not _techs.has("bronze_dawn"):
			continue
		if not _techs.has(tech) and Rules.tech_enabled(tech):
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
		"rot": _rot,
		"steady_held": steady_held,
		"famine_card_shown": famine_card_shown,
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
	_rot = d.get("rot", {}).duplicate()
	steady_held = float(d.get("steady_held", 0.0))
	famine_card_shown = bool(d.get("famine_card_shown", false))
	_steady_second = -1
	flows.from_dict(d.get("flows", {}))
