extends RefCounted
## Tests for the genre conventions from Jon's playtests: demolish, pause, the Hearth, bridges,
## fog and rates. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Hands = preload("res://scripts/hands.gd")
const World = preload("res://scripts/world.gd")
const Land = preload("res://scripts/land.gd")

## What Sim lets a caller do itself: commands that touch several blocks at once. Anything a single block can
## answer is asked of that block (`sim.economy.can_afford`), so a new name here needs a reason: add it to this
## list only when the method orchestrates more than one block.
const SIM_COMMANDS := [
	"demolish",
	"gather_by_hand",
	"generate",
	"hold_harvest",
	"place",
	"place_line",
	"release_harvest",
	"research",
	"set_paused",
	"tick",
]

## The blocks a Sim owns, each reached by its name, and the file it comes from.
const SIM_BLOCKS := {
	"economy": "economy",
	"world": "world",
	"pathing": "pathing",
	"tech_tree": "research",
	"town": "buildings",
	"people": "kith",
	"story": "story",
	"fog": "fog",
}

## Names Sim once forwarded to a block. They live on the block now; none may come back.
const SIM_RETIRED := [
	"story_events",
	"goals_done",
	"tiles",
	"camp_pos",
	"shard_pos",
	"roads",
	"fields",
	"astar",
	"buildings",
	"building_at",
	"road_rev",
	"road_net",
	"kith",
	"born",
	"learned",
	"researched",
	"research_goal",
	"research_queue",
	"inv",
	"seen",
	"food_credit",
	"starving",
	"food_use",
	"flows",
	"in_bounds",
	"tile_at",
	"touches_river",
	"can_afford",
	"add",
	"food_value",
	"food_total",
	"flour_reserve",
	"tech_visible",
	"missing_requirements",
	"requirements_met",
	"can_research",
	"building_unlocked",
	"placement_error",
	"built_type",
	"gather_tiles",
	"is_powered",
	"hut_radius",
	"housing",
	"haul",
	"buffered",
	"needs_worker",
	"walk_cost",
	"has_haulers",
	"harvest_yield",
	"work_speed",
	"progress_frac",
	"WIDTH",
	"HEIGHT",
	"NEIGHBORS",
]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_demolish_refunds_half()
	test_pause_frees_the_worker()
	test_dwellings_stay_near_the_hearth()
	test_roads_dont_cross_rivers()
	test_roads_cut_mountain_passes()
	test_fog_lifts_around_buildings_and_kith()
	test_rates_count_making_and_using()
	test_research_board_lines_stay_in_channels()
	test_research_queue()
	test_board_layout_is_data()
	test_side_branches_are_marked()
	test_build_tabs_cover_every_building()
	test_building_panel_texts()
	test_tree_gates_every_building()
	test_data_facade_exports_every_domain_constant()
	test_sim_surface_stays_small()
	test_sim_reaches_every_block()
	test_sim_keeps_no_pass_throughs()


func test_demolish_refunds_half() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var near := s.world.camp_pos + Vector2i(-2, 0)
	var other := s.world.camp_pos + Vector2i(-2, 1)
	t.place_free(s, "gatherers_hut", near)
	t.place_free(s, "gatherers_hut", other)
	for i in 10:
		s.tick(0.5)
	var first: Dictionary = s.town.buildings[s.town.building_at[near]]
	t.check(first["worker"] >= 0, "the hut has a worker")
	var worker: int = first["worker"]
	var wood: int = s.economy.inv["wood"]
	var stone: int = s.economy.inv["stone"]
	var refund := s.demolish(near)
	t.check(
		refund.size() == 2 and refund.get("wood") == 5 and refund.get("stone") == 2,
		"half back, rounded down (%s)" % str(refund)
	)
	t.check(
		s.economy.inv["wood"] >= wood + 5 and s.economy.inv["stone"] >= stone + 2, "the refund reaches the stockpile"
	)
	t.check(not s.town.building_at.has(near), "the hut is gone")
	t.check(s.people.kith[worker]["job"] != "work", "its worker goes idle")
	t.check(s.town.buildings[s.town.building_at[other]]["pos"] == other, "the other buildings keep their places")
	var k2: int = s.town.buildings[s.town.building_at[other]]["worker"]
	t.check(
		k2 < 0 or s.people.kith[k2]["building"] == s.town.building_at[other], "the other worker still points at its hut"
	)
	t.check(s.demolish(s.world.camp_pos).is_empty(), "the Hearth can't be torn down")
	var road := s.world.camp_pos + Vector2i(1, 1)
	t.place_free(s, "road", road)
	s.demolish(road)
	t.check(not s.world.roads.has(road), "roads can be torn up")
	for i in 20:
		s.tick(0.5)
	t.check(true, "the simulation keeps running after a demolish")


func test_pause_frees_the_worker() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var p := s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var i: int = s.town.building_at[p]
	t.check(s.town.buildings[i]["worker"] >= 0, "staffed")
	s.set_paused(i, true)
	s.tick(0.1)
	t.check(s.town.buildings[i]["worker"] < 0, "a paused building frees its worker")
	t.check(s.town.buildings[i]["alert"] == "Paused", "and says so")
	s.set_paused(i, false)
	s.tick(0.1)
	t.check(s.town.buildings[i]["worker"] >= 0, "resumed, it gets a worker back")


func test_dwellings_stay_near_the_hearth() -> void:
	var s: Sim = t.fresh()
	var near := s.world.camp_pos + Vector2i(0, 2)
	var far := Vector2i(-1, -1)
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			if (
				far.x < 0
				and s.world.tile_at(p) == "grass"
				and Vector2(p).distance_to(Vector2(s.world.camp_pos)) > Data.HEARTH_RADIUS
			):
				far = p
	s.economy.inv["wood"] = 100
	s.economy.inv["fiber"] = 100
	t.check(Data.BUILDINGS["camp"]["name"] == "Hearth", "the Camp is the Hearth")
	t.check(
		s.town.placement_error("dwelling", far) == "Must be within 6 tiles of the Hearth",
		"no Dwelling far from the Hearth"
	)
	t.check(
		Overlays.ghost_text("dwelling", s.town.placement_error("dwelling", far)).begins_with("Too far from the Hearth"),
		"the ghost's pill says the Dwelling is too far"
	)
	t.check(s.place("dwelling", near), "a Dwelling near the Hearth")
	t.check(
		s.town.placement_error("storehouse", far) != "Must be within 6 tiles of the Hearth",
		"other buildings go anywhere"
	)


func test_roads_dont_cross_rivers() -> void:
	var s: Sim = t.fresh()
	var river: Vector2i = t.find_tile(s, "river")
	s.tech_tree.researched["haulers"] = true
	s.economy.inv["stone"] = 10
	t.check(s.town.placement_error("road", river).begins_with("Roads can't cross the river"), "no roads on the river")
	t.check(not s.place("road", river), "a road won't go down on the river")
	t.check(s.pathing.astar.is_point_solid(river), "the river still blocks walking")
	var line := Rules.line_tiles(Vector2i(2, 3), Vector2i(5, 1))
	t.check(line.size() == 6 and line[0] == Vector2i(2, 3) and line[5] == Vector2i(5, 1), "a drag covers an L of tiles")


func test_roads_cut_mountain_passes() -> void:
	var s: Sim = t.fresh()
	var rock: Vector2i = t.find_tile(s, "rock")
	s.tech_tree.researched["haulers"] = true
	s.economy.inv["stone"] = 2
	t.check(s.town.placement_error("road", rock) == "Not enough materials", "a pass costs more than a road")
	s.economy.inv["stone"] = 5
	t.check(Overlays.blocked_hint(s, rock) == "Cut a pass with a Road (3 Stone)", "rocks say how to get through")
	var river: Vector2i = t.find_tile(s, "river")
	t.check(
		Overlays.blocked_hint(s, river) == "Cross with a Wooden Bridge (Paths & Haulers)", "the river says how to cross"
	)
	t.check(s.place("road", rock), "a road goes down on Rocks")
	t.check(s.economy.inv["stone"] == 2, "for 3 Stone")
	t.check(s.world.tile_at(rock) == "grass", "and clears the rock into a pass")
	t.check(s.world.roads.has(rock), "with a road through it")
	t.check(is_equal_approx(s.pathing.walk_cost(rock), Data.WALK_COST["road"]), "which walks like any road")
	var grass: Vector2i = s.world.camp_pos + Vector2i(0, 2)
	s.economy.inv["wood"] = 2
	t.check(s.place("road", grass), "a road by the Hearth")
	t.check(s.economy.inv["stone"] == 2 and s.economy.inv["wood"] == 0, "a road on grass costs 2 Wood, no Stone")
	var tree: Vector2i = t.find_tile(s, "tree")
	s.economy.inv["wood"] = 2
	t.check(s.town.placement_error("road", tree) == "", "a road can go through Forest")
	t.check(s.place("road", tree) and s.economy.inv["wood"] == 0, "for the same 2 Wood")
	t.check(s.world.tile_at(tree) == "grass" and s.world.roads.has(tree), "and the trees are felled for it")
	var line: Array = [grass + Vector2i(1, 0), grass + Vector2i(2, 0)]
	t.check(Overlays.line_text(s, "road", line).begins_with("Road: "), "a drag's pill counts the tiles")


func test_fog_lifts_around_buildings_and_kith() -> void:
	var s := Sim.new()
	s.generate(42)
	t.check(s.fog.is_revealed(s.world.camp_pos), "the Hearth is in view")
	t.check(s.fog.is_revealed(s.world.camp_pos + Vector2i(Data.SIGHT_START, 0)), "6 tiles around it too")
	var far := s.world.camp_pos + Vector2i(Data.SIGHT_START + 3, 0)
	t.check(not s.fog.is_revealed(far), "farther out is fog")
	t.check(s.gather_by_hand(far) == "", "can't gather in the fog")
	s.economy.inv["wood"] = 100
	s.economy.inv["stone"] = 100
	s.tech_tree.researched["gatherers_hut"] = true
	t.check(s.town.placement_error("gatherers_hut", far).begins_with("Unexplored"), "can't build in the fog")
	var edge := s.world.camp_pos + Vector2i(Data.SIGHT_START, 0)
	if s.world.tile_at(edge) == "grass":
		s.place("gatherers_hut", edge)
		t.check(s.fog.is_revealed(edge + Vector2i(Data.SIGHT_BUILDING, 0)), "a building lifts the fog 3 tiles out")
	var before := s.fog.count()
	s.people.kith[0]["pos"] = Vector2(s.world.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.economy.inv["berries"] = 50
	s.tick(0.1)
	t.check(s.fog.count() > before, "walking Kith lift the fog around them")
	t.check(sight_after_a_walk(true) > sight_after_a_walk(false), "Scouting lets the Kith see farther")


## How many tiles are explored after one Kith steps just past the fog's edge.
func sight_after_a_walk(scouting: bool) -> int:
	var s := Sim.new()
	s.generate(42)
	if scouting:
		s.tech_tree.researched["scouting"] = true
	s.people.kith[0]["pos"] = Vector2(s.world.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.economy.inv["berries"] = 50
	s.tick(0.1)
	return s.fog.count()


func test_rates_count_making_and_using() -> void:
	var s: Sim = t.fresh()
	t.check(s.economy.flows.rate("wood") == 0.0, "no rate before anything happens")
	s.economy.flows.add("wood", 6, "gatherers_hut")
	s.economy.flows.add("wood", -2, "charcoal_pit")
	s.economy.flows.advance(1.0)
	t.check(is_equal_approx(s.economy.flows.rate("wood"), 4.0), "net rate: made minus used, per second")
	var parts := s.economy.flows.parts("wood")
	t.check(is_equal_approx(parts["gatherers_hut"], 6.0) and is_equal_approx(parts["charcoal_pit"], -2.0), "by source")
	for i in Data.RATE_WINDOW + 5:
		s.economy.flows.advance(1.0)
	t.check(s.economy.flows.rate("wood") == 0.0, "old flows drop out of the window")
	var s2: Sim = t.fresh()
	s2.economy.inv["berries"] = 100
	s2.people.learned_by["wood"] = "Aro"
	s2.tech_tree.researched["haulers"] = true
	t.place_free(s2, "gatherers_hut", s2.world.camp_pos + Vector2i(-2, 0))
	t.road_link(s2, s2.world.camp_pos + Vector2i(-2, 0))
	for i in 240:  # two minutes: the starting food credit is eaten first, then whole berries come off the stockpile
		s2.tick(0.5)
	t.check(s2.economy.flows.rate("wood") > 0.0, "a working hut makes wood (%.2f/s)" % s2.economy.flows.rate("wood"))
	t.check(s2.economy.flows.rate("berries") < 0.0, "the Kith eat berries (%.2f/s)" % s2.economy.flows.rate("berries"))
	t.check(s2.economy.flows.parts("berries").has("kith"), "eating shows up as its own source")
	t.check(TopBar.rate_text(0.6) == "+0.60" and TopBar.rate_text(-0.25) == "−0.25", "rates read +0.60 and −0.25")
	t.check(
		TopBar.rate_text(0.0) == "0" and TopBar.rate_color(-1.0) != TopBar.rate_color(1.0),
		"flat is 0; loss and gain differ"
	)


## Every line runs in the gutters and channels: none passes under a card, none shares a track with another,
## and the board is small enough to be fitted whole into a 1280 x 800 window at a readable size.
func test_research_board_lines_stay_in_channels() -> void:
	var lay := TechLayout.build()
	t.check(lay["overflow"] == 0, "every line found a free track (%d did not)" % lay["overflow"])
	t.check(
		lay["size"].x <= 1360.0 and lay["size"].y <= 540.0,
		"the board is compact enough to fit a window whole (%s)" % lay["size"]
	)
	t.check(lay["edges"].size() == TechLayout.links().size(), "one line per requirement")
	var segs: Array = []
	for e in lay["edges"]:
		var pts: PackedVector2Array = e["pts"]
		t.check(pts[0].x == lay["rects"][e["from"]].end.x, e["from"] + " line leaves from the card's right edge")
		t.check(pts[pts.size() - 1].x == lay["rects"][e["to"]].position.x, e["to"] + " line enters on the left edge")
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			t.check(a.x == b.x or a.y == b.y, "lines are orthogonal")
			segs.append([e, a, b])
			var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))
			for tech in lay["rects"]:
				var card: Rect2 = lay["rects"][tech].grow(-1.0)
				var hit := box.end.x >= card.position.x and box.position.x <= card.end.x
				hit = hit and box.end.y >= card.position.y and box.position.y <= card.end.y
				t.check(not hit, "%s > %s passes under %s" % [e["from"], e["to"], tech])
	var shared := 0
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			if _runs_overlap(segs[i], segs[j]):
				shared += 1
	t.check(shared == 0, "no two lines share a stretch of track (%d do)" % shared)


## Two segments of different lines lying on top of each other. Lines into the same card may merge.
func _runs_overlap(s1: Array, s2: Array) -> bool:
	var e1: Dictionary = s1[0]
	var e2: Dictionary = s2[0]
	if e1["from"] == e2["from"] or e1["to"] == e2["to"]:
		return false
	var a1: Vector2 = s1[1]
	var b1: Vector2 = s1[2]
	var a2: Vector2 = s2[1]
	var b2: Vector2 = s2[2]
	if a1.x == b1.x and a2.x == b2.x and absf(a1.x - a2.x) < 1.0:
		return minf(maxf(a1.y, b1.y), maxf(a2.y, b2.y)) - maxf(minf(a1.y, b1.y), minf(a2.y, b2.y)) > 0.5
	if a1.y == b1.y and a2.y == b2.y and absf(a1.y - a2.y) < 2.5:
		return minf(maxf(a1.x, b1.x), maxf(a2.x, b2.x)) - maxf(minf(a1.x, b1.x), minf(a2.x, b2.x)) > 0.5
	return false


## The research board is laid out from Data.TECHS alone, so a new tree is a data edit.
func test_board_layout_is_data() -> void:
	for tech in Data.TECHS:
		var d: Dictionary = Data.TECHS[tech]
		t.check(d["lane"] == "gate" or Data.LANES.has(d["lane"]), tech + " sits in a real lane")
		for parent in d.get("via", {}):
			t.check(parent in d["requires"] + d.get("requires_any", []), tech + ": via names one of its parents")
			t.check(TechLayout.via_channel(tech, parent) >= 0, tech + ": via names a real channel")


## Clicking a far tech makes it the goal: its missing chain is queued (a few at a time)
## and researched as each becomes affordable.
func test_research_queue() -> void:
	var s: Sim = t.fresh()
	s.tech_tree.set_goal("grindstone")
	t.check(s.tech_tree.goal == "grindstone", "the goal is set")
	t.check(s.tech_tree.queue.size() <= Data.QUEUE_SLOTS and s.tech_tree.queue.size() >= 3, "a few techs are queued")
	t.check(s.tech_tree.queue[0] in ["cordage", "knapping", "fire"], "roots come first")
	t.check("grindstone" not in s.tech_tree.queue, "the goal waits until its parents are queued")
	s.tick(0.1)
	t.check(s.tech_tree.researched.is_empty(), "nothing is researched while it's unaffordable")
	t.give(s, 999)
	for i in 4:
		s.tick(0.1)
	t.check(s.tech_tree.researched.has("grindstone"), "the queue researches its way to the goal")
	for r in ["water_wheel", "masonry", "stone_axe", "farming"]:
		t.check(s.tech_tree.researched.has(r), "including " + r)
	t.check(s.tech_tree.queue.is_empty() and s.tech_tree.goal == "", "and empties once it's there")
	t.check(not s.tech_tree.researched.has("pottery"), "nothing off the route is researched")
	var s2: Sim = t.fresh()
	var route := Rules.route_to("calendar", s2.tech_tree.researched, Rules.visible_techs(false))
	t.check(route[route.size() - 1] == "calendar", "a route ends at its goal")
	t.check("storytelling" in route and "megaliths" not in route, "an either-or takes the shorter branch")
	t.check(s2.tech_tree.ready_list().is_empty(), "nothing is ready with an empty stockpile")


## Side branches are exactly the techs Bronze Dawn doesn't need.
func test_side_branches_are_marked() -> void:
	var needed := Rules.route_to("bronze_dawn", {}, Rules.visible_techs(false))
	for tech in Rules.era_techs(1):
		if tech != "bronze_dawn":
			t.check(
				Data.TECHS[tech].get("side", false) == (tech not in needed), tech + " is marked side only if optional"
			)


## Every building the player can place sits in exactly one build tab.
func test_build_tabs_cover_every_building() -> void:
	for type in Data.BUILD_ORDER:
		var n := 0
		for tab in Data.BUILD_TABS:
			n += 1 if type in Data.BUILD_TABS[tab] else 0
		t.check(n == 1, type + " is in exactly one build tab")
	for tab in Data.BUILD_TABS:
		for type in Data.BUILD_TABS[tab]:
			t.check(type in Data.BUILD_ORDER, type + " in the " + tab + " tab is a real building")


func test_building_panel_texts() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 100
	var p := s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	var trip := BuildingPanel.trip_text(s, p)
	t.check(trip.begins_with("To Hearth · 2 tiles"), "the trip line names the Hearth and the distance: " + trip)
	t.check(BuildingPanel.trip_text(s, s.world.camp_pos) == "", "the Hearth has no trip line")
	t.check(BuildingPanel.recipe_text(s, hut).begins_with("Gathers from"), "a hut lists what it gathers")
	var worker := BuildingPanel.worker_text(s, hut)
	t.check(
		worker.begins_with("%s the " % Data.PEOPLE_NAMES[0]) and worker.contains("works here"),
		"and its worker, by name and job, in a sentence: " + worker
	)
	var q := s.world.camp_pos + Vector2i(2, 0)
	t.place_free(s, "twine_post", q)
	var post: Dictionary = s.town.buildings[s.town.building_at[q]]
	var recipe := BuildingPanel.recipe_text(s, post)
	t.check(recipe.contains("→") and recipe.contains("Rope"), "a workshop shows its recipe: " + recipe)
	t.check(Overlays.demolish_text(s, p).contains("get back"), "demolish hover names the refund")
	t.check(Overlays.demolish_text(s, p).contains("goes idle"), "and that its Kith goes idle")
	t.check(
		Overlays.demolish_text(s, s.world.camp_pos).begins_with("The Hearth stays"), "the Hearth can't be demolished"
	)


## The research board and the build bar agree (Jon: the tree "isn't following and unlocking items like
## a warehouse"): every building and recipe names a real tech (or none, like the Dwelling), can't be
## placed or crafted before it, and that tech's card names it.
func test_tree_gates_every_building() -> void:
	var always := []
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		var tech: String = def["tech"]
		if tech == "" and def.has("event"):
			t.check(
				Data.STORY_EVENTS.has(def["event"]), "%s opens with a real story moment (%s)" % [type, def["event"]]
			)
			continue  # the era after the star has no research: its buildings wait for the story (tests/starfall_tests.gd)
		if tech == "":
			always.append(type)
			continue
		t.check(Data.TECHS.has(tech), "%s is gated by a real tech (%s)" % [type, tech])
		if not Data.TECHS.has(tech):
			continue
		var unlock: String = Data.TECHS[tech]["unlock"]
		t.check(unlock.contains(def["name"]), "%s's card names the %s it unlocks: %s" % [tech, def["name"], unlock])
		var s: Sim = t.fresh()
		t.give(s, 999)
		s.shard_seen = true
		for other in Data.TECHS:
			if other != tech:
				s.tech_tree.researched[other] = true
		if def.has("on_tiles"):  # ore lies in the land that grows east
			s.tech_tree.researched["bronze_dawn"] = true
			Land.grow_if_due(s)
			s.fog.reveal_all()
		var ok := 0
		for y in s.world.height:
			for x in s.world.width:
				if s.town.placement_error(type, Vector2i(x, y)) == "":
					ok += 1
		t.check(ok == 0, "%s can't be placed anywhere before %s (%d tiles)" % [type, tech, ok])
		s.tech_tree.researched[tech] = true
		for y in s.world.height:
			for x in s.world.width:
				if s.town.placement_error(type, Vector2i(x, y)) == "":
					ok += 1
		t.check(ok > 0 or def["kind"] == "camp", "%s can be placed once %s is researched" % [type, tech])
	t.check(always == ["camp", "dwelling"], "only the Hearth and the Dwelling need no research: %s" % [always])
	for r in Data.RECIPES:
		var rec: Dictionary = Data.RECIPES[r]
		t.check(Data.TECHS.has(rec["tech"]), "the %s recipe is gated by a real tech" % r)
		t.check(
			Data.TECHS[rec["tech"]]["unlock"].contains(rec["name"]), "%s's card names %s" % [rec["tech"], rec["name"]]
		)
		var s: Sim = t.fresh()
		t.give(s, 99)
		t.check(not Hands.craft(s, r), "can't craft %s before %s" % [r, rec["tech"]])
	# Every tech says what it unlocks in one short plain sentence (the What to learn next cards show it).
	for tech in Data.TECHS:
		var blurb: String = Data.TECH_BLURBS.get(tech, "")
		t.check(blurb != "", "%s has a one-line blurb" % tech)
		t.check(blurb.length() <= 90, "%s's blurb is short (%d characters)" % [tech, blurb.length()])
		t.check(blurb.ends_with(".") and blurb.count(". ") == 0, "%s's blurb is one sentence: %s" % [tech, blurb])
	for tech in Data.TECH_BLURBS:
		t.check(Data.TECHS.has(tech), "the blurb for %s belongs to a real tech" % tech)


## scripts/data.gd is a facade over the domain files in scripts/data/: every constant they define is
## re-exported under the same name with the same value, and no two files define the same name.
func test_data_facade_exports_every_domain_constant() -> void:
	var facade_script: Script = Data
	var facade: Dictionary = facade_script.get_script_constant_map()
	var owner_of := {}
	var files := Array(DirAccess.get_files_at("res://scripts/data"))
	files = files.filter(func(f): return f.ends_with(".gd"))
	t.check(files.size() >= 7, "the data domain files are in scripts/data/ (%d)" % files.size())
	for f in files:
		var domain_script: Script = load("res://scripts/data/" + f)
		var domain: Dictionary = domain_script.get_script_constant_map()
		for name in domain:
			t.check(not owner_of.has(name), "%s is defined once (in %s and %s)" % [name, owner_of.get(name, ""), f])
			owner_of[name] = f
			t.check(facade.has(name), "Data re-exports %s from data/%s" % [name, f])
			t.check(facade.get(name) == domain[name], "Data.%s is data/%s's value" % [name, f])
	for name in facade:
		if not name.begins_with("Data"):  # the preloaded domain scripts themselves
			t.check(owner_of.has(name), "Data.%s comes from a file in scripts/data/" % name)


func test_sim_surface_stays_small() -> void:
	var script: Script = Sim
	var commands: Array = []
	for m in script.get_script_method_list():
		if not String(m["name"]).begins_with("_"):
			commands.append(m["name"])
	commands.sort()
	t.check(commands == SIM_COMMANDS, "Sim's public methods are exactly its commands: " + str(commands))
	var fields: Array = []
	for p in script.get_script_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p["name"]).begins_with("_"):
			fields.append(p["name"])
	t.check(fields.size() <= 21, "Sim's public fields are the blocks and a few run flags (%d)" % fields.size())
	var source := FileAccess.get_file_as_string("res://scripts/sim.gd")
	t.check(source.count("\n") < 320, "sim.gd stays a thin owner (%d lines)" % source.count("\n"))


func test_sim_reaches_every_block() -> void:
	var s: Sim = t.fresh()
	for block in SIM_BLOCKS:
		var owned = s.get(block)
		t.check(owned is RefCounted, "sim.%s is a block" % block)
		if owned is RefCounted:
			var path: String = owned.get_script().resource_path
			t.check(
				path == "res://scripts/%s.gd" % SIM_BLOCKS[block],
				"sim.%s comes from %s.gd" % [block, SIM_BLOCKS[block]]
			)
	# the one place blocks meet: they share the same set of researched techs and the same map
	t.check(is_same(s.tech_tree.researched, s.tech_set), "the techs are one set, held by the research block")
	t.check(s.town.building_at.has(s.world.camp_pos), "the town and the world agree where the Hearth is")


func test_sim_keeps_no_pass_throughs() -> void:
	var s: Sim = t.fresh()
	var script: Script = Sim
	var constants := script.get_script_constant_map()
	var back: Array = []
	for name in SIM_RETIRED:
		if s.has_method(name) or name in s or constants.has(name):
			back.append(name)
	t.check(back.is_empty(), "no pass-through has come back: " + str(back))
