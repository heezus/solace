extends RefCounted
## Rate gates (Step 9C-2). The four era gates (Bronze Dawn, The Falling Star, Livewire, Skyward) no longer ask for a pile of every good:
## each lists goods to be made at R a minute or more, held for a minute, plus a small pile (a quarter of today's price) paid at research.
## With "hold 90 Brick" the best move was to wait; with "make 40 Brick a minute" it is to build more machine. Numbers: 9c-numbers-draft.md
## (the bots' machine as built two minutes before today's gate, never more than a careful player's machine plus one maker).
## The made figure is the flow view's (buildings only: hand gathering and hand crafting never count toward R). Stone and Wood stay piles.
## `held` (seconds R has been held, by "tech|good") lives in the Research block and is saved with it. Pure functions of the game state.

const Data = preload("res://scripts/data.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const Needs = preload("res://scripts/needs.gd")
const RateData = preload("res://scripts/rate_data.gd")

const LINE := "%s %d of %d a min (held %s of 1:00)"
const LINE_FULL := "%s: stores full, counts as made (held %s of 1:00)"
const LINE_ORDER := "%s: counts at full speed. Your order '%s' pauses %d %s (held %s of 1:00)"
const MORE := "One more %s: +%d."
const WONT := "One more %s won't help: %s."


## What the buildings made of `item` a minute over the flow window (the flow view's made figure, less hand work). A workshop that
## rests only because the stores of its good are full counts at its full speed: a Brick store at its cap is not a Brick shortfall.
static func made(s, item: String) -> float:
	var parts: Dictionary = s.economy.flows.parts_over(item, float(Data.RATE_WINDOW))
	var total := 0.0
	for source in parts:
		if parts[source] > 0.0 and not source in RateData.NOT_MADE_BY:
			total += parts[source]
	total *= 60.0
	if not full_makers(s, item).is_empty():
		total = maxf(total, _full_pace(s, item))
	return total


## The workshops of `item` that rest only because its stores are full, or because a standing order of the player's holds them.
static func full_makers(s, item: String) -> Array:
	var out: Array = []
	for b in FlowView.built_makers(s, item):
		if FlowView.store_full(b) or order_held(s, b):
			out.append(b)
	return out


## True while a standing order (a Pause on the Order Board) holds building `b`.
static func order_held(s, b: Dictionary) -> bool:
	return b["alert"] == Data.ORDER_PAUSED_ALERT and s.livewire.is_held(b)


## The standing order that holds the makers of `item`, with how many of them it holds: {text, count, kind}, {} when none does.
static func order_line(s, item: String) -> Dictionary:
	var stopped: Array = []
	for b in FlowView.built_makers(s, item):
		if order_held(s, b):
			stopped.append(b)
	if stopped.is_empty():
		return {}
	for o in s.livewire.orders:
		if o["holding"] and o["verb"] == "pause" and o["target"] == stopped[0]["type"]:
			var name: String = Data.BUILDINGS[o["target"]]["name"]
			return {
				"text": s.livewire.text(o),
				"count": stopped.size(),
				"kind": name if stopped.size() == 1 else s.livewire.plural(name)
			}
	return {}


## What the workshops of `item` that are working or resting on a full store would make a minute at full speed.
static func _full_pace(s, item: String) -> float:
	var pace := 0.0
	for b in FlowView.built_makers(s, item):
		var code := FlowView.wait_code(b)
		if code == "working" or FlowView.store_full(b) or order_held(s, b):
			pace += FlowView.full_rate(s, b, item)
	return pace


## Seconds the rate of `good` has been held for `tech` (0 when it is not now).
static func held(s, tech: String, good: String) -> float:
	return float(s.tech_tree.rate_held.get("%s|%s" % [tech, good], 0.0))


## True when every rated good of `tech` has been held for RateData.HOLD seconds (true for a tech that is not a gate).
static func met(s, tech: String) -> bool:
	for good in RateData.rates(tech):
		if held(s, tech, good) < RateData.HOLD:
			return false
	return true


## Look once (call about once a game second, `elapsed` seconds since the last look): every rated good of every gate not yet
## researched takes a sample of what is made a minute, and its seconds held are the minute's samples taken so far, scaled by how near
## their average is to R: a gate is met when the last minute's average is at or above R, so a dip costs ground (the average falls
## slowly) and a burst makes it up, and nothing starts again from nothing. Fun playtest 7: a one-second dip reset the minute to zero.
static func update(s, _elapsed: float) -> void:
	var held_now: Dictionary = s.tech_tree.rate_held
	var rings: Dictionary = s.tech_tree.rate_ring
	for tech in RateData.GATES:
		if s.tech_tree.researched.has(tech):
			continue
		for good in RateData.GATES[tech]:
			var key := "%s|%s" % [tech, good]
			var ring: Array = rings.get(key, [])
			ring.append(made(s, good))
			while ring.size() > int(RateData.HOLD):
				ring.pop_front()
			rings[key] = ring
			held_now[key] = held_of(ring, float(RateData.GATES[tech][good]))


## Seconds held for a ring of samples against rate `need`: the samples so far, times the share of `need` their average makes (at most 1).
static func held_of(ring: Array, need: float) -> float:
	if ring.is_empty():
		return 0.0
	var sum := 0.0
	for x in ring:
		sum += float(x)
	return float(ring.size()) * minf(sum / float(ring.size()) / need, 1.0)


## "0:35" for 35 seconds.
static func clock(seconds: float) -> String:
	var n := floori(seconds)
	return "%d:%02d" % [floori(n / 60.0), n % 60]


## One rated good's line: "Brick 34 of 40 a min (held 0:35 of 1:00)".
static func good_line(s, tech: String, good: String) -> String:
	if made(s, good) >= float(RateData.rates(tech)[good]) and not full_makers(s, good).is_empty():
		var order := order_line(s, good)
		if not order.is_empty():
			var held_for := clock(held(s, tech, good))
			return LINE_ORDER % [Data.ITEMS[good]["name"], order["text"], order["count"], order["kind"], held_for]
		return LINE_FULL % [Data.ITEMS[good]["name"], clock(held(s, tech, good))]
	return (
		LINE
		% [Data.ITEMS[good]["name"], roundi(made(s, good)), int(RateData.rates(tech)[good]), clock(held(s, tech, good))]
	)


## The lines of what `tech` still needs, one per rated good not yet held (the Research block shows them as open needs).
static func open_lines(s, tech: String) -> Array:
	var out: Array = []
	for good in RateData.rates(tech):
		if held(s, tech, good) < RateData.HOLD:
			out.append(good_line(s, tech, good))
	return out


## The good of `tech` furthest from being held (the least time held, then the biggest gap), "" when all are held.
static func worst(s, tech: String) -> String:
	var best := ""
	var best_score := INF
	for good in RateData.rates(tech):
		var h := held(s, tech, good)
		if h >= RateData.HOLD:
			continue
		var score := h - (float(RateData.rates(tech)[good]) - made(s, good)) * 0.01
		if score < best_score:
			best = good
			best_score = score
	return best


## The sum line for a gate goal: the rated good furthest from held, and what one more maker of it would add ("" when all are held).
static func line(s, tech: String) -> String:
	var good := worst(s, tech)
	if good == "":
		return ""
	return good_line(s, tech, good) + "." + _more(s, tech, good)


## " One more Kiln: +31." (a maker's rate), " One more Kiln won't help: Clay is short.", "" when no maker of the good can be added.
static func _more(s, tech: String, good: String) -> String:
	if made(s, good) >= float(RateData.rates(tech)[good]):
		return ""
	var type := ""
	for t in Needs.makers_of(good):
		if Data.BUILDINGS[t]["kind"] == "processor" and s.town.unlocked(t):
			type = t
			break
	if type == "":
		return ""
	var def: Dictionary = Data.BUILDINGS[type]
	var each := FlowView.added_rate(s, type, good)
	if each <= 0.0:
		return ""
	for b in FlowView.built_makers(s, good):
		if b["type"] != type:
			continue
		var why := FlowView.cause(s, b)
		var code: String = why["code"]
		if code == "input":
			return " " + WONT % [def["name"], "%s is short" % Data.ITEMS[why["input"]]["name"]]
		if code != "working" and code != "resting" and code != "paused":
			return " " + WONT % [def["name"], "its %ss are waiting" % def["name"]]
	if s.people.idle_now < 1:
		return " " + WONT % [def["name"], "no free Kith to work it"]  # a maker nobody staffs adds nothing
	return " " + MORE % [def["name"], roundi(each)]
