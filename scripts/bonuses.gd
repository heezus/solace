extends RefCounted
## Work multipliers. Every bonus is in one of three groups: Speed (shorter work cycles), Yield (more
## per harvest) and Output (more of each good a workshop makes a cycle). Bonuses add within a group (+50% and
## +100% make +150%) and the groups multiply.
## Data.BONUSES lists them; new ones (Bronze Tools, later upgrades) plug in the same way.
## Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Buildings = preload("res://scripts/buildings.gd")


## The bonuses at work on building b now, for `item` (yield bonuses name the item they apply to):
## an Array of {"id", "name", "group", "add"}.
static func active(s, b: Dictionary, item: String) -> Array:
	var out: Array = []
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	for id in Data.BONUSES:
		var bonus: Dictionary = Data.BONUSES[id]
		if bonus.has("tech") and not s.tech_tree.researched.has(bonus["tech"]):
			continue
		if bonus.has("kinds") and kind not in bonus["kinds"]:
			continue
		if bonus.has("types") and b["type"] not in bonus["types"]:
			continue
		if bonus.has("item") and bonus["item"] != item:
			continue
		if not _applies(s, b, id):
			continue
		var add: float = bonus["add"]
		var name: String = bonus["name"]
		if bonus.has("rank_of"):
			var extra: int = Ranks.rank(s, bonus["rank_of"]) - 1
			if extra <= 0:
				continue
			add *= extra
			name = "%s %s" % [Data.TECHS[bonus["rank_of"]]["name"], Data.RANK_NAMES[extra + 1]]
		out.append({"id": id, "name": name, "group": bonus["group"], "add": add})
	return out


## Checks that depend on the building itself: its worker's tool, a Standing Stone nearby.
static func _applies(s, b: Dictionary, id: String) -> bool:
	match id:
		"tools":
			return b["worker"] >= 0 and s.people.kith[b["worker"]].get("tool", 0) > 0
		"standing_stone":
			return s.town.in_range_of("aura", b["pos"])
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


## How many times what a workshop makes each cycle: 1 plus the Output group (Kilns II doubles a Kiln's Brick).
static func output(s, b: Dictionary) -> float:
	return total(active(s, b, ""), "output")


## The Yield bonuses that only buildings get (those with `kinds`, like Ochre at huts). The others
## (Foraging) are already in the click yield a hut's bundle is based on.
static func building_yield(s, b: Dictionary, item: String) -> float:
	var parts: Array = active(s, b, item).filter(func(p): return Data.BONUSES[p["id"]].has("kinds"))
	return total(parts, "yield")


## "20 jobs/min x Speed 2.5 (Flint Tools +50%, Standing Stone +100%) = 50 jobs/min", plus a line per yield bonus.
static func text(s, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if not def.has("time"):
		return ""
	var parts := active(s, b, "")
	var base: float = 60.0 / def["time"]
	var unit := "jobs/min"
	if def["kind"] == "processor":
		var out := Buildings.recipe_out(b)
		var made := 0
		for id in out:
			made += out[id]
		base *= made * output(s, b)
		unit = "%s/min" % Data.ITEMS[out.keys()[0]]["name"]
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
	var more := output(s, b)
	if def["kind"] == "processor" and more > 1.0:
		var names: Array = parts.filter(func(p): return p["group"] == "output").map(func(p): return p["name"])
		line += " (%s each cycle: %s)" % ["x" + _num(more), ", ".join(names)]
	return line


static func _num(x: float) -> String:
	return str(snappedf(x, 0.01)).trim_suffix(".0")
