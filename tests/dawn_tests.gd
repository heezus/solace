extends RefCounted
## What a newcomer is told after Bronze Dawn (playtest 7): the second era's own goal list that takes over from the
## stone age's, the pointer at the east edge of the map view that stays until the copper and then the tin are in sight,
## and the one-click Look east. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const EastPointer = preload("res://scripts/east_pointer.gd")
const Land = preload("res://scripts/land.gd")
const Rules = preload("res://scripts/rules.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const SidePanel = preload("res://scripts/side_panel.gd")

const IDS := [
	"prospecting",
	"find_copper",
	"copper_road",
	"mine",
	"smelting",
	"smelter",
	"find_tin",
	"crucible",
	"first_bronze",
]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_dawn_goals_are_plain_and_stable()
	test_the_dawn_goals_take_over_at_the_dawn()
	test_dawn_goals_count_in_any_order()
	test_the_ore_goals_follow_the_fog_and_the_road()
	test_the_first_bronze_stays_done()
	test_the_panel_reads_dawn_goals()
	test_the_dawn_banner_is_short()
	test_the_dawn_goals_survive_a_save()
	test_the_pointer_points_at_copper_then_tin()
	test_the_pointer_button_hides_and_looks()
	test_look_east_halves_the_way()


## A game one tick after Bronze Dawn: the land has grown and the new half is under fog.
func _dawn(map_seed := 42) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	s.fog.reveal_all()
	t.give(s, 99999)
	for tech in Rules.route_to("bronze_dawn", {}, Rules.visible_techs(true)):
		s.research(tech)
	s.tick(0.1)
	s.economy.inv["bronze"] = 0  # the stocking above gave some of everything,
	s.story.goals_done.erase("first_bronze")  # and met this goal on the way
	return s


func _ore(s: Sim, tile: String) -> Array:
	return Land.ore_tiles(s, tile)


func test_the_dawn_goals_are_plain_and_stable() -> void:
	var ids: Array = Data.GOALS_ERA2.map(func(g): return g["id"])
	t.check(ids == IDS, "the dawn goal ids and their order are stable: %s" % [ids])
	t.check(Data.GOALS_ERA2.size() == 9, "nine of them")
	for g in Data.GOALS_ERA2:
		var text: String = g["text"]
		t.check(text.length() <= 80, "%s: short enough to read at a glance (%d)" % [g["id"], text.length()])
		t.check(not text.to_lower().contains("update"), "%s: does not sound like a software update" % g["id"])
		t.check(not text.contains("Needs"), g["id"] + ": plain wording")
		for other in Data.GOALS:
			t.check(other["id"] != g["id"], "%s: an id of its own, not the stone age's" % g["id"])
	for g in Data.GOALS_ERA2:
		if g.has("tech"):
			t.check(Data.TECHS.has(g["tech"]), g["id"] + ": its tech exists")
		if g.has("building"):
			t.check(Data.BUILDINGS.has(g["building"]), g["id"] + ": its building exists")
	t.check(Data.GOALS_HEADER_ERA2 % [3, 9] == "Dawn goals 3/9", "the counter reads Dawn goals 3/9")


func test_the_dawn_goals_take_over_at_the_dawn() -> void:
	var s: Sim = t.fresh()
	t.check(s.story.goal_list() == Data.GOALS, "the stone age keeps its own list")
	var d := _dawn()
	t.check(d.story.goal_list() == Data.GOALS_ERA2, "after Bronze Dawn the dawn list is in force")
	t.check(
		d.story.done_count() == 0 and d.story.current_goal() == 0,
		"and it starts at the first goal, 0 done: %s" % [d.story.goals_done.keys()]
	)
	t.check(d.story.goals_done.has("bronze"), "the stone age's last goal was met by the dawn itself")
	d.story.goals_done.clear()
	d.story.update(d)
	t.check(
		not d.story.goals_done.has("find_copper") and not d.story.goals_done.has("first_bronze"),
		"no goal of the era is met by the fog or the stockpile of the first tick"
	)


func test_dawn_goals_count_in_any_order() -> void:
	var d := _dawn()
	d.tech_tree.researched.erase("prospecting")
	d.tech_tree.researched.erase("smelting")
	d.story.goals_done.clear()
	d.story.update(d)
	t.check(d.story.done_count() == 0, "nothing done without the techs")
	d.tech_tree.researched["smelting"] = true
	d.story.update(d)
	t.check(d.story.goals_done.has("smelting"), "discovering Smelting first meets its goal")
	t.check(d.story.current_goal() == 0, "the pointer stays on the first goal not done")
	t.check(d.story.done_count() == 1, "and the counter counts it: %d" % d.story.done_count())
	d.tech_tree.researched["prospecting"] = true
	d.story.update(d)
	t.check(d.story.current_goal() == 1 and d.story.done_count() == 2, "Prospecting after it moves the pointer on")


func test_the_ore_goals_follow_the_fog_and_the_road() -> void:
	var d := _dawn()
	d.story.goals_done.clear()
	d.story.update(d)
	t.check(not d.story.goals_done.has("find_copper"), "copper under fog is not found")
	var copper: Array = _ore(d, "copper_hills")
	var tin: Array = _ore(d, "tin_stream")
	t.check(copper.size() >= 14 and tin.size() == 3, "the land has its copper and tin")
	d.fog.reveal(tin[0], 1)
	d.story.update(d)
	t.check(d.story.goals_done.has("find_tin") and not d.story.goals_done.has("find_copper"), "tin is found alone")
	d.fog.reveal(copper[0], 1)
	d.story.update(d)
	t.check(d.story.goals_done.has("find_copper"), "and the copper when a tile of it is in sight")
	t.check(not d.story.goals_done.has("copper_road"), "no road to the copper yet")
	var beside := Vector2i(-1, -1)
	for n in Land.SIDES:
		if d.world.tile_at(copper[0] + n) == "grass":
			beside = copper[0] + n
			break
	if beside.x < 0:
		beside = copper[0] + Vector2i(0, 1)
		d.world.set_tile(beside, "grass")
	d.world.add_road(beside)
	d.story.update(d)
	t.check(d.story.goals_done.has("copper_road"), "a road tile beside the hills meets the road goal")
	t.check(not d.story.goals_done.has("mine"), "and a Mine is its own goal")
	t.check(t.place_free(d, "mine", copper[0]), "a Mine goes on the hills")
	d.story.update(d)
	t.check(d.story.goals_done.has("mine"), "and meets its goal")


func test_the_first_bronze_stays_done() -> void:
	var d := _dawn()
	d.story.goals_done.clear()
	d.economy.inv["bronze"] = 0
	d.story.update(d)
	t.check(not d.story.goals_done.has("first_bronze"), "no Bronze, no goal")
	d.economy.inv["bronze"] = 1
	d.story.update(d)
	t.check(d.story.goals_done.has("first_bronze"), "the first Bronze meets it")
	d.economy.inv["bronze"] = 0
	d.story.update(d)
	t.check(d.story.goals_done.has("first_bronze"), "and spending it later does not undo it")


func test_the_panel_reads_dawn_goals() -> void:
	var d := _dawn()
	d.story.goals_done.clear()
	var panel := SidePanel.new()
	panel.setup(d, 300.0)
	panel.refresh_goals(d)
	t.check(panel.goal_header.text == "Dawn goals 0/9", "the header counts the dawn goals: " + panel.goal_header.text)
	var shown: Array = panel.goal_labels.filter(func(l): return l.visible).map(func(l): return l.text)
	t.check(
		shown == ["> " + Data.GOALS_ERA2[0]["text"], "  " + Data.GOALS_ERA2[1]["text"]],
		"it shows the first dawn goal and the next: %s" % [shown]
	)
	for g in Data.GOALS_ERA2:
		d.story.goals_done[g["id"]] = true
	panel.refresh_goals(d)
	t.check(panel.goal_header.text == "Dawn goals 9/9", "all nine: " + panel.goal_header.text)
	t.check(
		panel.goal_labels[0].visible and panel.goal_labels[0].text == Data.GOALS_ALL_DONE, "then it says it is done"
	)
	t.check(not panel.goal_labels[1].visible, "with no closing line before the star falls")
	d.story.record("star_falling")
	panel.refresh_goals(d)
	t.check(panel.goal_header.text == "Dawn goals 9/9", "the count stays 9/9 after the fall: " + panel.goal_header.text)
	t.check(panel.goal_labels[0].text == Data.GOALS_ALL_DONE, "the first line still says all done")
	t.check(
		panel.goal_labels[1].visible and panel.goal_labels[1].text.strip_edges() == Data.GOALS_STAR_CLOSING,
		"and a closing line says what comes next once the star has fallen"
	)
	t.check(panel.goal_header.tooltip_text.count("Done: ") == 9, "and hovering the count lists them")
	var before := Sim.new()
	before.generate(1)
	panel.refresh_goals(before)
	t.check(panel.goal_header.text == "Goals 0/%d" % Data.GOALS.size(), "a stone-age game still reads Goals n/22")
	panel.free()


func test_the_dawn_banner_is_short() -> void:
	var text: String = Data.ERA_BANNER_TEXT
	var sentences := 0
	for part in text.replace("?", ".").replace("!", ".").split("."):
		sentences += 1 if part.strip_edges() != "" else 0
	t.check(sentences <= 2, "the banner is at most two sentences, not %d: %s" % [sentences, text])
	t.check(text.length() <= 100, "and short (%d characters)" % text.length())
	t.check(text.contains("Look east"), "and still points at Look east")
	t.check(not text.contains("\n"), "on one line")


func test_the_dawn_goals_survive_a_save() -> void:
	var d := _dawn()
	d.tech_tree.researched["smelting"] = true
	d.story.update(d)
	var back := Sim.new()
	t.check(RunSave.restore(back, RunSave.dump(d)), "the save loads")
	t.check(back.story.goal_list() == Data.GOALS_ERA2, "the dawn list is in force again")
	t.check(back.story.goals_done == d.story.goals_done, "with the same goals done")
	t.check(back.story.current_goal() == d.story.current_goal(), "and the same current goal")


func test_the_pointer_points_at_copper_then_tin() -> void:
	var d := _dawn()
	var first := Land.ore_target(d)
	t.check(first.get("ore", "") == "copper_hills", "copper first")
	var copper: Array = _ore(d, "copper_hills")
	var near := 99999.0
	for p in copper:
		near = minf(near, Vector2(p).distance_to(Vector2(d.world.camp_pos)))
	t.check(
		is_equal_approx(Vector2(first["tile"]).distance_to(Vector2(d.world.camp_pos)), near),
		"at the hills nearest the Hearth"
	)
	t.check(not d.fog.is_revealed(first["tile"]), "which are under fog")
	t.check(first["tile"].x >= d.world.stone_width, "in the new land")
	d.fog.reveal(copper[copper.size() - 1], 1)
	var second := Land.ore_target(d)
	t.check(second.get("ore", "") == "tin_stream" and second["tile"].x >= d.world.stone_width, "then the tin")
	for p in _ore(d, "tin_stream"):
		d.fog.reveal(p, 0)
	t.check(Land.ore_target(d).is_empty(), "and nothing once both are in sight")
	var stone := Sim.new()
	stone.generate(3)
	t.check(Land.ore_target(stone).is_empty(), "nothing before the land has grown")


func test_the_pointer_button_hides_and_looks() -> void:
	var d := _dawn()
	var pointer := EastPointer.new()
	pointer.setup()
	t.check(not pointer.visible, "hidden at the start")
	var looked: Array = []
	pointer.look.connect(func(tile): looked.append(tile))
	var stone := Sim.new()
	stone.generate(5)
	pointer.refresh(stone)
	pointer.place(Rect2(0, 0, 800, 600), Vector2(900, 300))
	t.check(not pointer.visible, "and before the dawn")
	pointer.refresh(d)
	var view := Rect2(0, 130, 1016, 560)
	pointer.place(view, Vector2(1500, 300))
	t.check(pointer.visible and pointer.text == "Look east: copper >", "up at the east edge: " + pointer.text)
	t.check(
		pointer.position.x + pointer.size.x <= view.end.x and pointer.position.x > view.end.x - 400.0,
		"at its right edge"
	)
	t.check(
		pointer.position.y >= view.position.y and pointer.position.y + pointer.size.y <= view.end.y, "and inside it"
	)
	pointer.place(view, Vector2(1500, 5000))
	t.check(
		pointer.position.y + pointer.size.y <= view.position.y + view.size.y * 0.7, "kept clear of the lower toasts"
	)
	t.check(pointer.get_theme_font_size("font_size") >= 14, "in text no smaller than 14 px")
	pointer.place(view, Vector2(500, 300))
	t.check(not pointer.visible, "it hides while the ore is already in view")
	pointer.place(view, Vector2(1500, 300))
	pointer._on_pressed()
	t.check(looked == [pointer.target["tile"]], "pressing it asks to look at the ore: %s" % [looked])
	for p in _ore(d, "copper_hills"):
		d.fog.reveal(p, 0)
	pointer.refresh(d)
	t.check(pointer.text == "Look east: tin >", "the copper seen, it points at the tin: " + pointer.text)
	pointer.free()


func test_look_east_halves_the_way() -> void:
	var d := _dawn()
	var target := Vector2i(d.world.stone_width + 8, 4)
	var at := Land.look_east_at(d, target)
	t.check(at.y == target.y, "level with the ore")
	t.check(at.x > d.world.camp_pos.x and at.x < target.x, "between the end of the town and the ore: %s" % at)
	d.world.add_road(Vector2i(d.world.stone_width - 2, 4))
	var later := Land.look_east_at(d, target)
	t.check(later.x > at.x and later.x < target.x, "and further east as the road grows: %s" % later)
	t.check(Land.look_east_at(d, Vector2i(2, 2)).x == 2, "never pointing past an ore that lies behind the road")
