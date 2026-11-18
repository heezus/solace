extends RefCounted
## The flow view's numbers (Step 9C-1): for each good, what is made and used a minute, the net, the stock and the buildings that make
## it, with how many of them are waiting and on what. `bottleneck` walks one step back from a good a goal needs to the input that
## holds its maker up, and names the building on the map to light. Pure functions of the game state; changes nothing.

const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Needs = preload("res://scripts/needs.gd")
const WaitWhy = preload("res://scripts/wait_why.gd")

const NONE := Vector2i(-1, -1)
## What a waiting building is waiting on, in a few words, and the one step that sets it right.
const WAIT_WORDS := {
	"input": "short of an input",
	"hands": "no free Kith",
	"haulers": "waiting for a hauler",
	"road": "no road",
	"power": "no power",
	"light": "no shardlight",
	"paused": "paused",
	"resting": "resting, plenty in stock",
	"other": "waiting",
}
const WAIT_FIX := {
	"hands": "build a Dwelling or free a hand",
	"haulers": "give the Hearth more hauler places",
	"road": "lay a road to it",
	"power": "power it",
	"light": "light it with the Cairn or a Lantern",
	"paused": "press Resume on its card",
	"other": "open its card",
}
const HELD := "%s is held by %s: %s; %s"
## A rival maker that eats the short input to make what nothing open needs: the line, and the one click that sets it right.
const RIVAL := "%s is held by %s. %ss take %d%% of it to make %s, which nothing open needs. Pause them?"
const RIVAL_SHARE := 0.4  # of the input's use, the least a rival must take to be named
const RIVAL_RESERVE := 20  # of its goods the stores hold before it counts as made for nothing
const MAKING := "%s is made by %s, all working; add one"
## A maker running flat out while the good it eats piles up: the line, and the one more that would clear it.
const SHORT := "%s is held by %ss: %s, %s piling up. One more %s: +%s a min."
const PILE := 20  # of an input the stores hold before a maker that eats it is said to be the one thing short
const NONE_BUILT := "%s is made at a %s. Build one."


## The goods to list: the ones the goal in front of the player is made of first, then every other good seen so far.
static func goods(s) -> Array:
	var goal := Needs.goal_goods(s)
	var out: Array = []
	for id in Data.ITEM_ORDER:
		if goal.has(id):
			out.append(id)
	for id in Data.ITEM_ORDER:
		if not goal.has(id) and s.economy.seen.has(id) and not id in out:
			out.append(id)
	return out


## One good's row: {item, name, goal, stock, made, used, net, by_hand (a minute), makers}. The rates are the top bar's window.
static func row(s, item: String) -> Dictionary:
	var parts: Dictionary = s.economy.flows.parts(item)
	var made := 0.0
	var used := 0.0
	for source in parts:
		if parts[source] > 0.0:
			made += parts[source]
		else:
			used -= parts[source]
	return {
		"item": item,
		"name": Data.ITEMS[item]["name"],
		"goal": Needs.goal_goods(s).has(item),
		"stock": int(s.economy.inv.get(item, 0)),
		"made": made * 60.0,
		"used": used * 60.0,
		"net": (made - used) * 60.0,
		"by_hand": float(parts.get("hand", 0.0)) * 60.0,
		"makers": makers(s, item),
	}


## Every row, the goal's goods first.
static func rows(s) -> Array:
	var out: Array = []
	for id in goods(s):
		out.append(row(s, id))
	return out


## The buildings that make `item`, grouped by type: [{type, name, count, working, waits: {code: n}, spots: [position]}].
static func makers(s, item: String) -> Array:
	var by_type := {}
	var order: Array = []
	for b in built_makers(s, item):
		var type: String = b["type"]
		if not by_type.has(type):
			by_type[type] = {
				"type": type, "name": _group_name(type, item), "count": 0, "working": 0, "waits": {}, "spots": []
			}
			order.append(type)
		var g: Dictionary = by_type[type]
		g["count"] += 1
		var code: String = cause(s, b)["code"]
		if code == "working":
			g["working"] += 1
		else:
			g["waits"][code] = int(g["waits"].get(code, 0)) + 1
			g["spots"].append(b["pos"])
	var out: Array = []
	for type in order:
		out.append(by_type[type])
	return out


## The standing buildings that make `item`: a Gatherer's Hut set to it, or a workshop whose output holds it.
static func built_makers(s, item: String) -> Array:
	var out: Array = []
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "gatherer":
			if b["focus"] == item:
				out.append(b)
		elif def.get("out", {}).has(item):
			out.append(b)
	return out


static func _group_name(type: String, item: String) -> String:
	if Data.BUILDINGS[type]["kind"] == "gatherer":
		return "%s hut" % Data.ITEMS[item]["name"]
	return Data.BUILDINGS[type]["name"]


static func _plural(n: int, name: String) -> String:
	return "%d %s%s" % [n, name, "" if n == 1 else "s"]


## What building `b` is doing, from the pill under it: "working", "paused", "hands", "input", "haulers", "road", "power", "light",
## "resting" or "other".
static func wait_code(b: Dictionary) -> String:
	var a: String = b["alert"]
	var low := a.to_lower()
	if b["paused"]:
		return "paused"
	if a == "":
		return "resting" if String(b["status"]).begins_with("Store full") else "working"
	if a == Data.HOLD_BACK_ALERT or a.begins_with("Idle: no free"):
		return "hands"
	if a.begins_with("Needs road") or a == "Needs a click" or a == "Full: click to collect":
		return "road"
	if a.begins_with("Full"):
		return "haulers"
	if a == Data.LUMEN["needs_light"]:
		return "light"
	if low.contains("power") or low.contains("pole") or low.contains("engine"):
		return "power"
	if a.begins_with("Needs "):
		return "input"
	if a.begins_with("Idle"):
		return "resting"
	return "other"


## What building `b` really waits on: {code (wait_code's, but "input" only when the stores are short of what its next cycle needs, else the
## delivery that is missing: "road" or "haulers"), input (the good, for "input"), text (the delivery's own reason, WaitWhy's)}. The pill
## says "Needs Copper Ore" whenever the building's own buffer is empty, with a thousand in the stores and no hauler to bring it.
static func cause(s, b: Dictionary) -> Dictionary:
	var code := wait_code(b)
	if code != "input":
		return {"code": code, "input": "", "text": ""}
	var recipe: Dictionary = Buildings.recipe_in(b)
	var input := WaitWhy.missing(s, b, recipe)
	if input == "":
		return {"code": code, "input": "", "text": ""}
	if stock_of(s, input) < int(recipe.get(input, 1)):
		return {"code": "input", "input": input, "text": ""}
	var why: Dictionary = WaitWhy.of(s, b, input)
	var is_road: bool = why["code"] == "no_road" or why["code"] == "cut"
	return {"code": "road" if is_road else "haulers", "input": input, "text": why["text"]}


## How many of `item` the stores hold; a fuel counts with the other (a Bloomery burns Charcoal when it has no Coal).
static func stock_of(s, item: String) -> int:
	var n := int(s.economy.inv.get(item, 0))
	if item == "coal" or item == "charcoal":
		n = int(s.economy.inv.get("coal", 0)) + int(s.economy.inv.get("charcoal", 0))
	return n


## The line a group of makers reads as: "2 Clay huts, both working", "1 of 2 Kilns waiting (short of an input)".
static func group_line(g: Dictionary) -> String:
	var n: int = g["count"]
	var waiting := n - int(g["working"])
	if waiting == 0:
		return "%s, %s working" % [_plural(n, g["name"]), "both" if n == 2 else "all" if n > 2 else "it is"]
	var why: Array = []
	for code in g["waits"]:
		why.append("%d %s" % [g["waits"][code], WAIT_WORDS[code]])
	return "%d of %s waiting (%s)" % [waiting, _plural(n, g["name"]), ", ".join(why)]


## The one line of what holds `item` up, and the building to light: {line, pos}. The maker that waits is read one step back: when it
## lacks an input, the line is about that input's makers; when it is waiting for a hand, a hauler, a road or power, about that.
static func bottleneck(s, item: String) -> Dictionary:
	var name: String = Data.ITEMS[item]["name"]
	var groups := makers(s, item)
	if groups.is_empty():
		var made: Array = Needs.makers_of(item)
		if made.is_empty():
			return {"line": Needs.provider(item), "pos": NONE}
		return {"line": NONE_BUILT % [name, Data.BUILDINGS[made[0]]["name"]], "pos": NONE}
	for g in groups:
		if g["spots"].is_empty():
			continue
		var b: Dictionary = s.town.buildings[s.town.building_at[g["spots"][0]]]
		var why := cause(s, b)
		var code: String = why["code"]
		if code == "input":
			return _input_held(s, item, why["input"], b)
		var line: String = HELD % [name, WAIT_WORDS[code], group_line(g), WAIT_FIX.get(code, "open its card")]
		if why["text"] != "":
			line += " (%s: %s)" % [Data.ITEMS[why["input"]]["name"], why["text"]]
		return {"line": line, "pos": b["pos"]}
	var first: Dictionary = groups[0]
	var at: Vector2i = built_makers(s, item)[0]["pos"]
	var piled := maker_short(s, item, first)
	if piled != "":
		return {"line": piled, "pos": at}
	return {"line": MAKING % [name, _plural(int(first["count"]), first["name"])], "pos": at}


## When the makers of `item` (group `g`) all work and an input of theirs piles up in the stores, the line that says one more maker
## would turn it to `item`: "Copper is held by Smelters: 1 Smelter, ore piling up. One more Smelter: +6.0 a min." "" when not so.
static func maker_short(s, item: String, g: Dictionary) -> String:
	var type: String = g["type"]
	var def: Dictionary = Data.BUILDINGS[type]
	if def["kind"] != "processor" or not s.town.unlocked(type) or g["working"] < g["count"]:
		return ""
	var piled := ""
	for id in def.get("in", {}):
		if int(s.economy.inv.get(id, 0)) >= PILE and float(s.economy.flows.rate(id)) >= 0.0:
			if piled == "" or s.economy.inv[id] > s.economy.inv[piled]:
				piled = id
	if piled == "":
		return ""
	var added := added_rate(s, type, item)
	if added <= 0.0:
		return ""
	return (
		SHORT
		% [
			Data.ITEMS[item]["name"],
			def["name"],
			_plural(int(g["count"]), def["name"]),
			String(Data.ITEMS[piled]["name"]).to_lower(),
			def["name"],
			"%.1f" % added,
		]
	)


## What one more of `type` would make of `item` a minute: what the ones standing make now, each, else the workshop's own rate.
static func added_rate(s, type: String, item: String) -> float:
	var parts: Dictionary = s.economy.flows.parts(item)
	var standing := 0
	for b in s.town.buildings:
		if b["type"] == type and (Data.BUILDINGS[type]["kind"] != "gatherer" or b["focus"] == item):
			standing += 1
	if standing > 0 and parts.get(type, 0.0) > 0.0:
		return float(parts[type]) * 60.0 / standing
	var def: Dictionary = Data.BUILDINGS[type]
	if def.get("out", {}).has(item) and float(def.get("time", 0.0)) > 0.0:
		return float(def["out"][item]) * 60.0 / float(def["time"])
	return 0.0


## `item` waits on `input`, which its maker `b` lacks: say how the input's own makers are doing.
static func _input_held(s, item: String, input: String, b: Dictionary) -> Dictionary:
	var name: String = Data.ITEMS[item]["name"]
	var in_name: String = Data.ITEMS[input]["name"]
	var rival := rival_use(s, input, b["type"])
	if not rival.is_empty():
		return {
			"line": RIVAL % [name, in_name, rival["name"], rival["share"], rival["makes"]],
			"pos": rival["spots"][0],
			"pause": rival["spots"],
		}
	var groups := makers(s, input)
	if groups.is_empty():
		var why := Needs.why_short(s, input, int(Buildings.recipe_in(b).get(input, 1)))
		return {
			"line": "%s is held by %s: %s" % [name, in_name, why if why != "" else Needs.provider(input)],
			"pos": b["pos"]
		}
	for g in groups:
		if not g["spots"].is_empty():
			var code: String = cause(s, s.town.buildings[s.town.building_at[g["spots"][0]]])["code"]
			return {
				"line": HELD % [name, in_name, group_line(g), WAIT_FIX.get(code, "fix what it waits on")],
				"pos": g["spots"][0]
			}
	var type: String = groups[0]["type"]
	var add := "add a hut" if Data.BUILDINGS[type]["kind"] == "gatherer" else "add a %s" % Data.BUILDINGS[type]["name"]
	return {"line": HELD % [name, in_name, group_line(groups[0]), add], "pos": b["pos"]}


## The biggest other maker of `input`'s use, when it makes a good no open goal, queued tech or goal price asks for and the stores
## already hold more than a reserve of: {name, share (percent of the use), makes, spots (its working buildings)}, or {} for none.
static func rival_use(s, input: String, own_type: String) -> Dictionary:
	var parts: Dictionary = s.economy.flows.parts(input)
	var total := 0.0
	for source in parts:
		total -= minf(parts[source], 0.0)
	if total <= 0.0:
		return {}
	var asked: Dictionary = Needs.goal_goods(s)
	for tech in s.tech_tree.queue:
		for id in s.tech_tree.cost_of(tech):
			asked[id] = true
	var best := ""
	for source in parts:
		if parts[source] >= 0.0 or source == own_type or not Data.BUILDINGS.has(source):
			continue
		var def: Dictionary = Data.BUILDINGS[source]
		if not def.get("in", {}).has(input) or def.get("out", {}).is_empty():
			continue
		var made: String = def["out"].keys()[0]
		if asked.has(made) or s.economy.inv.get(made, 0) < RIVAL_RESERVE:
			continue
		if best == "" or parts[source] < parts[best]:
			best = source
	if best == "" or -parts[best] / total < RIVAL_SHARE:
		return {}
	var spots: Array = []
	for b in s.town.buildings:
		if b["type"] == best and not b["paused"]:
			spots.append(b["pos"])
	if spots.is_empty():
		return {}
	var made_name: String = Data.ITEMS[Data.BUILDINGS[best]["out"].keys()[0]]["name"]
	return {
		"name": Data.BUILDINGS[best]["name"],
		"share": int(round(-parts[best] / total * 100.0)),
		"makes": made_name,
		"spots": spots,
	}
