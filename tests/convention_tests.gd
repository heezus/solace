extends RefCounted
## Tests for the genre conventions from Jon's playtests: demolish, pause, the Hearth, bridges,
## fog and rates. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/rules.gd")
const Research = preload("res://scripts/research.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Hands = preload("res://scripts/hands.gd")

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


func test_demolish_refunds_half() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 100
	var near := s.camp_pos + Vector2i(-2, 0)
	var other := s.camp_pos + Vector2i(-2, 1)
	t.place_free(s, "gatherers_hut", near)
	t.place_free(s, "gatherers_hut", other)
	for i in 10:
		s.tick(0.5)
	var first: Dictionary = s.buildings[s.building_at[near]]
	t.check(first["worker"] >= 0, "the hut has a worker")
	var worker: int = first["worker"]
	var wood: int = s.inv["wood"]
	var stone: int = s.inv["stone"]
	var refund := s.demolish(near)
	t.check(
		refund.size() == 2 and refund.get("wood") == 5 and refund.get("stone") == 2,
		"half back, rounded down (%s)" % str(refund)
	)
	t.check(s.inv["wood"] >= wood + 5 and s.inv["stone"] >= stone + 2, "the refund reaches the stockpile")
	t.check(not s.building_at.has(near), "the hut is gone")
	t.check(s.kith[worker]["job"] != "work", "its worker goes idle")
	t.check(s.buildings[s.building_at[other]]["pos"] == other, "the other buildings keep their places")
	var k2: int = s.buildings[s.building_at[other]]["worker"]
	t.check(k2 < 0 or s.kith[k2]["building"] == s.building_at[other], "the other worker still points at its hut")
	t.check(s.demolish(s.camp_pos).is_empty(), "the Hearth can't be torn down")
	var road := s.camp_pos + Vector2i(1, 1)
	t.place_free(s, "road", road)
	s.demolish(road)
	t.check(not s.roads.has(road), "roads can be torn up")
	for i in 20:
		s.tick(0.5)
	t.check(true, "the simulation keeps running after a demolish")


func test_pause_frees_the_worker() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 100
	var p := s.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var i: int = s.building_at[p]
	t.check(s.buildings[i]["worker"] >= 0, "staffed")
	s.set_paused(i, true)
	s.tick(0.1)
	t.check(s.buildings[i]["worker"] < 0, "a paused building frees its worker")
	t.check(s.buildings[i]["alert"] == "Paused", "and says so")
	s.set_paused(i, false)
	s.tick(0.1)
	t.check(s.buildings[i]["worker"] >= 0, "resumed, it gets a worker back")


func test_dwellings_stay_near_the_hearth() -> void:
	var s: GameState = t.fresh()
	var near := s.camp_pos + Vector2i(0, 2)
	var far := Vector2i(-1, -1)
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if (
				far.x < 0
				and s.tile_at(p) == "grass"
				and Vector2(p).distance_to(Vector2(s.camp_pos)) > Data.HEARTH_RADIUS
			):
				far = p
	s.inv["wood"] = 100
	s.inv["fiber"] = 100
	t.check(Data.BUILDINGS["camp"]["name"] == "Hearth", "the Camp is the Hearth")
	t.check(
		s.placement_error("dwelling", far) == "Must be within 6 tiles of the Hearth", "no Dwelling far from the Hearth"
	)
	t.check(
		Overlays.ghost_text("dwelling", s.placement_error("dwelling", far)).begins_with("Too far from the Hearth"),
		"the ghost's pill says the Dwelling is too far"
	)
	t.check(s.place("dwelling", near), "a Dwelling near the Hearth")
	t.check(
		s.placement_error("storehouse", far) != "Must be within 6 tiles of the Hearth", "other buildings go anywhere"
	)


func test_roads_dont_cross_rivers() -> void:
	var s: GameState = t.fresh()
	var river: Vector2i = t.find_tile(s, "river")
	s.researched["haulers"] = true
	s.inv["stone"] = 10
	t.check(s.placement_error("road", river).begins_with("Roads can't cross the river"), "no roads on the river")
	t.check(not s.place("road", river), "a road won't go down on the river")
	t.check(s.astar.is_point_solid(river), "the river still blocks walking")
	var line := Rules.line_tiles(Vector2i(2, 3), Vector2i(5, 1))
	t.check(line.size() == 6 and line[0] == Vector2i(2, 3) and line[5] == Vector2i(5, 1), "a drag covers an L of tiles")


func test_roads_cut_mountain_passes() -> void:
	var s: GameState = t.fresh()
	var rock: Vector2i = t.find_tile(s, "rock")
	s.researched["haulers"] = true
	s.inv["stone"] = 2
	t.check(s.placement_error("road", rock) == "Not enough materials", "a pass costs more than a road")
	s.inv["stone"] = 5
	t.check(Overlays.blocked_hint(s, rock) == "Cut a pass with a Road (3 Stone)", "rocks say how to get through")
	var river: Vector2i = t.find_tile(s, "river")
	t.check(
		Overlays.blocked_hint(s, river) == "Cross with a Wooden Bridge (Paths & Haulers)", "the river says how to cross"
	)
	t.check(s.place("road", rock), "a road goes down on Rocks")
	t.check(s.inv["stone"] == 2, "for 3 Stone")
	t.check(s.tile_at(rock) == "grass", "and clears the rock into a pass")
	t.check(s.roads.has(rock), "with a road through it")
	t.check(is_equal_approx(s.walk_cost(rock), Data.WALK_COST["road"]), "which walks like any road")
	var grass: Vector2i = s.camp_pos + Vector2i(0, 2)
	t.check(s.place("road", grass), "a road by the Hearth")
	t.check(s.inv["stone"] == 1, "a road on grass still costs 1 Stone")
	var line: Array = [grass + Vector2i(1, 0), grass + Vector2i(2, 0)]
	t.check(Overlays.line_text(s, "road", line).begins_with("Road: "), "a drag's pill counts the tiles")


func test_fog_lifts_around_buildings_and_kith() -> void:
	var s := GameState.new()
	s.generate(42)
	t.check(s.fog.is_revealed(s.camp_pos), "the Hearth is in view")
	t.check(s.fog.is_revealed(s.camp_pos + Vector2i(Data.SIGHT_START, 0)), "6 tiles around it too")
	var far := s.camp_pos + Vector2i(Data.SIGHT_START + 3, 0)
	t.check(not s.fog.is_revealed(far), "farther out is fog")
	t.check(s.gather_by_hand(far) == "", "can't gather in the fog")
	s.inv["wood"] = 100
	s.inv["stone"] = 100
	s.researched["gatherers_hut"] = true
	t.check(s.placement_error("gatherers_hut", far).begins_with("Unexplored"), "can't build in the fog")
	var edge := s.camp_pos + Vector2i(Data.SIGHT_START, 0)
	if s.tile_at(edge) == "grass":
		s.place("gatherers_hut", edge)
		t.check(s.fog.is_revealed(edge + Vector2i(Data.SIGHT_BUILDING, 0)), "a building lifts the fog 3 tiles out")
	var before := s.fog.count()
	s.kith[0]["pos"] = Vector2(s.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.inv["berries"] = 50
	s.tick(0.1)
	t.check(s.fog.count() > before, "walking Kith lift the fog around them")
	t.check(sight_after_a_walk(true) > sight_after_a_walk(false), "Scouting lets the Kith see farther")


## How many tiles are explored after one Kith steps just past the fog's edge.
func sight_after_a_walk(scouting: bool) -> int:
	var s := GameState.new()
	s.generate(42)
	if scouting:
		s.researched["scouting"] = true
	s.kith[0]["pos"] = Vector2(s.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.inv["berries"] = 50
	s.tick(0.1)
	return s.fog.count()


func test_rates_count_making_and_using() -> void:
	var s: GameState = t.fresh()
	t.check(s.flows.rate("wood") == 0.0, "no rate before anything happens")
	s.flows.add("wood", 6, "gatherers_hut")
	s.flows.add("wood", -2, "charcoal_pit")
	s.flows.advance(1.0)
	t.check(is_equal_approx(s.flows.rate("wood"), 4.0), "net rate: made minus used, per second")
	var parts := s.flows.parts("wood")
	t.check(is_equal_approx(parts["gatherers_hut"], 6.0) and is_equal_approx(parts["charcoal_pit"], -2.0), "by source")
	for i in Data.RATE_WINDOW + 5:
		s.flows.advance(1.0)
	t.check(s.flows.rate("wood") == 0.0, "old flows drop out of the window")
	var s2: GameState = t.fresh()
	s2.inv["berries"] = 100
	s2.learned["wood"] = "Aro"
	s2.researched["haulers"] = true
	t.place_free(s2, "gatherers_hut", s2.camp_pos + Vector2i(-2, 0))
	t.road_link(s2, s2.camp_pos + Vector2i(-2, 0))
	for i in 120:
		s2.tick(0.5)
	t.check(s2.flows.rate("wood") > 0.0, "a working hut makes wood (%.2f/s)" % s2.flows.rate("wood"))
	t.check(s2.flows.rate("berries") < 0.0, "the Kith eat berries (%.2f/s)" % s2.flows.rate("berries"))
	t.check(s2.flows.parts("berries").has("kith"), "eating shows up as its own source")
	t.check(TopBar.rate_text(0.6) == "+0.60" and TopBar.rate_text(-0.25) == "−0.25", "rates read +0.60 and −0.25")
	t.check(
		TopBar.rate_text(0.0) == "0" and TopBar.rate_color(-1.0) != TopBar.rate_color(1.0),
		"flat is 0; loss and gain differ"
	)


## Every line runs in the gutters and channels: none passes under a card, none shares a track with another,
## and the board scrolls cleanly in a 1280 x 800 window: one tier plus the gate past the edge at most.
func test_research_board_lines_stay_in_channels() -> void:
	var lay := TechLayout.build()
	t.check(lay["overflow"] == 0, "every line found a free track (%d did not)" % lay["overflow"])
	t.check(
		lay["size"].x <= 1230.0 + TechLayout.PITCH,
		"the board is at most a tier wider than the window (%d)" % int(lay["size"].x)
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
	var s: GameState = t.fresh()
	Research.set_goal(s, "grindstone")
	t.check(s.research_goal == "grindstone", "the goal is set")
	t.check(s.research_queue.size() <= Data.QUEUE_SLOTS and s.research_queue.size() >= 3, "a few techs are queued")
	t.check(s.research_queue[0] in ["cordage", "knapping", "fire"], "roots come first")
	t.check("grindstone" not in s.research_queue, "the goal waits until its parents are queued")
	s.tick(0.1)
	t.check(s.researched.is_empty(), "nothing is researched while it's unaffordable")
	t.give(s, 999)
	for i in 4:
		s.tick(0.1)
	t.check(s.researched.has("grindstone"), "the queue researches its way to the goal")
	for r in ["water_wheel", "masonry", "stone_axe", "farming"]:
		t.check(s.researched.has(r), "including " + r)
	t.check(s.research_queue.is_empty() and s.research_goal == "", "and empties once it's there")
	t.check(not s.researched.has("pottery"), "nothing off the route is researched")
	var s2: GameState = t.fresh()
	var route := Rules.route_to("calendar", s2.researched, Rules.visible_techs(false))
	t.check(route[route.size() - 1] == "calendar", "a route ends at its goal")
	t.check("storytelling" in route and "megaliths" not in route, "an either-or takes the shorter branch")
	t.check(Research.ready_list(s2).is_empty(), "nothing is ready with an empty stockpile")


## Side branches are exactly the techs Bronze Dawn doesn't need.
func test_side_branches_are_marked() -> void:
	var needed := Rules.route_to("bronze_dawn", {}, Rules.visible_techs(false))
	for tech in Data.TECHS:
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
	var s: GameState = t.fresh()
	s.inv["berries"] = 100
	var p := s.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var hut: Dictionary = s.buildings[s.building_at[p]]
	var trip := BuildingPanel.trip_text(s, p)
	t.check(trip.begins_with("To Hearth · 2 tiles"), "the trip line names the Hearth and the distance: " + trip)
	t.check(BuildingPanel.trip_text(s, s.camp_pos) == "", "the Hearth has no trip line")
	t.check(BuildingPanel.recipe_text(s, hut).begins_with("Gathers from"), "a hut lists what it gathers")
	var worker := BuildingPanel.worker_text(s, hut)
	t.check(worker.begins_with("Worker: %s the " % Data.PEOPLE_NAMES[0]), "and its worker, by name and job: " + worker)
	var q := s.camp_pos + Vector2i(2, 0)
	t.place_free(s, "twine_post", q)
	var post: Dictionary = s.buildings[s.building_at[q]]
	var recipe := BuildingPanel.recipe_text(s, post)
	t.check(recipe.contains("→") and recipe.contains("Rope"), "a workshop shows its recipe: " + recipe)
	t.check(Overlays.demolish_text(s, p).contains("get back"), "demolish hover names the refund")
	t.check(Overlays.demolish_text(s, p).contains("goes idle"), "and that its Kith goes idle")
	t.check(Overlays.demolish_text(s, s.camp_pos).begins_with("The Hearth stays"), "the Hearth can't be demolished")


## The research board and the build bar agree (Jon: the tree "isn't following and unlocking items like
## a warehouse"): every building and recipe names a real tech (or none, like the Dwelling), can't be
## placed or crafted before it, and that tech's card names it.
func test_tree_gates_every_building() -> void:
	var always := []
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		var tech: String = def["tech"]
		if tech == "":
			always.append(type)
			continue
		t.check(Data.TECHS.has(tech), "%s is gated by a real tech (%s)" % [type, tech])
		if not Data.TECHS.has(tech):
			continue
		var unlock: String = Data.TECHS[tech]["unlock"]
		t.check(unlock.contains(def["name"]), "%s's card names the %s it unlocks: %s" % [tech, def["name"], unlock])
		var s: GameState = t.fresh()
		t.give(s, 999)
		s.shard_seen = true
		for other in Data.TECHS:
			if other != tech:
				s.researched[other] = true
		var ok := 0
		for y in GameState.HEIGHT:
			for x in GameState.WIDTH:
				if s.placement_error(type, Vector2i(x, y)) == "":
					ok += 1
		t.check(ok == 0, "%s can't be placed anywhere before %s (%d tiles)" % [type, tech, ok])
		s.researched[tech] = true
		for y in GameState.HEIGHT:
			for x in GameState.WIDTH:
				if s.placement_error(type, Vector2i(x, y)) == "":
					ok += 1
		t.check(ok > 0 or def["kind"] == "camp", "%s can be placed once %s is researched" % [type, tech])
	t.check(always == ["camp", "dwelling"], "only the Hearth and the Dwelling need no research: %s" % [always])
	for r in Data.RECIPES:
		var rec: Dictionary = Data.RECIPES[r]
		t.check(Data.TECHS.has(rec["tech"]), "the %s recipe is gated by a real tech" % r)
		t.check(
			Data.TECHS[rec["tech"]]["unlock"].contains(rec["name"]), "%s's card names %s" % [rec["tech"], rec["name"]]
		)
		var s: GameState = t.fresh()
		t.give(s, 99)
		t.check(not Hands.craft(s, r), "can't craft %s before %s" % [r, rec["tech"]])
	# Every card's summary fits on it.
	var font := ThemeDB.fallback_font
	for tech in Data.TECHS:
		var w := font.get_string_size(Data.TECHS[tech]["unlock"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		t.check(w <= TechLayout.CARD_W - 70.0, "%s's summary fits its card (%d px)" % [tech, w])
