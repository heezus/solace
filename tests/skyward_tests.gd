extends RefCounted
## Livewire stage 3, the factories and the end (design-system/23-livewire.md): the Factory Floor and its recipe, the Shard Dynamo,
## Chain Orders, the Skyward gate's two deeds, its end card and the saves. Run from tests/livewire_tests.gd, which owns the
## helpers (town, meadow, put...).

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Work = preload("res://scripts/work.gd")
const Chain = preload("res://scripts/order_chain.gd")
const Buildings = preload("res://scripts/buildings.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")

var t  # the runner, tests/run_tests.gd
var base  # the Livewire tests, for their helpers


func run(runner, helpers) -> void:
	t = runner
	base = helpers
	test_the_data()
	test_the_floor_copies_a_workshop_faster()
	test_the_floor_picks_its_recipe()
	test_the_floor_saves_its_recipe()
	test_the_dynamo_burns_shards()
	test_chain_orders()
	test_chain_orders_save_and_tear_up()
	test_the_deeds()
	test_the_gate_ends_the_age()
	test_the_goals()
	test_the_panels()


# --- Helpers -------------------------------------------------------------------


func town() -> Sim:
	var s: Sim = base.town()
	s.story.record(Data.LIVEWIRE_BEGUN)
	return s


## A town with a Generator and a Pole by a meadow, so a machine put near the Pole runs. Returns the meadow's middle.
func powered(s: Sim) -> Vector2i:
	var c: Vector2i = base.meadow(s)
	s.people.found(10)
	base.put(s, "power_pole", c)
	var gen: Dictionary = base.put(s, "generator", c + Vector2i(0, 2))
	gen["inbuf"] = {"coal": 40}
	return c


## The town as a saved and loaded run, through JSON like a real save. Pass `edit` to change the saved dictionary first.
func reloaded(s: Sim, edit := Callable()) -> Sim:
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	if edit.is_valid():
		edit.call(d)
	var back := Sim.new()
	back.generate(2)
	t.check(RunSave.restore(back, d), "the run loads")
	return back


# --- The data ------------------------------------------------------------------


func test_the_data() -> void:
	var floor_def: Dictionary = Data.BUILDINGS["factory_floor"]
	t.check(floor_def["needs_power"] and floor_def["crew"] == 2, "a Floor needs power and two hands")
	t.check(floor_def["floor"].size() == 5 and "forge" in floor_def["floor"], "it can copy five workshops")
	t.check(Data.FLOOR_SPEED == 3.0, "three times the speed")
	var dynamo: Dictionary = Data.BUILDINGS["shard_dynamo"]
	t.check(dynamo["gives"] == 8 and dynamo["in"] == {"shard": 1} and dynamo["lesson"] == "heat_plate", "the Dynamo")
	t.check(not Data.BUILDINGS["generator"].has("lesson"), "the Generator is as it was")
	t.check("factory_floor" in Data.BUILD_TABS["Metal"] and "shard_dynamo" in Data.BUILD_TABS["Workshops"], "tabs")
	t.check(Data.TECHS["skyward"]["deeds"] == ["orders_written", "south_held"], "the gate asks for two deeds")
	t.check(Data.DEED_NAMES.has("orders_written") and Data.DEED_NAMES.has("south_held"), "which have names")
	t.check(Data.STORY_TECHS["skyward"] == Data.SKYWARD_EVENT, "Skyward is a story moment")
	t.check(Data.STORY_EVENTS.has(Data.SKYWARD_EVENT), "with an event")
	t.check(Data.SKYWARD_TEXT.contains("south") or Data.SKYWARD_TEXT.length() > 40, "and a card")


# --- The Floor -----------------------------------------------------------------


func test_the_floor_copies_a_workshop_faster() -> void:
	var s := town()
	var c := powered(s)
	var floor_b: Dictionary = base.put(s, "factory_floor", c + Vector2i(2, 0))
	t.check(floor_b["make"] == "twine_post", "a Floor starts on the first workshop")
	var kiln: Dictionary = base.put(s, "kiln", c + Vector2i(-3, 0))
	floor_b["make"] = "kiln"
	t.check(Buildings.recipe_out(floor_b) == Buildings.recipe_out(kiln), "it makes what the Kiln makes")
	t.check(Buildings.recipe_in(floor_b) == Buildings.recipe_in(kiln), "from what the Kiln takes")
	var plain := Work.time(s, kiln)
	var fast := Work.time(s, floor_b)
	t.check(is_equal_approx(fast * Data.FLOOR_SPEED, plain), "at 3x the speed: %s vs %s" % [fast, plain])
	floor_b["inbuf"] = {"clay": 4, "charcoal": 4}
	var made: int = s.economy.inv.get("brick", 0)
	base.tick_for(s, 40.0)
	t.check(floor_b["out"].get("brick", 0) + s.economy.inv.get("brick", 0) > made, "and it makes bricks")


func test_the_floor_picks_its_recipe() -> void:
	var s := town()
	var c := powered(s)
	var floor_b: Dictionary = base.put(s, "factory_floor", c + Vector2i(2, 0))
	var at: int = s.town.building_at[floor_b["pos"]]
	# only the workshops the Kith can build are on offer
	for type in _options(s, floor_b):
		t.check(type == floor_b["make"] or s.town.unlocked(type), "options are what is unlocked: %s" % type)
	floor_b["inbuf"] = {"fiber": 2}
	var stock: int = s.economy.inv.get("fiber", 0)
	var stepped: bool = s.town.cycle_floor(at)
	t.check(stepped and floor_b["make"] != "twine_post", "a click steps to the next workshop")
	t.check(floor_b["inbuf"].is_empty() and s.economy.inv.get("fiber", 0) == stock + 2, "what was loaded goes back")
	t.check(floor_b["progress"] == 0.0, "and the work starts over")
	var seen := {}
	for i in 12:
		s.town.cycle_floor(at)
		seen[floor_b["make"]] = true
		t.check(_options(s, floor_b).has(floor_b["make"]), "always one it can copy: %s" % floor_b["make"])
	t.check(seen.size() == _options(s, floor_b).size(), "and it comes round to each")
	t.check(not s.town.cycle_floor(-1) and not s.town.cycle_floor(999), "a bad index does nothing")
	var forge: Dictionary = base.put(s, "forge", c + Vector2i(-3, 0))
	t.check(not s.town.cycle_floor(s.town.building_at[forge["pos"]]), "a Forge is no Floor")
	var lone := town()
	var lone_floor: Dictionary = base.put(lone, "factory_floor", lone.world.camp_pos + Vector2i(3, 3))
	lone.town.lesson_has = func(_id): return false
	t.check(_options(lone, lone_floor).size() >= 1, "a Floor always has something it copies")


func _options(s: Sim, b: Dictionary) -> Array:
	const FloorRecipe = preload("res://scripts/floor_recipe.gd")
	return FloorRecipe.options(s.town, b)


func test_the_floor_saves_its_recipe() -> void:
	var s := town()
	var c := powered(s)
	var floor_b: Dictionary = base.put(s, "factory_floor", c + Vector2i(2, 0))
	floor_b["make"] = "kiln"
	var back := reloaded(s)
	var loaded := back.town.buildings.filter(func(b): return b["type"] == "factory_floor")
	t.check(loaded.size() == 1 and loaded[0]["make"] == "kiln", "the recipe is saved")
	# an old save (no recipe on the entry) loads with the first workshop
	var again := reloaded(s, func(d): d["buildings"]["buildings"].map(func(b): b.erase("make")))
	var floors := again.town.buildings.filter(func(b): return b["type"] == "factory_floor")
	t.check(floors.size() == 1 and floors[0]["make"] == "twine_post", "a save without one loads the first")


# --- The Dynamo ----------------------------------------------------------------


func test_the_dynamo_burns_shards() -> void:
	var s := town()
	t.check(not s.town.unlocked("shard_dynamo"), "no Dynamo before its tech and Lesson")
	s.tech_tree.researched["shard_dynamo"] = true
	t.check(not s.town.unlocked("shard_dynamo"), "or without the Lesson")
	s.teardown.lessons.append("heat_plate")
	t.check(s.town.unlocked("shard_dynamo"), "with both it can be built")
	var c: Vector2i = base.meadow(s)
	s.people.found(8)
	base.put(s, "power_pole", c)
	var dyn: Dictionary = base.put(s, "shard_dynamo", c + Vector2i(0, 2))
	dyn["inbuf"] = {"shard": 3}
	base.tick_for(s, 3.0)
	t.check(dyn["burn"] == 0.0 and dyn["inbuf"]["shard"] == 3, "banked while nothing asks")
	var forge: Dictionary = base.put(s, "forge", c + Vector2i(2, 0))
	forge["inbuf"] = {"iron": 6, "coal": 3}
	base.tick_for(s, 3.0)
	t.check(dyn["burn"] > 0.0 and dyn["inbuf"]["shard"] == 2, "lit by a machine, it burns a Shard")
	t.check(s.town.is_powered(forge["pos"]), "and the Forge runs")


# --- Chain Orders --------------------------------------------------------------


func order(target: String, holds: bool, after := 0) -> Dictionary:
	return {"holding": holds, "after": after, "target": target}


func test_chain_orders() -> void:
	var orders := [order("forge", true), order("kiln", false), order("smelter", true, 2), order("mine", true, 1)]
	t.check(Chain.ready(orders, orders[0]), "an order that waits on nothing is ready")
	t.check(not Chain.ready(orders, orders[2]), "one waiting on an order that is not holding is not")
	t.check(Chain.ready(orders, orders[3]), "one waiting on a holding order is")
	t.check(not Chain.ready(orders, order("x", true, 9)), "a place that does not exist is not ready")
	Chain.cycle(orders, 3)
	t.check(orders[3]["after"] == 2, "the button steps to the next place")
	Chain.cycle(orders, 3)
	t.check(orders[3]["after"] == 3, "and the next")
	Chain.cycle(orders, 3)
	t.check(orders[3]["after"] == 0, "and past the last to nothing (order 4 is skipped: not on itself)")
	orders[3]["after"] = 3
	Chain.cycle(orders, 0)
	t.check(orders[0]["after"] == 2, "order 1 skips itself and goes to 2")
	t.check(Chain.suffix(orders[2]).contains("2") and Chain.suffix(orders[1]) == "", "the line's tail")
	t.check(Chain.button(orders[1]) == Data.ORDER_WHILE_NONE and Chain.button(orders[2]).contains("2"), "the button")
	# the live Board reads the chain
	var s := town()
	var c: Vector2i = base.meadow(s)
	s.tech_tree.researched["chain_orders"] = true
	base.put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	base.put(s, "forge", c)
	base.put(s, "kiln", c + Vector2i(3, 0))
	for i in 2:
		s.livewire.add(s)
	s.livewire.orders[0].merge(
		{"item": "coal", "compare": "above", "number": 1, "verb": "pause", "target": "forge"}, true
	)
	s.livewire.orders[1].merge(
		{"item": "coal", "compare": "above", "number": 1, "verb": "pause", "target": "kiln"}, true
	)
	s.livewire.orders[1]["after"] = 1
	s.economy.inv["coal"] = 50
	s.livewire.tick(s, 3.0)
	t.check(s.livewire.orders[0]["holding"] and s.livewire.orders[1]["holding"], "both hold while the first does")
	s.economy.inv["coal"] = 0
	s.livewire.orders[0]["number"] = 99
	s.livewire.tick(s, 3.0)
	t.check(
		not s.livewire.orders[0]["holding"] and not s.livewire.orders[1]["holding"], "the second drops with the first"
	)
	t.check(s.livewire.slots(s) == Data.ORDER_SLOTS + Data.ORDER_SLOTS_CHAIN, "Chain Orders adds three slots")


func test_chain_orders_save_and_tear_up() -> void:
	var s := town()
	s.tech_tree.researched["chain_orders"] = true
	base.put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	for i in 3:
		s.livewire.add(s)
	s.livewire.orders[2]["after"] = 1
	s.livewire.orders[1]["after"] = 3
	var back := reloaded(s)
	t.check(back.livewire.orders.size() == 3 and back.livewire.orders[2]["after"] == 1, "the chain is saved")
	t.check(back.livewire.orders[1]["after"] == 3, "all of it")
	s.livewire.clear(0)
	t.check(s.livewire.orders[1]["after"] == 0, "an order that waited on the torn-up one waits on nothing")
	t.check(s.livewire.orders[0]["after"] == 2, "and a later place moves up (3 became 2)")
	var again := reloaded(s, func(d): d["game"]["livewire"]["orders"].map(func(o): o.erase("after")))
	t.check(again.livewire.orders.all(func(o): return o["after"] == 0), "an old save has no chains")


# --- The gate ------------------------------------------------------------------


func test_the_deeds() -> void:
	var s := town()
	t.check(s.gate.orders_written() == 0 and not s.gate.deed("orders_written"), "no orders yet")
	s.tech_tree.researched["chain_orders"] = true
	base.put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	for i in 5:
		s.livewire.add(s)
	t.check(s.gate.orders_written() == 0, "orders with no target are not written")
	for i in 4:
		s.livewire.orders[i]["target"] = "forge"
	t.check(not s.gate.deed("orders_written"), "four is not enough")
	s.livewire.orders[4]["target"] = "kiln"
	t.check(s.gate.deed("orders_written"), "five are")
	# the south
	var c: Vector2i = base.meadow(s, 8)
	var south: Vector2i = s.world.camp_pos + Vector2i(0, Data.SOUTH_ROWS_BELOW_HEARTH + 2)
	t.check(s.gate.in_south(south) and not s.gate.in_south(s.world.camp_pos + Vector2i(0, 3)), "the south is far down")
	t.check(not s.gate.deed("south_held"), "nothing held yet")
	t.check(not s.gate.deed("nonsense"), "an unknown deed is never done")
	var scorch: Dictionary = base.put(s, "scorcher", south)
	var lamp1: Dictionary = base.put(s, "arc_lamp", south + Vector2i(1, 0))
	var lamp2: Dictionary = base.put(s, "arc_lamp", south + Vector2i(-1, 0))
	scorch["burn"] = 5.0
	t.check(not s.gate.south_held(), "buildings with no power do not hold it")
	base.put(s, "power_pole", south + Vector2i(0, 1))
	var gen: Dictionary = base.put(s, "generator", south + Vector2i(0, 3))
	gen["inbuf"] = {"coal": 30}
	gen["burn"] = 50.0
	s.livewire.tick(s, 0.0)
	t.check(s.town.is_powered(scorch["pos"]) and s.town.is_powered(lamp1["pos"]), "(a net reaches them)")
	t.check(s.gate.south_held(), "a burning Scorcher and two lit lamps in the south hold it")
	scorch["burn"] = 0.0
	t.check(not s.gate.south_held(), "a Scorcher that is out does not")
	scorch["burn"] = 5.0
	s.town.remove_at(s.town.building_at[lamp2["pos"]])
	s.livewire.tick(s, 0.0)
	t.check(not s.gate.south_held(), "one lamp is not enough")
	# research asks for the deeds
	s.tech_tree.researched["factory_floor"] = true
	s.tech_tree.researched["scorcher"] = true
	s.tech_tree.researched["shard_dynamo"] = true
	for id in ["steel", "iron", "wire", "brick"]:
		s.economy.seen[id] = true
		s.economy.inv[id] = 999
	t.check(s.tech_tree.can_research("skyward") == s.gate.deed("south_held"), "Skyward waits on the deeds")


func test_the_gate_ends_the_age() -> void:
	var s := town()
	for id in ["factory_floor", "scorcher", "chain_orders", "shard_dynamo"]:
		s.tech_tree.researched[id] = true
	for id in ["steel", "iron", "wire", "brick"]:
		s.economy.seen[id] = true
		s.economy.inv[id] = 999
	var tech_tree = s.tech_tree
	tech_tree.deed_has = func(_id): return false
	t.check(not tech_tree.can_research("skyward"), "with no deeds done it cannot be bought")
	t.check(tech_tree.open_needs("skyward").size() > 0, "and it says what is missing")
	var missing: String = " ".join(tech_tree.open_needs("skyward"))
	t.check(missing.contains(Data.DEED_NAMES["orders_written"]), "the orders: %s" % missing)
	tech_tree.deed_has = func(id): return id == "orders_written"
	t.check(not tech_tree.can_research("skyward"), "one deed is not enough")
	tech_tree.deed_has = func(_id): return true
	t.check(tech_tree.can_research("skyward"), "both deeds open the gate")
	var heard: Array = []
	s.story.recorded.connect(func(id): heard.append(id))
	t.check(s.research("skyward"), "bought")
	t.check(Data.SKYWARD_EVENT in heard and s.story.has_event(Data.SKYWARD_EVENT), "and the age ends")


# --- The goals -----------------------------------------------------------------


func test_the_goals() -> void:
	var s := town()
	s.story.update(s)
	var done := func(id): return s.story.goals_done.has(id)
	t.check(Data.GOALS_FACTORIES.size() == 6, "six more goals")
	t.check(not done.call("factory_floor") and not done.call("skyward"), "none done at the start")
	s.tech_tree.researched["factory_floor"] = true
	base.put(s, "factory_floor", s.world.camp_pos + Vector2i(3, 3))
	s.tech_tree.researched["shard_dynamo"] = true
	s.teardown.lessons.append("heat_plate")
	base.put(s, "shard_dynamo", s.world.camp_pos + Vector2i(5, 3))
	s.tech_tree.researched["chain_orders"] = true
	s.story.update(s)
	t.check(
		done.call("factory_floor") and done.call("shard_dynamo") and done.call("chain_orders"), "the three builds tick"
	)
	t.check(not done.call("orders_written") and not done.call("south_held"), "the deeds do not")
	base.put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	for i in 5:
		s.livewire.add(s)
		s.livewire.orders[i]["target"] = "forge"
	s.story.update(s)
	t.check(done.call("orders_written"), "five written orders tick")
	s.tech_tree.researched["skyward"] = true
	s.story.update(s)
	t.check(done.call("skyward"), "the gate ticks the last")


# --- The panels ----------------------------------------------------------------


func test_the_panels() -> void:
	var s := town()
	var c := powered(s)
	var floor_b: Dictionary = base.put(s, "factory_floor", c + Vector2i(2, 0))
	var panel := BuildingPanel.new()
	panel.setup(s)
	panel.select(floor_b["pos"])
	var pick = panel.parts["floor"]
	var made: String = Data.ITEMS[Buildings.recipe_out(floor_b).keys()[0]]["name"]
	t.check(pick.visible and pick.button.text.contains(made), "the card shows the recipe: %s" % pick.button.text)
	var before: String = floor_b["make"]
	if not pick.button.disabled:
		pick.button.pressed.emit()
		t.check(floor_b["make"] != before and pick.button.text.contains(made) == false, "a click steps it")
	var forge: Dictionary = base.put(s, "forge", c + Vector2i(-3, 0))
	panel.select(forge["pos"])
	t.check(not panel.parts["floor"].visible, "and only on a Floor")
	panel.free()
