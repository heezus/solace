extends RefCounted
## A road runs through a building (design-system/14-hands-to-haulers.md): road, building, road is one network, so
## what stands past the building is served, and haulers and carts walk through its cell. Run from tests/run_tests.gd,
## which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Roads = preload("res://scripts/roads.gd")
const World = preload("res://scripts/world.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_road_runs_through_a_building()
	test_through_roads_follow_demolish_and_save()
	test_depots_are_where_a_road_ends()


## A road from the Hearth to one road tile `west`, a hut right after it, one more road tile and another hut past that:
## a straight line of four cells along `step` (east or south). Returns {"sim", "hut", "road_in" (the tile the Hearth's
## road reaches), "far" (the road tile past the hut), "beyond" (the second hut's tile)}, or {} when no such line of open
## grass was found.
func passage_camp(step: Vector2i) -> Dictionary:
	var s: Sim = t.fresh()
	s.tech_tree.researched["haulers"] = true
	var camp := s.world.camp_pos
	var found := Vector2i(-1, -1)
	var best_d := INF
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			var d := Vector2(p).distance_to(Vector2(camp))
			if d < 5.0 or d >= best_d:
				continue
			var line_ok := true
			for k in 4:
				var q: Vector2i = p + step * k
				line_ok = line_ok and s.world.in_bounds(q) and s.world.tile_at(q) == "grass"
				line_ok = line_ok and not s.town.building_at.has(q) and q != camp
			if line_ok:
				found = p
				best_d = d
	if found.x < 0:
		return {}
	var road_in: Vector2i = found
	var hut: Vector2i = found + step
	var far: Vector2i = hut + step
	var beyond: Vector2i = far + step
	if not t.place_free(s, "gatherers_hut", hut):
		return {}
	t.road_link(s, road_in)
	s.world.roads[road_in] = true
	s.world.roads[far] = true
	s.pathing.update_cell(road_in)
	s.pathing.update_cell(far)
	s.town.road_rev += 1
	if not t.place_free(s, "gatherers_hut", beyond):
		return {}
	return {"sim": s, "hut": hut, "road_in": road_in, "far": far, "beyond": beyond}


func test_a_road_runs_through_a_building() -> void:
	var made := 0
	for step in [Vector2i(1, 0), Vector2i(0, 1)]:
		var c := passage_camp(step)
		if c.is_empty():
			continue
		made += 1
		var s: Sim = c["sim"]
		var beyond: Dictionary = s.town.buildings[s.town.building_at[c["beyond"]]]
		var hut: Dictionary = s.town.buildings[s.town.building_at[c["hut"]]]
		t.check(Roads.linked(s, hut), "the hut by the Hearth's road is linked (step %s)" % step)
		t.check(Roads.linked(s, beyond), "so is the hut past it, through the first hut (step %s)" % step)
		t.check(Roads.road_linked(s, beyond), "and by a road, not by standing beside a depot (step %s)" % step)
		t.check(Roads.cart_can_reach(s, c["road_in"], c["far"]), "a cart rolls through the hut's cell (step %s)" % step)
	t.check(made == 2, "the setup found open ground along both axes (%d of 2)" % made)


func test_through_roads_follow_demolish_and_save() -> void:
	var c := passage_camp(Vector2i(1, 0))
	t.check(not c.is_empty(), "set up: a passage")
	if c.is_empty():
		return
	var s: Sim = c["sim"]
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run loads through JSON text")
	var past2: Dictionary = s2.town.buildings[s2.town.building_at[c["beyond"]]]
	t.check(Roads.linked(s2, past2), "a loaded run still runs through the building")
	s.demolish(c["hut"])
	var past: Dictionary = s.town.buildings[s.town.building_at[c["beyond"]]]
	t.check(not Roads.linked(s, past), "pulling the hut down cuts the road again")
	t.check(not Roads.cart_can_reach(s, c["road_in"], c["far"]), "and nothing rolls through the gap")
	t.check(t.place_free(s, "gatherers_hut", c["hut"]), "building it again")
	t.check(Roads.linked(s, past), "joins the road once more")


func test_depots_are_where_a_road_ends() -> void:
	var c := passage_camp(Vector2i(1, 0))
	if c.is_empty():
		return
	var s: Sim = c["sim"]
	t.check(Roads.depots(s).has(s.world.camp_pos), "the Hearth is a depot")
	t.check(not Roads._passage(s, s.world.camp_pos), "a road doesn't run through the Hearth")
	t.check(Roads._passage(s, c["hut"]), "a hut is a passage")
	t.check(Data.PASSAGE_COST > 1.0, "walking through a building costs more than the open road")
