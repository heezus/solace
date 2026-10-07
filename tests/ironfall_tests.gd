extends RefCounted
## Ironfall stage 1 (design-system/19-ironfall.md): the era's data, the techs that wait for the end of the Starfall, the land
## that grows south with its coal and iron, finite coal seams, the Coal Mine, the Bloomery, Iron Tools, the fourth research
## tab and the era's goals. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const World = preload("res://scripts/world.gd")
const MapSouth = preload("res://scripts/map_south.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Kith = preload("res://scripts/kith.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Hands = preload("res://scripts/hands.gd")
const Rules = preload("res://scripts/rules.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")

const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 42, 99, 123, 2024]
const STAGE_ONE := ["coal_seams", "ironstone", "bloomery", "iron_tools"]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_ironfall_data_is_whole()
	test_the_techs_wait_for_the_end_of_the_starfall()
	test_the_land_grows_south()
	test_the_south_is_fair()
	test_coal_is_finite()
	test_a_coal_mine_digs_a_seam_dry()
	test_digging_by_hand()
	test_iron_hills_need_ironstone()
	test_the_bloomery_makes_iron()
	test_iron_tools()
	test_the_fourth_tab()
	test_the_goals()
	test_a_grown_south_saves_and_loads()


## A game whose map has grown east and south: the stone age is behind it, `tech` has been learned and the fog is lifted.
func south(map_seed := 42, tech := "coal_seams") -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	s.tech_tree.researched["bronze_dawn"] = true
	s.tech_tree.researched[tech] = true
	s.tick(0.1)
	s.fog.reveal_all()
	t.give(s, 999)
	s.economy.inv["coal"] = 0
	s.economy.inv["iron_ore"] = 0
	s.economy.inv["iron"] = 0
	return s


## The tile of kind `tile` nearest the Hearth, or (-1, -1).
func nearest(s: Sim, tile: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and Vector2(p).distance_to(Vector2(s.world.camp_pos)) < best_d:
				best = p
				best_d = Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return best


func count(s: Sim, tile: String) -> int:
	return s.world.tiles.count(tile)


# --- The data -------------------------------------------------------------------


func test_ironfall_data_is_whole() -> void:
	var techs := Rules.era_techs(4)
	t.check(techs.size() == 16, "the fourth era has 16 techs (%d)" % techs.size())
	t.check(Data.ERAS.has(4) and Data.ERA_TIER_NAMES.has(4), "and a board of its own")
	for id in techs:
		var def: Dictionary = Data.TECHS[id]
		for parent in def["requires"]:
			t.check(Data.TECHS.has(parent), "%s needs a tech that exists (%s)" % [id, parent])
		t.check(
			def["requires"].is_empty() == (def.get("after", "") != ""), "%s: only the roots wait for the story" % id
		)
		t.check(Data.TECH_BLURBS.has(id), "%s has a blurb" % id)
	for id in techs:
		t.check(Rules.tech_enabled(id) == (id in STAGE_ONE), "%s is built only if it is in stage 1" % id)
	for item in ["coal", "iron_ore", "iron", "steel", "iron_tools"]:
		t.check(Data.ITEMS[item]["era"] == 4 and item in Data.ITEM_ORDER, "%s is an era-4 good" % item)
	for type in ["coal_mine", "bloomery"]:
		t.check(Data.TECHS[Data.BUILDINGS[type]["tech"]]["era"] == 4, "%s comes with an era-4 tech" % type)
		t.check(type in Data.BUILD_TABS["Metal"], "%s is on the Metal tab" % type)
	t.check(
		Data.COAL_PER_SEAM == 500 and Data.IRON_TOOL_JOBS == 300, "a seam holds 500 and an Iron Tool lasts 300 jobs"
	)


func test_the_techs_wait_for_the_end_of_the_starfall() -> void:
	var s: Sim = t.fresh()
	t.give(s, 999)
	t.check(not s.tech_tree.tech_visible("coal_seams"), "Coal Seams is out of view in the stone age")
	t.check(not s.research("coal_seams"), "and cannot be bought")
	t.check(not s.story.has_event(Data.IRONFALL_EVENT), "Ironfall has not begun")
	s.starfall.ended = true
	s.starfall.pending = "ending"
	s.story.update(s)
	t.check(not s.story.has_event(Data.IRONFALL_EVENT), "it waits for the ending card to be put away")
	s.starfall.pending = ""
	s.story.update(s)
	t.check(s.story.has_event(Data.IRONFALL_EVENT), "and begins when it is")
	t.check(s.tech_tree.tech_visible("coal_seams") and s.tech_tree.tech_visible("ironstone"), "the two roots show")
	t.check(s.tech_tree.tech_visible("bloomery"), "and the Bloomery, which they lead to")
	t.check(not s.research("bloomery"), "which cannot be bought before them")
	t.check(s.research("coal_seams") and s.tech_tree.researched.has("coal_seams"), "Coal Seams is bought")
	t.check(not s.research("bloomery"), "the Bloomery wants Ironstone too")
	t.check(s.research("ironstone") and s.research("bloomery"), "with both, the Bloomery can be bought")


# --- The land -------------------------------------------------------------------


func test_the_land_grows_south() -> void:
	var s := Sim.new()
	s.generate(42)
	s.tech_tree.researched["bronze_dawn"] = true
	var h: int = s.world.height
	s.tick(0.1)
	t.check(s.world.is_grown() and s.world.height == h, "Bronze Dawn grows the map east and no further")
	var w: int = s.world.width
	var before := s.world.tiles.duplicate()
	s.tech_tree.researched["ironstone"] = true
	s.tick(0.1)
	t.check(
		s.world.height == h + Data.SOUTH_ROWS and s.world.width == w,
		"Ironstone grows it south (%d rows)" % s.world.height
	)
	t.check(s.world.tiles.size() == w * s.world.height, "the tiles fill the new size")
	t.check(s.world.tiles.slice(0, before.size()) == before, "every old tile stays as it was")
	t.check(Data.LAND_GREW_SOUTH_EVENT in s.events, "and the Kith say so")
	t.check(not s.fog.is_revealed(Vector2i(w / 2, h + 3)), "the new land is under fog")
	s.tick(0.1)
	t.check(s.world.height == h + Data.SOUTH_ROWS, "it grows once")
	t.check(count(s, "coal_seam") >= 3 * MapSouth.COAL_TILES_MIN, "there are coal tiles (%d)" % count(s, "coal_seam"))
	t.check(count(s, "iron_hills") >= MapSouth.IRON_MIN, "and iron tiles (%d)" % count(s, "iron_hills"))
	t.check(s.world.seam_left.size() == MapSouth.COAL_SEAMS, "in three seams")
	for id in s.world.seam_left:
		t.check(s.world.seam_left[id] == Data.COAL_PER_SEAM, "each holds %d" % Data.COAL_PER_SEAM)
	for p in s.world.seam_of:
		t.check(s.world.tile_at(p) == "coal_seam", "every seam tile is coal")
	var coal_only := Sim.new()
	coal_only.generate(42)
	coal_only.tech_tree.researched["bronze_dawn"] = true
	coal_only.tech_tree.researched["coal_seams"] = true
	coal_only.tick(0.1)
	coal_only.tick(0.1)
	t.check(coal_only.world.height == h + Data.SOUTH_ROWS, "Coal Seams alone grows it too, so coal is not stranded")
	var none := Sim.new()
	none.generate(42)
	none.tech_tree.researched["bronze_dawn"] = true
	for i in 3:
		none.tick(0.1)
	t.check(not none.world.is_grown_south(), "and nothing else does")
	var old := Sim.new()
	old.generate(42)
	for i in 3:
		old.tick(0.1)
	t.check(old.world.height == h and old.world.width == old.world.stone_width, "a stone-age map stays the size it was")


func test_the_south_is_fair() -> void:
	var worst_crossings := 0
	var bad := 0
	for map_seed in SEEDS:
		var w := World.new()
		w.generate(map_seed)
		w.grow_east()
		var report := {}
		var strip := MapSouth.make(w, report)
		worst_crossings = maxi(worst_crossings, report["crossings"])
		if not report["faults"].is_empty():
			bad += 1
			printerr("south map %d: %s" % [map_seed, report["faults"]])
		t.check(strip.size() == w.width * Data.SOUTH_ROWS, "map %d: the strip fills its rows" % map_seed)
		t.check(
			MapSouth.seams_in(strip, w.width).size() == MapSouth.COAL_SEAMS, "map %d: three separate seams" % map_seed
		)
	t.check(bad == 0, "every south is fair (%d of %d are not)" % [bad, SEEDS.size()])
	print("South fairness: %d seeds, worst %d river tiles on the way" % [SEEDS.size(), worst_crossings])
	var a := World.new()
	var b := World.new()
	for w in [a, b]:
		w.generate(7)
		w.grow_east()
		w.grow_south()
	t.check(a.tiles == b.tiles and a.seam_of == b.seam_of, "a seed always grows the same south")


# --- Coal -----------------------------------------------------------------------


func test_coal_is_finite() -> void:
	var s := south()
	var w: World = s.world
	var p := nearest(s, "coal_seam")
	var id: int = w.seam_of[p]
	var tiles: Array = w.seam_of.keys().filter(func(q): return w.seam_of[q] == id)
	w.seam_left[id] = 10
	t.check(w.seam_draw(p, 4) == 4 and w.seam_left[id] == 6, "a draw takes from the pile")
	t.check(not w.seam_spent(p) and w.tile_at(p) == "coal_seam", "which is not spent yet")
	t.check(w.seam_draw(p, 9) == 6 and w.seam_left[id] == 0, "a draw past the pile gets what is left")
	t.check(w.seam_spent(p), "and the seam is spent")
	for q in tiles:
		t.check(w.tile_at(q) == "spent_seam", "every tile of it turns to a Spent Seam")
	t.check(w.seam_draw(p, 3) == 0, "nothing more comes out")
	t.check(w.seam_draw(w.camp_pos, 5) == 5, "ground that is no seam gives what is asked")
	var total := 0
	for other in w.seam_left:
		total += w.seam_left[other]
	t.check(total == 2 * Data.COAL_PER_SEAM, "the other two still hold their 500 (%d)" % total)


func test_a_coal_mine_digs_a_seam_dry() -> void:
	var fresh: Sim = south(42, "ironstone")
	var p := nearest(fresh, "coal_seam")
	t.check(fresh.town.placement_error("coal_mine", p) != "", "a Coal Mine waits for Coal Seams")
	var s := south()
	p = nearest(s, "coal_seam")
	t.check(s.town.placement_error("coal_mine", s.world.camp_pos + Vector2i(0, 3)) != "", "and stands only on a seam")
	t.check(t.place_free(s, "coal_mine", p), "a Coal Mine goes on a Coal Seam")
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(b["ore"] == "coal", "it digs coal")
	s.world.seam_left[s.world.seam_of[p]] = 7
	var said := false
	for i in 4000:
		s.economy.inv["berries"] = 999
		s.tick(0.1)
		if Data.SEAM_SPENT_EVENT in s.events:
			said = true
		s.events.clear()
	var dug: int = b["out"].get("coal", 0) + s.economy.inv.get("coal", 0)
	t.check(dug == 7, "the Mine digs exactly what the seam held (%d)" % dug)
	t.check(s.world.seam_spent(p) and s.world.tile_at(p) == "spent_seam", "and the seam is spent")
	t.check(said, "the Kith say so")
	t.check(b["status"] == Data.SEAM_SPENT_STATUS, "the Mine's card says it has nothing left (%s)" % b["status"])


func test_digging_by_hand() -> void:
	var s := south(42, "ironstone")
	var p := nearest(s, "coal_seam")
	t.check(s.gather_by_hand(p) == "", "coal cannot be dug by hand before Coal Seams")
	s.tech_tree.researched["coal_seams"] = true
	var id: int = s.world.seam_of[p]
	s.world.seam_left[id] = 5
	var got := 0
	for i in 12:
		var text := s.gather_by_hand(p)
		if text == "":
			break
		got += int(text.split(" ")[0])
	t.check(got == 5 and s.economy.inv["coal"] == 5, "a hold digs a seam dry and no further (%d)" % got)
	t.check(s.world.tile_at(p) == "spent_seam", "and it is spent")
	var iron := nearest(s, "iron_hills")
	t.check(s.gather_by_hand(iron) != "", "iron ore is dug by hand once Ironstone is learned")
	t.check(s.economy.inv["iron_ore"] > 0 and s.world.seam_draw(iron, 4) == 4, "and iron has no seam to run out")


func test_iron_hills_need_ironstone() -> void:
	var s := south(42, "coal_seams")
	s.tech_tree.researched["mining"] = true
	var p := nearest(s, "iron_hills")
	t.check(s.town.placement_error("mine", p).contains("Ironstone"), "a Mine on Iron Hills waits for Ironstone")
	s.tech_tree.researched["ironstone"] = true
	t.check(t.place_free(s, "mine", p), "and stands on them after")
	t.check(s.town.buildings[s.town.building_at[p]]["ore"] == "iron_ore", "digging iron ore")


# --- Iron -----------------------------------------------------------------------


func test_the_bloomery_makes_iron() -> void:
	var bloomery: Dictionary = Data.BUILDINGS["bloomery"]
	t.check(
		bloomery["in"] == {"iron_ore": 2, "coal": 1} and bloomery["out"] == {"iron": 1}, "2 Iron Ore + 1 Coal make Iron"
	)
	var s := south(42, "ironstone")
	t.check(
		s.town.placement_error("bloomery", s.world.camp_pos + Vector2i(-3, 2)) != "", "the Bloomery waits for its tech"
	)
	s.tech_tree.researched["coal_seams"] = true
	var at: Vector2i = s.world.camp_pos + Vector2i(-3, 2)
	t.check(t.place_free(s, "bloomery", at), "a Bloomery goes up by the Hearth")
	var b: Dictionary = s.town.buildings[s.town.building_at[at]]
	b["inbuf"]["iron_ore"] = 2
	b["inbuf"]["coal"] = 1
	for i in 800:
		s.economy.inv["berries"] = 999
		s.tick(0.1)
	t.check(b["out"].get("iron", 0) == 1, "it makes one Iron (%d)" % b["out"].get("iron", 0))
	t.check(b["inbuf"].get("iron_ore", 0) == 0 and b["inbuf"].get("coal", 0) == 0, "and uses its ore and coal")


func test_iron_tools() -> void:
	var s: Sim = t.fresh()
	t.give(s, 999)
	s.tech_tree.researched["iron_tools"] = true
	t.check(Kith.tool_jobs("iron_tools") == Data.IRON_TOOL_JOBS, "an Iron Tool lasts 300 jobs")
	s.economy.inv["iron_tools"] = 1
	s.economy.inv["bronze_tools"] = 1
	s.economy.inv["flint_tools"] = 1
	var hut: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	s.tick(0.1)
	var k: Dictionary = s.people.kith[b["worker"]]
	t.check(Kith.tool_of(k) == "iron_tools", "a worker takes Iron before Bronze before Flint")
	t.check(k["tool"] == Data.IRON_TOOL_JOBS, "and it lasts its 300 jobs")
	t.check(
		is_equal_approx(Bonuses.speed(s, b), 2.75), "Iron Tools give 75 points over Bronze (%.2f)" % Bonuses.speed(s, b)
	)
	t.check(Bonuses.tool_bonus("iron_tools") == 1.75 and Bonuses.tool_bonus("bronze_tools") == 1.0, "the shares")
	var iron_before: int = s.economy.inv["iron_tools"]
	k["tool"] = 1
	s.people.wear(b)
	t.check(Kith.tool_of(k) == "" or k["tool_id"] != "iron_tools" or iron_before == 0, "a worn Iron Tool breaks")
	s.hand_tools = true
	t.check(
		is_equal_approx(Hands.hold_time(s, "wood"), Data.HAND_TOOLS["iron_tools"]["hold"]), "by hand it is the quickest"
	)
	t.check("iron_tools" in Data.BUILDINGS["tool_bench"]["makes"], "the Tool Bench makes them")
	s.economy.inv["iron"] = 1
	s.economy.inv["wood"] = 2
	s.economy.inv["iron_tools"] = 0
	t.check(
		Hands.craft(s, "iron_tools") and s.economy.inv["iron_tools"] == 1,
		"and they are made by hand from Iron and Wood"
	)
	var fresh: Sim = t.fresh()
	t.give(fresh, 99)
	t.check(not Hands.recipe_unlocked(fresh, "iron_tools"), "but only once discovered")


# --- The board and the goals ------------------------------------------------------


func test_the_fourth_tab() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel.refresh()
	t.check(panel.era_buttons.size() == 3 and panel.era_buttons.has(4), "a third tab, for the fourth era")
	t.check(panel.era_buttons[4].disabled, "it is locked in the stone age")
	t.check(panel.era_buttons[4].tooltip_text == Data.ERA_TAB_LOCKED_IRONFALL, "and says when it opens")
	s.tech_tree.researched["bronze_dawn"] = true
	panel.refresh()
	t.check(panel.era_buttons[4].disabled, "Bronze Dawn does not open it")
	t.check(not panel.era_buttons[2].disabled, "though it opens the second")
	s.story.record(Data.IRONFALL_EVENT)
	panel.refresh()
	t.check(not panel.era_buttons[4].disabled, "the end of the Starfall opens it")
	panel._pick_era(4)
	t.check(
		panel.board.era == 4 and panel.title.text == Data.BOARD_TITLE % "Ironfall", "and it shows the Ironfall tree"
	)
	panel._pick_view("all")
	for tech in Rules.era_techs(4):
		t.check(panel.board.card_rect(tech).size.x > 0.0, "%s has a card on the board" % tech)
	var again := TechPanel.new()
	again.setup(s)
	again.visible = true
	again._on_open()
	t.check(again.board.era == 4, "the board opens on the newest era")
	again.free()
	panel.free()


func test_the_goals() -> void:
	var s := south(42, "ironstone")
	t.check(
		s.story.goal_list() == Data.GOALS_ERA2 or s.story.goal_list() == Data.GOALS,
		"the goals are the old era's at first"
	)
	s.story.record(Data.IRONFALL_EVENT)
	t.check(s.story.goal_list() == Data.GOALS_ERA4, "Ironfall has a checklist of its own")
	s.story.update(s)
	t.check(s.story.goals_done.has("ironstone"), "Ironstone ticks its goal")
	t.check(s.story.goals_done.has("find_iron"), "and the Iron Hills, seen, tick theirs")
	s.tech_tree.researched["coal_seams"] = true
	s.story.update(s)
	t.check(
		s.story.goals_done.has("find_coal") and s.story.goals_done.has("coal_seams"),
		"Coal Seams brings the coal in view"
	)
	t.place_free(s, "coal_mine", nearest(s, "coal_seam"))
	s.story.update(s)
	t.check(s.story.goals_done.has("coal_mine"), "a Coal Mine ticks the next")
	t.check(not s.story.goals_done.has("first_iron"), "no Iron yet")
	s.economy.inv["iron"] = 1
	s.story.update(s)
	t.check(s.story.goals_done.has("first_iron"), "the first Iron ticks")
	t.check(s.story.current_goal() < s.story.goal_list().size(), "and the list goes on")


func test_a_grown_south_saves_and_loads() -> void:
	var s := south()
	var p := nearest(s, "coal_seam")
	var id: int = s.world.seam_of[p]
	s.world.seam_draw(p, 120)
	var q := nearest(s, "coal_seam")
	s.world.seam_left[s.world.seam_of[q]] = 0
	s.world.seam_draw(q, 1)
	s.story.record(Data.IRONFALL_EVENT)
	var saved := Sim.new()
	t.check(
		RunSave.restore(saved, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a game with the south grown loads"
	)
	t.check(saved.world.height == s.world.height and saved.world.tiles == s.world.tiles, "the land is as it was")
	t.check(
		saved.world.seam_left == s.world.seam_left and saved.world.seam_of == s.world.seam_of, "and so are the seams"
	)
	t.check(saved.world.seam_left[id] == s.world.seam_left[id], "with what is left in them")
	t.check(saved.world.is_grown_south() and saved.story.has_event(Data.IRONFALL_EVENT), "and the era")
	saved.tick(0.1)
	t.check(saved.world.height == s.world.height, "it does not grow again")
	t.check(saved.tech_tree.tech_visible("bloomery") == s.tech_tree.tech_visible("bloomery"), "the board is as it was")
