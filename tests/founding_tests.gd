extends RefCounted
## Step 9B, the founding: a run after an ending that finished an era begins with ten founders who know the jobs, learns every tech
## the Kin knew for nothing (the four gates keep their price), has one "Reach <gate>" goal for each remembered era with the last
## telling's minutes beside a live clock, and can lay the town the last telling had when the Falling Star came. Run from run_tests.gd.

const Carry = preload("res://scripts/carry.gd")
const Data = preload("res://scripts/data.gd")
const Founding = preload("res://scripts/founding.gd")
const Launch = preload("res://scripts/launch.gd")
const NoticeCard = preload("res://scripts/notice_card.gd")
const Profile = preload("res://scripts/profile.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")

const TEMP_PROFILE := "user://solace_test_founding_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	_clean()
	test_the_carry_keeps_the_eras_the_jobs_and_the_plan_through_a_save()
	test_a_telling_that_went_on_to_the_next_era_remembers_the_one_before()
	test_a_new_run_begins_with_ten_founders_who_know_the_jobs()
	test_known_techs_are_learned_for_nothing_and_the_gates_cost_their_price()
	test_a_remembered_era_has_one_goal_with_a_clock()
	test_the_town_at_the_falling_star_is_laid_on_the_new_land()
	test_the_new_land_card_says_what_the_kin_remember_and_offers_the_plan()
	test_the_plan_buys_huts_first_then_roads_then_the_earliest_buildings()
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PROFILE):
		DirAccess.remove_absolute(TEMP_PROFILE)


## A Sim that has played the first two eras: the stone age and Bronze Dawn done, the Falling Star fallen, a few buildings up.
func _ended_run() -> Sim:
	var s := Sim.new()
	s.generate(5)
	for tech in ["knapping", "fire", "cordage", "bronze_dawn", "falling_star"]:
		s.tech_tree.researched[tech] = true
	s.people.learn("wood", "Aro")
	s.people.learn("berries", "Aro")
	s.story.stamps = {"bronze_dawn": 900.0, "star_falling": 2000.0}
	s.story.record("bronze_dawn")
	s.story.record("star_falling")
	s.seasons.time = 3000.0
	return s


func _put(s: Sim, type: String, off: Vector2i) -> void:
	s.town.add_building(type, s.world.camp_pos + off)


func test_the_carry_keeps_the_eras_the_jobs_and_the_plan_through_a_save() -> void:
	var c = Carry.new()
	c.exodus = 1
	c.jobs = ["wood", "berries"]
	c.last_eras = [15.0, 18.5, 16.0]
	c.founding = {
		"name": "The founding", "w": 2, "h": 2, "items": [{"t": "dwelling", "x": 0, "y": 1}], "ax": -3, "ay": 2
	}
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back = Carry.new()
	back.from_dict(d)
	t.check(back.jobs == ["wood", "berries"], "the jobs come back")
	t.check(back.last_eras == [15.0, 18.5, 16.0], "and the minutes of each era")
	t.check(back.founding["items"].size() == 1 and int(back.founding["ax"]) == -3, "and the founding plan")
	var plain = Carry.new()
	plain.from_dict({})
	t.check(
		plain.jobs.is_empty() and plain.last_eras.is_empty() and plain.founding.is_empty(),
		"a save without them has none"
	)


func test_a_telling_that_went_on_to_the_next_era_remembers_the_one_before() -> void:
	_clean()
	var s := _ended_run()
	_put(s, "dwelling", Vector2i(3, 2))
	Profile.set_out(s, TEMP_PROFILE)
	var n := Sim.new()
	Launch.begin_new(n, 1005, TEMP_PROFILE)
	t.check(n.carry.last_eras.size() == 3, "the last telling reached three eras: %s" % [n.carry.last_eras])
	t.check(n.carry.remembers_era(0) and n.carry.remembers_era(1), "the stone age and Bronze Dawn are remembered")
	t.check(not n.carry.remembers_era(2), "the Starfall, which it began and did not finish, is not")
	var first := Sim.new()
	Launch.begin_new(first, 7, "user://solace_test_founding_none.json")
	t.check(
		not first.carry.remembers_era(0) and first.people.kith.size() == Data.KITH_START,
		"a first run remembers nothing"
	)
	_clean()


func test_a_new_run_begins_with_ten_founders_who_know_the_jobs() -> void:
	_clean()
	Profile.set_out(_ended_run(), TEMP_PROFILE)
	var n := Sim.new()
	Launch.begin_new(n, 1005, TEMP_PROFILE)
	t.check(n.people.kith.size() == Founding.START_KITH, "ten founders walk out (%d)" % n.people.kith.size())
	t.check(n.people.knows("wood") and n.people.knows("berries"), "and they know the jobs the last telling learned")
	var base := Sim.new()
	base.generate(1005)
	t.check(not base.people.knows("wood"), "(a fresh run knows none)")
	_clean()


func test_known_techs_are_learned_for_nothing_and_the_gates_cost_their_price() -> void:
	var s := Sim.new()
	s.generate(5)
	s.carry.exodus = 1
	s.carry.techs = ["knapping", "fire", "bronze_dawn"]
	s.carry.last_eras = [10.0, 12.0]
	t.check(Founding.is_free(s, "knapping") and not Founding.is_free(s, "bronze_dawn"), "free, but not the gate")
	t.check(
		(
			Founding.mark(s, "knapping") == Founding.REMEMBERED_MARK
			and Founding.mark(s, "bronze_dawn") == Founding.GATE_MARK
		),
		"marked"
	)
	t.check(Founding.mark(s, "cordage") == "", "an unlearned tech has no mark")
	s.tick(1.2)  # a second passes: the Kin learn what they can for nothing
	t.check(s.tech_tree.researched.has("knapping"), "Knapping is learned at once, for nothing")
	t.check(not s.tech_tree.researched.has("bronze_dawn"), "the gate is not learned until it is paid for")


func test_a_remembered_era_has_one_goal_with_a_clock() -> void:
	var s := Sim.new()
	s.generate(5)
	t.check(s.story.goal_list() == Data.GOALS, "a first run has the whole stone age list")
	s.carry.exodus = 1
	s.carry.last_eras = [17.0, 12.0, 9.0]
	var list: Array = s.story.goal_list()
	t.check(list.size() == 1 and list[0]["id"] == "bronze" and list[0]["tech"] == "bronze_dawn", "one goal: the gate")
	s.seasons.time = 360.0
	var text: String = s.story.goal_text(list[0], s)
	t.check(
		text.contains("Reach Bronze Dawn") and text.contains("Last telling: 17 min. This telling: 6 min"),
		"the clock: " + text
	)
	s.story.record("bronze_dawn")
	s.story.stamps["bronze_dawn"] = 400.0
	list = s.story.goal_list()
	t.check(list.size() == 1 and list[0]["id"] == "falling_star", "Bronze Dawn's goal is its gate too")
	s.story.record("star_falling")
	t.check(s.story.goal_list() == Data.GOALS_ERA3, "an era the last telling began and did not finish keeps its goals")
	var again := Sim.new()
	again.generate(5)
	again.carry.exodus = 1
	again.carry.last_eras = [17.0]
	t.check(again.story.goal_list() == Data.GOALS, "a telling that stopped in the stone age remembers none")


func test_the_town_at_the_falling_star_is_laid_on_the_new_land() -> void:
	var s := Sim.new()
	s.generate(5)
	_put(s, "dwelling", Vector2i(3, 2))
	_put(s, "dwelling", Vector2i(5, 2))
	_put(s, "twine_post", Vector2i(3, 4))
	s.story.record("star_falling")
	s.tick(0.1)
	t.check(Founding.has_plan(s), "the Falling Star keeps the town as the founding plan")
	var plan: Dictionary = s.carry.founding
	t.check(
		plan["items"].size() == 3 and int(plan["ax"]) == 3 and int(plan["ay"]) == 2,
		"its three parts, the corner from the Hearth"
	)
	t.check(plan["banked"] == true, "laid at a carried plan's share of the price")
	var n := Sim.new()
	n.generate(6)
	n.carry.founding = plan.duplicate(true)
	var queued := Founding.lay(n)
	t.check(queued == 3 and n.carry.plans.size() == 3, "laying queues every part (%d)" % queued)
	var empty := Sim.new()
	empty.generate(5)
	empty.story.record("star_falling")
	empty.tick(0.1)
	t.check(not Founding.has_plan(empty), "a town of only the Hearth keeps nothing")
	_clean()
	var ended := _ended_run()
	_put(ended, "dwelling", Vector2i(3, 2))
	ended.carry.founding = plan.duplicate(true)
	Profile.set_out(ended, TEMP_PROFILE, "cataclysm")
	var next := Sim.new()
	Launch.begin_new(next, 1005, TEMP_PROFILE)
	t.check(Founding.has_plan(next), "every ending hands the plan on, a Cataclysm too")
	var dump := RunSave.dump(next)
	var back := Sim.new()
	t.check(
		RunSave.restore(back, JSON.parse_string(RunSave.to_json(dump))) and Founding.has_plan(back),
		"and a run save keeps it"
	)
	_clean()


func test_the_new_land_card_says_what_the_kin_remember_and_offers_the_plan() -> void:
	_clean()
	var ended := _ended_run()
	_put(ended, "dwelling", Vector2i(3, 2))
	Founding.snapshot(ended)
	Profile.set_out(ended, TEMP_PROFILE)
	var s := Sim.new()
	Launch.begin_new(s, 1005, TEMP_PROFILE)
	var lines: Array = Founding.card_lines(s)
	t.check(
		lines.size() >= 3 and lines[0] == Founding.REMEMBER_TITLE.to_upper(),
		"the card has the Kin's memories: %s" % [lines]
	)
	t.check("\n".join(lines).contains("10 of them"), "the founders are named")
	var card := NoticeCard.new()
	card.profile_path = TEMP_PROFILE
	card.setup()
	t.check(card.poll(s, false), "the card opens")
	var buttons := 0
	for c in card._box.get_children():
		buttons += 1 if c is Button else 0
	t.check(buttons == 2, "with a button for the plan as well as Begin (%d)" % buttons)
	card._pick(1)
	t.check(s.carry.plans.size() == 1, "pressing it lays the old town (%d parts)" % s.carry.plans.size())
	card.free()
	_clean()


func test_the_plan_buys_huts_first_then_roads_then_the_earliest_buildings() -> void:
	var s := Sim.new()
	s.generate(5)
	s.carry.founding = {
		"name": "The founding",
		"w": 6,
		"h": 1,
		"banked": true,
		"items":
		[
			{"t": "kiln", "x": 0, "y": 0},
			{"t": "twine_post", "x": 1, "y": 0},
			{"t": "road", "x": 2, "y": 0},
			{"t": "gatherers_hut", "x": 3, "y": 0},
			{"t": "dwelling", "x": 4, "y": 0},
		],
		"ax": 3,
		"ay": 3
	}
	Founding.lay(s)
	var order: Array = s.carry.plans.map(func(q): return q["t"])
	t.check(order[0] == "gatherers_hut" and order[1] == "road", "huts, then roads: %s" % [order])
	t.check(order.find("twine_post") < order.find("kiln"), "then the buildings of the earlier tech: %s" % [order])
