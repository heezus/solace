extends RefCounted
## Step 7D, blueprints (scripts/blueprints.gd, design-system/18-roadmap.md "Blueprints as built"): saving a boxed part of the town, laying
## it down as plans that are built in order as the tech, the ground and the stockpile allow, and what the profile banks (only an Exodus
## keeps the run's blueprints). Run from tests/run_tests.gd.

const Blueprints = preload("res://scripts/blueprints.gd")
const Carry = preload("res://scripts/carry.gd")
const Data = preload("res://scripts/data.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")

const SEED := 5

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_saving_a_box_keeps_roads_first_and_never_the_hearth()
	test_six_blueprints_are_held_and_an_empty_box_is_refused()
	test_laying_queues_every_part_on_the_map_once()
	test_plans_wait_for_tech_and_materials_in_order()
	test_a_banked_blueprint_costs_a_share_and_a_fresh_one_costs_full_price()
	test_a_part_that_can_never_go_is_dropped()
	test_an_exodus_banks_the_book_and_other_endings_keep_the_old_one()
	test_the_book_and_the_plans_survive_a_save_and_a_profile_file()


## A Sim with the whole map in view and the first run's tech and stock cleared.
func _sim() -> Sim:
	var s := Sim.new()
	s.generate(SEED)
	s.fog.reveal(s.world.camp_pos, 200)
	return s


## The top left of `w` by `h` open grass tiles, scanning row by row from the Hearth outwards, with a margin of one tile.
func _clearing(s: Sim, w: int, h: int, from := 4) -> Vector2i:
	for y in range(1, s.world.height - h - 1):
		for x in range(1, s.world.width - w - 1):
			var ok := true
			var corner := Vector2i(x, y)
			if maxi(absi(x - s.world.camp_pos.x), absi(y - s.world.camp_pos.y)) < from:
				continue
			for dy in h:
				for dx in w:
					var p := corner + Vector2i(dx, dy)
					if s.world.tile_at(p) != "grass" or s.town.building_at.has(p):
						ok = false
			if ok:
				return corner
	return Vector2i(-1, -1)


## A small yard at `at`: three roads along the top and a Gatherer's Hut under the middle one.
func _yard(s: Sim, at: Vector2i) -> void:
	for dx in 3:
		s.world.add_road(at + Vector2i(dx, 0), 0)
	s.town.add_building("gatherers_hut", at + Vector2i(1, 1))


func _yard_sim() -> Array:
	var s := _sim()
	var at := _clearing(s, 3, 2)
	_yard(s, at)
	return [s, at]


func test_saving_a_box_keeps_roads_first_and_never_the_hearth() -> void:
	var made := _yard_sim()
	var s: Sim = made[0]
	var at: Vector2i = made[1]
	var box := Rect2i(at, Vector2i(3, 2))
	t.check(Blueprints.save(s, box) == "", "a boxed yard saves")
	var bp: Dictionary = s.carry.blueprints[0]
	t.check(bp["items"].size() == 4, "the yard keeps its three roads and its hut (%d)" % bp["items"].size())
	t.check(bp["items"][0]["t"] == "road" and bp["items"][3]["t"] == "gatherers_hut", "roads go down before buildings")
	t.check(bp["items"][3]["x"] == 1 and bp["items"][3]["y"] == 1, "a part is kept as an offset from the box's corner")
	t.check(bp["name"] == Data.EXODUS["bp_name"] % 1, "a new blueprint gets a numbered name")
	var camp := Rect2i(s.world.camp_pos - Vector2i(1, 1), Vector2i(3, 3))
	var s2 := _sim()
	t.check(Blueprints.save(s2, camp) != "" and s2.carry.blueprints.is_empty(), "the Hearth is never kept")


func test_six_blueprints_are_held_and_an_empty_box_is_refused() -> void:
	var made := _yard_sim()
	var s: Sim = made[0]
	var box := Rect2i(made[1], Vector2i(3, 2))
	for i in int(Data.EXODUS["bp_max"]):
		t.check(Blueprints.save(s, box) == "", "blueprint %d saves" % (i + 1))
	t.check(Blueprints.save(s, box) == Data.EXODUS["bp_full"], "a seventh is refused")
	t.check(Blueprints.drop(s, 0) and s.carry.blueprints.size() == 5, "a blueprint can be deleted")
	t.check(not Blueprints.drop(s, 9), "deleting one that is not there does nothing")
	var empty := Rect2i(_clearing(s, 2, 2, 12), Vector2i(2, 2))
	var s2 := _sim()
	t.check(Blueprints.save(s2, empty) == Data.EXODUS["bp_nothing"], "a box over bare ground has nothing to keep")


func test_laying_queues_every_part_on_the_map_once() -> void:
	var made := _yard_sim()
	var src: Sim = made[0]
	var at: Vector2i = made[1]
	Blueprints.save(src, Rect2i(at, Vector2i(3, 2)))
	var s := _sim()
	s.carry.blueprints = src.carry.blueprints.duplicate(true)
	t.check(Blueprints.lay(s, 0, at) == 4 and s.carry.plans.size() == 4, "laying queues a plan for every part")
	Blueprints.lay(s, 0, at)
	t.check(s.carry.plans.size() == 4, "laying the same place twice queues it once")
	t.check(Blueprints.lay(s, 0, Vector2i(s.world.width - 1, 0)) == 1, "parts off the map are left out")
	t.check(Blueprints.lay(s, 7, at) == 0, "a blueprint that is not there lays nothing")


func test_plans_wait_for_tech_and_materials_in_order() -> void:
	var made := _yard_sim()
	var src: Sim = made[0]
	var at: Vector2i = made[1]
	Blueprints.save(src, Rect2i(at, Vector2i(3, 2)))
	var s := _sim()
	s.carry.blueprints = src.carry.blueprints.duplicate(true)
	Blueprints.lay(s, 0, at)
	s.tick(0.1)
	t.check(s.carry.plans.size() == 4 and not s.world.roads.has(at), "nothing is built before its tech is known")
	s.tech_tree.researched["haulers"] = true
	s.economy.inv["wood"] = 2
	s.tick(0.1)
	t.check(s.world.roads.has(at) and s.carry.plans.size() == 3, "the first road goes down when it is paid for")
	t.check(not s.world.roads.has(at + Vector2i(1, 0)), "and the next waits for materials")
	s.economy.inv["wood"] = 10
	s.tick(0.1)
	t.check(
		s.world.roads.has(at + Vector2i(1, 0)) and s.world.roads.has(at + Vector2i(2, 0)),
		"the rest of the road follows"
	)
	t.check(s.carry.plans.size() == 1, "the hut still waits for its tech")
	s.tech_tree.researched["gatherers_hut"] = true
	s.economy.inv["wood"] = 3
	s.economy.inv["stone"] = 9
	s.tick(0.1)
	t.check(s.carry.plans.size() == 1, "a plan held for materials builds nothing short of its price")
	s.economy.inv["wood"] = 12
	s.tick(0.1)
	t.check(
		s.carry.plans.is_empty() and s.town.building_at.has(at + Vector2i(1, 1)),
		"the hut goes up and the queue is empty"
	)
	t.check(
		s.economy.inv["stone"] == 4.0 or int(s.economy.inv["stone"]) == 4, "it cost what a hut costs: nothing is free"
	)


func test_a_banked_blueprint_costs_a_share_and_a_fresh_one_costs_full_price() -> void:
	var made := _yard_sim()
	var src: Sim = made[0]
	var at: Vector2i = made[1]
	Blueprints.save(src, Rect2i(at, Vector2i(3, 2)))
	t.check(not src.carry.blueprints[0]["banked"], "a blueprint saved this run is not banked yet")
	var profile := Profile.new()
	profile.bank(src, "exodus")
	var s := _sim()
	s.carry = profile.carry()
	t.check(s.carry.blueprints[0]["banked"], "one carried from an earlier run is")
	for tech in ["haulers", "gatherers_hut"]:
		s.tech_tree.researched[tech] = true
	Blueprints.lay(s, 0, at)
	t.check(s.carry.plans[0]["b"], "its plans are marked banked")
	s.economy.inv["wood"] = 100
	s.economy.inv["stone"] = 100
	s.tick(0.1)
	t.check(s.carry.plans.is_empty(), "the yard goes up")
	var share: float = Data.EXODUS["bp_share"]
	var road_wood := maxi(ceili(float(Data.BUILDINGS["road"]["cost"]["wood"]) * share - 0.0001), 1)
	var hut: Dictionary = Data.BUILDINGS["gatherers_hut"]["cost"]
	var hut_wood := ceili(float(hut["wood"]) * share - 0.0001)
	var spent_wood := 100 - int(s.economy.inv["wood"])
	t.check(
		spent_wood == 3 * road_wood + hut_wood,
		"three roads and a hut cost the share of their price (%d wood)" % spent_wood
	)
	t.check(
		int(s.economy.inv["stone"]) == 100 - ceili(float(hut["stone"]) * share - 0.0001),
		"and the share of its stone, rounded up"
	)
	t.check(is_equal_approx(s.town.plan_share, 1.0), "the discount is not left on for the player's own building")
	var fresh := _sim()
	fresh.carry.blueprints = src.carry.blueprints.duplicate(true)
	fresh.carry.blueprints[0]["banked"] = false
	for tech in ["haulers", "gatherers_hut"]:
		fresh.tech_tree.researched[tech] = true
	Blueprints.lay(fresh, 0, at)
	fresh.economy.inv["wood"] = 100
	fresh.economy.inv["stone"] = 100
	fresh.tick(0.1)
	var full_wood := 3 * int(Data.BUILDINGS["road"]["cost"]["wood"]) + int(hut["wood"])
	t.check(100 - int(fresh.economy.inv["wood"]) == full_wood, "a blueprint saved this run costs full price")


func test_a_part_that_can_never_go_is_dropped() -> void:
	var s := _sim()
	s.tech_tree.researched["haulers"] = true
	s.economy.inv["wood"] = 20
	var at := _clearing(s, 3, 2)
	s.world.add_road(at + Vector2i(1, 0), 0)  # a road already stands in the middle
	s.carry.blueprints = [
		{
			"name": "Test",
			"w": 3,
			"h": 1,
			"items": [{"t": "road", "x": 0, "y": 0}, {"t": "gatherers_hut", "x": 1, "y": 0}]
		}
	]
	Blueprints.lay(s, 0, at)
	s.tick(0.1)
	t.check(
		s.carry.plans.size() == 1, "the part that fits goes down and the one on a road is dropped or waits for its tech"
	)
	s.tech_tree.researched["gatherers_hut"] = true
	s.tick(0.1)
	t.check(s.carry.plans.is_empty(), "a hut on a road can never go and is dropped")


func test_an_exodus_banks_the_book_and_other_endings_keep_the_old_one() -> void:
	var made := _yard_sim()
	var s: Sim = made[0]
	var box := Rect2i(made[1], Vector2i(3, 2))
	Blueprints.save(s, box)
	var profile := Profile.new()
	profile.bank(s, "exodus")
	t.check(profile.blueprints.size() == 1, "an Exodus banks the blueprints the run saved")
	var next := profile.carry()
	t.check(next.blueprints.size() == 1, "the next run begins with them")
	var s2 := _sim()
	s2.carry = next
	_yard(s2, made[1])
	Blueprints.save(s2, box)
	Blueprints.save(s2, box)
	profile.bank(s2, "cataclysm")
	t.check(profile.blueprints.size() == 1, "a Cataclysm loses the ones the run saved and keeps the ones banked before")
	profile.bank(s2, "loop")
	t.check(profile.blueprints.size() == 1, "so does the Time loop")
	profile.bank(s2, "exodus")
	t.check(profile.blueprints.size() == 3, "and a later Exodus banks the whole book")


func test_the_book_and_the_plans_survive_a_save_and_a_profile_file() -> void:
	var made := _yard_sim()
	var s: Sim = made[0]
	Blueprints.save(s, Rect2i(made[1], Vector2i(3, 2)))
	Blueprints.lay(s, 0, made[1])
	var again := Carry.new()
	again.from_dict(JSON.parse_string(JSON.stringify(s.carry.to_dict())))
	t.check(
		again.blueprints.size() == 1 and again.plans.size() == 4,
		"the carry keeps its blueprints and plans through a save"
	)
	t.check(again.blueprints[0]["items"].size() == 4, "with every part")
	var profile := Profile.new()
	profile.bank(s, "exodus")
	var copy := Profile.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	t.check(copy.blueprints.size() == 1, "the profile keeps its blueprints through its file")
	var old := profile.to_dict()
	old.erase("blueprints")
	copy.from_dict(old)
	t.check(
		copy.blueprints.is_empty() and copy.runs == 1, "a version 3 profile written before blueprints loads with none"
	)
