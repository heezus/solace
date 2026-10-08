extends RefCounted
## The work cycle: how long a building's cycle takes, what a harvest brings back and how a workshop
## finishes a cycle. Bonuses give the multipliers and Hands the click yield this is based on. Static, and
## works on the Sim passed in, like Bonuses, Hands, Roads and Workers.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Hands = preload("res://scripts/hands.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Patch = preload("res://scripts/patch.gd")
const Lessons = preload("res://scripts/lessons.gd")


## Seconds for one work cycle at this building: its base time, shortened by the Speed group and, for a hut, by the
## Speed its patch gives (more tiles of its resource in reach: scripts/patch.gd).
static func time(s, b: Dictionary) -> float:
	return Data.BUILDINGS[b["type"]]["time"] / (Bonuses.speed(s, b) * Patch.speed(s, b))


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
	var more := 0.0  # a Field's extra yield, as a share of the bundle: Calendar, the Plough and the Ploughshare add up
	if s.world.fields.has(tile):
		more += Data.CALENDAR_FIELD_BONUS if s.tech_tree.researched.has("calendar") else 0.0
		more += Data.PLOUGH_FIELD_BONUS if s.tech_tree.researched.has("plough") else 0.0
		more += Data.PLOUGHSHARE_FIELD_BONUS if s.tech_tree.researched.has("bronze_ploughshare") else 0.0
		more += Lessons.rain_share(s, tile)
	if more > 0.0:
		b["field_extra"] = b.get("field_extra", 0.0) + n * more
		if b["field_extra"] >= 1.0:
			# One item a harvest as ever; the Plough's bigger share can pay out more than one at a time.
			var paid := floori(b["field_extra"]) if s.tech_tree.researched.has("plough") else 1
			b["field_extra"] -= paid
			n += paid
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
	b["progress"] = 0.0
	s.people.wear(b)
	var used := Buildings.recipe_in(b)
	for id in used:
		b["inbuf"][id] -= used[id]
		s.economy.note(id, -used[id], b["type"])
	var made := Buildings.recipe_out(b)
	if Data.BUILDINGS[b["type"]].has("dig"):  # a finite seam gives what is left of its pile, and no more
		for id in made:
			made[id] = s.world.seam_draw(b["pos"], made[id])
			if made[id] > 0 and s.world.seam_spent(b["pos"]):
				s.events.append(Data.SEAM_SPENT_EVENT)
	if made.has("flint_tools"):
		s.hand_tools = true  # the first Flint Tool made by anyone doubles hand gathering, as a hand-crafted one does
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
	var tiles: int = s.town.focus_tiles(b).size()
	if tiles > 1:
		line += "\n" + Data.PATCH_EXACT % [tiles, str(snappedf(Patch.speed(s, b), 0.01))]
	return line


# --- The Tool Bench ----------------------------------------------------------------


## Tools the stockpile holds, and the Tool Bench `b`'s own output waiting to be hauled.
static func tools_stocked(s, b: Dictionary) -> int:
	var n := 0
	for id in Data.TOOL_ITEMS:
		n += s.economy.inv.get(id, 0) + b["out"].get(id, 0)
	return n


## How many tools a Tool Bench keeps ready: Data.TOOL_SPARES, and one for each working Kith who holds none.
static func tool_goal(s) -> int:
	var n: int = Data.TOOL_SPARES
	for k in s.people.kith:
		if k["job"] == "work" and k["tool"] <= 0:
			n += 1
	return n


## True when Tool Bench `b` has made enough: the stockpile holds as many tools as are wanted. It pauses until some are
## taken, so it never drains the flint and wood the stone age needs.
static func enough(s, b: Dictionary) -> bool:
	return Data.BUILDINGS[b["type"]].has("makes") and tools_stocked(s, b) >= tool_goal(s)


## Bronze that the research queue is still waiting for. A Tool Bench leaves it alone, so tools never take the Bronze a
## tech needs.
static func bronze_reserved(s) -> int:
	var n := 0
	for tech in s.tech_tree.queue:
		n += s.tech_tree.cost_of(tech).get("bronze", 0)
	return n


## A Tool Bench makes the best tool it can: the last in its `makes` that is learned and that the stockpile can pay for,
## keeping back the Bronze the research queue needs (Flint Tools when nothing better). It changes only between batches,
## with nothing loaded or on the way.
static func choose_tool(s, b: Dictionary) -> void:
	var makes: Array = Data.BUILDINGS[b["type"]]["makes"]
	if b["progress"] > 0.0 or Buildings.buffered(b["inbuf"]) > 0 or Buildings.buffered(b["incoming"]) > 0:
		return
	var pick: String = makes[0]
	var spare_bronze: int = s.economy.inv.get("bronze", 0) - bronze_reserved(s)
	for id in makes:
		var cost: Dictionary = Data.RECIPES[id]["in"]
		var bronze_ok: bool = spare_bronze >= cost.get("bronze", 0)
		if Hands.recipe_unlocked(s, id) and s.economy.can_afford(cost) and bronze_ok:
			pick = id
	b["make"] = pick


## "Making: flint tools, 3 in stock (keeps 5 ready)." (or "Enough flint tools: ...") for a Tool Bench's panel.
static func bench_text(s, b: Dictionary) -> String:
	var tool_name: String = Data.ITEMS[b["make"]]["name"].to_lower()
	var stocked := tools_stocked(s, b)
	if enough(s, b):
		return Data.BENCH_ENOUGH % [tool_name, stocked]
	return Data.BENCH_MAKING % [tool_name, stocked, tool_goal(s)]
