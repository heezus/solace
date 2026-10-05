extends RefCounted
## What the Kith have found decides which techs show (Research.tech_visible), and the Hearth's look follows the techs
## (HearthLook). Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const TechNext = preload("res://scripts/tech_next.gd")
const HearthLook = preload("res://scripts/hearth_look.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_tech_shows_once_its_items_have_been_found()
	test_hidden_techs_do_not_leak_into_suggestions()
	test_found_items_survive_a_save()
	test_hearth_grows_with_its_milestone_techs()


func test_a_tech_shows_once_its_items_have_been_found() -> void:
	var s: Sim = t.fresh()
	var tree = s.tech_tree
	t.check(tree.tech_visible("knapping") and tree.tech_visible("fire"), "techs made of the start items show")
	t.check(not tree.tech_visible("cordage"), "Cordage hides until fiber has been found")
	t.check(not tree.tech_visible("foraging"), "Foraging too")
	t.check(not tree.tech_visible("storehouse"), "and a tech past several finds")
	s.economy.add("fiber", 1)
	t.check(tree.tech_visible("cordage") and tree.tech_visible("foraging"), "finding fiber shows its branch")
	t.check(not tree.tech_visible("storehouse"), "the rest stay hidden")
	s.economy.inv["fiber"] = 0
	t.check(tree.tech_visible("cordage"), "a find isn't lost when the stock runs out")
	t.check(not tree.can_research("cordage") and tree.requirements_met("cordage"), "visible, not yet affordable")
	var hidden := Data.TECHS.keys().filter(func(id): return not tree.tech_visible(id))
	t.check(hidden.size() > 20, "most of the board is still hidden at the start (%d)" % hidden.size())


func test_hidden_techs_do_not_leak_into_suggestions() -> void:
	var s: Sim = t.fresh()
	var before: Array = TechNext.ready_now(s, 1)
	t.check("cordage" not in before and "fire" in before, "the next-steps list shows only what has been found")
	t.check(s.tech_tree.visible_set().has("fire") and not s.tech_tree.visible_set().has("cordage"), "the same set")
	s.economy.add("fiber", 1)
	t.check("cordage" in TechNext.ready_now(s, 1), "and picks Cordage up once fiber is found")
	s.tech_tree.goal = "knapping"
	s.tech_tree.refill()
	t.check(s.tech_tree.goal == "knapping" or s.tech_tree.queue.has("knapping"), "routes to what shows still work")


func test_found_items_survive_a_save() -> void:
	var s: Sim = t.fresh()
	s.economy.add("fiber", 3)
	s.economy.inv["fiber"] = 0
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run loads through JSON text")
	t.check(s2.tech_tree.tech_visible("cordage"), "a loaded run still shows what had been found")
	t.check(not s2.tech_tree.tech_visible("storehouse"), "and still hides the rest")


func test_hearth_grows_with_its_milestone_techs() -> void:
	t.check(HearthLook.stage({}) == 0, "a bare camp is stage 0")
	t.check(HearthLook.stage({"fire": true}) == 1, "Fire lights the first stage")
	var all := {}
	for tech in HearthLook.MILESTONES:
		t.check(Data.TECHS.has(tech), "milestone %s is a real tech" % tech)
		all[tech] = true
	t.check(HearthLook.stage(all) == HearthLook.MILESTONES.size(), "every milestone is the last stage")
	t.check(HearthLook.reached({"fire": true, "calendar": true}) == ["fire", "calendar"], "reached keeps the order")
