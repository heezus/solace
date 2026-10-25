extends RefCounted
## The supply and use ledger (the director's Step 6, part A): for one era of a baseline run, per good, where it came from and what used
## it, and per five minutes where the Kith stood. EraProbe (tests/tools/era_probe.gd) owns one: begin(s) when an era opens, sample(s)
## once a game second, finish(s) for the table (`row["ledger"]`). It only looks: nothing here changes a Sim or a bot's play.
## tests/tools/ledger_md.py turns the rows of a baseline folder into ledger_<era>.md.
##
## made / used   good -> {source: total}: from Economy.flows (what each building type, "hand", "craft" and eating made or used up),
##               totals over the era. A building's own cost (buildings and research) is `paid`, which flows leave out.
## stock         good -> [start, middle, end] of the era; `cap` is the storage cap at the end. `held` is what stood in workshop buffers and
##               on haulers' backs at the start and end, outside the stores.
## cap_s, zero_s seconds a good stood at its cap (the game's "full" chip), and at 0 while a workshop waited for it.
## check         per good: change of stores plus held against made - used - paid - spilled, and the sum over all goods (bar 2% of flow).
## kith          one entry every five minutes: Kith, homes, jobs and the ones filled, haulers wanted and standing, idle, food a minute.
## flags         the lines Step 6 reads first.

const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const WaitWhy = preload("res://scripts/wait_why.gd")

const STOCK_EVERY := 60.0  # game seconds between readings of the stock
const KITH_EVERY := 300.0  # game seconds between entries of the Kith ledger
const ZERO_SHARE := 0.10  # flag: a good at 0 with a workshop waiting for it more than this share of the era
const CAP_SHARE := 0.30  # flag: a good at its cap more than this share of the era
const IDLE_SHARE := 0.25  # flag: idle Kith over this share of the town...
const IDLE_FOR := 300.0  # ...for more than this many seconds in a row
const CHECK_SHARE := 0.02  # the bar: the goods' sum against the era's whole flow (made, used and paid), not its net change
const FINITE := ["coal"]  # goods that run out (Coal Seams); their stand-in is `RENEWABLE`
const RENEWABLE := {"coal": "charcoal"}

var era := ""
var _at := 0.0
var _made := {}
var _used := {}
var _paid := {}  # why ("build", "research", "expedition", "twin", "story") -> {good: units}
var _held := []  # [start, end]: good -> units in buffers and on haulers' backs
var _regained := {}  # "refund" / "released" -> {good: units}
var _vanished := {}  # good -> units lost with the buildings the Bloom took
var _vanish_seen := {}
var _spilled := {}
var _cap_s := {}
var _zero_s := {}
var _stock := []  # [{"t": era seconds, "stock": {good: n}}]
var _kith := []
var _food_made := 0.0  # food units made / eaten so far, and as the last Kith entry read them
var _food_eaten := 0.0
var _food_seen := [0.0, 0.0]
var _idle_run := 0.0
var _idle_longest := 0.0
var _idle_max_share := 0.0
var _adj_run := 0.0
var _adj_longest := 0.0
var _adj_max_share := 0.0
var _clock_seen := -1  # the flow window's whole seconds when it was last read (-1: not yet)
var _paid_seen := {}
var _spill_seen := {}
var _regain_seen := {}
var _next_kith := 0.0
var _kith_t := 0.0  # era seconds of the last Kith entry


func begin(name: String, s) -> void:
	era = name
	_at = s.seasons.time
	_made = {}
	_used = {}
	_paid = {}
	_spilled = {}
	_regained = {}
	_vanished = {}
	_cap_s = {}
	_zero_s = {}
	_stock = []
	_kith = []
	_food_made = 0.0
	_food_eaten = 0.0
	_food_seen = [0.0, 0.0]
	_idle_run = 0.0
	_idle_longest = 0.0
	_idle_max_share = 0.0
	_adj_run = 0.0
	_adj_longest = 0.0
	_adj_max_share = 0.0
	_clock_seen = floori(s.economy.flows.clock)
	_paid_seen = s.economy.paid.duplicate(true)
	_spill_seen = s.economy.spilled_of.duplicate()
	_regain_seen = s.economy.regained.duplicate(true)
	_vanish_seen = s.economy.vanished.duplicate()
	_held = [_held_now(s), {}]
	_next_kith = 0.0
	_kith_t = 0.0
	_take_stock(s)


## One game second of the era.
func sample(s) -> void:
	if era == "":
		return
	var t: float = s.seasons.time - _at
	_read_flows(s)
	_read_paid(s)
	_read_stores(s)
	_read_idle(s)
	if t >= (_stock.size()) * STOCK_EVERY:
		_take_stock(s)
	if t >= _next_kith:
		_next_kith += KITH_EVERY
		_take_kith(s, t)


func _read_flows(s) -> void:
	var flows = s.economy.flows
	var clock := floori(flows.clock)
	if _clock_seen < 0:
		_clock_seen = clock
		return
	var closed := mini(clock - _clock_seen, flows.hist.size())
	_clock_seen = clock
	for i in closed:
		_tally(s, flows.hist[flows.hist.size() - 1 - i])


## Add one second of the flows (item|source -> amount, negative when used) to the totals.
func _tally(s, bucket: Dictionary) -> void:
	for key in bucket:
		var parts: PackedStringArray = str(key).split("|")
		var id := parts[0]
		var source := parts[1]
		var amount: float = bucket[key]
		var into: Dictionary = _made if amount > 0.0 else _used
		var by: Dictionary = into.get(id, {})
		by[source] = by.get(source, 0.0) + absf(amount)
		into[id] = by
		if Data.FOOD_VALUE.has(id):
			var food: float = absf(amount) * s.economy.food_value(id)
			if amount > 0.0:
				_food_made += food
			elif source == Data.FLOW_EAT_SOURCE:
				_food_eaten += food


## Read what has been paid, spilled and regained since the last sample: before a checkpoint is written (those counts are not
## saved with the game, so a resumed run counts them from 0) and when the era closes.
func flush(s) -> void:
	_read_paid(s)


func _read_paid(s) -> void:
	for why in s.economy.paid:
		var by: Dictionary = _paid.get(why, {})
		for id in s.economy.paid[why]:
			var more: int = s.economy.paid[why][id] - _paid_seen.get(why, {}).get(id, 0)
			if more > 0:
				by[id] = by.get(id, 0) + more
		_paid[why] = by
	_paid_seen = s.economy.paid.duplicate(true)
	for id in s.economy.spilled_of:
		var over: int = s.economy.spilled_of[id] - _spill_seen.get(id, 0)
		if over > 0:
			_spilled[id] = _spilled.get(id, 0) + over
	_spill_seen = s.economy.spilled_of.duplicate()
	for why in s.economy.regained:
		var back_by: Dictionary = _regained.get(why, {})
		for id in s.economy.regained[why]:
			var back: int = s.economy.regained[why][id] - _regain_seen.get(why, {}).get(id, 0)
			if back > 0:
				back_by[id] = back_by.get(id, 0) + back
		_regained[why] = back_by
	_regain_seen = s.economy.regained.duplicate(true)
	for id in s.economy.vanished:
		var gone: int = s.economy.vanished[id] - _vanish_seen.get(id, 0)
		if gone > 0:
			_vanished[id] = _vanished.get(id, 0) + gone
	_vanish_seen = s.economy.vanished.duplicate()


## Seconds at the cap, and at 0 while a workshop's next cycle is short of that good.
func _read_stores(s) -> void:
	for id in s.economy.caps:
		if s.economy.inv.get(id, 0) > 0 and s.economy.is_full(id):
			_cap_s[id] = _cap_s.get(id, 0.0) + 1.0
	var waiting := {}
	for b in s.town.buildings:
		if not str(b["status"]).begins_with("Needs ") or not Buildings.needs_worker(b):
			continue
		var id := WaitWhy.missing(s, b, Buildings.recipe_in(b))
		if id != "" and s.economy.inv.get(id, 0) == 0:
			waiting[id] = true
	for id in waiting:
		_zero_s[id] = _zero_s.get(id, 0.0) + 1.0


## Idle Kith: with no job, or a hauler beyond the places the depots want. The longest run over IDLE_SHARE of the town.
func _read_idle(s) -> void:
	var share := _idle(s) / maxf(s.people.kith.size(), 1.0)
	_idle_max_share = maxf(_idle_max_share, share)
	if share > IDLE_SHARE:
		_idle_run += 1.0
		_idle_longest = maxf(_idle_longest, _idle_run)
	else:
		_idle_run = 0.0
	# The same, without the Kith whose workplace the Bloom took: the town could not have kept them in work.
	var adjusted := maxf(_idle(s) - float(s.tide.lost_jobs), 0.0) / maxf(s.people.kith.size(), 1.0)
	_adj_max_share = maxf(_adj_max_share, adjusted)
	if adjusted > IDLE_SHARE:
		_adj_run += 1.0
		_adj_longest = maxf(_adj_longest, _adj_run)
	else:
		_adj_run = 0.0


func _idle(s) -> float:
	var jobless := 0
	var haulers := 0
	for k in s.people.kith:
		if k["job"] == "":
			jobless += 1
		elif k["job"] == "haul":
			haulers += 1
	return float(jobless + maxi(haulers - _wanted(s), 0))


func _wanted(s) -> int:
	var places = s.get("hauling")
	return places.total_wanted() if places != null else 0


## What stands outside the stores: workshop and building buffers, and what haulers carry.
func _held_now(s) -> Dictionary:
	var held := {}
	for b in s.town.buildings:
		for buf in [b["inbuf"], b["out"]]:
			for id in buf:
				held[id] = held.get(id, 0) + int(buf[id])
	for k in s.people.kith:
		for id in k["carry"]:
			held[id] = held.get(id, 0) + int(k["carry"][id])
	return held


func _take_stock(s) -> void:
	var stock := {}
	for id in Data.ITEM_ORDER:
		if s.economy.inv.get(id, 0) > 0:
			stock[id] = int(s.economy.inv[id])
	_stock.append({"t": snappedf(s.seasons.time - _at, 0.1), "stock": stock})


func _take_kith(s, t: float) -> void:
	var window := maxf(t - _kith_t, 1.0) / 60.0
	_kith_t = t
	var haulers := 0
	for k in s.people.kith:
		if k["job"] == "haul":
			haulers += 1
	var made_per_min: float = (_food_made - _food_seen[0]) / window
	var eaten_per_min: float = (_food_eaten - _food_seen[1]) / window
	_food_seen = [_food_made, _food_eaten]
	(
		_kith
		. append(
			{
				"minute": snappedf(t / 60.0, 0.1),
				"kith": s.people.kith.size(),
				"homes": s.town.housing(),
				"jobs": Ui.job_slots(s),
				"jobs_filled": Ui.jobs_filled(s),
				"haulers_wanted": _wanted(s),
				"haulers_standing": haulers,
				"idle": int(_idle(s)),
				"food_made_per_min": snappedf(made_per_min, 0.1) if t >= KITH_EVERY else 0.0,
				"food_eaten_per_min": snappedf(eaten_per_min, 0.1) if t >= KITH_EVERY else 0.0,
			}
		)
	)


## Close the era: the table.
func finish(s) -> Dictionary:
	_read_flows(s)
	_tally(s, s.economy.flows.now)  # the second under way: an era ends the moment its last tech is paid for
	flush(s)
	_take_stock(s)
	_held[1] = _held_now(s)
	var length: float = maxf(s.seasons.time - _at, 1.0)
	var minutes := length / 60.0
	var goods := {}
	var ids := {}
	for source in [_made, _used, _cap_s, _zero_s]:
		for id in source:
			ids[id] = true
	for why in _paid:
		for id in _paid[why]:
			ids[id] = true
	for id in _stock[0]["stock"]:
		ids[id] = true
	for id in _stock[-1]["stock"]:
		ids[id] = true
	var sum_change := 0.0
	var sum_flow := 0.0
	var sum_through := 0.0
	var middle: Dictionary = _stock[_stock.size() >> 1]["stock"]
	for id in ids:
		var made := _total(_made.get(id, {}))
		var used := _total(_used.get(id, {}))
		var built: float = _paid.get("build", {}).get(id, 0)
		var researched: float = _paid.get("research", {}).get(id, 0)
		var other := 0.0  # the rest: an expedition's pack, a twin's upkeep, the food a moment takes
		for why in _paid:
			if why != "build" and why != "research":
				other += _paid[why].get(id, 0)
		var paid := built + researched + other
		var spilled: float = _spilled.get(id, 0)
		var refunded: float = _regained.get("refund", {}).get(id, 0)
		var released: float = _regained.get("released", {}).get(id, 0)
		var start := int(_stock[0]["stock"].get(id, 0))
		var end := int(_stock[-1]["stock"].get(id, 0))
		var held_change := int(_held[1].get(id, 0)) - int(_held[0].get(id, 0))
		var change := float(end - start + held_change)
		var vanished: float = _vanished.get(id, 0)
		var flow := made + refunded + released - used - paid - spilled - vanished
		sum_change += change
		sum_flow += flow
		sum_through += made + used + paid
		goods[id] = {
			"made_per_min": _per_min(_made.get(id, {}), minutes),
			"used_per_min": _per_min(_used.get(id, {}), minutes),
			"paid_build": int(built),
			"paid_research": int(researched),
			"paid_other": int(other),
			"spilled": int(spilled),
			"refunded": int(refunded),
			"released": int(released),
			"vanished": int(vanished),
			"held": [int(_held[0].get(id, 0)), int(_held[1].get(id, 0))],
			"stock": [start, int(middle.get(id, 0)), end],
			"cap": int(s.economy.caps.get(id, 0)),
			"cap_min": snappedf(_cap_s.get(id, 0.0) / 60.0, 0.1),
			"zero_min": snappedf(_zero_s.get(id, 0.0) / 60.0, 0.1),
			"change": int(change),  # stores plus held, end against start
			"flow_change": snappedf(flow, 0.1),
		}
	var sum_off := absf(sum_change - sum_flow)
	var check := {
		"change": int(sum_change),
		"flow_change": snappedf(sum_flow, 0.1),
		"off_share": snappedf(sum_off / maxf(sum_through, 1.0), 0.0001),
		"off_share_of_change": snappedf(sum_off / maxf(absf(sum_change), 1.0), 0.0001),
		"met": sum_off / maxf(sum_through, 1.0) <= CHECK_SHARE,
	}
	var left := 0
	for id in s.world.seam_left:
		left += int(s.world.seam_left[id])
	var out := {
		"era": era,
		"length_min": snappedf(minutes, 0.1),
		"goods": goods,
		"check": check,
		"finite": {"coal_in_ground": left, "seams": s.world.seam_left.size()},
		"kith": _kith,
		"idle_longest_over_25_s": _idle_longest,
		"idle_max_share": snappedf(_idle_max_share, 0.01),
		"idle_adjusted_longest_over_25_s": _adj_longest,
		"idle_adjusted_max_share": snappedf(_adj_max_share, 0.01),
	}
	out["flags"] = _flags(out, length)
	era = ""
	return out


static func _total(by: Dictionary) -> float:
	var n := 0.0
	for source in by:
		n += by[source]
	return n


static func _per_min(by: Dictionary, minutes: float) -> Dictionary:
	var out := {}
	for source in by:
		out[source] = snappedf(by[source] / minutes, 0.01)
	return out


## The lines Step 6 reads first: a good at 0 with a workshop waiting, a good at its cap, a finite good with nothing standing in,
## idle Kith. Each is a short sentence.
func _flags(out: Dictionary, length: float) -> Array:
	var flags: Array = []
	var goods: Dictionary = out["goods"]
	for id in goods:
		var g: Dictionary = goods[id]
		var zero: float = g["zero_min"] * 60.0
		if zero / length > ZERO_SHARE:
			flags.append(
				(
					"%s at 0 with a workshop waiting %.0f%% of the era (%.1f min)"
					% [id, 100.0 * zero / length, g["zero_min"]]
				)
			)
		var cap: float = g["cap_min"] * 60.0
		if cap / length > CAP_SHARE:
			flags.append("%s at its cap %.0f%% of the era (%.1f min)" % [id, 100.0 * cap / length, g["cap_min"]])
	for id in FINITE:
		var g: Dictionary = goods.get(id, {})
		if g.is_empty():
			continue
		var stand_in: String = RENEWABLE[id]
		var made_stand: float = _total(goods.get(stand_in, {}).get("made_per_min", {}))
		if out["finite"]["coal_in_ground"] <= 0 and g["stock"][2] <= 0 and made_stand <= 0.0:
			flags.append("%s: nothing left in the ground or the stores, and no %s made" % [id, stand_in])
	if out["idle_longest_over_25_s"] > IDLE_FOR:
		(
			flags
			. append(
				(
					"idle Kith over %.0f%% of the town for %.1f min in a row (up to %.0f%%); %.1f min (up to %.0f%%) without the jobs the Bloom took"
					% [
						100.0 * IDLE_SHARE,
						out["idle_longest_over_25_s"] / 60.0,
						100.0 * out["idle_max_share"],
						out["idle_adjusted_longest_over_25_s"] / 60.0,
						100.0 * out["idle_adjusted_max_share"]
					]
				)
			)
		)
	if not out["check"]["met"]:
		flags.append(
			(
				"the goods' sum is %.1f%% off the era's flow (bar 2%%; %.1f%% of the net change)"
				% [100.0 * out["check"]["off_share"], 100.0 * out["check"]["off_share_of_change"]]
			)
		)
	return flags


# --- Keeping a run ---------------------------------------------------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"era": era,
		"at": _at,
		"made": _made,
		"used": _used,
		"paid": _paid,
		"held": _held,
		"spilled": _spilled,
		"regained": _regained,
		"vanished": _vanished,
		"cap_s": _cap_s,
		"zero_s": _zero_s,
		"stock": _stock,
		"kith": _kith,
		"food": [_food_made, _food_eaten, _food_seen[0], _food_seen[1]],
		"idle": [_idle_run, _idle_longest, _idle_max_share, _adj_run, _adj_longest, _adj_max_share],
		"next_kith": _next_kith,
		"clock_seen": _clock_seen,
		"kith_t": _kith_t,
	}


func from_dict(d: Dictionary) -> void:
	era = d["era"]
	_at = d["at"]
	_made = d["made"]
	_used = d["used"]
	_paid = d["paid"]
	_held = d["held"]
	_spilled = d["spilled"]
	_regained = d["regained"]
	_vanished = d.get("vanished", {})
	_cap_s = d["cap_s"]
	_zero_s = d["zero_s"]
	_stock = d["stock"]
	_kith = d["kith"]
	_food_made = d["food"][0]
	_food_eaten = d["food"][1]
	_food_seen = [d["food"][2], d["food"][3]]
	_idle_run = d["idle"][0]
	_idle_longest = d["idle"][1]
	_idle_max_share = d["idle"][2]
	if d["idle"].size() > 3:
		_adj_run = d["idle"][3]
		_adj_longest = d["idle"][4]
		_adj_max_share = d["idle"][5]
	_next_kith = d["next_kith"]
	_kith_t = d["kith_t"]
	_clock_seen = int(d.get("clock_seen", -1))  # the flow window is saved with the game: read on from where it was left
	_paid_seen = {}  # Economy.paid and spilled_of are not saved: a resumed run counts them from 0
	_spill_seen = {}
	_regain_seen = {}
	_vanish_seen = {}
