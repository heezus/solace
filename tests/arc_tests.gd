extends RefCounted
## Tests for From Hands to Haulers (design-system/14-hands-to-haulers.md): teach by doing, hut trips,
## looping after Paths & Haulers, rushing, click yield, ranks, tier costs and story events.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/rules.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Workers = preload("res://scripts/workers.gd")
const Hands = preload("res://scripts/hands.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_learning_at_ten_clicks()
	test_huts_gather_only_what_is_learned()
	test_dispatch_trips_and_queue_cap()
	test_no_loop_before_haulers_loop_after()
	test_rush_and_its_cooldown()
	test_click_yield_math()
	test_hold_to_harvest()
	test_rank_costs_and_effects()
	# test_tier_costs_scale()
	test_story_events()
	test_job_titles()


## A camp with a hut next to the forest west of the Hearth, the whole map in sight and food to spare.
func hut_camp() -> Array:
	var s: GameState = t.fresh()
	s.inv["berries"] = 200
	var p: Vector2i = s.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	return [s, s.building_at[p]]


func run_for(s: GameState, seconds: float) -> void:
	for i in int(seconds / 0.1):
		s.tick(0.1)


func test_learning_at_ten_clicks() -> void:
	var s: GameState = t.fresh()
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_CLICKS - 1:
		s.gather_by_hand(tree)
	t.check(not s.knows("wood"), "9 clicks: nobody has learned Wood yet")
	t.check(s.hand_counts["wood"] == Data.LEARN_CLICKS - 1, "hand clicks are counted per resource")
	s.events.clear()
	s.gather_by_hand(tree)
	t.check(s.knows("wood"), "the 10th click teaches a Kith to gather Wood")
	var first: String = Data.PEOPLE_NAMES[0]
	t.check(s.learned["wood"] == first, "the first learner is " + first)
	var toast := "%s learned woodcutting. %s the Woodcutter" % [first, first]
	t.check(s.events.has(toast), "and the toast says so: %s" % [s.events])
	s.events.clear()
	s.gather_by_hand(tree)
	t.check(s.events.is_empty(), "no second lesson for Wood")
	var rock: Vector2i = t.find_tile(s, "rock")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(rock)
	t.check(s.learned["stone"] == Data.PEOPLE_NAMES[1], "each resource is learned on its own, by the next Kith")
	t.check(not s.knows("flint"), "Flint is still unknown")


func test_huts_gather_only_what_is_learned() -> void:
	var r := hut_camp()
	var s: GameState = r[0]
	var b: Dictionary = s.buildings[r[1]]
	t.check(not Workers.knows_any(s, b["pos"]), "a new camp knows no jobs")
	t.check(Workers.dispatch(s, r[1]).begins_with("Nothing learned"), "so a hut can't send a trip yet")
	t.check(b["trips"] == 0, "and nothing is queued")
	var preview := BuildingPanel.gather_text(s, s.gather_tiles(b["pos"]))
	t.check(preview.contains("not yet learned (gather by hand 10x)"), "the preview says what isn't learned: " + preview)
	s.learned["wood"] = "Aro"
	preview = BuildingPanel.gather_text(s, s.gather_tiles(b["pos"]))
	t.check(preview.contains("Wood x") and not preview.contains("Wood x1 (not"), "Wood is learned: " + preview)
	t.check(Workers.knows_any(s, b["pos"]), "the hut knows Wood now")
	var k: Dictionary = s.kith[b["worker"]]
	for i in 12:
		var tile := Workers.next_gather_tile(s, k, b)
		t.check(s.tile_at(tile) == "tree", "the worker only walks to trees (%s)" % s.tile_at(tile))


func test_dispatch_trips_and_queue_cap() -> void:
	var r := hut_camp()
	var s: GameState = r[0]
	var i: int = r[1]
	var b: Dictionary = s.buildings[i]
	s.learned["wood"] = "Aro"
	run_for(s, 3.0)
	t.check(b["status"].begins_with("Waiting: click"), "a hut waits for a click: " + b["status"])
	var wood: int = s.inv["wood"]
	for n in Data.TRIP_QUEUE:
		t.check(Workers.click(s, i) == "Trip %d/%d" % [n + 1, Data.TRIP_QUEUE], "click %d queues a trip" % (n + 1))
	t.check(Workers.click(s, i).begins_with("Trips full"), "the queue holds %d trips" % Data.TRIP_QUEUE)
	t.check(b["trips"] == Data.TRIP_QUEUE, "no more than that")
	run_for(s, 1.0)
	t.check(s.kith[b["worker"]]["trip"], "the worker is out on a trip")
	t.check("first_trip" in s.story_events, "the first trip is a story moment")
	run_for(s, 90.0)
	t.check(b["trips"] == 0, "all three trips done")
	var bundle: int = Data.BUNDLE * s.harvest_yield("wood")
	t.check(bundle == 3, "a bundle is 3 harvests")
	t.check(s.inv["wood"] == wood + bundle * Data.TRIP_QUEUE, "each trip brings a bundle to the stockpile")
	t.check(s.buffered(b["out"]) == 0, "straight to the stockpile, not the hut")
	run_for(s, 20.0)
	t.check(s.inv["wood"] == wood + bundle * Data.TRIP_QUEUE, "then the hut waits for the next click")


func test_no_loop_before_haulers_loop_after() -> void:
	var r := hut_camp()
	var s: GameState = r[0]
	var b: Dictionary = s.buildings[r[1]]
	s.learned["wood"] = "Aro"
	var wood: int = s.inv["wood"]
	run_for(s, 60.0)
	t.check(s.inv["wood"] == wood and s.buffered(b["out"]) == 0, "before Paths & Haulers a hut doesn't loop")
	s.researched["haulers"] = true
	run_for(s, 60.0)
	t.check(s.inv["wood"] + s.buffered(b["out"]) > wood, "after it, the hut gathers on its own")
	t.check(s.inv["wood"] > wood, "and haulers carry the Wood to the stockpile")


func test_rush_and_its_cooldown() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 200
	s.inv["wood"] = 50
	var p: Vector2i = s.camp_pos + Vector2i(2, 0)
	t.place_free(s, "charcoal_pit", p)
	var i: int = s.building_at[p]
	var b: Dictionary = s.buildings[i]
	s.haul(i)  # load it by hand
	run_for(s, 3.0)
	t.check(b["status"] == "Working", "the pit is working: " + b["status"])
	t.check(Workers.can_rush(s, b), "a working building can be rushed")
	var before := s.buffered(b["out"])
	t.check(Workers.rush(s, i), "rush it")
	t.check(s.buffered(b["out"]) == before + 1, "the rush finished the cycle at once")
	t.check(is_equal_approx(b["rush_cd"], Data.RUSH_COOLDOWN), "then a %d s cooldown" % Data.RUSH_COOLDOWN)
	run_for(s, 1.0)
	t.check(not Workers.rush(s, i), "no second rush during the cooldown")
	t.check(Workers.click(s, i).begins_with("Rush in"), "a click says when it's ready")
	run_for(s, Data.RUSH_COOLDOWN)
	t.check(b["rush_cd"] == 0.0 and Workers.can_rush(s, b), "ready again after the cooldown")

	# After Paths & Haulers, clicking a hut rushes its trip home.
	var r := hut_camp()
	var s2: GameState = r[0]
	var hut: Dictionary = s2.buildings[r[1]]
	s2.learned["wood"] = "Aro"
	s2.researched["haulers"] = true
	run_for(s2, 1.5)
	var k: Dictionary = s2.kith[hut["worker"]]
	t.check(k["phase"] in ["to_tile", "harvest"], "the hut worker is out: " + k["phase"])
	var held := s2.buffered(hut["out"])
	t.check(Workers.click(s2, r[1]) == "Rushed!", "a click rushes a working hut")
	t.check(s2.buffered(hut["out"]) == held + s2._bundle_size(hut, "wood"), "the bundle is home at once")
	t.check(k["phase"] == "home", "and the worker with it")
	t.check(not Workers.can_rush(s2, hut), "on cooldown")


func test_click_yield_math() -> void:
	var s: GameState = t.fresh()
	t.check(s.harvest_yield("wood") == 1, "base: 1 a harvest")
	t.check(is_equal_approx(Hands.hold_time(s, "wood"), 1.0), "held for 1 s")
	s.hand_tools = true
	t.check(s.harvest_yield("stone") == 1, "Flint Tools don't raise the yield")
	t.check(is_equal_approx(Hands.hold_time(s, "stone"), 0.7), "they shorten the hold to 0.7 s")
	s.researched["stone_axe"] = true
	t.check(s.harvest_yield("wood") == 3, "Stone Axe: x3 for Wood")
	t.check(s.harvest_yield("stone") == 1, "the Stone Axe is for Wood only")
	s.researched["masonry"] = true
	s.ranks["masonry"] = 2
	t.check(s.harvest_yield("stone") == 2, "Masonry II: base 2")
	s.ranks["masonry"] = 3
	t.check(s.harvest_yield("stone") == 3, "Masonry III: base 3")
	s.ranks["stone_axe"] = 3
	t.check(s.harvest_yield("wood") == 9, "Stone Axe III: base 3 x axe 3 = 9 Wood")
	s.researched["foraging"] = true
	t.check(s.harvest_yield("berries") == 2, "Foraging still doubles Berries")
	t.check(Data.HAND_TOOLS["bronze_tools"]["hold"] == 0.4, "the Bronze Tools slot: a 0.4 s hold")
	var tree: Vector2i = t.find_tile(s, "tree")
	var wood: int = s.inv["wood"]
	s.gather_by_hand(tree)
	t.check(s.inv["wood"] == wood + 9, "a harvest gives exactly the harvest yield")


func test_hold_to_harvest() -> void:
	var s: GameState = t.fresh()
	var tree: Vector2i = t.find_tile(s, "tree")
	var rock: Vector2i = t.find_tile(s, "rock")
	t.check(s.hold_harvest(tree, 0.5) == "", "half a second: nothing yet")
	t.check(is_equal_approx(s.harvest_frac, 0.5), "the ring is half full")
	t.check(s.hold_harvest(tree, 0.5) == "+1 Wood", "a full second: the harvest pops")
	t.check(s.inv["wood"] == 1 and is_equal_approx(s.harvest_frac, 0.0), "and the ring starts again")
	for i in 25:
		s.hold_harvest(tree, 0.1)
	t.check(s.inv["wood"] == 3, "holding keeps harvesting: 2 more in 2.5 s (%d)" % s.inv["wood"])
	s.hold_harvest(tree, 0.9)
	s.hold_harvest(rock, 0.2)
	t.check(s.inv["stone"] == 0 and is_equal_approx(s.harvest_frac, 0.2), "moving to another tile starts over")
	s.release_harvest()
	t.check(s.harvest_frac == 0.0 and s.harvest_tile == Vector2i(-1, -1), "letting go empties the ring")
	s.hold_harvest(rock, 0.9)
	s.release_harvest()
	s.hold_harvest(rock, 0.2)
	t.check(s.inv["stone"] == 0, "a released hold doesn't count toward the next")
	s.hand_tools = true
	t.check(s.hold_harvest(rock, 0.5) == "+1 Stone", "Flint Tools: 0.7 s a harvest")
	t.check(s.hold_harvest(s.camp_pos, 5.0) == "", "the Hearth isn't a resource")
	for i in Data.LEARN_CLICKS:
		s.hold_harvest(rock, 0.7)
	t.check(s.knows("stone"), "learning takes %d harvests" % Data.LEARN_CLICKS)


func test_rank_costs_and_effects() -> void:
	var ranked: Array = Data.TECHS.keys().filter(func(tech): return Ranks.has_ranks(tech))
	t.check(ranked.size() >= 6 and ranked.size() <= 10, "6 to 10 techs have ranks (%d)" % ranked.size())
	for tech in ranked:
		var r: Dictionary = Data.TECHS[tech]["rank"]
		t.check(r.has("item") != r.has("building"), tech + ": a rank is for a resource or a workshop")
		if r.has("item"):
			t.check(Data.ITEMS.has(r["item"]), tech + " ranks a real resource")
		else:
			t.check(Data.BONUSES.has("rank_" + r["building"]), tech + " ranks have a Speed bonus")
		var c1: Dictionary = Data.TECHS[tech]["cost"]
		var c2 := Ranks.cost(tech, 2)
		var c3 := Ranks.cost(tech, 3)
		for id in c1:
			t.check(c2[id] == roundi(c1[id] * 2.5), "%s II costs 2.5x rank I in %s" % [tech, id])
			t.check(c3[id] == roundi(c1[id] * 6.25), "%s III costs 2.5x rank II in %s" % [tech, id])
	var s: GameState = t.fresh()
	t.give(s, 9999)
	t.check(Ranks.rank(s, "cordage") == 0 and Ranks.next_cost(s, "cordage").is_empty(), "no ranks before the tech")
	s.research("cordage")
	t.check(Ranks.rank(s, "cordage") == 1, "the tech is rank I")
	var rope: int = s.inv["fiber"]
	t.check(Ranks.buy(s, "cordage"), "buy rank II")
	t.check(s.inv["fiber"] == rope - Ranks.cost("cordage", 2)["fiber"], "rank II is paid for")
	t.check(Ranks.buy(s, "cordage") and Ranks.rank(s, "cordage") == 3, "buy rank III")
	t.check(not Ranks.buy(s, "cordage"), "III is the last rank")
	t.check(not Ranks.buy(s, "haulers"), "techs without ranks have none")
	var p: Vector2i = s.camp_pos + Vector2i(2, 0)
	t.place_free(s, "twine_post", p)
	var post: Dictionary = s.buildings[s.building_at[p]]
	t.check(is_equal_approx(Bonuses.speed(s, post), 1.5), "Cordage III: +25% per rank beyond I at the Twine Post")
	t.check(Bonuses.text(s, post).contains("Cordage III +50%"), "named in the speed math: " + Bonuses.text(s, post))
	var q: Vector2i = s.camp_pos + Vector2i(-2, 2)
	t.place_free(s, "charcoal_pit", q)
	t.check(is_equal_approx(Bonuses.speed(s, s.buildings[s.building_at[q]]), 1.0), "and nowhere else")
	# Ranks are never on the way to Bronze Dawn.
	var route := Rules.route_to("bronze_dawn", {}, Rules.visible_techs(true))
	var s2: GameState = t.fresh()
	t.give(s2, 99999)
	for tech in route:
		s2.research(tech)
	t.check(s2.won and s2.ranks.is_empty(), "Bronze Dawn is won without buying a single rank")


## Tech costs grow by tier (14-hands-to-haulers.md), and each tier pays in goods earlier tiers teach.
func test_tier_costs_scale() -> void:
	var bands := [[10, 20], [25, 60], [80, 150], [200, 400], [200, 400], [500, 700]]
	var made_by := {"rope": "cordage", "charcoal": "fire", "brick": "pottery", "flour": "grindstone"}
	var avg: Array = []
	for tier in bands.size():
		var sum := 0.0
		var n := 0
		for tech in Data.TECHS:
			var tt: Dictionary = Data.TECHS[tech]
			if tt["tier"] != tier:
				continue
			var total := 0
			for id in tt["cost"]:
				total += tt["cost"][id]
				if made_by.has(id):
					var maker: String = made_by[id]
					t.check(Data.TECHS[maker]["tier"] < tier, "%s pays in %s, made from an earlier tier" % [tech, id])
			var band: Array = bands[tier]
			t.check(total >= band[0] and total <= band[1], "%s costs %d, in tier band %s" % [tech, total, band])
			sum += total
			n += 1
		avg.append(sum / n)
	for tier in range(1, avg.size()):
		t.check(avg[tier] >= avg[tier - 1], "tier %d costs at least tier %d on average" % [tier + 1, tier])


func test_story_events() -> void:
	var s: GameState = t.fresh()
	t.check(s.story_events.is_empty(), "no story yet")
	s.gather_by_hand(s.shard_pos)
	s.gather_by_hand(s.shard_pos)
	t.check(s.story_events == ["shard_found"], "the Strange Stone is recorded once, by id")
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(tree)
	t.check("first_lesson" in s.story_events, "the first lesson is recorded")
	t.give(s, 99999)
	for tech in Rules.route_to("bronze_dawn", s.researched, Rules.visible_techs(true)):
		s.research(tech)
	t.check("haulers" in s.story_events and "bronze_dawn" in s.story_events, "Haulers and Bronze Dawn too")
	for id in s.story_events:
		t.check(Data.STORY_EVENTS.has(id), id + " is a stable id listed in Data.STORY_EVENTS")
		t.check(id == id.to_lower() and not id.contains(" "), id + " is snake_case")


## Job titles are labels from data (07-glossary.md): each worker building resolves to one.
func test_job_titles() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 200
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["kind"] in ["processor", "gatherer"]:
			var b := {"type": type, "gather_items": []}
			var job := Workers.building_job(s, b)
			t.check(job != "" and job != Data.JOB_IDLE, "%s's worker has a job title (%s)" % [type, job])
	for tile in Data.TILES:
		var item: String = Data.TILES[tile]["yields"]
		if item != "":
			t.check(Data.HUT_JOBS.has(item), "a hut gathering %s has a job title" % item)
			var b := {"type": "gatherers_hut", "gather_items": [item, item, "fiber"]}
			t.check(
				Workers.building_job(s, b) == Data.HUT_JOBS[item]["title"],
				"a hut takes the title of what it gathers most"
			)
	var mixed := {"type": "gatherers_hut", "gather_items": ["stone", "stone", "wood"]}
	s.learned["wood"] = "Aro"
	t.check(Workers.building_job(s, mixed) == "Woodcutter", "counting only what the Kith know, once they know some")
	var names := {}
	for k in s.kith:
		names[k["name"]] = true
		t.check(Workers.job_of(s, k) == Data.JOB_IDLE, "a new Kith is Idle")
	t.check(names.size() == s.kith.size(), "every Kith has their own name: %s" % [names.keys()])
	var p: Vector2i = t.find_grass(s, false)
	s.inv["clay"] = 20
	t.check(t.place_free(s, "kiln", p), "place a kiln")
	s.researched["haulers"] = true
	s.tick(0.1)
	var kiln: Dictionary = s.buildings[s.building_at[p]]
	t.check(Workers.title_of(s, s.kith[kiln["worker"]]).ends_with(" the Potter"), "the Kiln's worker is its Potter")
	var counts := Workers.job_counts(s)
	t.check(counts.contains("1 Potter") and counts.contains("Haulers"), "the top bar counts jobs: " + counts)
	for i in Data.PEOPLE_NAMES.size() + 1:
		s._add_kith()
	t.check(s.kith[-1]["name"].ends_with(" II"), "names come round again with II: " + s.kith[-1]["name"])
