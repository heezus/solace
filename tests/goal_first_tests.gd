extends RefCounted
## Goal first (fun playtest 6, call 2): a workshop whose goods nothing needs holds while the goal or the research queue is short of what it
## eats, runs again by itself, leaves a basic good above the floor, leaves a hand's pause and a hand's Resume alone, and has a toggle.
## Run from run_tests.gd.

const Data = preload("res://scripts/data.gd")
const Fun6bTests = preload("res://tests/fun6b_tests.gd")
const GoalFirst = preload("res://scripts/goal_first.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	Fun6bTests.new().run(runner)  # the fun-6 fixes B tests ride with this group (run_tests.gd is at its line cap)
	test_a_crucible_holds_while_the_wire_mill_waits_for_copper_and_resumes_by_itself()
	test_a_pit_leaves_wood_above_the_floor_when_charcoal_is_not_wanted()
	test_a_hands_pause_and_a_hands_resume_are_left_alone()
	test_the_toggle_turns_it_off_and_back_on_and_is_saved()


func _setup() -> Sim:
	var s: Sim = t.fresh()
	t.give(s, 0)
	s.tech_tree.queue = ["arc_lamps"]  # brick 40, steel 12, wire 20: the Wire Mill's Copper is down the recipes
	return s


func _place(s: Sim, type: String, dx: int) -> Dictionary:
	var at := s.world.camp_pos + Vector2i(dx, 2)
	s.town.add_building(type, at)
	return s.town.buildings[s.town.building_at[at]]


func test_a_crucible_holds_while_the_wire_mill_waits_for_copper_and_resumes_by_itself() -> void:
	var s := _setup()
	var c := _place(s, "crucible", 3)
	s.economy.inv["bronze"] = 50  # nothing open asks for Bronze
	s.economy.inv["copper"] = 5
	s.economy.inv["tin"] = 20
	GoalFirst.update(s)
	t.check(c["paused"], "the Crucible holds: the Copper is for the wire")
	t.check(c["goal_hold"] == GoalFirst.HOLDING % "Copper", "and says so: " + str(c["goal_hold"]))
	s.economy.inv["copper"] = 100
	GoalFirst.update(s)
	t.check(not c["paused"] and c["goal_hold"] == "", "with Copper in hand it runs again by itself")
	s.economy.inv["copper"] = 5
	s.economy.inv["bronze"] = 5  # and a Crucible whose Bronze is wanted is never held
	GoalFirst.update(s)
	t.check(not c["paused"], "under the reserve of its own good it runs on")
	s.tech_tree.queue = ["star_charts"]  # asks for 25 Bronze: the Crucible makes what is asked for
	s.economy.inv["bronze"] = 22
	GoalFirst.update(s)
	t.check(not c["paused"], "a Crucible that makes what the queue needs runs")


func test_a_pit_leaves_wood_above_the_floor_when_charcoal_is_not_wanted() -> void:
	var s := _setup()
	s.tech_tree.queue = []
	var p := _place(s, "charcoal_pit", 3)
	s.economy.inv["charcoal"] = 400  # nothing asks for it any more
	s.economy.inv["wood"] = 10
	GoalFirst.update(s)
	t.check(p["paused"], "a Pit does not draw Wood below 40 for Charcoal nothing needs")
	t.check(
		p["goal_hold"] == GoalFirst.HOLDING_FLOOR % ["Wood", GoalFirst.FLOOR], "and says so: " + str(p["goal_hold"])
	)
	s.economy.inv["wood"] = 300
	GoalFirst.update(s)
	t.check(not p["paused"], "with Wood in hand it runs again")


func test_a_hands_pause_and_a_hands_resume_are_left_alone() -> void:
	var s := _setup()
	var c := _place(s, "crucible", 3)
	s.economy.inv["bronze"] = 50
	s.economy.inv["copper"] = 5
	s.set_paused(s.town.building_at[c["pos"]], true)
	GoalFirst.update(s)
	t.check(c["goal_hold"] == "", "a Crucible the player paused is not Goal first's to hold or release")
	s.set_paused(s.town.building_at[c["pos"]], false)
	c["goal_free"] = true  # the panel's Resume sets this
	GoalFirst.update(s)
	t.check(not c["paused"], "a Crucible the player resumed is not held again")


func test_the_toggle_turns_it_off_and_back_on_and_is_saved() -> void:
	var s := _setup()
	var c := _place(s, "crucible", 3)
	s.economy.inv["bronze"] = 50
	s.economy.inv["copper"] = 5
	GoalFirst.update(s)
	t.check(c["paused"], "held with Goal first on")
	s.goal_first = false
	GoalFirst.update(s)
	t.check(not c["paused"] and c["goal_hold"] == "", "turning it off lets the workshop run")
	s.goal_first = true
	GoalFirst.update(s)
	t.check(c["paused"], "and on holds it again")
	t.check(Sim.new().goal_first, "a new game has it on")
