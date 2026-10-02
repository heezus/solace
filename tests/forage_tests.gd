extends RefCounted
## The famine fallback (scripts/forage.gd): playtest 4's newcomer clicked each hut once and then ran out of food and
## lost Kith with no way back. Once the warning is up and the food would run out within a minute, Kith with
## nothing to do pick berries by themselves, slowly: enough to keep the people fed, never enough to grow. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Forage = preload("res://scripts/forage.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const Workers = preload("res://scripts/workers.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_famine_comes_before_the_warning_and_goes_well_after_it()
	test_foraged_food_is_not_income()
	test_idle_kith_forage_and_the_food_recovers_without_growth()
	test_a_waiting_hut_worker_forages_and_a_click_calls_them_back()
	test_no_bush_in_reach_means_no_foraging()
	test_a_forager_survives_a_save()


## A game on the standard test map with `stock` berries and nothing else to eat, the people all idle at the Hearth.
func _camp(stock: int) -> Sim:
	var s: Sim = t.fresh()
	for id in s.economy.inv:
		s.economy.inv[id] = 0
	s.economy.inv["berries"] = stock
	s.economy.food_credit = 0.0
	return s


func _foragers(s: Sim) -> int:
	var n := 0
	for k in s.people.kith:
		n += 1 if String(k["phase"]).begins_with("forage") else 0
	return n


func test_the_famine_comes_before_the_warning_and_goes_well_after_it() -> void:
	var e := Economy.new()
	var eat := 4 * Data.FOOD_PER_KITH_PER_SEC
	e.flows.clock = Data.FORAGE_OPENING_SECONDS + 1.0  # past the opening
	e.inv["berries"] = int(eat * Data.FOOD_FORAGE_END_SECONDS) + 2
	e.food_credit = 0.0
	t.check(e.feed(4, 0.1) and not e.low and not e.famine, "plenty of food: no warning and no famine")
	e.inv["berries"] = int(eat * Data.FOOD_FAMINE_SECONDS) - 1
	e.feed(4, 0.1)
	t.check(e.famine and not e.low, "under the famine point the famine is on, before the warning")
	e.inv["berries"] = int(eat * Data.FOOD_WARN_SECONDS) - 1
	e.feed(4, 0.1)
	t.check(e.low and e.famine, "under the warning point the warning is up as well")
	e.inv["berries"] = int(eat * Data.FOOD_CLEAR_SECONDS) + 2
	e.feed(4, 0.1)
	t.check(not e.low and e.famine, "the warning comes down at its own point and the famine stays")
	e.inv["berries"] = int(eat * Data.FOOD_FORAGE_END_SECONDS) + 2
	e.feed(4, 0.1)
	t.check(not e.famine, "and the famine ends only once the food would last %.0f s" % Data.FOOD_FORAGE_END_SECONDS)


func test_foraged_food_is_not_income() -> void:
	var e := Economy.new()
	e.flows.hist = []
	for _n in Data.RATE_WINDOW:
		e.flows.hist.append({"berries|" + Data.FLOW_FORAGE_SOURCE: 1.0})
	t.check(e.food_supply() == 0.0 and e.food_income() == 0.0, "foraging is neither supply nor income")
	t.check(e.flows.rate("berries") > 0.0, "though the top bar's rate shows it")


## Three idle Kith on the starting berries, never touching the mouse: they forage, nobody leaves, the food comes back
## above the warning point, nobody is born.
func test_idle_kith_forage_and_the_food_recovers_without_growth() -> void:
	var s := _camp(6)
	var most := 0
	var low_at := -1.0
	var recovered := -1.0
	for n in 6000:  # ten minutes
		s.tick(0.1)
		s.events.clear()
		most = maxi(most, _foragers(s))
		if s.economy.low and low_at < 0.0:
			low_at = n * 0.1
		if low_at >= 0.0 and recovered < 0.0 and not s.economy.low:
			recovered = n * 0.1
	t.check(most >= 1, "idle Kith went out foraging (%d at once)" % most)
	t.check(s.people.kith.size() == Data.KITH_START, "nobody left and nobody was born (%d)" % s.people.kith.size())
	t.check(
		recovered > low_at and recovered >= 0.0,
		"the food came back above the warning point (%.0f s to %.0f s)" % [low_at, recovered]
	)
	t.check(s.economy.flows.hist.size() > 0 and s.economy.food_supply() == 0.0, "and none of it counted as income")
	t.check(s.economy.food_total() > 0.0, "with food in hand at the end (%.1f)" % s.economy.food_total())


func _hut_camp() -> Array:
	var s := _camp(40)
	var camp := s.world.camp_pos
	var spot := camp + Vector2i(3, 0)
	for dy in range(-2, 3):
		for dx in range(-3, 4):
			s.world.set_tile(spot + Vector2i(dx, dy), "grass")
	s.world.set_tile(spot + Vector2i(1, 0), "tree")
	s.tech_set["gatherers_hut"] = true
	s.people.learned_by["wood"] = "Aro"
	t.place_free(s, "gatherers_hut", spot)
	s.economy.inv["berries"] = 0
	return [s, spot]


func test_a_waiting_hut_worker_forages_and_a_click_calls_them_back() -> void:
	var a := _hut_camp()
	var s: Sim = a[0]
	var spot: Vector2i = a[1]
	var i: int = s.town.building_at[spot]
	s.economy.inv["berries"] = 4
	for _n in 100:
		s.tick(0.1)
	var w: int = s.town.buildings[i]["worker"]
	t.check(w >= 0, "the hut has its worker")
	var out := false
	for _n in 600:
		s.tick(0.1)
		out = out or String(s.people.kith[w]["phase"]).begins_with("forage")
	t.check(out, "a worker whose hut waits for a click goes foraging in a famine")
	t.check(String(s.town.buildings[i]["status"]) != "" and s.town.buildings[i]["trips"] == 0, "the hut still waits")
	for _n in 600:
		if String(s.people.kith[w]["phase"]).begins_with("forage"):
			break
		s.economy.inv["berries"] = mini(s.economy.inv["berries"], 4)  # keep the famine on
		s.tick(0.1)
	t.check(String(s.people.kith[w]["phase"]).begins_with("forage"), "out again")
	t.check(s.town.buildings[i]["status"] == Data.FORAGE_STATUS, "and the hut's card says so")
	Workers.click(s, i)
	s.tick(0.1)
	t.check(
		not String(s.people.kith[w]["phase"]).begins_with("forage"), "a click on the hut calls the worker back to it"
	)
	t.check(s.people.kith[w]["phase"] == "to_site" or s.people.kith[w]["task"].has("tile"), "to work the trip")


func test_no_bush_in_reach_means_no_foraging() -> void:
	var s := _camp(3)
	var camp := s.world.camp_pos
	for y in range(camp.y - Data.FORAGE_RADIUS - 2, camp.y + Data.FORAGE_RADIUS + 3):
		for x in range(camp.x - Data.FORAGE_RADIUS - 2, camp.x + Data.FORAGE_RADIUS + 3):
			if s.world.tile_at(Vector2i(x, y)) == "berry":
				s.world.set_tile(Vector2i(x, y), "grass")
	t.check(Forage.bush(s).x < 0, "no bush within reach of the Hearth")
	for _n in 1200:
		s.tick(0.1)
	t.check(s.economy.famine and _foragers(s) == 0, "a famine with nothing to forage: nobody goes out")


func test_a_forager_survives_a_save() -> void:
	var s := _camp(5)
	var d: Dictionary = {}
	for _n in 3000:
		s.tick(0.1)
		if _foragers(s) > 0 and String(s.people.kith[0]["phase"]) == "forage_back":
			d = RunSave.dump(s)
			break
	t.check(not d.is_empty(), "a Kith was carrying foraged berries home")
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.from_json(RunSave.to_json(d))), "the save loads")
	t.check(RunSave.to_json(RunSave.dump(copy)) == RunSave.to_json(d), "and writes back the same")
	var before: int = copy.economy.inv["berries"]
	for _n in 600:
		copy.tick(0.1)
	t.check(
		copy.economy.inv["berries"] >= before - 1 and copy.people.kith.size() == s.people.kith.size(),
		"and the foraging carries on"
	)
