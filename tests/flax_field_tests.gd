extends RefCounted
## The Flax Field (Jon's request, 2026-10-03: "I think we need an ability to plant fiber"). Flax is sown by dragging on
## open grassland for 2 Fiber, once Cordage is known; a hut set to Fiber cuts it exactly as it cuts a wild patch, and
## a sown tile, like a wild one, never runs out. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Work = preload("res://scripts/work.gd")
const Rules = preload("res://scripts/rules.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_card_sits_in_the_gathering_tab_and_needs_cordage()
	test_sowing_costs_fiber_and_marks_the_tile()
	test_it_goes_only_on_open_grass()
	test_demolishing_gives_half_the_fiber_back_and_the_grass_returns()
	test_a_hut_on_fiber_cuts_a_flax_field()
	test_a_sown_tile_yields_as_wild_flax_and_gets_no_grain_bonus()
	test_flax_fields_survive_a_save()
	test_an_old_save_has_no_flax_fields()
	test_the_tile_is_called_a_flax_field()


## A game with Cordage known, 100 of everything, and a cleared square of grass (radius 4) away from the Hearth.
## Returns [game, centre].
func _arena() -> Array:
	var s: Sim = t.fresh()
	s.tech_tree.researched["cordage"] = true
	s.tech_tree.researched["gatherers_hut"] = true
	s.tech_tree.researched["farming"] = true  # so a grain field can be set beside the flax
	t.give(s, 100)
	var c := s.world.camp_pos
	var at := Vector2i(-1, -1)
	for off in [Vector2i(9, 0), Vector2i(-9, 0), Vector2i(0, 8), Vector2i(0, -8)]:
		var p: Vector2i = c + off
		if s.world.in_bounds(p - Vector2i(5, 5)) and s.world.in_bounds(p + Vector2i(5, 5)):
			at = p
			break
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(at + Vector2i(dx, dy), "grass")
	return [s, at]


func test_the_card_sits_in_the_gathering_tab_and_needs_cordage() -> void:
	var def: Dictionary = Data.BUILDINGS["flax_field"]
	t.check(Data.BUILD_TABS["Gathering"].has("flax_field"), "it is on the Gathering tab")
	t.check(Data.BUILD_TABS["Gathering"].size() == 4, "the tab has four cards")
	t.check(Data.BUILD_ORDER.has("flax_field"), "and in the build order")
	t.check(def["kind"] == "field" and def["cost"] == {"fiber": 2}, "a field that costs 2 fiber and no grain")
	t.check(def["tech"] == "cordage" and Data.TECHS.has(def["tech"]), "it comes with Cordage")
	t.check(Rules.buildings_of("cordage").has("flax_field"), "Cordage lists it")
	t.check(Data.TECHS["cordage"]["unlock"].contains("Flax Field"), "and says so on its card")
	t.check(not def["desc"].is_empty() and def["desc"].length() < 130, "with a short plain description")
	var s: Sim = t.fresh()
	t.give(s, 100)
	var p := s.world.camp_pos + Vector2i(0, 3)
	s.world.set_tile(p, "grass")
	t.check(not s.town.unlocked("flax_field"), "locked at the start")
	t.check(s.town.placement_error("flax_field", p) == "Not discovered yet", "and it says why")
	t.check(not s.place("flax_field", p) and s.world.flax_fields.is_empty(), "nothing is sown while it is locked")
	s.tech_tree.researched["cordage"] = true
	t.check(s.town.unlocked("flax_field"), "Cordage opens it")
	t.check(not s.tech_tree.researched.has("farming"), "Farming is not needed")
	t.check(s.town.placement_error("flax_field", p) == "", "and the spot takes it")


func test_sowing_costs_fiber_and_marks_the_tile() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.economy.inv["grain"] = 0
	s.economy.inv["fiber"] = 5
	t.check(s.place("flax_field", p), "sown with no grain in the stockpile")
	t.check(s.economy.inv["fiber"] == 3, "it cost 2 fiber")
	t.check(s.world.tile_at(p) == "flax" and s.world.flax_fields.has(p), "the tile is flax and remembered as sown")
	t.check(not s.world.fields.has(p), "it is not a grain field")
	t.check(s.town.built_type(p) == "flax_field", "built_type names it")
	t.check(s.town.buildings.size() == 1 and not s.town.building_at.has(p), "it is not a building")
	s.economy.inv["fiber"] = 1
	t.check(s.town.placement_error("flax_field", p + Vector2i(1, 0)) == "Not enough materials", "1 fiber is too little")
	t.check(not s.place("flax_field", p + Vector2i(1, 0)) and s.economy.inv["fiber"] == 1, "so nothing is sown or paid")
	var line := Rules.line_tiles(p + Vector2i(0, 1), p + Vector2i(3, 1))
	s.economy.inv["fiber"] = 6
	t.check(s.place_line("flax_field", line) == 3, "a drag sows as many tiles as the fiber pays for")
	t.check(s.economy.inv["fiber"] == 0 and s.world.flax_fields.size() == 4, "three more at 2 fiber each")


func test_it_goes_only_on_open_grass() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	var cases := {"river": 1, "rock": 2, "tree": 3, "flax": 4, "grain": 5, "berry": 6, "clay": 7, "gravel": 8}
	for tile in cases:
		s.world.set_tile(p + Vector2i(cases[tile] - 4, 0), tile)
		var err := s.town.placement_error("flax_field", p + Vector2i(cases[tile] - 4, 0))
		t.check(err == "Fields go on open grassland", "no flax field on %s (%s)" % [tile, err])
		t.check(not s.place("flax_field", p + Vector2i(cases[tile] - 4, 0)), "and place refuses on %s" % tile)
	t.check(s.world.flax_fields.is_empty(), "nothing was sown")
	var wild := p + Vector2i(0, 2)
	s.world.set_tile(wild, "flax")
	t.check(s.town.placement_error("flax_field", wild) != "", "not on a wild flax patch")
	var sown := p + Vector2i(0, 3)
	t.check(s.place("flax_field", sown), "set up: a flax field")
	t.check(s.town.placement_error("flax_field", sown) != "", "not on a flax field again")
	var grain := p + Vector2i(1, 3)
	t.check(s.place("field", grain), "set up: a grain field")
	t.check(s.town.placement_error("flax_field", grain) != "", "not on a grain field")
	t.check(s.town.placement_error("field", sown) != "", "and a grain field cannot go on flax")
	var road := p + Vector2i(2, 3)
	s.tech_tree.researched["haulers"] = true
	t.check(s.place("road", road), "set up: a road")
	t.check(s.town.placement_error("flax_field", road) == "Something is already there", "not on a road")
	t.check(not s.place("flax_field", Vector2i(-1, -1)), "not off the map")


func test_demolishing_gives_half_the_fiber_back_and_the_grass_returns() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(s.place("flax_field", p), "set up: a flax field")
	var fiber: int = s.economy.inv["fiber"]
	var refund := s.demolish(p)
	t.check(refund == {"fiber": 1}, "half of 2 fiber comes back")
	t.check(s.economy.inv["fiber"] == fiber + 1, "into the stockpile")
	t.check(s.world.tile_at(p) == "grass" and s.world.flax_fields.is_empty(), "the grass comes back")
	t.check(s.town.built_type(p) == "", "nothing stands there")
	t.check(s.place("flax_field", p), "and it can be sown again")


func test_a_hut_on_fiber_cuts_a_flax_field() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(s.place("flax_field", p + Vector2i(1, 0)), "a flax field beside the spot")
	t.check(s.place("flax_field", p + Vector2i(1, 1)), "and another")
	t.check(s.town.default_focus(p) == "fiber", "a hut here would start on Fiber")
	t.check(s.town.focus_options(p) == ["fiber"], "Fiber is its one choice")
	t.check(s.town.tiles_of(p, "fiber").size() == 2, "it reaches both tiles")
	s.people.learned_by["fiber"] = "Aro"
	s.pathing.build()
	t.check(s.place("gatherers_hut", p), "the hut goes down")
	var i: int = s.town.building_at[p]
	t.check(s.town.buildings[i]["focus"] == "fiber", "set to Fiber")
	var before: int = s.economy.inv["fiber"]
	var got := 0
	var had := false
	for _n in 1200:
		s.town.buildings[i]["trips"] = 3
		s.tick(0.1)
		var w: int = s.town.buildings[i]["worker"]
		if w < 0:
			continue
		var carry: Dictionary = s.people.kith[w]["carry"]
		if not carry.is_empty() and not had:
			got += carry.get("fiber", 0)
			t.check(carry.size() == 1 and carry.has("fiber"), "it carries fiber and nothing else")
		had = not carry.is_empty()
	print("Hut on a flax field, two minutes: %d fiber" % got)
	t.check(got >= 10, "two minutes bring a good haul of fiber (%d)" % got)
	t.check(s.economy.inv["fiber"] > before or s.town.buildings[i]["out"].get("fiber", 0) > 0, "and the fiber arrives")
	t.check(
		s.world.flax_fields.has(p + Vector2i(1, 0)) and s.world.tile_at(p + Vector2i(1, 0)) == "flax",
		"it never ran out"
	)
	s.place("flax_field", p + Vector2i(-1, 0))
	t.check(s.town.tiles_of(p, "fiber").size() == 3, "a third tile joins the hut's reach")


func test_a_sown_tile_yields_as_wild_flax_and_gets_no_grain_bonus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.place("gatherers_hut", p)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	var wild := p + Vector2i(0, 2)
	var sown := p + Vector2i(0, 3)
	s.world.set_tile(wild, "flax")
	s.place("flax_field", sown)
	for tech in ["calendar", "plough", "bronze_ploughshare", "irrigation"]:
		s.tech_tree.researched[tech] = true
	var wild_total := 0
	var sown_total := 0
	for _n in 8:
		wild_total += Work.harvest_amount(s, hut, wild, "fiber")
		sown_total += Work.harvest_amount(s, hut, sown, "fiber")
	t.check(
		wild_total == sown_total,
		"eight harvests of a flax field match a wild patch (%d, %d)" % [sown_total, wild_total]
	)
	t.check(is_equal_approx(Work.harvest_time(s, hut, sown), Work.time(s, hut)), "and take as long, whatever the river")


func test_flax_fields_survive_a_save() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.place("flax_field", p)
	s.place("flax_field", p + Vector2i(2, 2))
	s.place("field", p + Vector2i(-2, 0))
	var d := RunSave.dump(s)
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.from_json(RunSave.to_json(d))), "a save with flax fields loads")
	t.check(copy.world.flax_fields.size() == 2 and copy.world.flax_fields.has(p + Vector2i(2, 2)), "they are back")
	t.check(copy.world.tile_at(p) == "flax" and copy.world.fields.size() == 1, "the grain field is a separate list")
	t.check(copy.town.built_type(p) == "flax_field", "and still known as built")
	t.check(RunSave.to_json(RunSave.dump(copy)) == RunSave.to_json(d), "and it writes back the same")
	var wild: Vector2i = t.find_tile(s, "flax")
	t.check(wild.x >= 0 and not copy.world.flax_fields.has(wild), "wild flax stays wild")


func test_an_old_save_has_no_flax_fields() -> void:
	var a := _arena()
	var s: Sim = a[0]
	s.place("flax_field", a[1])
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	d["world"].erase("flax_fields")  # a save from before flax could be sown
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a save without the list still loads")
	t.check(copy.world.flax_fields.is_empty(), "with no flax fields")
	t.check(copy.world.tile_at(a[1]) == "flax", "the tile itself is flax, as saved")


func test_the_tile_is_called_a_flax_field() -> void:
	var def: Dictionary = Data.BUILDINGS["flax_field"]
	t.check(def["name"] == "Flax Field" and not def["desc"].contains("wild"), "plain words, no 'wild' on the card")
	t.check(Data.TILES["flax"]["yields"] == "fiber", "flax yields fiber")
