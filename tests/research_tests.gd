extends RefCounted
## Unit testbench for the Research block (scripts/research.gd): requirements, hidden techs, paying for a
## tech, the goal and the queue. Research is built alone, on an Economy with a hand-set stockpile; no map,
## no Kith and no GameState. The last tests check GameState's pass-throughs and the effects it runs when
## Research reports a tech completed. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const GameState = preload("res://scripts/game_state.gd")
const Monitor = preload("res://tests/monitor.gd")
const Research = preload("res://scripts/research.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd
var _shard := false  # stands in for "the Strange Stone has been clicked"
var _eco: Economy
var _techs: Dictionary


func run(runner) -> void:
	t = runner
	test_requirements()
	test_requires_any()
	test_hidden_techs_follow_the_shard()
	test_can_research_needs_the_stock()
	test_research_pays_once()
	test_research_refuses_without_requirements()
	test_goal_queues_parents_first()
	test_queue_slot_limit()
	test_a_goal_that_is_done_is_dropped()
	test_set_goal_to_nothing_and_clear()
	test_goal_route_skips_hidden_techs()
	test_tick_researches_what_is_affordable()
	test_tick_goes_step_by_step()
	test_ready_list_is_in_tree_order()
	test_tech_researched_signal()
	test_tick_signals_each_tech_in_order()
	test_research_stands_alone()
	test_to_dict_and_from_dict()
	test_game_state_passes_through()
	test_game_state_runs_the_effects()
	test_game_state_queue_ticks()


func _shard_seen() -> bool:
	return _shard


## A Research block on an Economy that holds exactly `stock` (every other count zero) and a hand-set
## researched set. The Economy is left in _eco and the set in _techs for a test to look at.
func _block(stock: Dictionary = {}, done: Array = []) -> Research:
	_shard = false
	_techs = {}
	for id in done:
		_techs[id] = true
	_eco = Economy.new(_techs)
	for id in _eco.inv:
		_eco.inv[id] = 0
	for id in stock:
		_eco.inv[id] = stock[id]
	return Research.new(_eco, _techs, _shard_seen)


func test_tech_researched_signal() -> void:
	var r := _block({"fiber": 20})
	var m := Monitor.new()
	m.watch(r, "tech_researched")
	t.check(not r.research("gatherers_hut") and m.count() == 0, "a refused research signals nothing")
	t.check(r.research("cordage"), "research Cordage")
	t.check(m.args_of("tech_researched") == [["cordage"]], "tech_researched(id) fires once, with the id")
	t.check(_techs.has("cordage"), "after the tech is in the set")
	t.check(not r.research("cordage") and m.count() == 1, "a repeat signals nothing")
	r.unlocked("cordage")
	r.can_research("knapping")
	t.check(m.count() == 1, "queries never signal")


func test_tick_signals_each_tech_in_order() -> void:
	var r := _block({"fiber": 15, "wood": 99, "stone": 99, "flint": 99})
	var m := Monitor.new()
	m.watch(r, "tech_researched")
	r.set_goal("gatherers_hut")
	var route := r.queue.duplicate()
	var done := r.tick()
	t.check(done.size() > 0, "the tick researched something")
	t.check(
		m.args_of("tech_researched") == done.map(func(id): return [id]), "one signal per tech, in the order returned"
	)
	t.check(route.slice(0, done.size()) == done, "in queue order")


func test_requirements() -> void:
	var r := _block()
	t.check(r.missing_requirements("cordage") == 0, "a root tech misses nothing")
	t.check(r.requirements_met("cordage"), "so its requirements are met")
	t.check(r.missing_requirements("gatherers_hut") == 2, "Gatherer's Hut needs two techs")
	t.check(not r.requirements_met("gatherers_hut"), "so it isn't met yet")
	_techs["knapping"] = true
	t.check(r.missing_requirements("gatherers_hut") == 1, "one down, one to go: the set is read live")
	_techs["foraging"] = true
	t.check(r.missing_requirements("gatherers_hut") == 0 and r.requirements_met("gatherers_hut"), "both done")
	t.check(r.missing_requirements("bronze_dawn") == 5, "Bronze Dawn is five techs away")
	t.check(r.unlocked("knapping") and not r.unlocked("cordage"), "unlocked is true for researched techs only")


func test_requires_any() -> void:
	var r := _block({}, ["masonry"])
	t.check(r.missing_requirements("megaliths") == 1, "an open either-or counts as one")
	t.check(not r.requirements_met("megaliths"), "and blocks the tech")
	_techs["storytelling"] = true
	t.check(r.missing_requirements("megaliths") == 0 and r.requirements_met("megaliths"), "either branch will do")
	var r2 := _block({}, ["masonry", "star_lore"])
	t.check(r2.missing_requirements("megaliths") == 0, "the other branch works too")
	var r3 := _block({}, ["storytelling", "star_lore"])
	t.check(r3.missing_requirements("megaliths") == 1, "the either-or doesn't stand in for a plain requirement")
	t.check(r3.missing_requirements("calendar") == 1, "Calendar is short Farming only: its either-or is met")
	var r4 := _block({}, ["farming"])
	t.check(r4.missing_requirements("calendar") == 1, "Calendar's either-or is still open with Farming alone")


func test_hidden_techs_follow_the_shard() -> void:
	var r := _block({"stone": 20, "flint": 10}, ["storytelling"])
	t.check(Data.TECHS["star_lore"].get("hidden", false), "Star Lore is a hidden tech")
	t.check(not r.tech_visible("star_lore"), "hidden until the shard is seen")
	t.check(r.tech_visible("megaliths") and r.tech_visible("cordage"), "the rest are always visible")
	t.check(not r.requirements_met("star_lore"), "hidden means requirements aren't met")
	t.check(not r.can_research("star_lore"), "even with its parent done and the cost in hand")
	t.check(not r.research("star_lore") and not _techs.has("star_lore"), "and research refuses it")
	t.check(_eco.inv["stone"] == 20 and _eco.inv["flint"] == 10, "taking nothing")
	_shard = true
	t.check(r.tech_visible("star_lore"), "visible once the shard is seen")
	t.check(r.requirements_met("star_lore") and r.can_research("star_lore"), "and it can be researched")
	_shard = false
	t.check(not r.tech_visible("star_lore"), "the flag is read each time, not copied")


func test_can_research_needs_the_stock() -> void:
	var r := _block({"fiber": 14})
	t.check(not r.can_research("cordage"), "one short of the cost")
	_eco.inv["fiber"] = 15
	t.check(r.can_research("cordage"), "exactly the cost is enough")
	var r2 := _block({"fiber": 15}, ["cordage"])
	t.check(not r2.can_research("cordage"), "a researched tech can't be researched again")
	var r3 := _block({"berries": 5, "fiber": 10})
	t.check(r3.can_research("foraging"), "a two-item cost, both covered")
	_eco.inv["berries"] = 4
	t.check(not r3.can_research("foraging"), "one item short is short")


func test_research_pays_once() -> void:
	var r := _block({"fiber": 20, "wood": 7})
	t.check(r.research("cordage"), "research reports the tech completed")
	t.check(_techs.has("cordage"), "it is in the researched set")
	t.check(_eco.inv["fiber"] == 5, "exactly the cost was paid: 20 - 15")
	t.check(_eco.inv["wood"] == 7, "and nothing else")
	_eco.inv["fiber"] = 30
	t.check(not r.research("cordage"), "a repeat is refused")
	t.check(_eco.inv["fiber"] == 30, "and costs nothing")
	t.check(_techs.size() == 1, "the set is unchanged")


func test_research_refuses_without_requirements() -> void:
	var r := _block({"wood": 99, "stone": 99})
	t.check(not r.research("gatherers_hut"), "its parents aren't researched")
	t.check(_eco.inv["wood"] == 99 and _eco.inv["stone"] == 99 and _techs.is_empty(), "nothing paid or marked")
	var r2 := _block({"wood": 5})
	t.check(not r2.research("fire"), "an unaffordable root is refused")
	t.check(_eco.inv["wood"] == 5 and _techs.is_empty(), "leaving the stock alone")


func test_goal_queues_parents_first() -> void:
	var r := _block()
	r.set_goal("gatherers_hut")
	t.check(r.goal == "gatherers_hut", "the goal is set")
	t.check(r.queue.size() == 3, "the two parents and the goal are queued")
	t.check(r.queue[-1] == "gatherers_hut", "the goal comes last")
	t.check("knapping" in r.queue and "foraging" in r.queue, "behind both of its parents")
	_techs["knapping"] = true
	r.refill()
	t.check(r.queue == ["foraging", "gatherers_hut"], "refill drops what is done")
	_techs["foraging"] = true
	r.refill()
	t.check(r.queue == ["gatherers_hut"] and r.goal == "gatherers_hut", "then only the goal is left")


func test_queue_slot_limit() -> void:
	var r := _block()
	r.set_goal("bronze_dawn")
	t.check(r.queue.size() == Data.QUEUE_SLOTS, "a long route fills exactly the slots")
	t.check("bronze_dawn" not in r.queue, "the goal waits until its parents are queued")
	var seen := {}
	var parents_first := true
	for tech in r.queue:
		for need in Data.TECHS[tech]["requires"]:
			if not seen.has(need) and need in r.queue:
				parents_first = false
		seen[tech] = true
	t.check(parents_first, "every queued tech comes after its queued parents")


func test_a_goal_that_is_done_is_dropped() -> void:
	var r := _block({}, ["cordage"])
	r.set_goal("cordage")
	t.check(r.goal == "" and r.queue.is_empty(), "a goal already researched is dropped at once")
	var r2 := _block()
	r2.set_goal("fire")
	t.check(r2.goal == "fire" and r2.queue == ["fire"], "a root goal queues just itself")
	_techs["fire"] = true
	r2.refill()
	t.check(r2.goal == "" and r2.queue.is_empty(), "the goal is dropped once reached")


func test_set_goal_to_nothing_and_clear() -> void:
	var r := _block()
	r.set_goal("pottery")
	t.check(not r.queue.is_empty(), "a queue to start")
	r.set_goal("")
	t.check(r.goal == "" and r.queue.is_empty(), "an empty goal empties the queue")
	r.set_goal("pottery")
	r.clear()
	t.check(r.goal == "" and r.queue.is_empty(), "clear drops the goal and the queue")
	t.check(r.tick().is_empty(), "and there is nothing to research")


func test_goal_route_skips_hidden_techs() -> void:
	var r := _block({}, ["masonry"])
	r.set_goal("megaliths")
	t.check(r.queue == ["storytelling", "megaliths"], "the either-or takes the visible branch")
	t.check("star_lore" not in r.queue, "never a hidden tech")


func test_tick_researches_what_is_affordable() -> void:
	var r := _block({"flint": 5, "stone": 10, "berries": 5, "fiber": 10, "wood": 20})
	_eco.inv["stone"] = 20
	r.set_goal("gatherers_hut")
	var done := r.tick()
	t.check(done == ["knapping", "foraging", "gatherers_hut"], "the whole chain went in one tick, parents first")
	t.check(r.goal == "" and r.queue.is_empty(), "the goal is dropped once it is reached")
	t.check(_techs.has("gatherers_hut"), "and it is researched")
	t.check(_eco.inv["flint"] == 0 and _eco.inv["stone"] == 0 and _eco.inv["wood"] == 0, "every cost paid exactly once")
	t.check(_eco.inv["berries"] == 0 and _eco.inv["fiber"] == 0, "the rest too")
	t.check(r.tick().is_empty(), "a further tick does nothing")


func test_tick_goes_step_by_step() -> void:
	var r := _block({"flint": 5, "stone": 10})
	r.set_goal("gatherers_hut")
	t.check(r.tick() == ["knapping"], "only what is affordable is researched")
	t.check(r.queue == ["foraging", "gatherers_hut"], "and the queue is refilled behind it")
	t.check(r.goal == "gatherers_hut", "the goal stays")
	t.check(r.tick().is_empty() and r.queue == ["foraging", "gatherers_hut"], "nothing new, nothing changes")
	_eco.inv["berries"] = 5
	_eco.inv["fiber"] = 10
	t.check(r.tick() == ["foraging"], "Foraging as soon as it is affordable")
	t.check(r.queue == ["gatherers_hut"], "the goal is next")
	_eco.inv["wood"] = 19
	_eco.inv["stone"] = 10
	t.check(r.tick().is_empty(), "one wood short")
	_eco.inv["wood"] = 20
	t.check(r.tick() == ["gatherers_hut"] and r.goal == "", "then the goal, and the goal is dropped")


func test_ready_list_is_in_tree_order() -> void:
	var r := _block()
	t.check(r.ready_list().is_empty(), "nothing is ready with an empty stockpile")
	_eco.inv["fiber"] = 25
	_eco.inv["berries"] = 5
	_eco.inv["wood"] = 10
	_eco.inv["stone"] = 5
	var ready := r.ready_list()
	t.check("foraging" in ready and "cordage" in ready and "fire" in ready, "the affordable roots are ready")
	t.check("knapping" not in ready and "gatherers_hut" not in ready, "the rest aren't")
	var last := -1
	var in_order := true
	for tech in ready:
		var at := Data.TECH_ORDER.find(tech)
		if at < last:
			in_order = false
		last = at
	t.check(in_order, "in tree order")
	r.research("cordage")
	t.check("cordage" not in r.ready_list(), "a researched tech drops out")


## The researched techs (in order), the goal and the queue survive a dict and a JSON round trip, and the set
## the Economy shares is refilled in place.
func test_to_dict_and_from_dict() -> void:
	var a := _block({"fiber": 50, "berries": 50})
	t.check(a.research("foraging") and a.research("cordage"), "set up: two techs researched")
	a.set_goal("gatherers_hut")
	t.check(not a.queue.is_empty(), "and a goal with a queue")
	var d := a.to_dict()
	t.check(d["researched"] == ["foraging", "cordage"], "the techs are written in the order they were researched")
	var b := _block()
	var shared := _techs
	b.from_dict(d)
	t.check(RunSave.to_json(b.to_dict()) == RunSave.to_json(d), "a Research restored from a dict writes the same dict")
	t.check(
		b.researched.keys() == ["foraging", "cordage"] and b.goal == a.goal and b.queue == a.queue,
		"same techs, goal and queue"
	)
	t.check(is_same(b.researched, shared) and shared.has("cordage"), "the shared researched set is refilled in place")
	var c := _block()
	c.from_dict(RunSave.from_json(RunSave.to_json(d)))
	t.check(RunSave.to_json(c.to_dict()) == RunSave.to_json(d), "the same after a trip through JSON text")
	var m := Monitor.new()
	m.watch(c, "tech_researched")
	c.from_dict(d)
	t.check(m.count() == 0, "restoring announces nothing")
	c.from_dict({})
	t.check(_techs.is_empty() and c.goal == "" and c.queue.is_empty(), "an empty dict clears it")


func test_research_stands_alone() -> void:
	var a := _block({"fiber": 15})
	var techs_a := _techs
	var b := _block({"fiber": 15})
	a.research("cordage")
	t.check(techs_a.has("cordage") and not _techs.has("cordage"), "two blocks don't share a researched set")
	t.check(a.researched == techs_a, "the block's set is the one handed in")
	a.set_goal("fire")
	t.check(b.goal == "" and b.queue.is_empty(), "or a queue")
	var e := Economy.new(techs_a)
	techs_a["baking"] = true
	t.check(e.food_value("flour") == Data.BAKED_FLOUR_FOOD, "an Economy sees the block's set through its view")


func test_game_state_passes_through() -> void:
	var s: GameState = t.fresh()
	t.check(s.researched == s.tech_tree.researched and s.research_queue == s.tech_tree.queue, "the set and queue")
	s.researched["knapping"] = true
	t.check(s.tech_tree.researched.has("knapping"), "a write to GameState.researched lands in the block")
	t.check(
		s.economy.food_value("berries") == 1.0 and not s.researched.has("smoking"), "and the Economy's view is shared"
	)
	s.researched["smoking"] = true
	t.check(s.economy.food_value("berries") == Data.SMOKED_BERRY_FOOD, "so it sees techs set on GameState")
	s.tech_tree.set_goal("gatherers_hut")
	t.check(
		s.research_goal == "gatherers_hut" and s.research_queue == ["foraging", "gatherers_hut"], "goal and queue read"
	)
	t.check(s.missing_requirements("gatherers_hut") == 1 and not s.requirements_met("gatherers_hut"), "requirements")
	t.check(not s.tech_visible("star_lore"), "hidden until the shard is seen")
	s.shard_seen = true
	t.check(s.tech_visible("star_lore"), "GameState.shard_seen is what the block reads")
	t.check(not s.can_research("cordage"), "cordage is unaffordable with nothing in the stockpile")
	s.inv["fiber"] = 15
	t.check(s.can_research("cordage"), "and affordable with the fiber")
	t.check(s.research("cordage") and s.inv["fiber"] == 0, "GameState.research pays through the Economy")
	t.check(not s.research("cordage"), "a repeat is refused")
	t.check(s.researched.has("cordage") and s.tech_tree.researched.has("cordage"), "in the block's set")


func test_game_state_runs_the_effects() -> void:
	var s: GameState = t.fresh()
	t.give(s, 999)
	t.check(s.research("cordage"), "research Cordage")
	t.check("Discovered Cordage" in s.events, "completing a tech announces it")
	t.check(not s.won and s.story_events.is_empty(), "with no other effect")
	for tech in ["knapping", "foraging", "gatherers_hut"]:
		t.check(s.research(tech), "research " + tech)
	var hut: Vector2i = s.camp_pos + Vector2i(0, 2)
	t.check(s.place("gatherers_hut", hut), "a hut to test the Haulers effect on")
	s.buildings[s.building_at[hut]]["trips"] = 3
	t.check(s.research("haulers"), "research Paths & Haulers")
	t.check(s.buildings[s.building_at[hut]]["trips"] == 0, "Haulers resets the queued trips")
	t.check("haulers" in s.story_events, "and records the story event")
	t.check(s.has_haulers(), "and has_haulers reads the block's set")
	for tech in Data.TECHS["bronze_dawn"]["requires"]:
		s.researched[tech] = true
	t.check(s.research("bronze_dawn"), "research Bronze Dawn")
	t.check(s.won and "bronze_dawn" in s.story_events, "it wins the game and records the story")
	t.check("Discovered %s" % Data.TECHS["bronze_dawn"]["name"] in s.events, "and announces it")


func test_game_state_queue_ticks() -> void:
	var s: GameState = t.fresh()
	s.tech_tree.set_goal("cordage")
	s.tick(0.1)
	t.check(not s.researched.has("cordage"), "a tick with an empty stockpile researches nothing")
	s.inv["fiber"] = 15
	s.tick(0.1)
	t.check(s.researched.has("cordage"), "the queue researches a tech once it is affordable")
	t.check("Discovered Cordage" in s.events, "with the same announcement")
	t.check(s.research_goal == "" and s.research_queue.is_empty(), "and the goal is dropped once reached")
