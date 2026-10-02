extends RefCounted
## The work cycle: how long a building's cycle takes, what a harvest brings back and how a workshop
## finishes a cycle. Bonuses give the multipliers and Hands the click yield this is based on. Static, and
## works on the Sim passed in, like Bonuses, Hands, Roads and Workers.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Hands = preload("res://scripts/hands.gd")
const Buildings = preload("res://scripts/buildings.gd")


## Seconds for one work cycle at this building: its base time, shortened by the Speed group.
static func time(s, b: Dictionary) -> float:
	return Data.BUILDINGS[b["type"]]["time"] / Bonuses.speed(s, b)


## Seconds for a hut worker to harvest `tile`. Irrigation halves it for Fields touching the river.
static func harvest_time(s, b: Dictionary, tile: Vector2i) -> float:
	var t := time(s, b)
	if s.tech_tree.researched.has("irrigation") and s.world.fields.has(tile) and s.world.touches_river(tile):
		t /= 2.0
	return t


## A hut's bundle of `item`, before any Calendar share.
static func bundle_size(s, b: Dictionary, item: String) -> int:
	return roundi(Data.BUNDLE * Hands.harvest_yield(s, item) * Bonuses.building_yield(s, b, item))


## How much one harvest of `tile` brings back: a bundle, Data.BUNDLE times your click yield for the item
## (so tools and ranks count), times the Yield bonuses only huts get (Ochre on Clay). Calendar adds a
## quarter to Fields, paid out as whole items as the building's share builds up.
static func harvest_amount(s, b: Dictionary, tile: Vector2i, item: String) -> int:
	var n := bundle_size(s, b, item)
	var more := 0.0  # a Field's extra yield, as a share of the bundle: Calendar and the Plough add up
	if s.world.fields.has(tile):
		more += Data.CALENDAR_FIELD_BONUS if s.tech_tree.researched.has("calendar") else 0.0
		more += Data.PLOUGH_FIELD_BONUS if s.tech_tree.researched.has("plough") else 0.0
	if more > 0.0:
		b["field_extra"] = b.get("field_extra", 0.0) + n * more
		if b["field_extra"] >= 1.0:
			b["field_extra"] -= 1.0
			n += 1
	return n


## 0 to 1: how far along the current work cycle is, for the progress bar.
static func progress_frac(s, b: Dictionary) -> float:
	if Data.BUILDINGS[b["type"]]["kind"] == "gatherer" and b["worker"] >= 0:
		var k: Dictionary = s.people.kith[b["worker"]]
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		return clampf(k["timer"] / harvest_time(s, b, tile), 0.0, 1.0)
	return clampf(b["progress"] / time(s, b), 0.0, 1.0)


## A workshop's cycle is done: it uses its inputs and makes its goods.
static func finish_cycle(s, b: Dictionary) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	b["progress"] = 0.0
	s.people.wear(b)
	for id in def["in"]:
		b["inbuf"][id] -= def["in"][id]
		s.economy.note(id, -def["in"][id], b["type"])
	var made := Buildings.recipe_out(b)
	var more := Bonuses.output(s, b)
	for id in made:
		var n := roundi(made[id] * more)
		b["out"][id] = b["out"].get(id, 0) + n
		s.economy.note(id, n, b["type"])


## What a building's card says about its rate: the speed math, then a hut's bundle of its focus once its
## people know how to gather it.
static func text(s, b: Dictionary) -> String:
	var line := Bonuses.text(s, b)
	if line == "" or Data.BUILDINGS[b["type"]]["kind"] != "gatherer":
		return line
	var item: String = b["focus"]
	if item != "" and s.people.knows(item):
		line += "\nBundle: %d %s (%d x a click)" % [bundle_size(s, b, item), Data.ITEMS[item]["name"], Data.BUNDLE]
	return line
