extends RefCounted
## Work multipliers. Every bonus is in one of two groups: Speed (shorter work cycles) and Yield (more
## per harvest). Bonuses add within a group (+50% and +100% make +150%) and the groups multiply.
## Data.BONUSES lists them; new ones (Bronze Tools, later upgrades) plug in the same way.
## Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")


## The bonuses at work on building b now, for `item` (yield bonuses name the item they apply to):
## an Array of {"id", "name", "group", "add"}.
static func active(s, b: Dictionary, item: String) -> Array:
	var out: Array = []
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	for id in Data.BONUSES:
		var bonus: Dictionary = Data.BONUSES[id]
		if bonus.has("tech") and not s.researched.has(bonus["tech"]):
			continue
		if bonus.has("kinds") and kind not in bonus["kinds"]:
			continue
		if bonus.has("item") and bonus["item"] != item:
			continue
		if not _applies(s, b, id):
			continue
		out.append({"id": id, "name": bonus["name"], "group": bonus["group"], "add": bonus["add"]})
	return out


## Checks that depend on the building itself: its worker's tool, a Standing Stone nearby.
static func _applies(s, b: Dictionary, id: String) -> bool:
	match id:
		"tools":
			return b["worker"] >= 0 and s.kith[b["worker"]].get("tool", 0) > 0
		"standing_stone":
			return s._in_range_of("aura", b["pos"])
	return true


## 1 + the sum of a group's bonuses.
static func total(parts: Array, group: String) -> float:
	var m := 1.0
	for p in parts:
		if p["group"] == group:
			m += p["add"]
	return m


static func speed(s, b: Dictionary) -> float:
	return total(active(s, b, ""), "speed")


## How much one harvest of `item` yields: the base 1 times the Yield group.
static func yield_mult(s, b: Dictionary, item: String) -> float:
	return total(active(s, b, item), "yield")


## "20 jobs/min x Speed 2.5 (Flint Tools +50%, Standing Stone +100%) = 50 jobs/min", plus a line per yield bonus.
static func text(s, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if not def.has("time"):
		return ""
	var parts := active(s, b, "")
	var base: float = 60.0 / def["time"]
	var unit := "jobs/min"
	if def["kind"] == "processor":
		var made := 0
		for id in def["out"]:
			made += def["out"][id]
		base *= made
		unit = "%s/min" % Data.ITEMS[def["out"].keys()[0]]["name"]
	var sp := total(parts, "speed")
	var line := "%s %s" % [_num(base), unit]
	if sp > 1.0:
		var names: Array = []
		for p in parts:
			if p["group"] == "speed":
				names.append("%s +%d%%" % [p["name"], roundi(p["add"] * 100.0)])
		line += " x Speed %s (%s) = %s %s" % [_num(sp), ", ".join(names), _num(base * sp), unit]
	if def["kind"] == "gatherer":
		line += ", plus walking"
		for item in b["gather_items"]:
			var y := yield_mult(s, b, item)
			if y > 1.0 and not line.contains("Yield x%s on %s" % [_num(y), Data.ITEMS[item]["name"]]):
				line += "\nYield x%s on %s" % [_num(y), Data.ITEMS[item]["name"]]
	return line


static func _num(x: float) -> String:
	return str(snappedf(x, 0.01)).trim_suffix(".0")
