extends RefCounted
## Step 8A, Skyreach (design-system/32-skyreach.md): era 6 from the second telling on. The first telling still ends at Skyward, the
## second goes on; a Signal Tower surveys a sector of the sky; a surveyed landfall shows 90 seconds ahead; the Skyreach is raised in
## three deliveries and its third stage opens the endings card. Run from tests/livewire_tests.gd, which owns the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Skyreach = preload("res://scripts/skyreach.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Art = preload("res://scripts/art.gd")
const Overlays = preload("res://scripts/overlays.gd")
const SkyArt = preload("res://scripts/sky_art.gd")
const SkyMarks = preload("res://scripts/sky_marks.gd")

var t  # the runner, tests/run_tests.gd
var base  # the Livewire tests, for their helpers


## A node that draws the sky's marks and every Skyreach building state in its own _draw, as the map does.
class SkyCanvas:
	extends Node2D
	var sim

	func _draw() -> void:
		SkyMarks.draw(self, sim, 1.0)
		var cell := Rect2(Vector2(200, 200), Vector2.ONE * Overlays.TILE)
		for lit in [false, true]:
			Art.map_building(self, "signal_tower", cell, lit, 0.0)
		for stage in 4:
			Art.map_building(self, "skyreach_tower", cell, false, 0.0, stage)
		Overlays.placement_ghost(self, sim, "signal_tower", sim.world.camp_pos + Vector2i(3, 3), "")


func run(runner, helpers) -> void:
	t = runner
	base = helpers
	test_the_data()
	test_the_first_telling_ends_at_skyward()
	test_the_second_telling_goes_on()
	test_a_tower_surveys_its_sector()
	test_a_surveyed_landfall_is_marked_ahead()
	test_an_unsurveyed_landfall_gives_no_warning()
	test_a_landfall_starts_a_patch()
	test_the_sky_opens_with_a_floor_of_stores()
	test_a_scorcher_burns_a_seed_out()
	test_the_site_is_the_only_place()
	test_the_site_is_one_a_road_can_reach()
	test_the_site_has_room()
	test_the_towers_ground_holds()
	test_three_deliveries_raise_the_skyreach()
	test_help_shortens_a_stage()
	test_the_save_keeps_the_sky()
	test_the_painted_art_is_all_there()
	test_a_tower_is_lit_while_it_warns()
	test_the_way_is_laid_with_the_right_piece()
	test_the_sky_draws_with_its_art()


# --- Helpers -------------------------------------------------------------------


## A town in Livewire with Skyward bought: a second telling (`second`) or the first.
func town(second := true) -> Sim:
	var s: Sim = base.town()
	s.story.record(Data.LIVEWIRE_BEGUN)
	if second:
		s.carry.exodus = 1
	s.story.record(Data.SKYWARD_EVENT)
	s.story.update(s)
	return s


## A town where the sky is open, a meadow cleared for towers, and the Signal Tower's cost in the stockpile.
func sky() -> Sim:
	var s := town()
	base.meadow(s, 8)
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 400
	s.people.found(10)
	return s


## Put a Signal Tower `far` tiles from the Hearth towards the sector `sector` (the middle of that sector's direction).
func tower_in(s: Sim, sector: int, far := 6) -> Dictionary:
	var angle := deg_to_rad(sector * 60.0 - 180.0 + 0.0)
	var p: Vector2i = s.world.camp_pos + Vector2i(roundi(cos(angle) * far), roundi(sin(angle) * far))
	return base.put(s, Skyreach.SIGNAL, p)


# --- The tests -----------------------------------------------------------------


func test_the_data() -> void:
	var d: Dictionary = Data.SKYREACH
	t.check(d["names"].size() == d["sectors"], "a name for every sector")
	t.check(d["stage_cost"].size() == 3, "three stages")
	for cost in d["stage_cost"]:
		for id in cost:
			t.check(Data.ITEMS.has(id), "stage goods are items: %s" % id)
	t.check(Skyreach.wave_size(0) == 2 and Skyreach.wave_size(100) == 4, "waves of 2, growing to 4")
	t.check(Skyreach.wave_time(1) - Skyreach.wave_time(0) == d["wave_every"], "a wave every two minutes")
	var hearth := Vector2i(50, 50)
	var seen := {}
	for k in range(0, 360, 10):
		var p := hearth + Vector2i(roundi(cos(deg_to_rad(k)) * 20.0), roundi(sin(deg_to_rad(k)) * 20.0))
		seen[Skyreach.sector_of(hearth, p)] = true
	t.check(seen.size() == d["sectors"], "every sector is some direction")
	t.check(Skyreach.sector_of(hearth, hearth + Vector2i(20, 0)) == 0, "east is sector 0")
	for id in ["signal_tower", "skyreach_tower"]:
		t.check(Data.BUILDINGS.has(id) and Data.BUILD_ORDER.has(id), "%s is a building in the menu order" % id)


func test_the_first_telling_ends_at_skyward() -> void:
	var s := town(false)
	t.check(s.story.has_event(Data.SKYWARD_EVENT), "Skyward stands")
	t.check(not s.story.has_event("skyreach_begun"), "and the sky is not opened in a first telling")
	s.skyreach.tick(s, 5.0)
	t.check(s.skyreach.falls.is_empty() and s.skyreach.begun_at < 0.0, "so the Skyreach does nothing")
	t.check(
		s.town.placement_error("signal_tower", s.world.camp_pos + Vector2i(0, 8)) != "",
		"and no Signal Tower can be raised"
	)


func test_the_second_telling_goes_on() -> void:
	var s := town()
	t.check(s.story.has_event("skyreach_begun"), "Skyward opens the sky in the second telling")
	t.check(s.story.goal_list() == Data.SKYREACH["goals"], "and the goals are the Skyreach's")
	s.story.card_up = false
	s.story.update(s)
	t.check(s.story.stamps.has("skyreach_begun"), "the era is stamped for the Chronicle")


func test_a_tower_surveys_its_sector() -> void:
	var s := sky()
	var b := tower_in(s, 2)
	base.tick_for(s, 3.0)
	t.check(s.skyreach.surveyed.size() == 1, "one tower surveys one sector (%s)" % str(s.skyreach.surveyed))
	var sector: int = Skyreach.sector_of(s.world.camp_pos, b["pos"])
	t.check(s.skyreach.surveyed.has(sector), "the sector it stands in")
	t.check(s.skyreach.site.x >= 0, "and the first tower finds the Skyreach's site")
	t.check(Skyreach.sector_of(s.world.camp_pos, s.skyreach.site) in range(Data.SKYREACH["sectors"]), "in a sector")


func test_a_surveyed_landfall_is_marked_ahead() -> void:
	var s := sky()
	# Survey every sector, so any fall of the first wave is seen.
	for sector in Data.SKYREACH["sectors"]:
		tower_in(s, sector)
	var warn: float = Data.SKYREACH["warn"]
	var first: float = Skyreach.wave_time(0)
	base.tick_for(s, first - warn - 5.0)
	t.check(s.skyreach.marked(s).is_empty(), "nothing is marked before the warning's reach")
	base.tick_for(s, 10.0)
	var marks: Array = s.skyreach.marked(s)
	t.check(
		marks.size() == Skyreach.wave_size(0),
		"the first wave shows %d falls (%d)" % [Skyreach.wave_size(0), marks.size()]
	)
	for m in marks:
		t.check(m["eta"] <= warn + 0.5 and m["eta"] > 0.0, "marked %d s ahead (%.1f)" % [warn, m["eta"]])
	t.check(not s.skyreach.falls.is_empty() and not s.skyreach.falls[0]["fell"], "and they have not fallen yet")


func test_an_unsurveyed_landfall_gives_no_warning() -> void:
	var s := sky()
	base.tick_for(s, Skyreach.wave_time(0) - 30.0)
	t.check(s.skyreach.marked(s).is_empty(), "no tower, no mark")
	t.check(not s.skyreach.falls.is_empty(), "though the wave is planned")


func test_a_landfall_starts_a_patch() -> void:
	var s := sky()
	base.tick_for(s, Skyreach.wave_time(0) + 5.0)
	var f: Dictionary = s.skyreach.falls[0]
	t.check(f["fell"], "the first fall has fallen")
	t.check(s.tide.is_bloom(s, f["pos"]), "and the Bloom has taken the ground")
	var same := sky()
	base.tick_for(same, Skyreach.wave_time(0) - Data.SKYREACH["warn"] + 1.0)
	t.check(same.skyreach.falls[0]["pos"] == f["pos"], "a map falls the same way every time")


func test_the_sky_opens_with_a_floor_of_stores() -> void:
	var floor_of: Dictionary = Data.SKYREACH["floor"]
	var empty := town()
	for id in floor_of:
		empty.economy.inv[id] = 0
	empty.economy.inv["wire"] = 5
	empty.events.clear()
	base.tick_for(empty, 2.0)
	for id in floor_of:
		t.check(
			empty.economy.inv[id] == floor_of[id],
			"%s is topped up to %d (%d)" % [id, floor_of[id], empty.economy.inv[id]]
		)
	t.check(empty.events.has(Data.SKYREACH["shared"]), "and the log says the Lumen shared what they salvaged")
	var rich := town()
	for id in floor_of:
		rich.economy.inv[id] = floor_of[id] + 40
	base.tick_for(rich, 2.0)
	t.check(rich.economy.inv["wire"] >= floor_of["wire"] + 40, "stores above the floor are not touched")
	var foes := town()
	foes.starfall.lean = "enemies"
	foes.economy.inv["wire"] = 0
	foes.events.clear()
	base.tick_for(foes, 2.0)
	t.check(foes.events.has(Data.SKYREACH["scavenged"]), "scavengers bring it when the Lumen are enemies")
	var first := town(false)
	first.economy.inv["wire"] = 0
	base.tick_for(first, 2.0)
	t.check(first.economy.inv["wire"] == 0, "the first telling is given nothing")


func test_a_scorcher_burns_a_seed_out() -> void:
	var s := sky()
	var p: Vector2i = s.world.camp_pos + Vector2i(14, 0)
	t.check(not s.tide.scorched(p), "no Scorcher burning, no seed burns out")
	s.tide._fires = [p + Vector2i(2, 0)]  # a burning, powered Scorcher (refresh_lights fills this from the buildings)
	t.check(s.tide.scorched(p), "a burning Scorcher in reach burns a seed out on landing")
	t.check(not s.tide.scorched(p + Vector2i(12, 0)), "but not one out of its reach")


func test_the_site_is_the_only_place() -> void:
	var s := sky()
	tower_in(s, 0)
	base.tick_for(s, 3.0)
	var site: Vector2i = s.skyreach.site_pos()
	var elsewhere: Vector2i = s.world.camp_pos + Vector2i(0, 9)
	t.check(s.town.placement_error("skyreach_tower", elsewhere) != "", "not just anywhere")
	s.world.set_tile(site, "grass")
	t.check(
		s.town.placement_error("skyreach_tower", site) == "",
		"but on the site (%s)" % s.town.placement_error("skyreach_tower", site)
	)
	t.check(s.place("skyreach_tower", site), "it goes down")
	var b: Dictionary = s.town.buildings[s.town.building_at[site]]
	t.check(Buildings.served(b), "and it is served by haulers")
	t.check(not s.town.placement_error("skyreach_tower", site + Vector2i(1, 0)) == "", "only one")


func test_the_site_is_one_a_road_can_reach() -> void:
	var s := sky()
	var camp: Vector2i = s.world.camp_pos
	var near: Vector2i = camp + Vector2i(6, 0)
	var across: Vector2i = camp + Vector2i(12, 0)
	for dy in range(-32, 33):  # open ground all round the Hearth
		for dx in range(-32, 33):
			var q := camp + Vector2i(dx, dy)
			if s.world.in_bounds(q) and q != camp and not s.town.building_at.has(q):
				s.world.set_tile(q, "grass")
	s.pathing.build()
	t.check(s.skyreach._walkable(s).has(across), "on open ground a road reaches %s" % across)
	for dy in range(-30, 31):  # a long river between the town and the far side
		if s.world.in_bounds(camp + Vector2i(9, dy)):
			s.world.set_tile(camp + Vector2i(9, dy), "river")
	s.pathing.refresh()
	var reach: Dictionary = s.skyreach._walkable(s)
	t.check(reach.has(near), "the near bank is reached")
	t.check(not reach.has(across), "a site across a long river is not one a road can reach")
	s.world.set_tile(camp + Vector2i(6, 1), "grain")
	t.check(not s.skyreach._walkable(s).has(camp + Vector2i(6, 1)), "and a field is not ground for a road")


func test_the_site_has_room() -> void:
	var s := sky()
	var edge: int = Data.SKYREACH["site_edge"]
	t.check(not s.skyreach._roomy(s, Vector2i(0, 19)), "a tile on the map's edge is no site")
	t.check(not s.skyreach._roomy(s, Vector2i(edge - 1, 19)), "nor one %d tiles in" % (edge - 1))
	t.check(s.skyreach._roomy(s, Vector2i(edge, edge)), "but one %d tiles in is" % edge)
	var camp: Vector2i = s.world.camp_pos
	for dy in range(-16, 17):
		for dx in range(-16, 17):
			var q := camp + Vector2i(dx, dy)
			if s.world.in_bounds(q) and q != camp and not s.town.building_at.has(q):
				s.world.set_tile(q, "grass")
	s.pathing.build()
	var walk: Dictionary = s.skyreach._walkable(s)
	var spot: Vector2i = camp + Vector2i(7, 0)
	t.check(s.skyreach._open_sides(s, spot, walk) == 4, "on open ground all four sides are open")
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		s.world.set_tile(spot + d, "river")
	s.pathing.refresh()
	walk = s.skyreach._walkable(s)
	t.check(s.skyreach._open_sides(s, spot, walk) < Data.SKYREACH["site_sides"], "a tile with one open side is no site")
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		s.world.set_tile(spot + d, "grass")
	s.pathing.refresh()
	var told: Array = []
	s.skyreach.said.connect(func(m): told.append(m))
	s.skyreach._find_site(s, 0)
	var site: Vector2i = s.skyreach.site
	t.check(Data.SKYREACH["way_held"] in told, "the log says the way will hold: %s" % str(told))
	t.check(site.x >= 0 and s.skyreach._roomy(s, site), "the site found keeps off the edge")
	t.check(
		s.skyreach._open_sides(s, site, s.skyreach._walkable(s)) >= Data.SKYREACH["site_sides"],
		"and has room for a road"
	)


func test_the_towers_ground_holds() -> void:
	var s := sky()
	var camp: Vector2i = s.world.camp_pos
	var site: Vector2i = camp + Vector2i(0, 9)
	s.skyreach.site = site
	t.check(
		s.skyreach.holds(s, site) and s.skyreach.holds(s, site + Vector2i(1, 1)),
		"the site and the ring round it hold at once"
	)
	t.check(not s.skyreach.holds(s, site + Vector2i(2, 0)), "but not a tile beyond the ring")
	base.put(s, Skyreach.TOWER, site)
	var lane: Array = []
	for y in range(camp.y + 1, site.y):  # a road from beside the Hearth to the tower's top side
		lane.append(Vector2i(camp.x, y))
	for p in lane:
		s.world.roads[p] = true
	var stray: Vector2i = camp + Vector2i(3, 4)
	s.world.roads[stray] = true
	s.town.road_rev += 1
	t.check(s.skyreach.holds(s, site), "the tower's own ground holds")
	t.check(s.skyreach.holds(s, lane[0]) and s.skyreach.holds(s, lane[-1]), "and the road that links it to a depot")
	t.check(not s.skyreach.holds(s, stray), "but not a road that leads nowhere")
	t.check(s.tide._state(s, lane[3]) == 2, "so the tide never takes it")
	# the link is cut, then laid again by hand: the new link holds too
	var cut: Vector2i = lane[3]
	s.world.roads.erase(cut)
	s.town.road_rev += 1
	t.check(not s.skyreach.holds(s, lane[0]), "a road beyond a cut no longer links the tower, so it is not held")
	t.check(s.skyreach.holds(s, lane[-1]), "the tower's own side stays held")
	s.world.roads[cut] = true
	s.town.road_rev += 1
	t.check(s.skyreach.holds(s, cut) and s.skyreach.holds(s, lane[0]), "a link laid again holds")
	t.check(s.tide._state(s, cut) == 2, "so the tide cannot take the mended tile")
	var relaid: Vector2i = camp + Vector2i(1, 5)  # a different road to the same depot: the link may take any path
	for y in range(camp.y + 2, site.y):
		s.world.roads.erase(Vector2i(camp.x, y))
	for y in range(camp.y + 1, site.y + 1):  # down the next column to the tower's side
		s.world.roads[Vector2i(camp.x + 1, y)] = true
	s.town.road_rev += 1
	t.check(s.skyreach.holds(s, relaid), "a link by another way holds")
	t.check(not s.skyreach.holds(s, lane[2]), "and the road it replaced is not held")


func test_three_deliveries_raise_the_skyreach() -> void:
	var s := sky()
	var tower: Dictionary = base.put(s, Skyreach.TOWER, s.world.camp_pos + Vector2i(0, 9))
	t.check(Haulers.stock_wanted(s, tower) == Data.SKYREACH["stage_cost"][0], "haulers are asked for stage 1")
	var heard: Array = []
	s.skyreach.said.connect(func(m): heard.append(m))
	for stage in 3:
		t.check(Skyreach.stage_of(tower) == stage, "stage %d stands" % stage)
		s.skyreach.tick(s, 1.0)  # nothing delivered: nothing begins
		t.check(float(tower.get("clock", -1.0)) < 0.0, "stage %d waits for goods" % (stage + 1))
		t.check(
			Skyreach.note(tower).begins_with("Stage %d needs" % (stage + 1)), "and says so: %s" % Skyreach.note(tower)
		)
		tower["inbuf"] = Data.SKYREACH["stage_cost"][stage].duplicate()
		s.skyreach.tick(s, 0.5)
		t.check(Haulers.stock_wanted(s, tower).is_empty(), "while it builds, nothing more is wanted")
		t.check(float(tower["clock"]) >= 0.0, "stage %d begins" % (stage + 1))
		var seconds: float = s.skyreach.stage_seconds(s)
		var spent := 0.0
		while spent < seconds + 2.0 and Skyreach.stage_of(tower) == stage:
			s.skyreach.tick(s, 1.0)
			spent += 1.0
	t.check(Skyreach.stage_of(tower) == 3, "three stages stand")
	t.check(s.story.has_event(Data.SKYREACH["done"]), "the era is done and the endings card opens")
	t.check(Haulers.stock_wanted(s, tower).is_empty(), "nothing is wanted after")


func test_help_shortens_a_stage() -> void:
	var s := sky()
	s.starfall.lean = "allies"
	var helped: float = s.skyreach.stage_seconds(s)
	s.starfall.lean = "neighbours"
	t.check(s.skyreach.stage_seconds(s) == helped, "neighbours help as allies do")
	s.starfall.lean = "enemies"
	var alone: float = s.skyreach.stage_seconds(s)
	t.check(
		is_equal_approx(helped, alone * Data.SKYREACH["help_speed"]),
		"the Lumen shave 30%% (%.0f s against %.0f s)" % [helped, alone]
	)


func test_the_save_keeps_the_sky() -> void:
	var s := sky()
	tower_in(s, 1)
	base.tick_for(s, Skyreach.wave_time(0) - 60.0)
	var back := Sim.new()
	back.generate(2)
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run loads")
	t.check(back.skyreach.site == s.skyreach.site, "the site is kept")
	t.check(back.skyreach.falls.size() == s.skyreach.falls.size(), "the planned falls are kept")
	t.check(back.skyreach.begun_at == s.skyreach.begun_at, "and when the era began")


# --- The painted art (Step 8D, docs/art/skyreach) -----------------------------


func test_the_painted_art_is_all_there() -> void:
	for name in SkyArt.TALL:
		var tex := SkyArt.tall(name)
		t.check(tex != null, "%s is painted" % name)
		var sheet := SkyArt.whole(name)
		var region: Array = SkyArt.TALL[name][0]
		t.check(
			(
				sheet != null
				and region[0] + region[2] <= sheet.get_width()
				and region[1] + region[3] <= sheet.get_height()
			),
			"%s: its painted region lies inside its sheet" % name
		)
		var drawn: Array = SkyArt.TALL[name][1]
		t.check(
			absf(float(region[2]) / region[3] - float(drawn[0]) / drawn[1]) < 0.05,
			"%s: drawn at the shape it was painted" % name
		)
	for name in ["landfall_mark", "skyreach_site_ring", "sky_sector_edge", "skyreach_way", "skyreach_way_corner"]:
		var tex := SkyArt.whole(name)
		t.check(tex != null and tex.get_size() == Vector2(192, 192), "%s is a 192 px square" % name)
	var atlas := SkyArt.whole("seed_fall")
	t.check(atlas != null and atlas.get_size() == Vector2(576, 192), "the seed fall is three frames")
	for i in 3:
		t.check(SkyArt.frame(atlas, i).get_size() == Vector2(192, 192), "frame %d is one tile's picture" % i)
	for name in ["seed_fall_splash_1", "seed_fall_splash_2", "chronicle_star_gold"]:
		t.check(SkyArt.whole(name) != null, "%s is painted" % name)
	for type in ["signal_tower", "skyreach_tower"]:
		t.check(Art.building_sprite(type) != null, "%s has a card and build bar picture" % type)
	t.check(not SkyArt.draws("watchtower") and SkyArt.icon("watchtower") == null, "no other building is taken over")


func test_the_tall_pictures_stand_on_their_tile() -> void:
	var cell := Rect2(Vector2(96, 144), Vector2.ONE * 48.0)
	var tower := SkyArt.rect_of("signal_tower", cell)
	t.check(tower.size == Vector2(26, 55), "the Signal Tower is drawn 26 by 55 on a 48 px tile")
	t.check(is_equal_approx(tower.get_center().x, cell.get_center().x), "centred on its tile")
	t.check(is_equal_approx(tower.end.y, cell.end.y - 2.0), "its base two pixels above the tile's bottom edge")
	var big := SkyArt.rect_of("skyreach_tower_3", Rect2(Vector2.ZERO, Vector2.ONE * 96.0))
	t.check(big.size == Vector2(92, 158) and is_equal_approx(big.end.y, 92.0), "and it grows with the tile")
	var base_rects := {}
	for stage in 4:
		base_rects[SkyArt.rect_of(SkyArt.name_of("skyreach_tower", false, stage), cell).end.y] = true
	t.check(base_rects.size() == 1, "the four stages of the Skyreach share one ground line")
	t.check(
		SkyArt.rect_of("signal_tower_lit", cell).end.y == tower.end.y,
		"and the lit Signal Tower stands where the idle one does"
	)
	t.check(SkyArt.name_of("skyreach_tower", false, 9) == "skyreach_tower_3", "a stage is held to the picture it has")


func test_a_tower_is_lit_while_it_warns() -> void:
	test_the_tall_pictures_stand_on_their_tile()
	var s := sky()
	var tower := tower_in(s, 0)
	var other := tower_in(s, 3)
	t.check(not s.skyreach.warns(s, tower), "a tower with no landfall to warn of is not lit")
	base.tick_for(s, Skyreach.wave_time(0) - Data.SKYREACH["warn"] + 5.0)
	var sector0: int = Skyreach.sector_of(s.world.camp_pos, tower["pos"])
	var sector3: int = Skyreach.sector_of(s.world.camp_pos, other["pos"])
	var in_zero := false
	var in_three := false
	for f in s.skyreach.falls:
		in_zero = in_zero or f["sector"] == sector0
		in_three = in_three or f["sector"] == sector3
	t.check(s.skyreach.warns(s, tower) == in_zero, "a tower is lit when a landfall is coming in its sector")
	t.check(s.skyreach.warns(s, other) == in_three, "and not when it is only coming in another")
	var site: Vector2i = s.skyreach.site_pos()
	t.check(not s.skyreach.warns(s, {"type": "watchtower", "pos": site}), "and nothing but a Signal Tower is ever lit")


func test_the_way_is_laid_with_the_right_piece() -> void:
	var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for a in sides:
		for b in sides:
			if a == b:
				continue
			var piece: Array = SkyMarks.way_piece(a, b)
			var turns: int = piece[1]
			var base_sides := (
				[Vector2(-1, 0), Vector2(1, 0)] if piece[0] == "skyreach_way" else [Vector2(-1, 0), Vector2(0, 1)]
			)
			var turned := []
			for side in base_sides:
				turned.append(Vector2i(side.rotated(turns * PI / 2.0).round()))  # clockwise on the screen
			t.check(
				turned.has(a) and turned.has(b) and (a + b == Vector2i.ZERO) == (piece[0] == "skyreach_way"),
				"the way joining %s and %s is laid as %s turned %d" % [a, b, piece[0], turns]
			)


func test_the_sky_draws_with_its_art() -> void:
	var s := sky()
	for sector in Data.SKYREACH["sectors"]:
		tower_in(s, sector)
	s.fog.reveal_all()
	base.tick_for(s, Skyreach.wave_time(0) - Data.SKYREACH["warn"] + 5.0)
	var site: Vector2i = s.skyreach.site_pos()
	t.check(site.x >= 0 and not s.skyreach.way.is_empty(), "the site and the way to it are found")
	for p in s.skyreach.way:
		s.world.roads[p] = true  # the way laid, so its glow draws
	var canvas := SkyCanvas.new()
	canvas.sim = s
	t.root.add_child(canvas)
	canvas.notification(CanvasItem.NOTIFICATION_DRAW)  # as the engine would on a redraw
	base.tick_for(s, s.skyreach.falls[0]["at"] - s.skyreach.now(s) + 1.2)  # the first seed has just fallen
	canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	canvas.free()
	t.check(not s.skyreach.falls.is_empty() and s.skyreach.falls[0]["fell"], "a landfall fell while the sky was drawn")
