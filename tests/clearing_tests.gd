extends RefCounted
## Clearing natural land (scripts/clearing.gd): the Demolish tool on a resource tile turns it into grass for good. Each
## kind clears; the river, the Hearth, the Strange Stone, ore, unexplored land and the last tile of a kind stay; huts
## re-read their reach; a cleared tile survives a save. Run from tests/run_tests.gd, which owns check() and fresh().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Clearing = preload("res://scripts/clearing.gd")
const Overlays = preload("res://scripts/overlays.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_clearable_set_is_data()
	test_each_resource_kind_clears_to_grass()
	test_the_pill_says_what_is_lost_or_why_it_stays()
	test_the_river_the_shard_ore_and_the_hearth_stay()
	test_unexplored_land_stays()
	test_the_last_tile_of_a_kind_stays()
	test_a_sown_field_is_not_wild_grain()
	test_a_hut_moves_on_when_its_focus_is_cleared()
	test_a_hut_with_nothing_left_has_no_focus()
	test_a_cleared_tile_survives_a_save()
	test_a_road_still_cuts_rocks_and_forest()
	test_the_map_grows_east_after_clearing()


## A tile of `kind` on the map, with `spare` more kept somewhere else so the guard lets it go. A kind the map lacks is
## put down at the top-left grass corner first.
func _tile(s: Sim, kind: String, spare: int = 1) -> Vector2i:
	var found: Array = []
	for y in s.world.height:
		for x in s.world.width:
			if s.world.tile_at(Vector2i(x, y)) == kind and not s.world.fields.has(Vector2i(x, y)):
				found.append(Vector2i(x, y))
	var corner := 0
	while found.size() < spare + 1:
		var q := Vector2i(corner, 0)
		corner += 1
		if s.world.tile_at(q) == "grass" and s.town.built_type(q) == "":
			s.world.set_tile(q, kind)
			found.append(q)
	return found[0]


## Every tile of `kind` turned to grass except `keep`.
func _only(s: Sim, kind: String, keep: Vector2i) -> void:
	for y in s.world.height:
		for x in s.world.width:
			var q := Vector2i(x, y)
			if q != keep and s.world.tile_at(q) == kind:
				s.world.set_tile(q, "grass")


func test_the_clearable_set_is_data() -> void:
	var clearable := []
	for kind in Data.TILES:
		if Data.TILES[kind].get("clearable", false):
			clearable.append(kind)
			t.check(Data.TILES[kind]["yields"] != "", "%s yields something" % kind)
		else:
			t.check(kind == "grass" or Data.TILES[kind].has("stays"), "%s says why it stays" % kind)
	clearable.sort()
	t.check(
		clearable == ["berry", "clay", "flax", "grain", "gravel", "rock", "tree"],
		"the clearable tiles are the seven gatherable kinds: " + str(clearable)
	)


func test_each_resource_kind_clears_to_grass() -> void:
	for kind in ["flax", "tree", "rock", "gravel", "clay", "berry", "grain"]:
		var s: Sim = t.fresh()
		var p := _tile(s, kind)
		var stock := s.economy.inv.duplicate()
		t.check(Clearing.check(s, p)["ok"], "%s can be cleared" % kind)
		t.check(Clearing.clear(s, p) == kind, "clearing it says what it was")
		t.check(s.world.tile_at(p) == "grass", "%s tile is open grass now" % kind)
		t.check(s.economy.inv == stock, "clearing costs nothing and gives nothing back")
		t.check(s.pathing.walk_cost(p) == 1.0, "and the walking cell is plain again")
		t.check(s.events.back() == Data.CLEAR_EVENT % Data.TILES[kind]["name"], "the log says what was cleared")
		t.check(Clearing.clear(s, p) == "", "a cleared tile can't be cleared again")


func test_the_pill_says_what_is_lost_or_why_it_stays() -> void:
	var s: Sim = t.fresh()
	var clay := _tile(s, "clay")
	t.check(Overlays.demolish_text(s, clay) == "Clear Clay Bank · gone for good", Overlays.demolish_text(s, clay))
	var river := _tile(s, "river")
	t.check(
		Overlays.demolish_text(s, river).begins_with("The river stays"),
		"the river: " + Overlays.demolish_text(s, river)
	)
	var grass := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if s.world.tile_at(Vector2i(x, y)) == "grass" and s.town.built_type(Vector2i(x, y)) == "":
				grass = Vector2i(x, y)
	t.check(Overlays.demolish_text(s, grass) == "", "open grass has no pill")
	t.check(Overlays.demolish_text(s, Vector2i(-3, 2)) == "", "off the map has none")


func test_the_river_the_shard_ore_and_the_hearth_stay() -> void:
	var s: Sim = t.fresh()
	var river := _tile(s, "river")
	t.check(not Clearing.check(s, river)["ok"] and Clearing.clear(s, river) == "", "the river stays")
	t.check(s.world.tile_at(river) == "river", "and is still river")
	t.check(not Clearing.check(s, s.world.shard_pos)["ok"], "the Strange Stone stays")
	t.check(Clearing.check(s, s.world.shard_pos)["text"].begins_with("The Strange Stone stays"), "and says so")
	var ore := Vector2i(0, 0)
	for kind in ["copper_hills", "tin_stream"]:
		s.world.set_tile(ore, kind)
		t.check(
			not Clearing.check(s, ore)["ok"] and Clearing.check(s, ore)["text"] != "", "%s stays, with a reason" % kind
		)
		t.check(Clearing.clear(s, ore) == "" and s.world.tile_at(ore) == kind, "%s is untouched" % kind)
	t.check(s.demolish(s.world.camp_pos).is_empty(), "the Hearth is not demolished")
	t.check(not Clearing.check(s, s.world.camp_pos)["ok"], "and is not cleared as land")
	t.check(Overlays.demolish_text(s, s.world.camp_pos).begins_with("The Hearth stays"), "the Hearth pill is unchanged")


func test_unexplored_land_stays() -> void:
	var s: Sim = t.fresh()
	var p := _tile(s, "tree")
	s.fog.cells.fill(0)
	t.check(not Clearing.check(s, p)["ok"], "fogged land can't be cleared")
	t.check(Overlays.demolish_text(s, p) == Data.CLEAR_FOG, "and the pill says unexplored, giving nothing away")
	t.check(Clearing.clear(s, p) == "" and s.world.tile_at(p) == "tree", "the tile is untouched")
	s.fog.reveal(p, 1)
	t.check(Clearing.check(s, p)["ok"], "once seen it can be")


func test_the_last_tile_of_a_kind_stays() -> void:
	for kind in ["flax", "berry", "rock", "gravel", "clay"]:
		var s: Sim = t.fresh()
		var p := _tile(s, kind)
		_only(s, kind, p)
		t.check(not Clearing.check(s, p)["ok"], "the last %s stays" % kind)
		t.check(Clearing.check(s, p)["text"] == Data.CLEAR_LAST % Data.TILES[kind]["name"], "and says so plainly")
		t.check(Clearing.clear(s, p) == "" and s.world.tile_at(p) == kind, "it is still there")
		var other := Vector2i(1, 0) if p != Vector2i(1, 0) else Vector2i(2, 0)
		s.world.set_tile(other, kind)
		t.check(Clearing.check(s, p)["ok"] and Clearing.check(s, other)["ok"], "with a second one either may go")
		t.check(Clearing.clear(s, p) == kind, "so one goes")
		t.check(not Clearing.check(s, other)["ok"], "and then the other is the last")


func test_a_sown_field_is_not_wild_grain() -> void:
	var s: Sim = t.fresh()
	var wild := _tile(s, "grain")
	_only(s, "grain", wild)
	var field := Vector2i(0, 0)
	s.world.set_tile(field, "grass")
	s.world.add_field(field)
	t.check(not Clearing.check(s, wild)["ok"], "sown fields don't count as another Wild Grain")
	t.check(
		s.town.built_type(field) == "field" and not Clearing.check(s, field)["ok"], "a field is demolished, not cleared"
	)


## A square of grass round a spot away from the Hearth, with a hut unlocked: [game, centre].
func _arena() -> Array:
	var s: Sim = t.fresh()
	s.tech_set["gatherers_hut"] = true
	t.give(s, 100)
	var c := s.world.camp_pos
	var at := c + Vector2i(9, 0)
	if not s.world.in_bounds(at + Vector2i(5, 5)):
		at = c + Vector2i(-9, 0)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(at + Vector2i(dx, dy), "grass")
	return [s, at]


func test_a_hut_moves_on_when_its_focus_is_cleared() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.set_tile(p + Vector2i(1, 0), "clay")
	s.world.set_tile(p + Vector2i(2, 1), "gravel")
	s.world.set_tile(p + Vector2i(-3, 0), "gravel")  # the clay and flint sit side by side: the hut picked clay
	t.check(s.place("gatherers_hut", p), "a hut goes down")
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(hut["focus"] == "clay", "it works the clay")
	t.check(
		s.town.focus_options(p) == ["clay", "flint"] or s.town.focus_options(p) == ["flint", "clay"],
		"both are on offer"
	)
	s.world.set_tile(Vector2i(0, 0), "clay")  # clay elsewhere on the map, so the one by the hut may go
	t.check(Clearing.clear(s, p + Vector2i(1, 0)) == "clay", "the clay tile is cleared")
	t.check(not ("clay" in s.town.focus_options(p)), "clay is no longer on offer")
	t.check(hut["focus"] == "flint", "the hut moves on to the flint: " + str(hut["focus"]))
	t.check(not s.town.focus_tiles(hut).is_empty(), "and has tiles to walk out to")
	t.check(s.people.knows_focus(hut) == s.people.knows("flint"), "it works whatever the people know")
	t.check(
		"clay" not in hut["gather_items"] and "flint" in hut["gather_items"], "its remembered reach follows the land"
	)


func test_a_hut_with_nothing_left_has_no_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.set_tile(p + Vector2i(1, 0), "berry")
	s.world.set_tile(Vector2i(0, 0), "berry")  # berries elsewhere, so this one may go
	t.check(s.place("gatherers_hut", p), "a hut goes down")
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(hut["focus"] == "berries", "on the berries")
	t.check(Clearing.clear(s, p + Vector2i(1, 0)) == "berry", "the bushes are cleared")
	t.check(hut["focus"] == "" and s.town.focus_options(p).is_empty(), "it has nothing to work and no focus")
	t.check(s.town.focus_tiles(hut).is_empty() and hut["gather_items"].is_empty(), "and no tiles")
	for i in 10:
		s.tick(0.5)
	t.check(true, "the simulation carries on")


func test_a_cleared_tile_survives_a_save() -> void:
	var s: Sim = t.fresh()
	var p := _tile(s, "clay")
	var q := _tile(s, "tree")
	t.check(Clearing.clear(s, p) == "clay" and Clearing.clear(s, q) == "tree", "two tiles cleared")
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var b: Sim = Sim.new()
	t.check(RunSave.restore(b, d), "a save is loaded")
	t.check(b.world.tile_at(p) == "grass" and b.world.tile_at(q) == "grass", "the cleared tiles are still grass")
	t.check(b.world.tiles == s.world.tiles, "and every other tile is as it was")
	t.check(b.pathing.walk_cost(q) == 1.0, "the walking grid is plain there too")
	t.check(
		RunSave.to_json(RunSave.dump(b)) == RunSave.to_json(RunSave.dump(s)),
		"the loaded game writes back the same save"
	)


func test_a_road_still_cuts_rocks_and_forest() -> void:
	for kind in ["rock", "tree"]:
		var s: Sim = t.fresh()
		var p := _tile(s, kind)
		t.give(s, 100)
		t.check(t.place_free(s, "road", p), "a road goes over %s" % kind)
		t.check(s.world.tile_at(p) == "grass" and s.world.roads.has(p), "and clears it to grass")


func test_the_map_grows_east_after_clearing() -> void:
	var s: Sim = t.fresh()
	var p := _tile(s, "rock")
	Clearing.clear(s, p)
	var w: int = s.world.width
	t.check(s.world.grow_east(), "the map grows east")
	t.check(
		s.world.tile_at(p) == "grass" and s.world.width == w * 2, "the cleared tile is still grass in the grown map"
	)
