extends RefCounted
## Hauler places and resting at a full store (scripts/hauling.gd, scripts/store_rest.gd). Run from tests/run_tests.gd, which owns
## check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Hauling = preload("res://scripts/hauling.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const StoreRest = preload("res://scripts/store_rest.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_depot_wants_the_haulers_its_load_needs()
	test_a_paused_building_asks_for_nothing()
	test_the_player_sets_a_depot_above_or_below_auto()
	test_places_come_before_workshops()
	test_leftover_kith_go_where_the_gap_is_biggest()
	test_a_waiting_building_names_its_depot()
	test_a_full_store_rests_the_building()
	test_food_producers_rest_and_births_go_on()
	test_places_survive_a_save()


## A town with haulers known, a Storehouse far from the Hearth, and a charcoal pit beside each.
func _town(kith: int) -> Sim:
	var s: Sim = t.fresh()
	t.give(s, 200)
	for id in ["storehouse", "fire", "haulers"]:
		s.tech_tree.researched[id] = true
	var camp := s.world.camp_pos
	var far := camp + Vector2i(8 if camp.x < 14 else -8, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s.world.set_tile(far + Vector2i(dx, dy), "grass")
	s.pathing.build()
	s.place("storehouse", far)
	s.place("charcoal_pit", far + Vector2i(1, 0))
	s.place("charcoal_pit", camp + Vector2i(1, 0))
	s.people.found(kith)
	return s


func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds * 10.0):
		s.tick(0.1)


func test_a_depot_wants_the_haulers_its_load_needs() -> void:
	var s := _town(10)
	_run(s, 40.0)
	var camp := s.world.camp_pos
	t.check(s.hauling.auto.size() == 2, "both depots have work: %s" % [s.hauling.auto])
	t.check(s.hauling.wanted(camp) >= 1, "the Hearth wants at least one hauler")
	var before: int = s.hauling.wanted(camp)
	for i in 3:
		s.place("charcoal_pit", camp + Vector2i(1, 2 * i + 2))
	for pit in s.town.buildings:
		if pit["type"] == "charcoal_pit":
			pit["worker"] = 0  # a worker is named, so each pit counts its load
	s.hauling.refresh(s)
	t.check(s.hauling.wanted(camp) >= before, "more pits by the Hearth never lower its wanted count")
	var trips: float = Hauling.trips_per_minute(s, s.town.buildings[s.town.building_at[camp + Vector2i(1, 0)]])
	t.check(trips > 0.0, "a staffed pit asks for trips a minute (%f)" % trips)


func test_a_paused_building_asks_for_nothing() -> void:
	var s := _town(10)
	_run(s, 20.0)
	var pit: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(1, 0)]]
	t.check(Hauling.trips_per_minute(s, pit) > 0.0, "a working pit asks for trips")
	s.set_paused(s.town.building_at[pit["pos"]], true)
	t.check(Hauling.trips_per_minute(s, pit) == 0.0, "a paused one asks for none")
	s.set_paused(s.town.building_at[pit["pos"]], false)
	pit["worker"] = -1
	t.check(Hauling.trips_per_minute(s, pit) == 0.0, "nor one with no worker")


func test_the_player_sets_a_depot_above_or_below_auto() -> void:
	var s := _town(12)
	_run(s, 40.0)
	var camp := s.world.camp_pos
	var auto: int = s.hauling.wanted(camp)
	s.hauling.nudge(camp, 1)
	t.check(s.hauling.wanted(camp) == auto + 1, "+ asks for one more")
	s.hauling.nudge(camp, 1)
	s.hauling.nudge(camp, -1)
	t.check(s.hauling.wanted(camp) == auto + 1, "and - one fewer than that")
	_run(s, 31.0)
	t.check(s.hauling.wanted(camp) == auto + 1, "the setting stays through the next reading")
	s.hauling.reset(camp)
	t.check(s.hauling.wanted(camp) == auto, "Auto returns to the load's number")
	for i in 10:
		s.hauling.nudge(camp, -1)
	t.check(s.hauling.wanted(camp) == 0, "it can be set to none, and no lower")


## Haulers are not taken for workshops while a depot is short: with no spare Kith the places are filled first.
func test_places_come_before_workshops() -> void:
	var s := _town(3)
	_run(s, 40.0)
	var wanted: int = s.hauling.total_needed()
	t.check(wanted >= 2, "two depots want at least two haulers (%d)" % wanted)
	var crew := 0
	for b in s.town.buildings:
		crew += 1 if b["worker"] >= 0 else 0
	var haulers := 0
	for k in s.people.kith:
		haulers += 1 if k["job"] == "haul" else 0
	t.check(haulers + crew == 3, "every Kith has a job (%d hauling, %d at work)" % [haulers, crew])
	s.hauling.nudge(s.world.camp_pos, 1)
	s.place("charcoal_pit", s.world.camp_pos + Vector2i(1, 2))
	_run(s, 5.0)
	var new_pit: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(1, 2)]]
	t.check(new_pit["worker"] < 0, "a new pit is not staffed from the haulers the depots still want")
	for i in 3:
		s.people.add_kith()
	_run(s, 5.0)
	t.check(new_pit["worker"] >= 0 or s.people.kith.size() == 6, "it is staffed once Kith beyond the places are born")


## The places fill to the roomy count, but a workshop is only held back for the haulers the load needs: Kith beyond that staff it.
func test_roomy_places_do_not_starve_a_new_workshop() -> void:
	var s := _town(30)
	_run(s, 40.0)
	t.check(s.hauling.total_needed() <= s.hauling.total_wanted(), "the staffing reserve is not above the places")
	var spot := s.world.camp_pos + Vector2i(1, 2)
	s.place("charcoal_pit", spot)
	_run(s, 5.0)
	var pit: Dictionary = s.town.buildings[s.town.building_at[spot]]
	t.check(pit["worker"] >= 0, "a new pit is staffed while idle Kith stand at the depots")


func test_leftover_kith_go_where_the_gap_is_biggest() -> void:
	var s := _town(20)
	_run(s, 70.0)
	var camp := s.world.camp_pos
	var far: Vector2i = camp + Vector2i(8 if camp.x < 14 else -8, 0)
	s.hauling.nudge(far, 6)
	for k in s.people.kith:
		if k["job"] == "haul":
			k["depot"] = camp  # everyone stands at the Hearth
	s.hauling.refresh(s)
	_run(s, 1.0)
	t.check(s.hauling.have(far) >= 1, "idle haulers move to the depot that is short (%d)" % s.hauling.have(far))
	t.check(
		s.hauling.have(far) <= s.hauling.wanted(far) + 1,
		"and no more than it wants (%d of %d)" % [s.hauling.have(far), s.hauling.wanted(far)]
	)


func test_a_waiting_building_names_its_depot() -> void:
	var s := _town(10)
	_run(s, 40.0)
	var pit: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(1, 0)]]
	var note: String = s.hauling.waiting_note(s, pit)
	t.check(note.begins_with("Waiting for a hauler: Hearth, "), "the note names the Hearth: %s" % note)
	t.check(" of %d" % s.hauling.wanted(s.world.camp_pos) in note, "and its count: %s" % note)
	for b in s.town.buildings:
		if b["type"] == "storehouse":
			var by: String = s.hauling.names[b["pos"]]
			t.check(by.begins_with("Storehouse by the "), "a Storehouse is named for what stands by it: %s" % by)


## A pit whose product is at the cap finishes its cycle and rests; it works again when the stock falls below 90%.
func test_a_full_store_rests_the_building() -> void:
	var s := _town(10)
	_run(s, 30.0)
	var camp := s.world.camp_pos
	var pit: Dictionary = s.town.buildings[s.town.building_at[camp + Vector2i(1, 0)]]
	var cap: int = s.economy.caps["charcoal"]
	s.economy.inv["charcoal"] = cap
	_run(s, 40.0)
	var spilled: int = s.economy.spilled  # what was already on its way when the store filled may still spill
	t.check(pit["status"] == Data.STORE_FULL_STATUS, "a pit with its store full rests: %s" % pit["status"])
	t.check(pit["resting"], "and is marked resting")
	_run(s, 40.0)
	t.check(s.economy.spilled == spilled, "nothing more spilled while it rested")
	t.check(pit["worker"] >= 0, "its worker stays")
	s.economy.inv["charcoal"] = int(cap * 0.92)
	_run(s, 5.0)
	t.check(pit["resting"], "between nine tenths and the cap it keeps resting")
	s.economy.inv["charcoal"] = int(cap * 0.8)
	_run(s, 10.0)
	t.check(
		not pit["resting"] and pit["status"] != Data.STORE_FULL_STATUS,
		"under nine tenths it starts again: %s" % pit["status"]
	)
	var tool_bench_rests := false
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]].has("makes") and b.get("resting", false):
			tool_bench_rests = true
	t.check(not tool_bench_rests, "the Tool Bench never rests (it stops at enough)")


## Food producers rest at a full store like any other, and a food store near its cap counts as steady food, so births go on.
func test_food_producers_rest_and_births_go_on() -> void:
	var s := _town(3)
	_run(s, 5.0)
	var mill: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(1, 0)]].duplicate(true)
	mill["type"] = "grindstone"  # a stand-in that makes flour, a food, beside the Hearth
	mill["progress"] = 0.0
	mill["resting"] = false
	s.economy.inv["flour"] = s.economy.caps["flour"]
	t.check(StoreRest.rests(s, mill), "a full flour store rests the mill")
	s.economy.inv["flour"] = int(s.economy.caps["flour"] * 0.5)
	t.check(not StoreRest.rests(s, mill), "and half a store does not")
	s.economy.flows.hist.clear()
	for i in Data.RATE_WINDOW:
		s.economy.flows.hist.append({})
	var empty_of_food: Dictionary = {}
	for id in Data.FOOD_VALUE:
		empty_of_food[id] = 0
	s.economy.inv.merge(empty_of_food, true)
	t.check(not s.economy.food_covers_eating(), "with no food in and none stored, the food does not cover eating")
	s.economy.inv["berries"] = int(s.economy.caps["berries"] * 0.95)
	t.check(s.economy.food_covers_eating(), "a berry store near its cap does, though nothing is coming in")


func test_places_survive_a_save() -> void:
	var s := _town(12)
	_run(s, 40.0)
	var camp := s.world.camp_pos
	s.hauling.nudge(camp, 2)
	var d := RunSave.dump(s)
	var b := Sim.new()
	t.check(RunSave.restore(b, RunSave.from_json(RunSave.to_json(d))), "a town with places restores")
	t.check(b.hauling.wanted(camp) == s.hauling.wanted(camp), "with the same wanted count")
	t.check(b.hauling.offset == s.hauling.offset, "and the player's setting")
	var kith_depots := []
	for k in s.people.kith:
		kith_depots.append(k["depot"])
	var restored := []
	for k in b.people.kith:
		restored.append(k["depot"])
	t.check(restored == kith_depots, "and every hauler keeps their place")
	var old: Dictionary = RunSave.from_json(RunSave.to_json(d))
	old["game"].erase("hauling")
	for k in old["kith"]["kith"]:
		k.erase("depot")
	var c := Sim.new()
	t.check(RunSave.restore(c, old), "a save from before places still loads")
	t.check(c.hauling.auto.is_empty(), "and the readings are taken afresh")
