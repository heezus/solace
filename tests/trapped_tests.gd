extends RefCounted
## "No trapped telling" (fun-4): the goal line names the techs on the way (even the cheap ones), a Lesson learned in an earlier telling is
## not asked for again, a Teardown part says where it comes from, raised hauler places say what they take, the Tide Watch warning counts
## down in steps a player can see, and the table's page shows the new land's card and can lay the founding plan. Run from run_tests.gd.

const Buildings = preload("res://scripts/buildings.gd")
const Chain = preload("res://scripts/chain.gd")
const Data = preload("res://scripts/data.gd")
const Needs = preload("res://scripts/needs.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")
const AiStory = preload("res://tests/tools/ai_story.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_goal_line_names_the_techs_on_the_way()
	test_a_learned_lesson_is_not_asked_for_again_and_a_missing_one_says_where_it_comes_from()
	test_raised_hauler_places_say_what_they_take()
	test_the_table_page_shows_the_new_land_card_and_lays_the_plan()
	test_the_table_page_says_free_homes()
	test_ore_seams_stay_minable_under_the_bloom()
	test_the_defences_are_free_to_start_with_and_burn_four_tiles_a_minute()
	test_the_first_push_leaves_the_diggers_alone()


func test_the_goal_line_names_the_techs_on_the_way() -> void:
	var s := Sim.new()
	s.generate(5)
	t.check(
		Chain.route_line(s, "gatherers_hut") == "Gatherer's Hut needs Knapping and Foraging first.",
		"a tech names the parents not yet discovered: %s" % Chain.route_line(s, "gatherers_hut")
	)
	t.check(
		Chain.note(s, "gatherers_hut").contains("Knapping and Foraging first"), "and the goal's IN THE WAY carries it"
	)
	s.tech_tree.researched["knapping"] = true
	s.tech_tree.researched["foraging"] = true
	t.check(Chain.route_line(s, "gatherers_hut") == "", "once they are discovered the line goes")
	var far := Chain.route_line(s, "falling_star")
	t.check(
		far.begins_with("The Falling Star needs ") and far.ends_with(" first."),
		"a far gate lists what stands before it: %s" % far
	)
	t.check(far.contains(" more first.") or far.count(",") <= 3, "and keeps the list short")


func test_a_learned_lesson_is_not_asked_for_again_and_a_missing_one_says_where_it_comes_from() -> void:
	var s := Sim.new()
	s.generate(5)
	var line := Needs.shut(s, "shard_dynamo")
	t.check(
		line.contains("Heat Plate") and line.contains("from the Wreck"),
		"a Lesson not learned says which part teaches it and where it comes from: %s" % line
	)
	s.teardown.lessons.append("heat_plate")
	t.check(
		Needs.shut(s, "shard_dynamo") == "",
		"a Lesson an earlier telling learned is not asked for: only the tech is left"
	)


func test_raised_hauler_places_say_what_they_take() -> void:
	var s := Sim.new()
	s.generate(5)
	var depot: Vector2i = s.world.camp_pos
	s.hauling.auto = {depot: 6}
	s.hauling._have = {depot: 1}
	for k in s.people.kith:
		k["job"] = "work"
	t.check(
		s.hauling.take_note(s, depot) == "Takes 5 Kith from work",
		"5 more places, nobody idle: " + s.hauling.take_note(s, depot)
	)
	s.people.kith[0]["job"] = ""
	s.people.kith[1]["job"] = ""
	t.check(
		s.hauling.take_note(s, depot) == "Takes 3 Kith from work",
		"two idle Kith cover some: " + s.hauling.take_note(s, depot)
	)
	s.hauling.auto = {depot: 3}
	t.check(s.hauling.take_note(s, depot) == "Uses 2 idle Kith", "idle Kith cover it: " + s.hauling.take_note(s, depot))
	s.hauling._have = {depot: 3}
	t.check(s.hauling.take_note(s, depot) == "", "full places take nothing")


func test_the_table_page_shows_the_new_land_card_and_lays_the_plan() -> void:
	AiStory.reset("user://trapped_profile.json")
	var s := Sim.new()
	s.generate(3)
	s.carry.exodus = 1
	s.carry.last_eras = [10.0, 10.0, 10.0, 10.0]
	s.carry.founding = {"name": "The founding", "items": [{"t": "gatherers_hut", "x": 3, "y": 2}], "ax": 0, "ay": 0}
	var page := Snapshot.text(s, 1, [], [])
	t.check(page.contains("THE NEW LAND (card)"), "the page shows the new land's card")
	t.check(page.contains("What the Kin remember".to_upper()), "with what the Kin remember")
	t.check(
		page.contains('"do":"lay_plan"') and page.contains("FOUNDING PLAN: 1 parts"),
		"and the move that lays the founding plan"
	)
	var refused := Snapshot.apply(s, [{"do": "lay_plan"}])
	t.check(refused.is_empty(), "the plan is laid (%s)" % [refused])
	t.check(not s.carry.plans.is_empty(), "its parts are queued")
	t.check(not Snapshot.text(s, 2, [], []).contains("THE NEW LAND (card)"), "and the card goes from the page")
	t.check(Snapshot.HELP.contains('"do":"lay_plan"'), "the page's MOVES help lists the move")
	AiStory.reset()


func test_the_table_page_says_free_homes() -> void:
	var s := Sim.new()
	s.generate(3)
	var page := Snapshot.text(s, 1, [], [])
	t.check(
		page.contains("homes for") and page.contains(" free"),
		"the Kith line says homes and how many are free, not a bare 'room for'"
	)
	t.check(not page.contains("room for"), "so 'No room' and 'room for 7' cannot read as a contradiction")


func test_ore_seams_stay_minable_under_the_bloom() -> void:
	var s := Sim.new()
	s.generate(5)
	s.fog.reveal_all()
	s.tech_tree.researched["mining"] = true
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 500
	var seam: Vector2i = s.world.camp_pos + Vector2i(8, 0)
	var bare: Vector2i = s.world.camp_pos + Vector2i(8, 3)
	for p in [seam, bare]:
		s.world.set_tile(p, "copper_hills" if p == seam else "grass")
	s.tide._grow(s, seam)
	s.tide._grow(s, bare)
	t.check(s.tide.bloom_at(seam) and s.tide.bloom_at(bare), "the Bloom has grown over both")
	t.check(
		s.town.placement_error("mine", seam) == "",
		"a Mine can still go on the ore: %s" % s.town.placement_error("mine", seam)
	)
	t.check(s.town.placement_error("dwelling", bare).contains("Bloom"), "but bare ground under the Bloom is refused")
	t.check(s.place("mine", seam), "the Mine is placed")
	s.tide._grow(s, seam)
	t.check(not s.tide.hit.has(seam), "a building on the ore is never overgrown")
	for i in 40:
		s.tick(10.0)
	t.check(s.town.building_at.has(seam), "and it is still standing after the tide has had its time")
	t.check(
		Buildings.trade_allows("lumen_market", "iron") and Buildings.trade_allows("lumen_market", "clay"),
		"the Lumen Market trades Iron and Clay"
	)
	t.check(Buildings.trade_allows("lumen_market", "coal"), "and Coal")


func test_the_defences_are_free_to_start_with_and_burn_four_tiles_a_minute() -> void:
	var s := Sim.new()
	s.generate(5)
	var research_cost: Dictionary = s.tech_tree.cost_of("scorcher")
	t.check(not research_cost.is_empty(), "before the Bloom wakes the Scorcher tech has its price")
	s.tide.begun = true
	t.check(
		s.tech_tree.cost_of("scorcher").is_empty() and s.tech_tree.cost_of("arc_lamps").is_empty(),
		"once it wakes the two techs are free"
	)
	t.check(
		s.town.price("scorcher").is_empty() and s.town.price("arc_lamp").is_empty(),
		"so is the first Scorcher and the first Arc Lamp"
	)
	s.tech_tree.researched["scorcher"] = true
	s.fog.reveal_all()
	var at: Vector2i = s.world.camp_pos + Vector2i(8, 0)
	t.check(s.place("scorcher", at), "the free Scorcher goes down for nothing")
	t.check(not s.town.price("scorcher").is_empty(), "the second one has its price")
	t.check(
		60.0 / Data.SCORCH_SECONDS >= 4.0,
		"a Scorcher clears at least four tiles a minute (%.0f s a tile)" % Data.SCORCH_SECONDS
	)
	t.check(
		float(Data.BUILDINGS["scorcher"]["burn"]) / Data.SCORCH_SECONDS >= 4.0, "and one Coal still does four tiles"
	)


func test_the_first_push_leaves_the_diggers_alone() -> void:
	var s := Sim.new()
	s.generate(5)
	s.fog.reveal_all()
	s.tech_tree.researched["mining"] = true
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 500
	var seam: Vector2i = s.world.camp_pos + Vector2i(9, 0)
	s.world.set_tile(seam, "copper_hills")
	s.place("mine", seam)
	s.tide.begun = true
	s.tide.time = 10.0
	s.tide.refresh_lights(s)
	t.check(s.tide._state(s, seam + Vector2i(2, 0)) == 1, "in the first minutes the tide waits outside a Mine's ring")
	t.check(s.tide._state(s, seam + Vector2i(8, 0)) == 0, "and takes open ground as it does")
	s.tide.time = 400.0
	t.check(s.tide._state(s, seam + Vector2i(2, 0)) == 0, "later pushes are as they were")
