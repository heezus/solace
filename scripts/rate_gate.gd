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
const MORE := "One more %s: +%d."
const WONT := "One more %s won't help: %s."


## What the buildings made of `item` a minute over the flow window (the flow view's made figure, less hand work).
static func made(s, item: String) -> float:
	var parts: Dictionary = s.economy.flows.parts_over(item, float(Data.RATE_WINDOW))
	var total := 0.0
	for source in parts:
		if parts[source] > 0.0 and not source in RateData.NOT_MADE_BY:
			total += parts[source]
	return total * 60.0


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
## researched counts `elapsed` more seconds when it is made at R or more, and starts again from nothing when it is not.
static func update(s, elapsed: float) -> void:
	var held_now: Dictionary = s.tech_tree.rate_held
	for tech in RateData.GATES:
		if s.tech_tree.researched.has(tech):
			continue
		for good in RateData.GATES[tech]:
			var key := "%s|%s" % [tech, good]
			if made(s, good) >= float(RateData.GATES[tech][good]):
				held_now[key] = minf(float(held_now.get(key, 0.0)) + elapsed, RateData.HOLD)
			else:
				held_now[key] = 0.0


## "0:35" for 35 seconds.
static func clock(seconds: float) -> String:
	var n := floori(seconds)
	return "%d:%02d" % [floori(n / 60.0), n % 60]


## One rated good's line: "Brick 34 of 40 a min (held 0:35 of 1:00)".
static func good_line(s, tech: String, good: String) -> String:
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
	return " " + MORE % [def["name"], roundi(each)]
