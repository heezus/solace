extends RefCounted
## The Livewire block (design-system/23-livewire.md, stage 1): the Order Board's standing orders and the net the Power Poles make.
## An order is one line: When a good in the stores is below or above a number, then one verb on a kind of building. The verbs are
## Pause (workshops and mines only: a building finishes the job it is on, then waits, with its worker and its stock) and Bring
## first (haulers serve that kind of building ahead of the rest, and keep the good from the others while the targets are short of
## it, for Data.BRING_SKIP_SECONDS at most, so a rule can never stall a hauler). Pause beats Bring first. The orders are read every
## Data.ORDER_EVAL_SECONDS of game time, and wait while no Order Board stands. The net is worked out in scripts/power.gd and held
## here (`nets`), so Buildings and Workers ask this block how a machine is powered and how fast it runs.
## Sim owns one, reached as `sim.livewire`. Static helpers work on the Sim passed in; this block keeps no reference to a block.
## Signal: said(message) is a line for the event log (an order fired).

signal said(message: String)

const Data = preload("res://scripts/data.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Power = preload("res://scripts/power.gd")

## The standing orders, each: {item, compare, number, verb, target, holding, fired, born, said, claim}. `target` is a building type
## ("" until one is chosen), `fired` the game time it last began to hold (-1 for never), `born` when it was written, `said` when it
## last wrote to the event feed and `claim` the seconds a Bring first has been short of its good.
var orders: Array = []
var time := 0.0  # game seconds since the run began
## The nets (scripts/power.gd): {poles, engines, machines, given, asks}, rebuilt when Buildings.road_rev changes. Not saved.
var nets: Array = []
var net_of: Dictionary = {}  # the tile of a pole, a machine or an engine -> its index in `nets`
var net_rev := -1
var _clock := 0.0  # seconds since the orders were last read
var _held: Dictionary = {}  # building type -> true while a Pause holds it
var _first: Dictionary = {}  # building type -> true while a Bring first serves it ahead of the rest
var _kept: Dictionary = {}  # good -> the building types it is kept for (Bring first, while the targets are short of it)

# --- Each tick -----------------------------------------------------------------------------------------------------


## One tick: count the net, and read the orders when it is time.
func tick(s, delta: float) -> void:
	time += delta
	Power.update(s)
	if orders.is_empty() and _held.is_empty() and _first.is_empty():
		return
	_clock += delta
	if _clock >= Data.ORDER_EVAL_SECONDS:
		_clock = 0.0
		_read(s)


## The net a tile is on, {} when it is on none.
func net_at(p: Vector2i) -> Dictionary:
	return nets[net_of[p]] if net_of.has(p) else {}


## True when a net that gives power reaches tile p (Buildings.is_powered asks this besides the Boiler and Wheel reach).
func powered_at(p: Vector2i) -> bool:
	return net_at(p).get("given", 0) > 0


## How fast the machine at b runs: 1.0, or the net's ratio when it is on a net that is short.
func speed_of(b: Dictionary) -> float:
	return Power.speed(net_at(b["pos"]))


## True while a Pause holds building b: it finishes the job it is on and waits.
func is_held(b: Dictionary) -> bool:
	return _held.has(b["type"])


## True while a Bring first serves building b ahead of the rest.
func serves_first(b: Dictionary) -> bool:
	return _first.has(b["type"])


## True when the good `item` is kept from building b for now: a Bring first names other buildings, and they are short of it.
func kept_back(b: Dictionary, item: String) -> bool:
	return _kept.has(item) and b["type"] not in _kept[item]


# --- Reading the orders --------------------------------------------------------------------------------------------


func _read(s) -> void:
	_held = {}
	_first = {}
	_kept = {}
	var board := has_board(s)
	for o in orders:
		var live: bool = board and o["target"] != "" and when_holds(s, o) and _stands(s, o["target"])
		if live and not o["holding"]:
			o["fired"] = time
			if time - o["said"] >= Data.ORDER_FEED_SECONDS or o["said"] < 0.0:
				o["said"] = time
				said.emit(Data.ORDER_FIRED_LINE % text(o))
		o["holding"] = live
		if not live:
			o["claim"] = 0.0
		elif o["verb"] == "pause":
			_held[o["target"]] = true
		else:
			_first[o["target"]] = true
	for type in _held:
		_first.erase(type)  # a Pause beats a Bring first on the same building
	for o in orders:
		if o["holding"] and o["verb"] == "bring" and _first.has(o["target"]):
			_claim(s, o)


## A Bring first that is short of its good keeps the good from the other buildings for a while: the targets' open wants for it
## are more than the stockpile holds. Once it has gone on for Data.BRING_SKIP_SECONDS the claim is dropped.
func _claim(s, o: Dictionary) -> void:
	var unmet := 0
	for b in s.town.buildings:
		if b["type"] == o["target"]:
			var want: int = Haulers.stock_wanted(s, b).get(o["item"], 0)
			unmet += maxi(want - b["inbuf"].get(o["item"], 0) - b["incoming"].get(o["item"], 0), 0)
	o["claim"] = o["claim"] + Data.ORDER_EVAL_SECONDS if unmet > 0 else 0.0
	if unmet > 0 and o["claim"] <= Data.BRING_SKIP_SECONDS and s.economy.inv.get(o["item"], 0) < unmet:
		if not _kept.has(o["item"]):
			_kept[o["item"]] = []
		_kept[o["item"]].append(o["target"])


## True when the When of order o holds now: the good in the stores is below or above the number.
func when_holds(s, o: Dictionary) -> bool:
	var have: int = s.economy.inv.get(o["item"], 0)
	return have < o["number"] if o["compare"] == "below" else have > o["number"]


func _stands(s, type: String) -> bool:
	return s.town.buildings.any(func(b): return b["type"] == type)


# --- The Board -----------------------------------------------------------------------------------------------------


## True while an Order Board stands. The orders wait without one.
func has_board(s) -> bool:
	return _stands(s, "order_board")


## How many orders the Board holds: Data.ORDER_SLOTS, and the Foremen and Chain Orders techs add more.
func slots(s) -> int:
	var n: int = Data.ORDER_SLOTS
	if s.tech_tree.researched.has("foremen"):
		n += Data.ORDER_SLOTS_FOREMEN
	if s.tech_tree.researched.has("chain_orders"):
		n += Data.ORDER_SLOTS_CHAIN
	return n


## How many orders hold now.
func holding_count() -> int:
	return orders.filter(func(o): return o["holding"]).size()


## Write a new order: the first good the Kith have seen, below the first number, no target yet (it does nothing until a kind of
## building is chosen). False when every slot is used.
func add(s) -> bool:
	if orders.size() >= slots(s):
		return false
	var items := items_for(s)
	(
		orders
		. append(
			{
				"item": Data.ORDER_START_ITEM if Data.ORDER_START_ITEM in items else items[0],
				"compare": "below",
				"number": Data.ORDER_START_NUMBER,
				"verb": "pause",
				"target": "",
				"holding": false,
				"fired": -1.0,
				"born": time,
				"said": -1.0,
				"claim": 0.0,
			}
		)
	)
	return true


## Tear order i up.
func clear(i: int) -> void:
	if i >= 0 and i < orders.size():
		orders.remove_at(i)


## The goods an order can read: the ones the Kith have held, in the top bar's order.
func items_for(s) -> Array:
	var out: Array = Data.ITEM_ORDER.filter(func(id): return s.economy.seen.has(id) or s.economy.inv.get(id, 0) > 0)
	return out if not out.is_empty() else [Data.ORDER_START_ITEM]


## Building types an order's verb can name: workshops and mines to Pause; those and the fed ones (a Boiler) to Bring first.
## Only ones that are open to the Kith, and the one the order already names.
func targets_for(s, verb: String, current := "") -> Array:
	return Data.BUILD_ORDER.filter(
		func(type): return type == current or (s.town.unlocked(type) and can_target(verb, type))
	)


## True when verb `verb` can be written against buildings of type `type`.
static func can_target(verb: String, type: String) -> bool:
	var def: Dictionary = Data.BUILDINGS[type]
	if verb == "pause":
		return def["kind"] == "processor"
	return def["kind"] == "processor" or def.get("fed", false)


## Step an order's good to the next the Kith have seen.
func cycle_item(s, i: int) -> void:
	var items := items_for(s)
	orders[i]["item"] = items[(items.find(orders[i]["item"]) + 1) % items.size()]


func toggle_compare(i: int) -> void:
	var o: Dictionary = orders[i]
	o["compare"] = "above" if o["compare"] == "below" else "below"


## Step an order's number up (dir 1) or down (dir -1) along Data.ORDER_NUMBERS.
func step_number(i: int, dir: int) -> void:
	var nums: Array = Data.ORDER_NUMBERS
	var now: int = orders[i]["number"]
	var at := -1  # the last of the numbers that is no more than this one
	for k in nums.size():
		if nums[k] <= now:
			at = k
	var to := at + 1 if dir > 0 else (at - 1 if at >= 0 and nums[at] == now else at)
	orders[i]["number"] = nums[clampi(to, 0, nums.size() - 1)]


## Step an order to the next verb; its target is cleared if the new verb cannot name it.
func cycle_verb(i: int) -> void:
	var o: Dictionary = orders[i]
	var verbs: Array = Data.ORDER_VERB_ORDER
	o["verb"] = verbs[(verbs.find(o["verb"]) + 1) % verbs.size()]
	if o["target"] != "" and not can_target(o["verb"], o["target"]):
		o["target"] = ""


## Step an order to the next kind of building its verb can name.
func cycle_target(s, i: int) -> void:
	var o: Dictionary = orders[i]
	var types := targets_for(s, o["verb"], o["target"])
	if not types.is_empty():
		o["target"] = types[(types.find(o["target"]) + 1) % types.size()]


# --- Words ---------------------------------------------------------------------------------------------------------


## The order as a line: "When Coal is below 20: Pause Forges".
func text(o: Dictionary) -> String:
	var what := Data.ORDER_NO_TARGET
	if o["target"] != "":
		var kind := plural(Data.BUILDINGS[o["target"]]["name"])
		what = (
			Data.ORDER_PAUSE_TEXT % kind
			if o["verb"] == "pause"
			else Data.ORDER_BRING_TEXT % [Data.ITEMS[o["item"]]["name"], kind]
		)
	return Data.ORDER_WHEN % [Data.ITEMS[o["item"]]["name"], o["compare"], o["number"], what]


## When order o last fired, or that it holds now, or that it has gone stale (not fired for Data.ORDER_STALE_SECONDS).
func last_firing(o: Dictionary) -> String:
	if o["holding"]:
		return Data.ORDER_NOW
	if is_stale(o):
		return Data.ORDER_STALE % span(time - maxf(o["fired"], o["born"]))
	if o["fired"] < 0.0:
		return Data.ORDER_NEVER
	return Data.ORDER_LAST % span(time - o["fired"])


## True when an order is not holding and has not begun to for Data.ORDER_STALE_SECONDS (since it was written, if never).
func is_stale(o: Dictionary) -> bool:
	return not o["holding"] and time - maxf(o["fired"], o["born"]) >= Data.ORDER_STALE_SECONDS


## "45 s" or "3 min": a duration as a short phrase.
static func span(seconds: float) -> String:
	if seconds < 90.0:
		return "%d s" % maxi(roundi(seconds), 1)
	return "%d min" % roundi(seconds / 60.0)


## A kind of building's name in the plural: "Kiln" -> "Kilns", "Bloomery" -> "Bloomeries", "Smelter" -> "Smelters".
static func plural(word: String) -> String:
	if word.ends_with("y") and not word.right(2).left(1) in ["a", "e", "i", "o", "u"]:
		return word.left(word.length() - 1) + "ies"
	if word.ends_with("s") or word.ends_with("x") or word.ends_with("ch") or word.ends_with("sh"):
		return word + "es"
	return word + "s"


# --- Save ----------------------------------------------------------------------------------------------------------


## The orders and the clock, as JSON-safe values. The net is rebuilt on load, and what the orders hold is read again at once.
func to_dict() -> Dictionary:
	var list: Array = []
	for o in orders:
		list.append(o.duplicate())
	return {"orders": list, "time": time}


## Restore what to_dict wrote. An order keeps whether it was holding, so a load does not make it fire again.
func from_dict(d: Dictionary) -> void:
	time = float(d.get("time", 0.0))
	orders = []
	for saved in d.get("orders", []):
		var type := String(saved.get("target", ""))
		var item := String(saved.get("item", Data.ORDER_START_ITEM))
		if (type != "" and not Data.BUILDINGS.has(type)) or not Data.ITEMS.has(item):
			continue  # a rule about something the game no longer has is dropped
		(
			orders
			. append(
				{
					"item": item,
					"compare": "above" if String(saved.get("compare", "below")) == "above" else "below",
					"number": int(saved.get("number", Data.ORDER_START_NUMBER)),
					"verb": String(saved.get("verb", "pause")),
					"target": type,
					"holding": bool(saved.get("holding", false)),
					"fired": float(saved.get("fired", -1.0)),
					"born": float(saved.get("born", 0.0)),
					"said": float(saved.get("said", -1.0)),
					"claim": float(saved.get("claim", 0.0)),
				}
			)
		)
	nets = []
	net_of = {}
	net_rev = -1
	_held = {}
	_first = {}
	_kept = {}
	_clock = Data.ORDER_EVAL_SECONDS  # read the orders on the first tick
