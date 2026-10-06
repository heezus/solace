extends RefCounted
## PR 1 of the growth batch (design-system/17-needs-and-upgrades.md): buildings stay off the build bar until the tech
## tree has revealed them, the Jobs line counts places and not buildings, road and bridge tiers, copy cost, the hand
## cart and fog scouting. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const CardText = preload("res://scripts/card_text.gd")
const Ui = preload("res://scripts/ui.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_cards_wait_for_the_tech_tree_to_reveal_them()
	test_jobs_filled_never_passes_jobs()


# --- Hidden until learned ------------------------------------------------------


func test_cards_wait_for_the_tech_tree_to_reveal_them() -> void:
	var s: Sim = t.fresh()
	t.check(CardText.shown(s, "dwelling") and CardText.shown(s, "camp"), "buildings with no tech always show")
	for type in ["cart_shed", "trading_post", "storehouse", "kiln", "road", "water_wheel", "mine"]:
		t.check(not CardText.shown(s, type), "%s stays off the bar before the tree reveals it" % type)
	t.check(not CardText.shown(s, "road"), "the Road waits for Paths & Haulers to show up on the board")
	t.check(not s.tech_tree.tech_visible("haulers"), "(it is not in view at the start)")
	for id in Data.ITEM_ORDER:  # everything has been found: only the research decides what shows
		s.economy.seen[id] = true
	t.check(s.tech_tree.tech_visible("haulers"), "Paths & Haulers is in view once its items were found")
	t.check(CardText.shown(s, "road"), "so the Road card shows, locked")
	t.check(not CardText.shown(s, "cart_shed"), "the Cart Shed still hides: The Wheel needs its own parents in view")
	s.tech_tree.researched["the_wheel"] = true
	t.check(CardText.shown(s, "cart_shed"), "a learned tech always shows its card")


# --- The Jobs line -------------------------------------------------------------


func test_jobs_filled_never_passes_jobs() -> void:
	var s: Sim = t.fresh()
	var camp: Vector2i = s.world.camp_pos
	t.check(Ui.job_slots(s) == 0 and Ui.jobs_filled(s) == 0, "no buildings, no jobs")
	s.town.add_building("mine", camp + Vector2i(3, 0))  # a Mine needs two people
	s.town.add_building("gatherers_hut", camp + Vector2i(3, 2))
	t.check(Ui.job_slots(s) == 3, "a Mine is two jobs and a hut one: 3, not 2 buildings (%d)" % Ui.job_slots(s))
	while s.people.kith.size() < 6:
		s.people.add_kith()
	var mine: Dictionary = s.town.buildings[1]
	var hut: Dictionary = s.town.buildings[2]
	for i in 3:
		s.people.kith[i]["job"] = "work"
	mine["worker"] = 0
	mine["mate"] = 1
	hut["worker"] = 2
	t.check(Ui.jobs_filled(s) == 3, "three Kith hold the three places")
	s.people.kith[3]["job"] = "haul"
	s.people.kith[4]["job"] = "scout"
	t.check(Ui.jobs_filled(s) == 3, "a hauler or a scout holds no place")
	s.people.kith[5]["job"] = "work"  # at work by the Kith list, but no building holds them
	t.check(Ui.jobs_filled(s) == 3, "a Kith no building holds is not counted: never 4 of 3")
	t.check(Ui.idle_kith(s) == 3, "the rest are the other three")
	s.set_paused(2, true)
	t.check(Ui.job_slots(s) == 2 and Ui.jobs_filled(s) == 2, "a paused building is not a job and its worker is off it")
	t.check(Ui.jobs_filled(s) <= Ui.job_slots(s), "filled never passes jobs")
