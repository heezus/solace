extends RefCounted
## Tests for work multipliers (scripts/bonuses.gd) and Flint Tools in Kith hands.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Hands = preload("res://scripts/hands.gd")
const Work = preload("res://scripts/work.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_bonuses_add_within_and_multiply_across()
	test_workers_take_tools()
	test_tools_wear_out()
	test_hand_gathering_keeps_its_tools()
	test_bonus_table_is_well_formed()


func test_bonuses_add_within_and_multiply_across() -> void:
	var parts := [
		{"group": "speed", "add": 0.5},
		{"group": "speed", "add": 1.0},
		{"group": "yield", "add": 1.0},
	]
	t.check(is_equal_approx(Bonuses.total(parts, "speed"), 2.5), "speed bonuses add: 1 + 0.5 + 1 = 2.5")
	t.check(is_equal_approx(Bonuses.total(parts, "yield"), 2.0), "yield bonuses are their own group")
	t.check(is_equal_approx(Bonuses.total([], "speed"), 1.0), "no bonuses: x1")

	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var p := s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	t.check(t.place_free(s, "standing_stone", p + Vector2i(0, 1)), "a Standing Stone beside the hut")
	s.tech_tree.researched["knapping"] = true
	s.economy.inv["flint_tools"] = 1
	s.tick(0.1)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(is_equal_approx(Bonuses.speed(s, hut), 2.5), "tool and Standing Stone add: x2.5, not x3")
	var tree: Vector2i = t.find_tile(s, "tree")
	s.tech_tree.researched["stone_axe"] = true
	t.check(
		Work.harvest_amount(s, hut, tree, "wood") == Data.BUNDLE * 3,
		"Stone Axe is a click tool: x3 Wood, so a bundle is %d Wood" % (Data.BUNDLE * 3)
	)
	var cycles := 60.0 / Data.BUILDINGS["gatherers_hut"]["time"]
	t.check(is_equal_approx(60.0 / Work.time(s, hut), cycles * 2.5), "speed x2.5 and the bundle multiply")
	var text := Work.text(s, hut)
	t.check(text.contains("x Speed 2.5"), "the panel shows the speed math: " + text)
	t.check(text.contains("Flint Tools +50%") and text.contains("Standing Stone +100%"), "and names each bonus")


func test_workers_take_tools() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var p := s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(is_equal_approx(Bonuses.speed(s, hut), 1.0), "no tools: normal speed")
	t.check(Hands.tools_held(s) == 0, "nobody holds a tool")
	s.economy.inv["flint_tools"] = 2
	var k: Dictionary = s.people.kith[hut["worker"]]
	s.people.wear(hut)  # one job done: the worker picks up a tool on the way back
	t.check(k["tool"] == Data.TOOL_JOBS, "the worker takes a tool good for %d jobs" % Data.TOOL_JOBS)
	t.check(s.economy.inv["flint_tools"] == 1, "from the stockpile")
	t.check(Hands.tools_held(s) == 1, "one Kith holds a tool")
	t.check(is_equal_approx(Bonuses.speed(s, hut), 1.5), "a worker with a tool works 50% faster")
	t.check(is_equal_approx(Work.time(s, hut), Data.BUILDINGS["gatherers_hut"]["time"] / 1.5), "so each job is shorter")
	var q := s.world.camp_pos + Vector2i(2, 0)
	t.place_free(s, "gatherers_hut", q)
	s.tick(0.1)
	var hut2: Dictionary = s.town.buildings[s.town.building_at[q]]
	if hut2["worker"] >= 0:
		t.check(s.people.kith[hut2["worker"]]["tool"] == Data.TOOL_JOBS, "a newly staffed worker takes the spare")
		t.check(s.economy.inv["flint_tools"] == 0, "which empties the stockpile")


func test_tools_wear_out() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var p := s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.economy.inv["flint_tools"] = 1
	s.tick(0.1)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	var k: Dictionary = s.people.kith[hut["worker"]]
	t.check(k["tool"] == Data.TOOL_JOBS, "equipped on taking the job")
	for i in Data.TOOL_JOBS - 1:
		s.people.wear(hut)
	t.check(k["tool"] == 1, "each job wears the tool")
	s.people.wear(hut)
	t.check(k["tool"] == 0, "worn out after %d jobs" % Data.TOOL_JOBS)
	t.check(is_equal_approx(Bonuses.speed(s, hut), 1.0), "back to normal speed")
	s.economy.inv["flint_tools"] = 1
	s.people.wear(hut)
	t.check(k["tool"] == Data.TOOL_JOBS, "a new tool from the stockpile after the next job")


func test_hand_gathering_keeps_its_tools() -> void:
	var s: Sim = t.fresh()
	var tree: Vector2i = t.find_tile(s, "tree")
	s.tech_tree.researched["knapping"] = true
	s.economy.inv["flint"] = 2
	s.economy.inv["wood"] = 2
	Hands.craft(s, "flint_tools")
	s.economy.inv["flint_tools"] = 0  # the Kith took every spare
	s.economy.inv["wood"] = 0
	s.gather_by_hand(tree)
	t.check(s.economy.inv["wood"] == 1, "a Flint Tool shortens the hold, it doesn't add Wood")
	t.check(is_equal_approx(Hands.hold_time(s, "wood"), 0.7), "you keep a tool for yourself: the hold stays 0.7 s")
	s.tech_tree.researched["stone_axe"] = true
	s.gather_by_hand(tree)
	t.check(s.economy.inv["wood"] == 4, "the Stone Axe is a yield tool: 3 Wood a harvest")
	t.check(is_equal_approx(Hands.hold_time(s, "wood"), 0.7), "and the Flint Tool still sets the hold")
	s.tech_tree.researched["ochre"] = true
	var clay: Vector2i = t.find_tile(s, "clay")
	s.fog.reveal_all()
	s.economy.inv["clay"] = 0
	s.gather_by_hand(clay)
	t.check(s.economy.inv.get("clay", 0) == 1, "Ochre is for huts only: 1 Clay a harvest by hand")


func test_bonus_table_is_well_formed() -> void:
	for id in Data.BONUSES:
		var b: Dictionary = Data.BONUSES[id]
		t.check(b["group"] in ["speed", "yield"], "%s is a Speed or Yield bonus" % id)
		t.check(b["add"] > 0.0, "%s adds something" % id)
		t.check(not b.has("tech") or Data.TECHS.has(b["tech"]), "%s names a real tech" % id)
		t.check(not b.has("rank_of") or Data.TECHS[b["rank_of"]].has("rank"), "%s is a ranked tech's bonus" % id)
		t.check(not b.has("item") or Data.ITEMS.has(b["item"]), "%s names a real item" % id)
