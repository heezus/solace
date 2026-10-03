extends RefCounted
## Tests for From Hands to Haulers (design-system/14-hands-to-haulers.md): teach by doing, hut trips,
## looping after Paths & Haulers, rushing, click yield, ranks, tier costs and story events.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Workers = preload("res://scripts/workers.gd")
const Hands = preload("res://scripts/hands.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const Roads = preload("res://scripts/roads.gd")
const World = preload("res://scripts/world.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_learning_after_a_few_clicks()
	test_huts_gather_only_what_is_learned()
	test_dispatch_trips_and_queue_cap()
	test_no_loop_before_haulers_loop_after()
	test_rush_and_its_cooldown()
	test_click_yield_math()
	test_hold_to_harvest()
	test_rank_costs_and_effects()
	test_tier_costs_scale()
	test_story_events()
	test_job_titles()
	test_fiber_comes_from_flax()
	test_flax_near_every_hearth()
	test_haulers_need_roads()
	test_haulers_walk_roads_only()


## A camp with a hut next to the forest west of the Hearth, the whole map in sight and food to spare.
func hut_camp() -> Array:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 200
	var p: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	return [s, s.town.building_at[p]]


func run_for(s: Sim, seconds: float) -> void:
	for i in int(seconds / 0.1):
		s.tick(0.1)


func test_learning_after_a_few_clicks() -> void:
	var s: Sim = t.fresh()
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_FIRST - 1:
		s.gather_by_hand(tree)
	t.check(not s.people.knows("wood"), "one click short: nobody has learned Wood yet")
	t.check(s.hand_counts["wood"] == Data.LEARN_FIRST - 1, "hand clicks are counted per resource")
	s.events.clear()
	s.gather_by_hand(tree)
	t.check(s.people.knows("wood"), "click %d (the first lesson) teaches a Kith to gather Wood" % Data.LEARN_FIRST)
	var first: String = Data.PEOPLE_NAMES[0]
	t.check(s.people.learned_by["wood"] == first, "the first learner is " + first)
	var toast: String = Data.LEARNED_LINE % [first, Data.HUT_JOBS["wood"]["craft"], "Woodcutter"]
	t.check(s.events.has(toast), "and the toast says so: %s" % [s.events])
	s.events.clear()
	s.gather_by_hand(tree)
	t.check(s.events.is_empty(), "no second lesson for Wood")
	var rock: Vector2i = t.find_tile(s, "rock")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(rock)
	t.check(
		s.people.learned_by["stone"] == Data.PEOPLE_NAMES[1], "each resource is learned on its own, by the next Kith"
	)
	t.check(not s.people.knows("flint"), "Flint is still unknown")


func test_huts_gather_only_what_is_learned() -> void:
	var r := hut_camp()
	var s: Sim = r[0]
	var b: Dictionary = s.town.buildings[r[1]]
	t.check(not s.people.knows_any(b["pos"]), "a new camp knows no jobs")
	t.check(Workers.dispatch(s, r[1]).begins_with("Nothing learned"), "so a hut can't send a trip yet")
	t.check(b["trips"] == 0, "and nothing is queued")
	var preview := BuildingPanel.gather_text(s, s.town.focus_tiles(b))
	t.check(
		preview.contains("not yet learned (gather by hand %dx)" % Data.LEARN_FIRST),
		"the preview says what isn't learned: " + preview
	)
	s.people.learned_by["wood"] = "Aro"
	preview = BuildingPanel.gather_text(s, s.town.focus_tiles(b))
	t.check(preview.contains("Wood x") and not preview.contains("Wood x1 (not"), "Wood is learned: " + preview)
	t.check(s.people.knows_any(b["pos"]), "the hut knows Wood now")
	var k: Dictionary = s.people.kith[b["worker"]]
	for i in 12:
		var tile := Workers.next_gather_tile(s, k, b)
		t.check(s.world.tile_at(tile) == "tree", "the worker only walks to trees (%s)" % s.world.tile_at(tile))


func test_dispatch_trips_and_queue_cap() -> void:
	var r := hut_camp()
	var s: Sim = r[0]
	var i: int = r[1]
	var b: Dictionary = s.town.buildings[i]
	s.people.learned_by["wood"] = "Aro"
	run_for(s, 3.0)
	t.check(b["status"].begins_with("Waiting: click"), "a hut waits for a click: " + b["status"])
	var wood: int = s.economy.inv["wood"]
	for n in Data.TRIP_QUEUE:
		t.check(Workers.click(s, i) == "Trip %d/%d" % [n + 1, Data.TRIP_QUEUE], "click %d queues a trip" % (n + 1))
	t.check(Workers.click(s, i).begins_with("Trips full"), "the queue holds %d trips" % Data.TRIP_QUEUE)
	t.check(b["trips"] == Data.TRIP_QUEUE, "no more than that")
	run_for(s, 1.0)
	t.check(s.people.kith[b["worker"]]["trip"], "the worker is out on a trip")
	t.check("first_trip" in s.story.events, "the first trip is a story moment")
	run_for(s, 90.0)
	t.check(b["trips"] == 0, "all three trips done")
	var bundle: int = Data.BUNDLE * Hands.harvest_yield(s, "wood")
	t.check(bundle == 3, "a bundle is 3 harvests")
	t.check(s.economy.inv["wood"] == wood + bundle * Data.TRIP_QUEUE, "each trip brings a bundle to the stockpile")
	t.check(Buildings.buffered(b["out"]) == 0, "straight to the stockpile, not the hut")
	run_for(s, 20.0)
	t.check(s.economy.inv["wood"] == wood + bundle * Data.TRIP_QUEUE, "then the hut waits for the next click")


func test_no_loop_before_haulers_loop_after() -> void:
	var r := hut_camp()
	var s: Sim = r[0]
	var b: Dictionary = s.town.buildings[r[1]]
	s.people.learned_by["wood"] = "Aro"
	var wood: int = s.economy.inv["wood"]
	run_for(s, 60.0)
	t.check(
		s.economy.inv["wood"] == wood and Buildings.buffered(b["out"]) == 0, "before Paths & Haulers a hut doesn't loop"
	)
	s.tech_tree.researched["haulers"] = true
	run_for(s, 30.0)
	t.check(
		s.economy.inv["wood"] == wood and Buildings.buffered(b["out"]) == 0, "researching it alone doesn't: no road yet"
	)
	t.check(b["alert"] == "Needs road", "the hut shows Needs road: " + b["alert"])
	t.road_link(s, b["pos"])
	run_for(s, 60.0)
	t.check(s.economy.inv["wood"] + Buildings.buffered(b["out"]) > wood, "after it, the hut gathers on its own")
	t.check(s.economy.inv["wood"] > wood, "and haulers carry the Wood to the stockpile")


func test_rush_and_its_cooldown() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 200
	s.economy.inv["wood"] = 50
	var p: Vector2i = s.world.camp_pos + Vector2i(2, 0)
	t.place_free(s, "charcoal_pit", p)
	var i: int = s.town.building_at[p]
	var b: Dictionary = s.town.buildings[i]
	s.town.haul(i)  # load it by hand
	run_for(s, 3.0)
	t.check(b["status"] == "Working", "the pit is working: " + b["status"])
	t.check(Workers.can_rush(s, b), "a working building can be rushed")
	var before := Buildings.buffered(b["out"])
	t.check(Workers.rush(s, i), "rush it")
	var batch: int = Data.BUILDINGS["charcoal_pit"]["out"]["charcoal"]
	t.check(Buildings.buffered(b["out"]) == before + batch, "the rush finished the cycle at once")
	t.check(is_equal_approx(b["rush_cd"], Data.RUSH_COOLDOWN), "then a %d s cooldown" % Data.RUSH_COOLDOWN)
	run_for(s, 1.0)
	t.check(not Workers.rush(s, i), "no second rush during the cooldown")
	t.check(Workers.click(s, i).begins_with("Rush in"), "a click says when it's ready")
	run_for(s, Data.RUSH_COOLDOWN)
	t.check(b["rush_cd"] == 0.0 and Workers.can_rush(s, b), "ready again after the cooldown")

	# After Paths & Haulers, clicking a hut rushes its trip home.
	var r := hut_camp()
	var s2: Sim = r[0]
	var hut: Dictionary = s2.town.buildings[r[1]]
	s2.people.learned_by["wood"] = "Aro"
	s2.tech_tree.researched["haulers"] = true
	t.road_link(s2, hut["pos"])
	run_for(s2, 1.5)
	var k: Dictionary = s2.people.kith[hut["worker"]]
	t.check(k["phase"] in ["to_tile", "harvest"], "the hut worker is out: " + k["phase"])
	var held := Buildings.buffered(hut["out"])
	t.check(Workers.click(s2, r[1]) == "Rushed!", "a click rushes a working hut")
	t.check(Buildings.buffered(hut["out"]) == held + Work.bundle_size(s2, hut, "wood"), "the bundle is home at once")
	t.check(k["phase"] == "home", "and the worker with it")
	t.check(not Workers.can_rush(s2, hut), "on cooldown")

	# A road felled the tree the worker was out at: a rush brings nothing, not an item with no name.
	run_for(s2, Data.RUSH_COOLDOWN + 1.5)
	for _wait in 100:  # how long a trip takes depends on where the nearest trees are: wait until the worker is out
		if k["phase"] in ["to_tile", "harvest"]:
			break
		run_for(s2, 0.1)
	if k["phase"] in ["to_tile", "harvest"]:
		var tile: Vector2i = k["task"].get("tile", hut["pos"])
		s2.world.set_tile(tile, "grass")
		t.check(Workers.rush(s2, r[1]), "rush a worker whose tree is gone")
		t.check(not s2.economy.inv.has("") and not hut["out"].has(""), "nothing with no name is stored")
	else:
		t.check(false, "the hut worker should be out again: " + k["phase"])


func test_click_yield_math() -> void:
	var s: Sim = t.fresh()
	t.check(Hands.harvest_yield(s, "wood") == 1, "base: 1 a harvest")
	t.check(is_equal_approx(Hands.hold_time(s, "wood"), 1.0), "held for 1 s")
	s.hand_tools = true
	t.check(Hands.harvest_yield(s, "stone") == 1, "Flint Tools don't raise the yield")
	t.check(is_equal_approx(Hands.hold_time(s, "stone"), 0.7), "they shorten the hold to 0.7 s")
	s.tech_tree.researched["stone_axe"] = true
	t.check(Hands.harvest_yield(s, "wood") == 3, "Stone Axe: x3 for Wood")
	t.check(Hands.harvest_yield(s, "stone") == 1, "the Stone Axe is for Wood only")
	s.tech_tree.researched["masonry"] = true
	s.ranks["masonry"] = 2
	t.check(Hands.harvest_yield(s, "stone") == 2, "Masonry II: base 2")
	s.ranks["masonry"] = 3
	t.check(Hands.harvest_yield(s, "stone") == 3, "Masonry III: base 3")
	s.ranks["stone_axe"] = 3
	t.check(Hands.harvest_yield(s, "wood") == 9, "Stone Axe III: base 3 x axe 3 = 9 Wood")
	s.tech_tree.researched["foraging"] = true
	t.check(Hands.harvest_yield(s, "berries") == 2, "Foraging still doubles Berries")
	t.check(Data.HAND_TOOLS["bronze_tools"]["hold"] == 0.4, "the Bronze Tools slot: a 0.4 s hold")
	var tree: Vector2i = t.find_tile(s, "tree")
	var wood: int = s.economy.inv["wood"]
	s.gather_by_hand(tree)
	t.check(s.economy.inv["wood"] == wood + 9, "a harvest gives exactly the harvest yield")


func test_hold_to_harvest() -> void:
	var s: Sim = t.fresh()
	var tree: Vector2i = t.find_tile(s, "tree")
	var rock: Vector2i = t.find_tile(s, "rock")
	t.check(s.hold_harvest(tree, 0.5) == "", "half a second: nothing yet")
	t.check(is_equal_approx(s.harvest_frac, 0.5), "the ring is half full")
	t.check(s.hold_harvest(tree, 0.5) == "+1 Wood", "a full second: the harvest pops")
	t.check(s.economy.inv["wood"] == 1 and is_equal_approx(s.harvest_frac, 0.0), "and the ring starts again")
	for i in 25:
		s.hold_harvest(tree, 0.1)
	t.check(s.economy.inv["wood"] == 3, "holding keeps harvesting: 2 more in 2.5 s (%d)" % s.economy.inv["wood"])
	s.hold_harvest(tree, 0.9)
	s.hold_harvest(rock, 0.2)
	t.check(s.economy.inv["stone"] == 0 and is_equal_approx(s.harvest_frac, 0.2), "moving to another tile starts over")
	s.release_harvest()
	t.check(s.harvest_frac == 0.0 and s.harvest_tile == Vector2i(-1, -1), "letting go empties the ring")
	s.hold_harvest(rock, 0.9)
	s.release_harvest()
	s.hold_harvest(rock, 0.2)
	t.check(s.economy.inv["stone"] == 0, "a released hold doesn't count toward the next")
	s.hand_tools = true
	t.check(s.hold_harvest(rock, 0.5) == "+1 Stone", "Flint Tools: 0.7 s a harvest")
	t.check(s.hold_harvest(s.world.camp_pos, 5.0) == "", "the Hearth isn't a resource")
	for i in Data.LEARN_CLICKS:
		s.hold_harvest(rock, 0.7)
	t.check(s.people.knows("stone"), "learning takes %d harvests" % Data.LEARN_FIRST)


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
	var s: Sim = t.fresh()
	t.give(s, 9999)
	t.check(Ranks.rank(s, "cordage") == 0 and Ranks.next_cost(s, "cordage").is_empty(), "no ranks before the tech")
	s.research("cordage")
	t.check(Ranks.rank(s, "cordage") == 1, "the tech is rank I")
	var rope: int = s.economy.inv["fiber"]
	t.check(Ranks.buy(s, "cordage"), "buy rank II")
	t.check(s.economy.inv["fiber"] == rope - Ranks.cost("cordage", 2)["fiber"], "rank II is paid for")
	t.check(Ranks.buy(s, "cordage") and Ranks.rank(s, "cordage") == 3, "buy rank III")
	t.check(not Ranks.buy(s, "cordage"), "III is the last rank")
	t.check(not Ranks.buy(s, "haulers"), "techs without ranks have none")
	var p: Vector2i = s.world.camp_pos + Vector2i(2, 0)
	t.place_free(s, "twine_post", p)
	var post: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(is_equal_approx(Bonuses.speed(s, post), 1.5), "Cordage III: +25% per rank beyond I at the Twine Post")
	t.check(Bonuses.text(s, post).contains("Cordage III +50%"), "named in the speed math: " + Bonuses.text(s, post))
	var q: Vector2i = s.world.camp_pos + Vector2i(-2, 2)
	t.place_free(s, "charcoal_pit", q)
	t.check(is_equal_approx(Bonuses.speed(s, s.town.buildings[s.town.building_at[q]]), 1.0), "and nowhere else")
	# Ranks are never on the way to Bronze Dawn.
	var route := Rules.route_to("bronze_dawn", {}, Rules.visible_techs(true))
	var s2: Sim = t.fresh()
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
		for tech in Rules.era_techs(1):
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
	var s: Sim = t.fresh()
	t.check(s.story.events.is_empty(), "no story yet")
	s.gather_by_hand(s.world.shard_pos)
	s.gather_by_hand(s.world.shard_pos)
	t.check(s.story.events == ["shard_found"], "the Strange Stone is recorded once, by id")
	var tree: Vector2i = t.find_tile(s, "tree")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(tree)
	t.check("first_lesson" in s.story.events, "the first lesson is recorded")
	t.give(s, 99999)
	for tech in Rules.route_to("bronze_dawn", s.tech_tree.researched, Rules.visible_techs(true)):
		s.research(tech)
	t.check("haulers" in s.story.events and "bronze_dawn" in s.story.events, "Haulers and Bronze Dawn too")
	for id in s.story.events:
		t.check(Data.STORY_EVENTS.has(id), id + " is a stable id listed in Data.STORY_EVENTS")
		t.check(id == id.to_lower() and not id.contains(" "), id + " is snake_case")


## Job titles are labels from data (07-glossary.md): each worker building resolves to one.
func test_job_titles() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 200
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["kind"] in ["processor", "gatherer"]:
			var b := {"type": type, "gather_items": [], "focus": ""}
			var job := s.people.building_job(b)
			t.check(job != "" and job != Data.JOB_IDLE, "%s's worker has a job title (%s)" % [type, job])
	for tile in Data.TILES:
		var item: String = Data.TILES[tile]["yields"]
		if item != "" and not Data.TILES[tile].get("mine_only", false):  # ore is for Mines, not huts
			t.check(Data.HUT_JOBS.has(item), "a hut gathering %s has a job title" % item)
			var b := {"type": "gatherers_hut", "gather_items": [item, item, "fiber"], "focus": ""}
			t.check(
				s.people.building_job(b) == Data.HUT_JOBS[item]["title"],
				"a hut takes the title of what it gathers most"
			)
	var mixed := {"type": "gatherers_hut", "gather_items": ["stone", "stone", "wood"], "focus": ""}
	s.people.learned_by["wood"] = "Aro"
	t.check(s.people.building_job(mixed) == "Woodcutter", "counting only what the Kith know, once they know some")
	var names := {}
	for k in s.people.kith:
		names[k["name"]] = true
		t.check(s.people.job_of(k) == Data.JOB_IDLE, "a new Kith is Idle")
	t.check(names.size() == s.people.kith.size(), "every Kith has their own name: %s" % [names.keys()])
	var p: Vector2i = t.find_grass(s, false)
	s.economy.inv["clay"] = 20
	t.check(t.place_free(s, "kiln", p), "place a kiln")
	s.tech_tree.researched["haulers"] = true
	s.tick(0.1)
	var kiln: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(
		s.people.title_of(s.people.kith[kiln["worker"]]).ends_with(" the Potter"), "the Kiln's worker is its Potter"
	)
	var counts := s.people.job_counts()
	t.check(counts.contains("1 Potter") and counts.contains("Haulers"), "the top bar counts jobs: " + counts)
	for i in Data.PEOPLE_NAMES.size() + 1:
		s.people.add_kith()
	t.check(s.people.kith[-1]["name"].ends_with(" II"), "names come round again with II: " + s.people.kith[-1]["name"])


## Fiber comes only from wild flax: bare grass gives nothing by hand or to a hut, and a hut by the
## flax cuts it once a Kith has learned it (its worker is the Thatcher).
func test_fiber_comes_from_flax() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 200
	t.check(Data.TILES["grass"]["yields"] == "" and Data.TILES["flax"]["yields"] == "fiber", "flax yields Fiber")
	t.check(not Data.TILES["flax"]["buildable"], "flax can't be built on")
	var grass: Vector2i = t.find_grass(s, false)
	t.check(Hands.item_at(s, grass) == "", "bare grass gives nothing by hand")
	for i in 30:
		t.check(s.hold_harvest(grass, 0.1) == "", "holding on grass never pays out")
	t.check(s.economy.inv.get("fiber", 0) == 0, "no Fiber from grass")
	var flax: Vector2i = s.world.camp_pos + MapGen.FLAX_PATCH[0]
	t.check(s.world.tile_at(flax) == "flax", "the Hearth's flax patch is there")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(flax)
	t.check(s.people.knows("fiber"), "10 harvests of flax teach it")
	# A hut with only grass in range has nothing to gather: clear a patch of ground for one.
	var open: Vector2i = s.world.camp_pos + Vector2i(0, 6)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s.world.set_tile(open + Vector2i(dx, dy), "grass")
	s.pathing.build()
	t.place_free(s, "gatherers_hut", open)
	var bare: Dictionary = s.town.buildings[s.town.building_at[open]]
	t.check(bare["gather_items"].is_empty(), "a hut on bare grass lists nothing to gather")
	t.check(not s.people.knows_any(open), "and knows nothing it could gather there")
	# A hut next to the flax cuts it.
	var by := flax + Vector2i(1, 1)
	if s.town.placement_error("gatherers_hut", by) != "":
		by = flax + Vector2i(0, 2)
	t.check(t.place_free(s, "gatherers_hut", by), "a hut by the flax")
	var hut: Dictionary = s.town.buildings[s.town.building_at[by]]
	t.check("fiber" in hut["gather_items"], "it will gather Fiber")
	s.economy.inv["fiber"] = 0
	s.tech_tree.researched["haulers"] = true
	t.road_link(s, by)
	t.road_link(s, open)
	run_for(s, 90.0)
	t.check(s.economy.inv.get("fiber", 0) + hut["out"].get("fiber", 0) > 0, "the hut brings in Fiber from the flax")
	t.check(bare["out"].is_empty() and bare["status"] != "Working", "the bare-grass hut brings nothing")


## Every map has wild flax within a hut's reach of the Hearth, in sight from the start, and more
## patches out on the grassland.
func test_flax_near_every_hearth() -> void:
	for map_seed in [1, 2, 3, 4, 5, 6, 7, 8, 42, 1234, 99991]:
		var s := Sim.new()
		s.generate(map_seed)
		var near := 0
		var total := 0
		for y in World.HEIGHT:
			for x in World.WIDTH:
				var p := Vector2i(x, y)
				if s.world.tile_at(p) != "flax":
					continue
				total += 1
				var d: Vector2i = (p - s.world.camp_pos).abs()
				if maxi(d.x, d.y) <= 4 and s.fog.is_revealed(p) and s.people.trip_info(p)["ok"]:
					near += 1
		t.check(near >= 2, "map %d: flax in sight and reach of the Hearth (%d tiles)" % [map_seed, near])
		t.check(total >= near + 4, "map %d: more flax patches out on the grassland (%d tiles)" % [map_seed, total])


## Paths & Haulers alone automates nothing: a hut or workshop with no road link keeps working by
## clicks and shows Needs road; a road to the Hearth (or a Storehouse) makes it run on its own, and
## tearing the road up unlinks it again.
func test_haulers_need_roads() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 500
	s.economy.inv["wood"] = 200
	s.tech_tree.researched["haulers"] = true
	var p := open_spot(s, 4)
	t.check(t.place_free(s, "charcoal_pit", p), "a pit four tiles from the Hearth")
	var i: int = s.town.building_at[p]
	var pit: Dictionary = s.town.buildings[i]
	t.check(not Roads.linked(s, pit) and not Roads.automated(s, pit), "no road: not linked")
	run_for(s, 20.0)
	t.check(
		Buildings.buffered(pit["inbuf"]) == 0 and pit["alert"] == "Needs road", "no hauler loads it: " + pit["alert"]
	)
	t.check(pit["status"].contains("Needs road"), "its status says so: " + pit["status"])
	t.check(Workers.road_hint(s, p).contains("Hearth"), "and what to connect: " + Workers.road_hint(s, p))
	Workers.click(s, i)
	t.check(Buildings.buffered(pit["inbuf"]) > 0, "a click still loads it by hand")
	t.road_link(s, p)
	t.check(Roads.linked(s, pit) and Roads.depot_of(s, pit) == s.world.camp_pos, "a road to the Hearth links it")
	var charcoal: int = s.economy.inv.get("charcoal", 0)
	run_for(s, 60.0)
	t.check(s.economy.inv.get("charcoal", 0) > charcoal + 4, "haulers keep it loaded and emptied")
	t.check(pit["alert"] != "Needs road", "the marker is gone")
	var road: Vector2i = Vector2i(-1, -1)
	for n in World.NEIGHBORS:
		if s.world.roads.has(p + n):
			road = p + n
	s.demolish(road)
	t.check(not Roads.linked(s, pit), "tearing up the road unlinks it")
	# A Storehouse is a depot too: a road to it is enough.
	var s2: Sim = t.fresh()
	s2.economy.inv["berries"] = 500
	s2.tech_tree.researched["haulers"] = true
	var store := open_spot(s2, 6)
	var pit2: Vector2i = store + Vector2i(2, 0)
	for q in [store + Vector2i(1, 0), pit2]:
		s2.world.set_tile(q, "grass")
	t.check(t.place_free(s2, "storehouse", store) and t.place_free(s2, "charcoal_pit", pit2), "a Storehouse and a pit")
	s2.world.roads[store + Vector2i(1, 0)] = true
	s2.town.road_rev += 1
	var b2: Dictionary = s2.town.buildings[s2.town.building_at[pit2]]
	t.check(Roads.linked(s2, b2) and Roads.depot_of(s2, b2) == store, "one road tile to the Storehouse links it")


## The open grass tile nearest the Hearth at least `dist` tiles from it (in steps), with nothing
## built next to it.
func open_spot(s: Sim, dist: int) -> Vector2i:
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


## Haulers never leave the roads on a job: every step of a pickup or delivery is a road tile, the
## depot or the building they serve.
func test_haulers_walk_roads_only() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 500
	s.economy.inv["wood"] = 300
	s.tech_tree.researched["haulers"] = true
	var p := open_spot(s, 5)
	t.check(t.place_free(s, "charcoal_pit", p), "a pit to serve")
	t.road_link(s, p)
	var off_road := 0
	var tasks := 0
	for step in 600:
		s.tick(0.1)
		for k in s.people.kith:
			if k["job"] != "haul" or not k["task"].has("kind"):
				continue
			tasks += 1
			for q in k["path"]:
				if not s.world.roads.has(q) and q != p and q != s.world.camp_pos:
					off_road += 1
	t.check(tasks > 0, "haulers took jobs")
	t.check(off_road == 0, "every hauler step on a job is a road tile (%d off-road)" % off_road)
