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
const MAKING := "%s is made by %s, all working; add one"
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
		var code := wait_code(b)
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
		var code := wait_code(b)
		if code == "input":
			var input := WaitWhy.missing(s, b, Buildings.recipe_in(b))
			if input != "":
				return _input_held(s, item, input, b)
		return {
			"line": HELD % [name, WAIT_WORDS[code], group_line(g), WAIT_FIX.get(code, "open its card")], "pos": b["pos"]
		}
	var first: Dictionary = groups[0]
	var at: Vector2i = built_makers(s, item)[0]["pos"]
	return {"line": MAKING % [name, _plural(int(first["count"]), first["name"])], "pos": at}


## `item` waits on `input`, which its maker `b` lacks: say how the input's own makers are doing.
static func _input_held(s, item: String, input: String, b: Dictionary) -> Dictionary:
	var name: String = Data.ITEMS[item]["name"]
	var in_name: String = Data.ITEMS[input]["name"]
	var groups := makers(s, input)
	if groups.is_empty():
		return {"line": "%s is held by %s: %s" % [name, in_name, Needs.why_short(s, input)], "pos": b["pos"]}
	for g in groups:
		if not g["spots"].is_empty():
			var code := wait_code(s.town.buildings[s.town.building_at[g["spots"][0]]])
			return {
				"line": HELD % [name, in_name, group_line(g), WAIT_FIX.get(code, "fix what it waits on")],
				"pos": g["spots"][0]
			}
	var type: String = groups[0]["type"]
	var add := "add a hut" if Data.BUILDINGS[type]["kind"] == "gatherer" else "add a %s" % Data.BUILDINGS[type]["name"]
	return {"line": HELD % [name, in_name, group_line(groups[0]), add], "pos": b["pos"]}
