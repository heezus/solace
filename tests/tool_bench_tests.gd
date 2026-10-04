extends RefCounted
## The Tool Bench (design-system/14-hands-to-haulers.md): a workshop that makes Flint Tools, then Bronze Tools, so the
## player stops crafting by hand. It makes them from hauled inputs, keeps a small stock and stops when it has it, and
## hand crafting, pickup and wear work as before. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Hands = preload("res://scripts/hands.gd")
const Roads = preload("res://scripts/roads.gd")
const Workers = preload("res://scripts/workers.gd")
const Buildings = preload("res://scripts/buildings.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Work = preload("res://scripts/work.gd")
const World = preload("res://scripts/world.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_bench_comes_with_knapping_and_hand_crafting_stays()
	test_bench_makes_tools_from_hauled_inputs()
	test_bench_stops_at_its_target_and_resumes()
	test_bench_needs_a_road_or_a_click()
	test_bench_switches_to_bronze()
	test_bench_saves_and_loads()
	test_tools_made_by_the_bench_wear_as_ever()


## A camp with Knapping and Paths & Haulers known, flint and wood to spare, and a Tool Bench `dist` tiles out (linked
## by road when `link`). Returns [the Sim, the bench's index].
func bench_camp(link := true, dist := 4) -> Array:
	var s: Sim = t.fresh()
	s.tech_tree.researched["haulers"] = true
	var p := _open_spot(s, dist)
	t.check(t.place_free(s, "tool_bench", p), "a Tool Bench goes up")
	s.economy.inv["flint"] = 200
	s.economy.inv["wood"] = 200
	if link:
		t.road_link(s, p)
	return [s, s.town.building_at[p]]


func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds / 0.1):
		s.economy.inv["berries"] = 500
		s.tick(0.1)


func test_bench_comes_with_knapping_and_hand_crafting_stays() -> void:
	var s: Sim = t.fresh()
	t.give(s, 100)
	var p := _open_spot(s, 4)
	t.check(s.town.placement_error("tool_bench", p) == "Not discovered yet", "no bench before Knapping")
	t.check(not Hands.craft(s, "flint_tools"), "and no hand crafting either")
	s.tech_tree.researched["knapping"] = true
	t.check(s.town.placement_error("tool_bench", p) == "", "Knapping lets you build one")
	t.check(Data.BUILDINGS["tool_bench"]["job"] == "Toolmaker", "its worker is the Toolmaker")
	t.check(Hands.craft(s, "flint_tools") and Hands.craft(s, "flint_tools"), "hand crafting works with a bench free")
	t.check(s.economy.inv["flint_tools"] == 102 and s.hand_tools, "and makes tools as before")
	t.check(
		Data.BUILDINGS["tool_bench"]["name"] in Data.TECHS["knapping"]["unlock"], "the Knapping card names the bench"
	)


func test_bench_makes_tools_from_hauled_inputs() -> void:
	var made: Array = bench_camp()
	var s: Sim = made[0]
	var b: Dictionary = s.town.buildings[made[1]]
	t.check(Roads.linked(s, b), "the bench is road-linked")
	t.check(not s.hand_tools and s.economy.inv.get("flint_tools", 0) == 0, "no tools yet")
	var flint: int = s.economy.inv["flint"]
	_run(s, 120.0)
	var tools: int = s.economy.inv.get("flint_tools", 0) + Buildings.buffered(b["out"])
	t.check(tools >= 2, "it made tools from flint and wood that haulers brought (%d)" % tools)
	t.check(s.hand_tools, "the first tool made by the bench counts as a made tool, as a hand-crafted one does")
	t.check(s.economy.inv["flint"] <= flint - 2 * tools, "each tool used 2 Flint (%d left)" % s.economy.inv["flint"])
	t.check(b["make"] == "flint_tools", "it is making Flint Tools")
	var text := BuildingPanel.recipe_text(s, b)
	t.check(
		text.contains("flint tools") and text.contains("in stock"),
		"the panel says what it makes and the stock: " + text
	)
	b["out"].clear()
	s.economy.inv["flint_tools"] = 0
	text = BuildingPanel.recipe_text(s, b)
	t.check(text.begins_with("Making: flint tools, 0 in stock (keeps "), "and says it is making them: " + text)
	t.check(
		Buildings.recipe_in(b) == {"flint": 2, "wood": 2} and Buildings.recipe_out(b) == {"flint_tools": 1}, "recipe"
	)


func test_bench_stops_at_its_target_and_resumes() -> void:
	var made: Array = bench_camp()
	var s: Sim = made[0]
	var b: Dictionary = s.town.buildings[made[1]]
	_run(s, 240.0)
	var goal := Work.tool_goal(s)
	var have := Work.tools_stocked(s, b)
	t.check(have >= goal and have <= goal + 1, "it keeps about what is wanted: %d of %d" % [have, goal])
	t.check(
		Work.enough(s, b) and b["status"].begins_with("Enough flint tools"), "and says it has enough: " + b["status"]
	)
	var flint: int = s.economy.inv["flint"]
	var wood: int = s.economy.inv["wood"]
	var held: int = Buildings.buffered(b["inbuf"])
	_run(s, 120.0)
	t.check(
		s.economy.inv["flint"] == flint and s.economy.inv["wood"] == wood, "full, it leaves the flint and wood alone"
	)
	t.check(Buildings.buffered(b["inbuf"]) == held, "and haulers stop loading it (%d held)" % held)
	s.economy.inv["flint_tools"] = 0
	b["out"].clear()
	_run(s, 120.0)
	t.check(s.economy.inv["flint"] < flint, "stock taken away, it starts again")
	t.check(Work.tools_stocked(s, b) >= goal - 1, "and fills back up")


func test_bench_needs_a_road_or_a_click() -> void:
	var made: Array = bench_camp(false)
	var s: Sim = made[0]
	var b: Dictionary = s.town.buildings[made[1]]
	t.check(not Roads.linked(s, b), "no road: not linked")
	_run(s, 90.0)
	t.check(Buildings.buffered(b["inbuf"]) == 0 and s.economy.inv.get("flint_tools", 0) == 0, "no hauler loads it")
	Workers.click(s, made[1])
	t.check(Buildings.buffered(b["inbuf"]) > 0, "a click loads it by hand, like any workshop")
	_run(s, 30.0)
	t.check(s.economy.inv.get("flint_tools", 0) + Buildings.buffered(b["out"]) >= 1, "and it makes a tool")
	t.road_link(s, b["pos"])
	var flint: int = s.economy.inv["flint"]
	_run(s, 120.0)
	t.check(s.economy.inv["flint"] < flint, "a road lets haulers keep it fed")


func test_bench_switches_to_bronze() -> void:
	var made: Array = bench_camp()
	var s: Sim = made[0]
	var b: Dictionary = s.town.buildings[made[1]]
	s.tech_tree.researched["bronze_tools"] = true
	s.economy.inv["bronze"] = 0
	Work.choose_tool(s, b)
	t.check(b["make"] == "flint_tools", "with no Bronze in stock it stays on flint")
	s.economy.inv["bronze"] = 6
	Work.choose_tool(s, b)
	t.check(b["make"] == "bronze_tools", "with Bronze Tools learned and Bronze in stock it makes bronze")
	t.check(Buildings.recipe_in(b) == {"bronze": 1, "wood": 2}, "from 1 Bronze and 2 Wood, as by hand")
	_run(s, 150.0)
	t.check(s.economy.inv.get("bronze_tools", 0) + Buildings.buffered(b["out"]) >= 1, "it made a Bronze Tool")
	var fresh_bench: Array = bench_camp()
	var s2: Sim = fresh_bench[0]
	var b2: Dictionary = s2.town.buildings[fresh_bench[1]]
	s2.tech_tree.researched["bronze_tools"] = true
	s2.tech_tree.queue = ["star_charts"]
	s2.economy.inv["bronze"] = Data.TECHS["star_charts"]["cost"]["bronze"]
	Work.choose_tool(s2, b2)
	t.check(b2["make"] == "flint_tools", "it keeps back the Bronze the research queue is waiting for")
	s2.economy.inv["bronze"] += 1
	Work.choose_tool(s2, b2)
	t.check(b2["make"] == "bronze_tools", "and uses only what is left over")
	t.check(BuildingPanel.recipe_text(s, b).contains("bronze tools"), "the panel says so")
	var held: int = Buildings.buffered(b["inbuf"])
	b["inbuf"]["bronze"] = 1
	s.economy.inv["bronze"] = 0
	Work.choose_tool(s, b)
	t.check(b["make"] == "bronze_tools" and held >= 0, "it never switches with a batch loaded")


func test_bench_saves_and_loads() -> void:
	var made: Array = bench_camp()
	var s: Sim = made[0]
	var b: Dictionary = s.town.buildings[made[1]]
	s.tech_tree.researched["bronze_tools"] = true
	s.economy.inv["bronze"] = 6
	Work.choose_tool(s, b)
	_run(s, 25.0)
	t.check(b["make"] == "bronze_tools", "set up: a bench on bronze")
	var d := RunSave.dump(s)
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(d))), "the run loads through JSON text")
	var b2: Dictionary = s2.town.buildings[made[1]]
	t.check(b2["make"] == "bronze_tools" and b2["type"] == "tool_bench", "the bench keeps what it is making")
	t.check(b2["inbuf"] == b["inbuf"] and b2["out"] == b["out"], "and what it holds")
	var old: Dictionary = d.duplicate(true)
	for saved in old["buildings"]["buildings"]:
		saved.erase("make")
	var s3 := Sim.new()
	t.check(RunSave.restore(s3, old), "a save from before the bench loads")
	t.check(s3.town.buildings[made[1]]["make"] == "flint_tools", "and a bench in it starts on flint")
	_run(s2, 60.0)
	t.check(s2.town.buildings[made[1]]["status"] != "", "the restored bench keeps working")


func test_tools_made_by_the_bench_wear_as_ever() -> void:
	var s: Sim = t.fresh()
	s.tech_tree.researched["knapping"] = true
	s.economy.inv["flint_tools"] = 2
	var k: Dictionary = s.people.kith[0]
	k["tool"] = 0
	k["tool_id"] = ""
	s.people.equip(k)
	t.check(k["tool"] == Data.TOOL_JOBS and s.economy.inv["flint_tools"] == 1, "a Kith takes a bench tool from stock")
	t.check(Work.tool_goal(s) == Data.TOOL_SPARES, "toolless Kith that aren't working add nothing to the target")
	k["job"] = "work"
	k["tool"] = 0
	t.check(Work.tool_goal(s) == Data.TOOL_SPARES + 1, "a working Kith with no tool adds one")
	k["tool"] = 1
	k["building"] = 0
	s.town.buildings[0]["worker"] = 0
	s.people.wear(s.town.buildings[0])
	t.check(
		k["tool"] == Data.TOOL_JOBS and s.economy.inv["flint_tools"] == 0, "a worn-out tool is swapped for the next"
	)
	s.economy.inv["bronze_tools"] = 1
	k["tool"] = 0
	s.people.equip(k)
	t.check(k["tool_id"] == "bronze_tools" and k["tool"] == Data.BRONZE_TOOL_JOBS, "and bronze still comes first")


func _open_spot(s: Sim, dist: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			var steps: int = maxi(absi(p.x - s.world.camp_pos.x), absi(p.y - s.world.camp_pos.y))
			if steps >= dist and d < best_d and s.world.tile_at(p) == "grass" and not s.town.building_at.has(p):
				best = p
				best_d = d
	return best
