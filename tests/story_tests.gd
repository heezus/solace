extends RefCounted
## Unit testbench for the Story block (scripts/story.gd) and the signal wiring of the whole game: story ids
## stay unique and recorded once, the goals stay done once met, and each story moment comes from a signal
## that Sim._init connects, checked with the signal monitor (tests/monitor.gd). The first tests build
## Story alone and feed it by hand, with no Sim. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Monitor = preload("res://tests/monitor.gd")
const Rules = preload("res://scripts/rules.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Story = preload("res://scripts/story.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_record_is_once_and_ordered()
	test_story_ids_are_stable_and_unique()
	test_listeners_record_their_moment()
	test_current_goal_follows_goals_done()
	test_goals_stay_done()
	test_story_needs_no_other_block()
	test_to_dict_and_from_dict()
	test_sim_owns_a_live_story()
	test_researching_haulers_records_once()
	test_bronze_dawn_is_recorded_and_wins()
	test_learning_by_watching_records_a_lesson()
	test_the_first_trip_is_a_signal()
	test_the_strange_stone_is_a_signal()
	test_story_order_matches_the_moments()
	test_kith_messages_reach_the_player()
	test_a_hidden_tech_waits_for_the_stone()


func test_record_is_once_and_ordered() -> void:
	var story := Story.new()
	var m := Monitor.new()
	m.watch(story, "recorded")
	t.check(story.events.is_empty(), "no story yet")
	story.record("shard_found")
	story.record("haulers")
	story.record("shard_found")
	t.check(story.events == ["shard_found", "haulers"], "each id once, in the order they happened")
	t.check(m.count("recorded") == 2, "recorded fires once per new id, not for a repeat")
	t.check(m.args_of("recorded") == [["shard_found"], ["haulers"]], "and carries the id")


func test_story_ids_are_stable_and_unique() -> void:
	var seen := {}
	for id in Data.STORY_EVENTS:
		t.check(not seen.has(id), id + " is listed once")
		seen[id] = true
		t.check(id == id.to_lower() and not id.contains(" "), id + " is snake_case")
	for tech in Data.STORY_TECHS:
		t.check(Data.TECHS.has(tech), tech + " (a story tech) is a real tech")
		t.check(Data.STORY_EVENTS.has(Data.STORY_TECHS[tech]), tech + " records an id listed in STORY_EVENTS")
	var ids := ["first_lesson", "first_trip", "shard_found", "haulers", "bronze_dawn"]
	t.check(Data.STORY_EVENTS.keys() == ids, "the ids are the stable ones a profile save will keep")


func test_listeners_record_their_moment() -> void:
	var story := Story.new()
	story.on_tech_researched("cordage")
	t.check(story.events.is_empty(), "a tech that is no story moment records nothing")
	story.on_tech_researched("haulers")
	story.on_tech_researched("haulers")
	t.check(story.events == ["haulers"], "Haulers records its id, once")
	story.on_learned("wood", "Aro")
	story.on_trip_started()
	story.on_shard_found()
	story.on_tech_researched("bronze_dawn")
	t.check(
		story.events == ["haulers", "first_lesson", "first_trip", "shard_found", "bronze_dawn"], "one listener each"
	)


func test_current_goal_follows_goals_done() -> void:
	var story := Story.new()
	t.check(story.current_goal() == 0, "the first goal is up at the start")
	story.goals_done[Data.GOALS[0]["id"]] = true
	t.check(story.current_goal() == 1, "done goals are skipped")
	story.goals_done[Data.GOALS[2]["id"]] = true
	t.check(story.current_goal() == 1, "the first goal not done is the current one")
	for g in Data.GOALS:
		story.goals_done[g["id"]] = true
	t.check(story.current_goal() == Data.GOALS.size(), "with all done it is one past the end")
	var ids := {}
	for g in Data.GOALS:
		t.check(not ids.has(g["id"]), "goal %s is listed once" % g["id"])
		ids[g["id"]] = true


func test_goals_stay_done() -> void:
	var s: Sim = t.fresh()
	s.story.update(s)
	t.check(not s.story.goals_done.has("knapping"), "Knapping is not done at the start")
	s.tech_tree.researched["knapping"] = true
	s.story.update(s)
	t.check(s.story.goals_done.has("knapping"), "researching Knapping meets its goal")
	s.tech_tree.researched.erase("knapping")
	s.story.update(s)
	t.check(s.story.goals_done.has("knapping"), "and it stays done")
	t.check(not s.story.goal_met(s, {"id": "knapping", "tech": "knapping"}), "even though it is no longer met")
	var before: int = s.story.goals_done.size()
	s.story.update(s)
	t.check(s.story.goals_done.size() == before, "updating again adds nothing")


## The story ids (in order) and the goals met survive a dict and a JSON round trip, without a signal.
func test_to_dict_and_from_dict() -> void:
	var a := Story.new()
	a.record("shard_found")
	a.record("first_lesson")
	a.goals_done["learn_wood"] = true
	a.goals_done["road"] = true
	var d := a.to_dict()
	var b := Story.new()
	var m := Monitor.new()
	m.watch(b, "recorded")
	b.from_dict(d)
	t.check(RunSave.to_json(b.to_dict()) == RunSave.to_json(d), "a Story restored from a dict writes the same dict")
	t.check(b.events == ["shard_found", "first_lesson"] and b.goals_done == a.goals_done, "same story and goals")
	t.check(m.count() == 0, "restoring records nothing new")
	var c := Story.new()
	c.from_dict(RunSave.from_json(RunSave.to_json(d)))
	t.check(RunSave.to_json(c.to_dict()) == RunSave.to_json(d), "the same after a trip through JSON text")
	t.check(c.current_goal() == a.current_goal(), "and the checklist stands where it did")
	c.record("shard_found")
	t.check(c.events.size() == 2, "a restored moment is not recorded twice")


func test_story_needs_no_other_block() -> void:
	var story := Story.new()
	story.record("first_lesson")
	t.check(story.current_goal() == 0 and story.events == ["first_lesson"], "records and reads goals on its own")


func test_sim_owns_a_live_story() -> void:
	var s: Sim = t.fresh()
	s.story.record("shard_found")
	t.check(s.story.events == ["shard_found"], "the Sim's Story block is live")


func test_researching_haulers_records_once() -> void:
	var s: Sim = t.fresh()
	t.give(s, 999)
	var research := Monitor.new()
	var story := Monitor.new()
	research.watch(s.tech_tree, "tech_researched")
	story.watch(s.story, "recorded")
	for tech in Rules.route_to("haulers", s.tech_tree.researched, Rules.visible_techs(true)):
		t.check(s.research(tech), "research " + tech)
	t.check(
		research.count("tech_researched") == Rules.route_to("haulers", {}, Rules.visible_techs(true)).size(),
		"one signal per tech"
	)
	var got: Array = research.args_of("tech_researched")
	t.check(got[got.size() - 1] == ["haulers"], "Haulers is the last, with its id")
	t.check(got.count(["haulers"]) == 1, "and it fires exactly once")
	t.check(story.count("recorded") == 1 and story.args_of("recorded") == [["haulers"]], 'Story records "haulers" once')
	t.check(not s.research("haulers"), "a repeat is refused")
	t.check(research.count("tech_researched") == got.size() and story.count("recorded") == 1, "and signals nothing")


func test_bronze_dawn_is_recorded_and_wins() -> void:
	var s: Sim = t.fresh()
	t.give(s, 99999)
	var story := Monitor.new()
	story.watch(s.story, "recorded")
	for tech in Rules.route_to("bronze_dawn", s.tech_tree.researched, Rules.visible_techs(true)):
		s.research(tech)
	t.check(s.won, "Bronze Dawn wins the game (the owner still does this)")
	t.check(story.args_of("recorded").has(["bronze_dawn"]) and story.count("recorded") == 2, "Haulers and Bronze Dawn")
	t.check(s.story.events == ["haulers", "bronze_dawn"], "in the order they were researched")


func test_learning_by_watching_records_a_lesson() -> void:
	var s: Sim = t.fresh()
	var people := Monitor.new()
	people.watch(s.people, "learned")
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_CLICKS - 1:
		s.gather_by_hand(tree)
	t.check(people.count() == 0 and s.story.events.is_empty(), "nothing learned before the last click")
	s.gather_by_hand(tree)
	t.check(people.args_of("learned") == [["wood", Data.PEOPLE_NAMES[0]]], "learned(item, name) fires once")
	t.check(s.story.events == ["first_lesson"], "and Story records the first lesson")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(tree)
	t.check(people.count("learned") == 1, "more clicks on the same thing teach nothing new")
	var stone: Vector2i = t.find_tile(s, "rock")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(stone)
	t.check(people.count("learned") == 2 and s.story.events == ["first_lesson"], "a second lesson is no new story")


func test_the_first_trip_is_a_signal() -> void:
	var s: Sim = t.fresh()
	var people := Monitor.new()
	people.watch(s.people, "trip_started")
	s.economy.inv["berries"] = 200
	var p: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	s.people.learned_by["wood"] = "Aro"
	t.check(s.story.events.is_empty(), "no trip yet")
	s.town.buildings[s.town.building_at[p]]["trips"] = 1
	for i in 100:
		s.tick(0.1)
		if people.count("trip_started") > 0:
			break
	t.check(people.count("trip_started") == 1, "the worker setting out on a clicked trip is one signal")
	t.check(s.story.events == ["first_trip"], "and Story records the first trip")


func test_the_strange_stone_is_a_signal() -> void:
	var s: Sim = t.fresh()
	var m := Monitor.new()
	m.watch(s, "shard_found")
	m.watch(s.story, "recorded")
	s.gather_by_hand(s.world.shard_pos)
	s.gather_by_hand(s.world.shard_pos)
	t.check(m.count("shard_found") == 2, "each click on the Strange Stone signals")
	t.check(m.count("recorded") == 1 and s.story.events == ["shard_found"], "but the story is recorded once")
	t.check(s.shard_seen, "and the stone is seen")


func test_story_order_matches_the_moments() -> void:
	var s: Sim = t.fresh()
	s.gather_by_hand(s.world.shard_pos)
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(tree)
	t.give(s, 99999)
	for tech in Rules.route_to("bronze_dawn", s.tech_tree.researched, Rules.visible_techs(true)):
		s.research(tech)
	t.check(s.story.events == ["shard_found", "first_lesson", "haulers", "bronze_dawn"], "%s" % [s.story.events])
	var seen := {}
	for id in s.story.events:
		t.check(not seen.has(id), id + " appears once")
		seen[id] = true


func test_kith_messages_reach_the_player() -> void:
	var s: Sim = t.fresh()
	var m := Monitor.new()
	m.watch(s.people, "announce")
	m.watch(s.people, "born")
	s.economy.inv["berries"] = 500
	s.events.clear()
	for i in int(Data.GROW_TIME * 10.0) + 20:
		t.steady_income(s)
		s.tick(0.1)
		if m.count("born") > 0:
			break
	t.check(m.count("born") == 1, "a birth is one born signal")
	t.check(m.args_of("born")[0] == [s.people.kith[s.people.kith.size() - 1]["name"]], "carrying the newborn's name")
	var told := Data.BORN_EVENT % Data.PEOPLE["one"]
	t.check(m.args_of("announce") == [[told]] and told in s.events, "and Sim shows the announcement")


func test_a_hidden_tech_waits_for_the_stone() -> void:
	var s: Sim = t.fresh()
	t.check(not s.tech_tree.tech_visible("star_lore"), "hidden before the Strange Stone")
	s.gather_by_hand(s.world.shard_pos)
	t.check(s.tech_tree.tech_visible("star_lore"), "visible after: the signal did not replace the flag")
