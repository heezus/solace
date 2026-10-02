extends RefCounted
## Unit testbench for the Kith block (scripts/kith.gd): population growth against housing and food,
## starvation, names, job assignment, walking, dropping a task when its building goes, tool wear, job
## titles and the walk to a depot. The block is built alone: a hand-made World, the Pathing grid over it, an
## Economy with a hand-set stockpile, a hand-set set of researched techs and a Buildings block, with a
## test method standing in for the player's message list. No fog block and no Sim. The last tests
## check the Sim's people and that its tick still calls the block in the same order.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Sim = preload("res://scripts/sim.gd")
const Kith = preload("res://scripts/kith.gd")
const Monitor = preload("res://tests/monitor.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Research = preload("res://scripts/research.gd")
const RunSave = preload("res://scripts/run_save.gd")
const World = preload("res://scripts/world.gd")

var t  # the runner, tests/run_tests.gd
var _techs: Dictionary = {}  # the researched techs
var _eco: Economy
var _world: World
var _pathing: Pathing
var _town: Buildings
var _events: Array = []  # what the block told the player
var _camp := Vector2i(1, 4)


func run(runner) -> void:
	t = runner
	test_found_and_names()
	test_names_come_round()
	test_births_need_time_room_and_food()
	test_housing_is_the_cap()
	test_storytelling_shortens_the_wait()
	test_starvation_removes_one()
	test_the_last_one_stays()
	test_the_one_who_leaves_is_not_working()
	test_jobs_go_in_build_order()
	test_the_rest_idle_then_haul()
	test_idle_come_before_haulers()
	test_a_paused_building_is_skipped()
	test_a_hauler_is_taken_off_its_task()
	test_a_new_worker_takes_a_spare_tool()
	test_walking_step_by_step()
	test_roads_are_faster()
	test_no_way_there()
	test_release_a_worker()
	test_drop_a_task()
	test_tasks_follow_a_demolished_building()
	test_worker_home()
	test_tool_wear()
	test_tool_wears_out_and_is_replaced()
	test_job_titles()
	test_knowing_what_to_gather()
	test_nearest_depot_and_trip()
	test_a_trip_cut_off_by_water()
	test_signals_for_births_and_leavers()
	test_signals_for_lessons_and_trips()
	test_to_dict_and_from_dict()
	test_sim_starts_with_the_first_people()
	test_sim_ticks_through_the_block()


func _seen(_p: Vector2i) -> bool:
	return true


func _shard_seen() -> bool:
	return false


func _has_tech(id: String) -> bool:
	return _techs.has(id)


func _note(message: String) -> void:
	_events.append(message)


## A Kith block on a 12 by 8 map of grass with the Hearth at (1, 4) and `count` people at the Hearth, an
## Economy that holds exactly `stock` (every other count zero, no food credit) and the techs in `done`
## researched. The pieces are left in _world, _pathing, _eco, _town and _techs for a test to look at.
func _block(count: int = 0, stock: Dictionary = {}, done: Array = []) -> Kith:
	_techs = {}
	for id in done:
		_techs[id] = true
	_events = []
	_eco = Economy.new(_techs)
	for id in _eco.inv:
		_eco.inv[id] = 0
	for id in stock:
		_eco.inv[id] = stock[id]
	_eco.food_credit = 0.0
	_world = World.new(12, 8)
	_world.camp_pos = _camp
	_pathing = Pathing.new(_world, _has_tech)
	_pathing.build()
	var research := Research.new(_eco, _techs, _shard_seen)
	_town = Buildings.new(_world, _eco, research, _seen)
	_town.add_building("camp", _camp)
	var k := Kith.new(_world, _pathing, _eco, research, _town)
	k.announce.connect(_note)
	k.found(count)
	return k


## A building standing at p (free and unchecked), and its place in the list.
func _put(type: String, p: Vector2i) -> int:
	_town.add_building(type, p)
	return _town.buildings.size() - 1


## `n` Gatherer's Huts in a column at x, and their places in the list.
func _huts(n: int, x: int = 3) -> Array:
	var found: Array = []
	for i in n:
		found.append(_put("gatherers_hut", Vector2i(x, 1 + i)))
	return found


## Make person j work building i, the way assign_jobs would.
func _link(k: Kith, j: int, i: int) -> void:
	k.kith[j]["job"] = "work"
	k.kith[j]["building"] = i
	_town.buildings[i]["worker"] = j


## Tick the population `seconds` whole seconds.
func _grow_for(k: Kith, seconds: int, fed: bool = true) -> void:
	for i in seconds:
		_steady()  # food coming in steadily, as a birth needs (tests/growth_tests.gd tests the rule)
		k.grow(1.0, fed)


## A window of berries from a hut, more than anyone here eats, and an eating rate for the people there are.
func _steady() -> void:
	_eco.flows.hist = []
	for _n in Data.RATE_WINDOW:
		_eco.flows.hist.append({"berries|gatherers_hut": 1.0})
	_eco.steady_held = Data.STEADY_SECONDS


# --- Population --------------------------------------------------------------


func test_found_and_names() -> void:
	var k := _block(3)
	t.check(k.kith.size() == 3, "founded with the people asked for")
	for i in 3:
		t.check(k.kith[i]["name"] == Data.PEOPLE_NAMES[i], "person %d is called %s" % [i, Data.PEOPLE_NAMES[i]])
		t.check(Kith.tile_of(k.kith[i]) == _camp, "they start at the Hearth")
		t.check(
			k.kith[i]["job"] == "" and k.kith[i]["building"] == -1 and k.kith[i]["tool"] == 0, "with no job or tool"
		)
	t.check(k.births == 3, "three births counted")
	k.found(2)
	t.check(
		k.kith.size() == 2 and k.kith[0]["name"] == Data.PEOPLE_NAMES[3],
		"founding again starts over, but never repeats a name"
	)
	t.check(k.births == 5, "the count of births keeps counting")


func test_names_come_round() -> void:
	var k := _block(0)
	var n: int = Data.PEOPLE_NAMES.size()
	for i in n * 2 + 1:
		k.add_kith()
	t.check(k.kith[n - 1]["name"] == Data.PEOPLE_NAMES[n - 1], "the last of the first round has a plain name")
	t.check(k.kith[n]["name"] == "%s %s" % [Data.PEOPLE_NAMES[0], Data.RANK_NAMES[2]], "the second round adds II")
	t.check(k.kith[n * 2]["name"] == "%s %s" % [Data.PEOPLE_NAMES[0], Data.RANK_NAMES[3]], "and the third III")
	for i in n * 2:
		k.add_kith()
	t.check(k.kith[n * 3]["name"].ends_with(" " + Data.RANK_NAMES[3]), "later rounds stay at III")
	var names := {}
	for p in k.kith.slice(0, n * 3):
		names[p["name"]] = true
	t.check(names.size() == n * 3, "no name is given twice in three rounds")


func test_signals_for_births_and_leavers() -> void:
	var k := _block(1, {"berries": 40})
	var m := Monitor.new()
	m.watch(k, "born")
	m.watch(k, "left")
	m.watch(k, "announce")
	_grow_for(k, int(Data.GROW_TIME))
	t.check(m.args_of("born") == [[Data.PEOPLE_NAMES[1]]], "a birth emits born(name) once")
	t.check(m.names() == ["born", "announce"], "then the announcement")
	t.check(m.count("left") == 0, "nobody left")
	var hungry := _block(3)
	var h := Monitor.new()
	h.watch(hungry, "born")
	h.watch(hungry, "left")
	_grow_for(hungry, int(Data.STARVE_TIME), false)
	t.check(h.args_of("left") == [[Data.PEOPLE_NAMES[2]]], "starvation emits left(name) for the one who goes")
	t.check(h.count("born") == 0, "and no birth")
	var founded := Monitor.new()
	var fresh_block := _block(0)
	founded.watch(fresh_block, "born")
	fresh_block.found(3)
	t.check(founded.count() == 0 and fresh_block.kith.size() == 3, "the starting people are founded, not born")


func test_signals_for_lessons_and_trips() -> void:
	var k := _block(2)
	var m := Monitor.new()
	m.watch(k, "learned")
	m.watch(k, "trip_started")
	k.learn("wood", "Aro")
	t.check(k.knows("wood") and k.learned_by["wood"] == "Aro", "learn records who learned what")
	t.check(m.args_of("learned") == [["wood", "Aro"]], "and emits learned(item, name)")
	k.start_trip(k.kith[0])
	t.check(k.kith[0]["trip"] and m.count("trip_started") == 1, "start_trip marks the worker and signals")


func test_births_need_time_room_and_food() -> void:
	var k := _block(1, {"berries": 40})
	_grow_for(k, int(Data.GROW_TIME) - 1)
	t.check(k.kith.size() == 1 and k.grow_timer > 0.0, "the timer runs, and nobody is born early")
	_grow_for(k, 1)
	t.check(k.kith.size() == 2, "one is born after GROW_TIME seconds")
	t.check(k.grow_timer == 0.0, "the timer starts over")
	t.check(_events == [Data.BORN_EVENT % Data.PEOPLE["one"]], "and the player is told: %s" % [_events])
	t.check(_eco.inv["berries"] < 40, "a birth eats Data.BIRTH_FOOD from the stockpile")
	t.check(
		k.kith[1]["name"] == Data.PEOPLE_NAMES[1] and Kith.tile_of(k.kith[1]) == _camp,
		"the newborn is named and at the Hearth"
	)
	var poor := _block(2, {"berries": 2 * 2 + int(Data.BIRTH_FOOD) - 2})
	_grow_for(poor, int(Data.GROW_TIME) * 2)
	t.check(
		poor.kith.size() == 2 and poor.grow_timer == 0.0,
		"without food to spare for a birth, none comes and the timer resets"
	)
	var fed := _block(2, {"berries": 2 * 2 + int(Data.BIRTH_FOOD)})
	_grow_for(fed, int(Data.GROW_TIME))
	t.check(fed.kith.size() == 3, "exactly enough food is enough")


func test_housing_is_the_cap() -> void:
	var k := _block(4, {"berries": 500})
	t.check(k.kith.size() == 4, "the Hearth houses 4")
	_grow_for(k, int(Data.GROW_TIME) * 2)
	t.check(k.kith.size() == 4 and k.grow_timer == 0.0, "a full camp grows no more")
	_put("dwelling", Vector2i(3, 6))
	_grow_for(k, int(Data.GROW_TIME))
	t.check(k.kith.size() == 5, "a Dwelling makes room for one more")
	_grow_for(k, int(Data.GROW_TIME) * 5)
	t.check(k.kith.size() == _town.housing() and k.kith.size() == 7, "and fills to what the buildings house")
	_techs["shelter"] = true
	_grow_for(k, int(Data.GROW_TIME) * 3)
	t.check(k.kith.size() == 9, "Shelter adds two to every Dwelling")


func test_storytelling_shortens_the_wait() -> void:
	var k := _block(1, {"berries": 100})
	t.check(k.grow_time() == Data.GROW_TIME, "the normal wait")
	_techs["storytelling"] = true
	t.check(k.grow_time() == Data.GROW_TIME * Data.STORYTELLING_GROW, "Storytelling cuts it")
	_grow_for(k, ceili(k.grow_time()))
	t.check(k.kith.size() == 2, "a birth comes sooner")


func test_starvation_removes_one() -> void:
	var k := _block(3)
	_grow_for(k, int(Data.STARVE_TIME) - 1, false)
	t.check(k.kith.size() == 3 and k.starve_timer > 0.0, "hunger takes a while to bite")
	_grow_for(k, 1, false)
	t.check(k.kith.size() == 2, "one leaves after STARVE_TIME seconds")
	t.check(k.starve_timer == 0.0, "and the timer starts over")
	t.check(_events == [Data.LEFT_EVENT % Data.PEOPLE["one"]], "the player is told: %s" % [_events])
	k.grow(5.0, false)
	k.grow(1.0, true)
	t.check(k.starve_timer == 0.0, "a fed tick clears the hunger timer")
	k.grow_timer = 4.0
	k.grow(1.0, false)
	t.check(k.grow_timer == 0.0, "and hunger clears the birth timer")


func test_the_last_one_stays() -> void:
	var k := _block(2)
	_grow_for(k, int(Data.STARVE_TIME) * 3, false)
	t.check(k.kith.size() == 1, "the last person never leaves")


func test_the_one_who_leaves_is_not_working() -> void:
	var k := _block(3)
	var h := _huts(2)
	k.assign_jobs()
	t.check(k.kith[0]["job"] == "work" and k.kith[1]["job"] == "work" and k.kith[2]["job"] == "", "two work, one idles")
	k.grow(Data.STARVE_TIME, false)
	t.check(
		k.kith.size() == 2 and _town.buildings[h[0]]["worker"] == 0 and _town.buildings[h[1]]["worker"] == 1,
		"the idle one leaves"
	)
	var m := _block(3)
	var g := _huts(2)
	_link(m, 1, g[0])
	_link(m, 2, g[1])
	m.grow(Data.STARVE_TIME, false)
	t.check(m.kith.size() == 2 and m.kith[0]["building"] == g[0], "the one not working leaves")
	t.check(
		_town.buildings[g[0]]["worker"] == 0 and _town.buildings[g[1]]["worker"] == 1,
		"the workers' places moved up by one"
	)
	var all := _block(2)
	var a := _huts(2)
	all.assign_jobs()
	all.grow(Data.STARVE_TIME, false)
	t.check(
		all.kith.size() == 1 and _town.buildings[a[1]]["worker"] == -1,
		"when all work, the last one leaves and frees its building"
	)
	t.check(_town.buildings[a[0]]["worker"] == 0, "the other keeps theirs")


# --- Jobs --------------------------------------------------------------------


func test_jobs_go_in_build_order() -> void:
	var k := _block(2)
	var h := _huts(3)
	k.assign_jobs()
	for i in 2:
		var p: Dictionary = k.kith[i]
		t.check(
			p["job"] == "work" and p["building"] == h[i] and p["phase"] == "to_site",
			"person %d staffs the hut built %d" % [i, i]
		)
		t.check(_town.buildings[h[i]]["worker"] == i, "and the hut points back at them")
		t.check(
			not p["path"].is_empty() and p["path"][p["path"].size() - 1] == _town.buildings[h[i]]["pos"],
			"walking to it"
		)
	t.check(_town.buildings[h[2]]["worker"] == -1, "the newest waits: no one is free")
	t.check(_town.buildings[0]["worker"] == -1, "the Hearth needs no worker")
	k.assign_jobs()
	t.check(k.kith[0]["building"] == h[0] and k.kith[1]["building"] == h[1], "assigning again changes nothing")


func test_the_rest_idle_then_haul() -> void:
	var k := _block(3)
	_huts(1)
	k.assign_jobs()
	t.check(k.kith[1]["job"] == "" and k.kith[2]["job"] == "", "before haulers, the others wait at the Hearth")
	_techs["haulers"] = true
	k.assign_jobs()
	t.check(k.kith[0]["job"] == "work", "the worker keeps working")
	t.check(k.kith[1]["job"] == "haul" and k.kith[2]["job"] == "haul", "once researched, the others haul")
	t.check(k.kith[1]["phase"] == "" and k.kith[1]["task"].is_empty(), "with no task yet")


func test_idle_come_before_haulers() -> void:
	var k := _block(2, {}, ["haulers"])
	k.assign_jobs()
	t.check(k.kith[0]["job"] == "haul" and k.kith[1]["job"] == "haul", "two haulers")
	k.add_kith()
	var h := _huts(1)
	k.assign_jobs()
	t.check(k.kith[2]["building"] == h[0] and k.kith[2]["job"] == "work", "the new one, who was free, takes the job")
	t.check(k.kith[0]["job"] == "haul" and k.kith[1]["job"] == "haul", "the haulers stay put")
	var more := _huts(1, 5)
	k.assign_jobs()
	t.check(
		k.kith[0]["building"] == more[0] and k.kith[0]["job"] == "work", "with no one free, the first hauler is taken"
	)


func test_a_paused_building_is_skipped() -> void:
	var k := _block(1)
	var h := _huts(2)
	_town.set_paused(h[0], true)
	k.assign_jobs()
	t.check(_town.buildings[h[0]]["worker"] == -1, "a paused building gets no one")
	t.check(k.kith[0]["building"] == h[1], "the next one does")


func test_a_hauler_is_taken_off_its_task() -> void:
	var k := _block(2, {}, ["haulers"])
	var h := _huts(1)
	k.assign_jobs()
	var hauler: Dictionary = k.kith[1]
	t.check(hauler["job"] == "haul", "the second one hauls")
	_town.buildings[h[0]]["claimed"] = true
	hauler["task"] = {"kind": "pickup", "building": h[0]}
	hauler["carry"] = {"wood": 2}
	var more := _huts(1, 5)
	k.assign_jobs()
	t.check(hauler["job"] == "work" and hauler["building"] == more[0], "the hauler is reassigned to the new hut")
	t.check(hauler["task"].is_empty() and not _town.buildings[h[0]]["claimed"], "their pickup is let go")
	t.check(_eco.inv["wood"] == 2 and hauler["carry"].is_empty(), "and what they carried goes to the stockpile")


func test_a_new_worker_takes_a_spare_tool() -> void:
	var k := _block(2, {"flint_tools": 1})
	_huts(2)
	k.assign_jobs()
	t.check(k.kith[0]["tool"] == Data.TOOL_JOBS, "the first worker takes the spare tool")
	t.check(k.kith[1]["tool"] == 0 and _eco.inv["flint_tools"] == 0, "the second finds none left")
	t.check(_eco.flows.now.get("flint_tools|" + Data.FLOW_TOOL_SOURCE, 0.0) == -1.0, "and the flow notes it")


# --- Walking -----------------------------------------------------------------


func test_walking_step_by_step() -> void:
	var k := _block(1)
	var p: Dictionary = k.kith[0]
	var to := Vector2i(5, 4)
	t.check(k.walk_to(p, to), "a way across open grass")
	t.check(
		p["path"].size() == 4 and p["path"][0] == Vector2i(2, 4) and p["path"][3] == to,
		"four tiles, not counting where they stand"
	)
	var speed := Data.KITH_SPEED
	t.check(not k.step(p, 0.25), "not there after a quarter second")
	t.check(is_equal_approx(p["pos"].x, 1.0 + speed * 0.25) and p["pos"].y == 4.0, "half a tile along")
	t.check(p["path"].size() == 4, "the first tile is still ahead")
	t.check(not k.step(p, 0.25), "still walking")
	t.check(p["path"].size() == 3 and Kith.tile_of(p) == Vector2i(2, 4), "a tile passed at 2 tiles a second")
	t.check(not k.step(p, 1.0), "another second")
	t.check(Kith.tile_of(p) == Vector2i(4, 4), "two more tiles")
	t.check(k.step(p, 0.5), "there at last")
	t.check(p["pos"] == Vector2(to) and p["path"].is_empty(), "exactly on the tile with no path left")
	t.check(k.step(p, 1.0) and p["pos"] == Vector2(to), "stepping when there is a no-op that says so")
	t.check(k.walk_to(p, to) and p["path"].is_empty(), "walking to where they stand is done at once")


func test_roads_are_faster() -> void:
	var k := _block(1)
	var p: Dictionary = k.kith[0]
	for x in range(2, 6):
		_world.add_road(Vector2i(x, 4))
		_pathing.update_cell(Vector2i(x, 4))
	t.check(k.walk_to(p, Vector2i(5, 4)), "a walk along the road")
	var need: float = 4.0 * Data.WALK_COST["road"] / Data.KITH_SPEED
	t.check(need < 4.0 / Data.KITH_SPEED, "a road is faster than open grass")
	t.check(not k.step(p, need - 0.05), "not there just before the road time")
	t.check(k.step(p, 0.06), "there just after: four tiles at the road's walk cost")


func test_no_way_there() -> void:
	var k := _block(1)
	var p: Dictionary = k.kith[0]
	for y in 8:
		_world.set_tile(Vector2i(6, y), "river")
	_pathing.refresh()
	t.check(not k.walk_to(p, Vector2i(9, 4)), "no way across the river")
	t.check(p["path"].is_empty(), "and no path is set")
	t.check(k.walk_to(p, Vector2i(5, 4)), "but the near bank is fine")
	t.check(not p["path"].has(Kith.tile_of(p)), "and the path leaves out the tile they stand on")
	_world.add_road(Vector2i(6, 4))
	_pathing.update_cell(Vector2i(6, 4))
	t.check(k.walk_to(p, Vector2i(9, 4)), "a bridge opens it")
	t.check(p["path"].has(Vector2i(6, 4)), "and the path goes over it")
	_world.set_tile(_camp, "river")
	_pathing.update_cell(_camp)
	t.check(k.walk_to(p, Vector2i(3, 4)), "someone standing on a tile that turned to water may still step off")


func test_worker_home() -> void:
	var k := _block(1)
	var h := _huts(1)
	var b: Dictionary = _town.buildings[h[0]]
	t.check(not k.worker_home(b), "no worker, not home")
	k.assign_jobs()
	t.check(not k.worker_home(b), "walking to the site")
	k.kith[0]["phase"] = "home"
	t.check(k.worker_home(b), "at the site")


# --- Releasing and dropping ----------------------------------------------------


func test_release_a_worker() -> void:
	var k := _block(1)
	var h := _huts(1)
	var b: Dictionary = _town.buildings[h[0]]
	k.release_worker(b)
	t.check(b["worker"] == -1 and k.kith[0]["job"] == "", "releasing a building with no worker does nothing")
	k.assign_jobs()
	var p: Dictionary = k.kith[0]
	p["carry"] = {"wood": 3}
	p["task"] = {"tile": Vector2i(4, 4)}
	p["timer"] = 1.5
	p["trip"] = true
	p["phase"] = "harvest"
	k.release_worker(b)
	t.check(b["worker"] == -1, "the building is free")
	t.check(
		p["job"] == "" and p["building"] == -1 and p["phase"] == "" and p["timer"] == 0.0, "the worker is idle again"
	)
	t.check(p["path"].is_empty() and p["task"].is_empty() and not p["trip"], "with nothing left to do")
	t.check(_eco.inv["wood"] == 3 and p["carry"].is_empty(), "what they carried is in the stockpile")


func test_drop_a_task() -> void:
	var k := _block(1, {}, ["haulers"])
	var h := _huts(2)
	var p: Dictionary = k.kith[0]
	p["carry"] = {"stone": 2}
	k.drop_task(p)
	t.check(p["carry"].is_empty() and _eco.inv["stone"] == 2, "a hauler with a load puts it back")
	_town.buildings[h[0]]["claimed"] = true
	p["task"] = {"kind": "pickup", "building": h[0]}
	k.drop_task(p)
	t.check(not _town.buildings[h[0]]["claimed"] and p["task"].is_empty(), "a pickup is unclaimed")
	_town.buildings[h[1]]["incoming"] = {"wood": 5}
	p["task"] = {"kind": "deliver", "building": h[1], "item": "wood", "amount": 3}
	k.drop_task(p)
	t.check(
		_town.buildings[h[1]]["incoming"]["wood"] == 2 and p["task"].is_empty(),
		"a delivery is taken off what was coming"
	)
	p["task"] = {"tile": Vector2i(4, 4)}
	k.drop_task(p)
	t.check(p["task"].is_empty(), "a hut worker's tile is just cleared")


func test_tasks_follow_a_demolished_building() -> void:
	var k := _block(4, {}, ["haulers"])
	var h := _huts(3)
	k.assign_jobs()
	t.check(
		k.kith[0]["building"] == h[0] and k.kith[1]["building"] == h[1] and k.kith[2]["building"] == h[2],
		"three workers"
	)
	var hauler: Dictionary = k.kith[3]
	_town.buildings[h[1]]["incoming"] = {"wood": 3}
	hauler["task"] = {"kind": "deliver", "building": h[1], "item": "wood", "amount": 3}
	hauler["path"] = [Vector2i(2, 4)]
	hauler["carry"] = {"wood": 1}
	k.release_worker(_town.buildings[h[1]])
	k.drop_tasks_at(h[1])
	t.check(
		hauler["task"].is_empty() and hauler["path"].is_empty(), "the hauler heading there drops its task and stops"
	)
	t.check(
		_town.buildings[h[1]]["incoming"]["wood"] == 0 and _eco.inv["wood"] == 1,
		"what it promised and carried is put back"
	)
	var other := {"kind": "pickup", "building": h[2]}
	hauler["task"] = other
	_town.remove_at(h[1])
	k.shift_buildings_after(h[1])
	t.check(k.kith[0]["building"] == h[0], "a worker before the gap keeps their number")
	t.check(k.kith[2]["building"] == h[2] - 1, "a worker after it moves up one")
	t.check(hauler["task"]["building"] == h[2] - 1, "and so does a task")
	t.check(_town.buildings[k.kith[2]["building"]]["worker"] == 2, "which is still their building")


# --- Tools -------------------------------------------------------------------


func test_tool_wear() -> void:
	var k := _block(1)
	var h := _huts(1)
	var b: Dictionary = _town.buildings[h[0]]
	k.wear(b)
	t.check(k.kith[0]["tool"] == 0 and _events.is_empty(), "wearing a building with no worker does nothing")
	k.assign_jobs()
	k.wear(b)
	t.check(k.kith[0]["tool"] == 0, "no tool to wear, and none to pick up")
	k.kith[0]["tool"] = 5
	k.wear(b)
	t.check(k.kith[0]["tool"] == 4, "one job done wears the tool by one")
	t.check(_events.is_empty(), "with nothing to say")


func test_tool_wears_out_and_is_replaced() -> void:
	var k := _block(1, {"flint_tools": 2})
	var h := _huts(1)
	var b: Dictionary = _town.buildings[h[0]]
	k.assign_jobs()
	t.check(k.kith[0]["tool"] == Data.TOOL_JOBS and _eco.inv["flint_tools"] == 1, "a tool from the stockpile")
	k.kith[0]["tool"] = 1
	k.wear(b)
	t.check(_events == ["A Flint Tool wore out"], "the last job breaks it and the player hears: %s" % [_events])
	t.check(k.kith[0]["tool"] == Data.TOOL_JOBS and _eco.inv["flint_tools"] == 0, "a spare is picked up on the spot")
	k.kith[0]["tool"] = 1
	k.wear(b)
	t.check(k.kith[0]["tool"] == 0, "with none left they go without")
	k.equip(k.kith[0])
	t.check(k.kith[0]["tool"] == 0, "equip with an empty stockpile does nothing")
	_eco.inv["flint_tools"] = 1
	k.kith[0]["tool"] = 3
	k.equip(k.kith[0])
	t.check(k.kith[0]["tool"] == 3 and _eco.inv["flint_tools"] == 1, "someone holding a tool takes no second")


# --- Titles and knowledge ------------------------------------------------------


func test_job_titles() -> void:
	var k := _block(4, {}, ["haulers"])
	var camp: Dictionary = _town.buildings[0]
	var pit: Dictionary = _town.buildings[_put("charcoal_pit", Vector2i(3, 6))]
	var hut: Dictionary = _town.buildings[_put("gatherers_hut", Vector2i(3, 2))]
	hut["gather_items"] = ["wood", "wood", "stone"]
	hut["focus"] = ""  # a hut with no focus is named for what is most in its reach
	t.check(k.building_job(camp) == "", "the Hearth has no job")
	t.check(k.building_job(pit) == Data.BUILDINGS["charcoal_pit"]["job"], "a workshop names its own job")
	t.check(k.building_job(hut) == Data.HUT_JOBS["wood"]["title"], "a hut is named for what it gathers most")
	k.learned_by["stone"] = "Aro"
	t.check(k.building_job(hut) == Data.HUT_JOBS["stone"]["title"], "once they know one, that counts far more")
	t.check(k.job_of(k.kith[0]) == Data.JOB_IDLE, "no job yet is Idle")
	t.check(k.title_of(k.kith[0]) == "%s the %s" % [Data.PEOPLE_NAMES[0], Data.JOB_IDLE], "titled by name")
	_town.buildings[_town.building_at[Vector2i(3, 6)]]["paused"] = true
	k.assign_jobs()
	t.check(k.job_of(k.kith[0]) == Data.HUT_JOBS["stone"]["title"], "a worker has their building's title")
	t.check(k.job_of(k.kith[1]) == Data.JOB_HAULER, "the rest haul")
	t.check(k.title_of(k.kith[1]).ends_with(" the " + Data.JOB_HAULER), "and are titled so")
	t.check(
		k.job_counts() == "3 Haulers, 1 %s" % Data.HUT_JOBS["stone"]["title"], "counted most first: %s" % k.job_counts()
	)
	var idle := _block(2)
	t.check(idle.job_counts() == "2 %s" % Data.JOB_IDLE, "idle is never plural: %s" % idle.job_counts())
	var tie := _block(2)
	_huts(2)
	tie.assign_jobs()
	t.check(tie.job_counts() == "2 %ss" % Data.HUT_JOBS["fiber"]["title"], "two of the same job: %s" % tie.job_counts())


func test_knowing_what_to_gather() -> void:
	var k := _block(1)
	t.check(not k.knows("wood"), "no one knows Wood at first")
	k.learned_by["wood"] = Data.PEOPLE_NAMES[0]
	t.check(k.knows("wood") and not k.knows("stone"), "and only what was learned")
	_world.set_tile(Vector2i(4, 2), "tree")
	_world.set_tile(Vector2i(4, 6), "rock")
	t.check(k.knows_any(Vector2i(3, 2)), "a hut beside a tree finds something it knows")
	t.check(not k.knows_any(Vector2i(3, 6)), "one that reaches only Stone does not")
	t.check(not k.knows_any(Vector2i(9, 1)), "nor one with nothing in reach")


# --- The walk to a depot -------------------------------------------------------


func test_nearest_depot_and_trip() -> void:
	var k := _block(0)
	var far := Vector2i(8, 4)
	t.check(k.nearest_depot(far) == _camp, "with only the Hearth, that is the nearest")
	var trip := k.trip_info(_camp)
	t.check(
		trip["ok"] and trip["tiles"] == 0 and trip["seconds"] == 0.0 and trip["depot"] == _camp,
		"at the Hearth there is no walk"
	)
	trip = k.trip_info(far)
	t.check(trip["ok"] and trip["tiles"] == 7, "seven tiles to the Hearth")
	t.check(is_equal_approx(trip["seconds"], 7.0 / Data.KITH_SPEED * 2.0), "there and back at walking speed")
	var store := Vector2i(10, 4)
	_put("storehouse", store)
	t.check(
		k.nearest_depot(far) == store and k.nearest_depot(Vector2i(2, 4)) == _camp,
		"a Storehouse is nearer to what is nearer to it"
	)
	trip = k.trip_info(far)
	t.check(trip["depot"] == store and trip["tiles"] == 2, "the trip is to the Storehouse: %s" % [trip])
	_world.add_road(Vector2i(9, 4))
	_pathing.update_cell(Vector2i(9, 4))
	var faster := k.trip_info(far)
	t.check(faster["seconds"] < trip["seconds"], "a road on the way shortens it")


func test_a_trip_cut_off_by_water() -> void:
	var k := _block(0)
	for y in 8:
		_world.set_tile(Vector2i(2, y), "river")
	_pathing.refresh()
	var trip := k.trip_info(Vector2i(3, 4))
	t.check(not trip["ok"] and trip["tiles"] == 0 and trip["seconds"] == 0.0, "water in the way: no trip")
	t.check(trip["depot"] == _camp, "though the depot is still named")
	_world.add_road(Vector2i(2, 4))
	_pathing.update_cell(Vector2i(2, 4))
	t.check(k.trip_info(Vector2i(3, 4))["ok"], "a bridge mends it")


# --- Sim ---------------------------------------------------------------


## The people (positions, paths, tasks, what they carry), who learned what, the birth count and the timers
## survive a dict and a JSON round trip, and nothing is emitted.
func test_to_dict_and_from_dict() -> void:
	var a := _block(3, {"flint_tools": 2})
	var huts := _huts(2)
	a.assign_jobs()
	a.kith[0]["pos"] = Vector2(2.25, 4.5)
	a.kith[0]["path"] = [Vector2i(3, 4), Vector2i(3, 3)]
	a.kith[0]["timer"] = 0.7
	a.kith[0]["task"] = {"tile": Vector2i(5, 5)}
	a.kith[1]["carry"] = {"wood": 2}
	a.kith[1]["job"] = "haul"
	a.kith[1]["task"] = {"kind": "deliver", "building": huts[1], "item": "wood", "amount": 3, "depot": Vector2i(1, 4)}
	a.kith[1]["trip"] = true
	a.learn("wood", "Aro")
	a.learn("stone", "Bel")
	a.grow_timer = 3.5
	a.starve_timer = 1.5
	var d := a.to_dict()
	var b := _block()
	var m := Monitor.new()
	for sig in ["born", "left", "learned", "announce", "trip_started"]:
		m.watch(b, sig)
	b.from_dict(d)
	t.check(RunSave.to_json(b.to_dict()) == RunSave.to_json(d), "a Kith restored from a dict writes the same dict")
	t.check(b.kith == a.kith, "every person comes back as they were, tasks and paths too")
	t.check(b.learned_by == a.learned_by and b.learned_by.keys() == ["wood", "stone"], "who learned what, in order")
	t.check(b.births == a.births and b.grow_timer == 3.5 and b.starve_timer == 1.5, "the count and the timers")
	t.check(m.count() == 0, "restoring emits nothing")
	var c := _block()
	c.from_dict(RunSave.from_json(RunSave.to_json(d)))
	t.check(RunSave.to_json(c.to_dict()) == RunSave.to_json(d), "the same after a trip through JSON text")
	t.check(c.kith == a.kith, "and the people are the same (Vector2, Vector2i and ints, not floats)")
	t.check(c.kith[1]["task"]["depot"] is Vector2i and c.kith[1]["task"]["amount"] is int, "task positions and counts")
	c.from_dict({})
	t.check(c.kith.is_empty() and c.learned_by.is_empty() and c.births == 0, "an empty dict clears it")


func test_sim_starts_with_the_first_people() -> void:
	var s: Sim = t.fresh()
	t.check(s.people.births == Data.KITH_START, "the count of names given out starts at the first people")
	s.people.learned_by["wood"] = "Aro"
	t.check(s.people.knows("wood"), "a write to the block's learned list is what knows() reads")
	t.check(s.people.kith.size() == Data.KITH_START, "the camp starts with the first people")
	t.check(Kith.tile_of(s.people.kith[0]) == s.world.camp_pos, "at the Hearth")
	s.people.add_kith()
	t.check(
		s.people.kith.size() == Data.KITH_START + 1 and s.people.kith[-1]["name"] == Data.PEOPLE_NAMES[Data.KITH_START],
		"one more, named next"
	)
	t.check(s.people.trip_info(s.world.camp_pos)["ok"], "trip_info is the block's")


func test_sim_ticks_through_the_block() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 300
	s.tech_tree.researched["haulers"] = true
	s.tick(0.1)
	t.check(s.people.kith[0]["job"] == "haul", "the first tick hands out jobs")
	for i in int(Data.GROW_TIME) + 1:
		t.steady_income(s)
		s.tick(1.0)
	t.check(s.people.kith.size() == Data.KITH_START + 1, "and grows the camp")
	t.check(s.events.has(Data.BORN_EVENT % Data.PEOPLE["one"]), "the block's message reaches Sim.events")
	var here := Kith.tile_of(s.people.kith[0])
	t.check(s.fog.is_revealed(here), "and the Kith lift the fog where they stand")
	s.economy.inv["berries"] = 0
	s.economy.food_credit = 0.0
	for i in int(Data.STARVE_TIME) + 1:
		s.tick(1.0)
	t.check(s.events.has(Data.LEFT_EVENT % Data.PEOPLE["one"]), "hunger sends someone away, and the player is told")
