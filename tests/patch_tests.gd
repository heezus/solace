extends RefCounted
## More tiles of a hut's resource in reach make it work faster (playtest 2026-10-03: "one field vs 50 fields doesn't seem
## different to me, the workers only need 1 of a resource to go gather it"): the Speed table, the cap, wild tiles and Fields
## counting alike, what the hut and the tile say about it, and that nothing but a hut feels it. Run from tests/run_tests.gd,
## which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Work = preload("res://scripts/work.gd")
const Patch = preload("res://scripts/patch.gd")
const PatchRate = preload("res://scripts/patch_rate.gd")
const PatchText = preload("res://scripts/patch_text.gd")
const FieldText = preload("res://scripts/field_text.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_speed_table_and_its_cap()
	test_a_hut_works_faster_with_more_tiles_in_reach()
	test_fields_count_like_wild_tiles()
	test_only_the_huts_resource_counts()
	test_workshops_feel_no_patch()
	test_the_words_say_where_the_hut_stands()
	test_a_field_says_what_one_more_tile_is_worth()
	test_a_full_hut_says_more_fields_add_nothing()
	test_the_panel_and_the_pill()


## A game with a cleared square of grass (radius 4) away from the Hearth, a hut at its centre on `n` clay tiles in a block
## to the east (room for up to 12 in reach). Returns [game, hut position].
func _arena(n: int) -> Array:
	var s: Sim = t.fresh()
	t.give(s, 100)
	var c := s.world.camp_pos
	var at := c + Vector2i(9, 0)
	if not s.world.in_bounds(at + Vector2i(5, 5)):
		at = c - Vector2i(9, 0)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(at + Vector2i(dx, dy), "grass")
	_clay(s, at, n)
	t.check(t.place_free(s, "gatherers_hut", at), "the hut goes down")
	s.town.set_focus(s.town.building_at[at], "clay")
	return [s, at]


## Make clay tiles around `at` until `n` are in its reach (never on the hut's own tile).
func _clay(s: Sim, at: Vector2i, n: int) -> void:
	var made := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := at + Vector2i(dx, dy)
			if p != at and made < n and s.world.tile_at(p) == "grass":
				s.world.set_tile(p, "clay")
				made += 1


func _hut(a: Array) -> Dictionary:
	return a[0].town.buildings[a[0].town.building_at[a[1]]]


func test_the_speed_table_and_its_cap() -> void:
	var step: float = Data.PATCH_STEP
	t.check(Patch.bonus(0) == 0.0 and Patch.bonus(1) == 0.0, "no bonus for none, or for one tile")
	t.check(is_equal_approx(Patch.bonus(2), step), "the second tile adds one step")
	t.check(is_equal_approx(Patch.bonus(4), step * 3.0), "four tiles: three steps")
	t.check(
		is_equal_approx(Patch.bonus(Data.PATCH_MAX_TILES), step * (Data.PATCH_MAX_TILES - 1)),
		"the cap's tile: all steps"
	)
	t.check(
		Patch.bonus(Data.PATCH_MAX_TILES + 6) == Patch.bonus(Data.PATCH_MAX_TILES), "more than the cap adds nothing"
	)
	t.check(Patch.is_full(Data.PATCH_MAX_TILES) and not Patch.is_full(Data.PATCH_MAX_TILES - 1), "full at the cap")


func test_a_hut_works_faster_with_more_tiles_in_reach() -> void:
	var one := _arena(1)
	var four := _arena(4)
	var full := _arena(Data.PATCH_MAX_TILES)
	var many := _arena(12)
	var base: float = Data.BUILDINGS["gatherers_hut"]["time"]
	t.check(is_equal_approx(Work.time(one[0], _hut(one)), base), "one tile: the plain %.1f s" % base)
	t.check(
		is_equal_approx(Work.time(four[0], _hut(four)), base / (1.0 + Data.PATCH_STEP * 3.0)),
		"four tiles: %.2f s" % Work.time(four[0], _hut(four))
	)
	t.check(Work.time(full[0], _hut(full)) < Work.time(four[0], _hut(four)), "the cap's tiles are faster than four")
	t.check(
		is_equal_approx(Work.time(many[0], _hut(many)), Work.time(full[0], _hut(full))),
		"twelve tiles work no faster than the cap's: more only means it has plenty"
	)
	t.check(
		Work.text(four[0], _hut(four)).contains("Patch: 4 tiles in reach, Speed x1.3"),
		"the exact numbers say it too: " + Work.text(four[0], _hut(four))
	)
	t.check(not Work.text(one[0], _hut(one)).contains("Patch:"), "one tile: no patch line")
	var rate_one := PatchRate.per_minute(one[0], _hut(one), one[0].town.focus_tiles(_hut(one)), "clay")
	var rate_four := PatchRate.per_minute(four[0], _hut(four), four[0].town.focus_tiles(_hut(four)), "clay")
	t.check(rate_four > rate_one * 1.1, "and brings more a minute: %.1f against %.1f" % [rate_four, rate_one])


func test_fields_count_like_wild_tiles() -> void:
	var a := _arena(0)
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.set_tile(p + Vector2i(1, 0), "grain")  # one wild grain
	s.town.set_focus(s.town.building_at[p], "grain")
	var b := _hut(a)
	b["focus"] = "grain"
	t.check(Patch.speed(s, b) == 1.0, "one wild grain tile: no bonus")
	for i in 3:
		s.world.add_field(p + Vector2i(-1, -1 + i))
	t.check(
		is_equal_approx(Patch.speed(s, b), 1.0 + Data.PATCH_STEP * 3.0),
		"three Fields beside it: four tiles, three steps"
	)
	s.world.remove_field(p + Vector2i(-1, -1))
	t.check(is_equal_approx(Patch.speed(s, b), 1.0 + Data.PATCH_STEP * 2.0), "tear one down and it slows one step")


func test_only_the_huts_resource_counts() -> void:
	var a := _arena(2)
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	for i in 4:
		s.world.set_tile(p + Vector2i(2, -2 + i), "tree")
	var b := _hut(a)
	t.check(is_equal_approx(Patch.speed(s, b), 1.0 + Data.PATCH_STEP), "two clay tiles count; the four trees do not")
	s.town.set_focus(s.town.building_at[p], "wood")
	t.check(is_equal_approx(Patch.speed(s, b), 1.0 + Data.PATCH_STEP * 3.0), "switched to Wood, the four trees count")


func test_workshops_feel_no_patch() -> void:
	var a := _arena(Data.PATCH_MAX_TILES)
	var s: Sim = a[0]
	var spot: Vector2i = a[1] + Vector2i(0, 3)
	t.check(t.place_free(s, "twine_post", spot), "a Twine Post goes down by the clay")
	var post: Dictionary = s.town.buildings[s.town.building_at[spot]]
	t.check(Patch.speed(s, post) == 1.0, "a workshop is not a hut: no patch speed")


func test_the_words_say_where_the_hut_stands() -> void:
	var one := PatchText.tiles_line("clay", 1)
	t.check(one.begins_with("1 Clay tile in range: enough to work."), "one tile is enough to work: " + one)
	t.check(one.contains("+10% speed") and one.contains("up to +70% at 8 tiles"), "and says what more adds: " + one)
	var some := PatchText.tiles_line("clay", 4)
	t.check(some.begins_with("4 Clay tiles in range: +30% speed."), "four tiles: " + some)
	var full := PatchText.tiles_line("clay", Data.PATCH_MAX_TILES)
	t.check(full.contains("+70% speed, the most a patch gives"), "the cap: " + full)
	t.check(full.contains("More tiles will not help this hut"), "and says more do not help: " + full)
	t.check(PatchText.tiles_line("clay", 0) == "", "none: nothing to say")
	t.check(PatchText.tiles_line("clay", 11).contains("+70%"), "past the cap it still says +70%")


func test_a_field_says_what_one_more_tile_is_worth() -> void:
	var a := _arena(0)
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	for i in 3:
		s.world.add_field(p + Vector2i(1, -1 + i))
	var b := _hut(a)
	s.town.set_focus(s.town.building_at[p], "grain")
	b["worker"] = 0
	var field := p + Vector2i(1, 0)
	var gain := PatchRate.tile_gain(s, b, field, "grain")
	t.check(gain > 0.0, "a field beside a hut with two others is worth something (%.2f a minute)" % gain)
	var line := FieldText.gain_line(s, field, "grain")
	t.check(line.begins_with("Each field adds +10% to the hut's speed"), "line: " + line)
	t.check(line.contains("about +%s Grain a minute" % FieldText.num(gain)), "with the live number: " + line)
	var lone := _arena(0)
	var s2: Sim = lone[0]
	s2.world.add_field(lone[1] + Vector2i(1, 0))
	_hut(lone)["focus"] = "grain"
	var first := FieldText.gain_line(s2, lone[1] + Vector2i(1, 0), "grain")
	t.check(first.begins_with("It is the only Grain tile this hut has"), "a hut's only tile says so: " + first)
	t.check(FieldText.gain_line(s, p + Vector2i(-4, 0), "grain") == "", "far from every hut: no line")


func test_a_full_hut_says_more_fields_add_nothing() -> void:
	var a := _arena(0)
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	var made := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := p + Vector2i(dx, dy)
			if q != p and made < Data.PATCH_MAX_TILES:
				s.world.add_field(q)
				made += 1
	_hut(a)["focus"] = "grain"
	var extra := p + Vector2i(2, 2)
	t.check(s.world.fields.size() == Data.PATCH_MAX_TILES, "fixture: the cap's worth of fields")
	var inside := FieldText.gain_line(s, p + Vector2i(0, -2), "grain")
	t.check(inside.begins_with("Each field adds +10%"), "one of the six still gives the hut a step: " + inside)
	var more := FieldText.gain_line(s, extra, "grain")
	t.check(more.begins_with("The hut already has %d tiles in reach" % Data.PATCH_MAX_TILES), "a seventh: " + more)
	t.check(more.contains("adds nothing"), "and says so plainly: " + more)
	s.world.add_field(extra)
	t.check(
		is_equal_approx(Patch.speed(s, _hut(a)), 1.0 + Patch.bonus(Data.PATCH_MAX_TILES)),
		"and the hut is no faster for it"
	)


func test_the_panel_and_the_pill() -> void:
	var a := _arena(4)
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	var b := _hut(a)
	var panel := PatchText.panel_text(s, b)
	t.check(panel.contains("4 Clay tiles in range: +30% speed"), "the hut's panel: " + panel)
	t.check(not panel.contains("Fields"), "no Fields, no Fields line")
	s.world.set_tile(p + Vector2i(0, 2), "grass")
	s.world.add_field(p + Vector2i(0, 2))
	t.check(PatchText.panel_text(s, b) == panel, "a Field of another crop is not this hut's patch")
	t.check(PatchText.placement_text(s, p).contains("4 Clay tiles in range"), "the placement line names the resource")
	t.check(PatchText.pill_text(s, p).begins_with("Clay x4"), "and the pill: " + PatchText.pill_text(s, p))
	t.check(PatchText.pill_text(s, p + Vector2i(0, 2)) == "", "a spot with nothing in reach has no pill")
	t.check(PatchText.with_pill(s, "twine_post", p, "note") == "note", "only a hut's ghost gets the pill")
	t.check(
		PatchText.with_pill(s, "gatherers_hut", p + Vector2i(0, 2), "note") == "note",
		"and none when there is nothing to say"
	)
	var grain := _arena(0)
	var gs: Sim = grain[0]
	var gp: Vector2i = grain[1]
	for i in 3:
		gs.world.add_field(gp + Vector2i(1, -1 + i))
	_hut(grain)["focus"] = "grain"
	var gpanel := PatchText.panel_text(gs, _hut(grain))
	t.check(gpanel.contains("3 of its 3 tiles are Fields."), "a hut on Fields says so: " + gpanel)
