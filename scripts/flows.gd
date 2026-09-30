extends RefCounted
## Where goods come from and go: every making and using of an item is noted by source, per second,
## over a sliding window. The top bar shows the net rate; its hover panel lists the sources.

const Data = preload("res://scripts/data.gd")
const Codec = preload("res://scripts/save_codec.gd")

var hist: Array = []  # one Dictionary per finished second: "item|source" -> amount (negative when used)
var now: Dictionary = {}
var clock := 0.0


## Note `amount` of `item` made (positive) or used up (negative) by `source`: a building type,
## "hand", "craft" or "kith" (eating).
func add(item: String, amount: float, source: String) -> void:
	var key := item + "|" + source
	now[key] = now.get(key, 0.0) + amount


## Close the current second once a whole second has passed.
func advance(delta: float) -> void:
	var before := floori(clock)
	clock += delta
	if floori(clock) == before:
		return
	hist.append(now)
	now = {}
	while hist.size() > Data.RATE_WINDOW:
		hist.pop_front()


## Net change of `item` per second over the window, from making and using it
## (spending on research and buildings doesn't count).
func rate(item: String) -> float:
	var total := 0.0
	var by_source := parts(item)
	for source in by_source:
		total += by_source[source]
	return total


## Per-second rate of `item` by source: {"gatherers_hut": 0.6, "twine_post": -0.75}.
func parts(item: String) -> Dictionary:
	var out := {}
	if hist.is_empty():
		return out
	var prefix := item + "|"
	for bucket in hist:
		for key in bucket:
			var k: String = key
			if k.begins_with(prefix):
				var source := k.substr(prefix.length())
				out[source] = out.get(source, 0.0) + bucket[key]
	for source in out:
		out[source] /= float(hist.size())
	return out


# --- Save --------------------------------------------------------------------


## The window as JSON-safe values: the finished seconds, the one under way and the clock.
func to_dict() -> Dictionary:
	var past: Array = []
	for bucket in hist:
		past.append(Codec.float_dict(bucket))
	return {"hist": past, "now": Codec.float_dict(now), "clock": clock}


## Restore the window written by to_dict. Nothing is emitted or checked.
func from_dict(d: Dictionary) -> void:
	hist = []
	for bucket in d.get("hist", []):
		hist.append(Codec.float_dict(bucket))
	now = Codec.float_dict(d.get("now", {}))
	clock = float(d.get("clock", 0.0))
