extends RefCounted
## Seasons of Strain (scripts/seasons.gd, design-system/24-balance.md pick 1): when they come, what each answer does, and that the
## schedule is the same on a map every time. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_none_comes_before_the_first_and_the_card_waits_for_an_answer()
	test_a_town_short_of_food_is_spared_until_it_is_fed()
	test_the_schedule_is_the_same_on_a_map_twice_and_never_repeats_a_kind()
	test_a_lean_season_answered_with_rations()
	test_a_lean_season_answered_with_foraging()
	test_a_cold_snap_burns_fuel_or_slows_the_workshops()
	test_a_bloom_surge_runs_the_tide_or_costs_coal()
	test_a_season_is_remembered_by_a_save()


func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds):
		s.seasons.tick(s, 1.0)


## A game where every kind could come: the dawn is told and the tide has begun.
func _everything(s: Sim) -> void:
	s.story.record("bronze_dawn")
	s.tide.begun = true
	s.economy.inv["berries"] = 100000


func test_none_comes_before_the_first_and_the_card_waits_for_an_answer() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 200
	_run(s, Data.SEASON_FIRST - 5.0)
	t.check(s.seasons.phase == "idle", "no season in the first six minutes")
	_run(s, 10.0)
	t.check(
		s.seasons.phase == "pending" and s.seasons.kind == "lean",
		"the first is a lean season: nothing else could come yet"
	)
	t.check(s.economy.eat_factor == 1.0, "and nothing changes until the player answers")
	_run(s, Data.SEASON_AUTO + 1.0)
	t.check(
		s.seasons.phase == "active" and s.seasons.answer == 0,
		"a card nobody answers answers itself with the first option"
	)


func _kinds(seed_value: int, seasons: int) -> Array:
	var s := Sim.new()
	s.generate(seed_value)
	_everything(s)
	var out: Array = []
	while out.size() < seasons:
		s.seasons.tick(s, 1.0)
		if s.seasons.phase == "pending":
			out.append(s.seasons.kind + "@" + str(int(s.seasons.time)))
			s.seasons.choose(s, 0)
	return out


func test_a_town_short_of_food_is_spared_until_it_is_fed() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 0
	_run(s, Data.SEASON_FIRST + 60.0)
	t.check(s.seasons.phase == "idle", "no season lands on a town that is short of food")
	s.economy.inv["berries"] = 200
	_run(s, 2.0)
	t.check(s.seasons.phase == "pending", "and it comes once the stores are back")


func test_the_schedule_is_the_same_on_a_map_twice_and_never_repeats_a_kind() -> void:
	var a: Array = _kinds(42, 6)
	t.check(a == _kinds(42, 6), "the same map meets the same seasons at the same times: %s" % [a])
	var kinds: Array = a.map(func(x): return x.split("@")[0])
	var repeats := 0
	for i in range(1, kinds.size()):
		repeats += 1 if kinds[i] == kinds[i - 1] else 0
	t.check(repeats == 0, "one kind never comes twice running: %s" % [kinds])
	t.check(a != _kinds(7, 6), "another map meets another run of seasons")


func test_a_lean_season_answered_with_rations() -> void:
	var s: Sim = t.fresh()
	s.seasons.kind = "lean"
	s.seasons.phase = "pending"
	var hut: Vector2i = s.world.camp_pos + Vector2i(3, 0)
	t.give(s, 200)
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	b["focus"] = "berries"
	t.check(s.seasons.speed_factor(s, b) == 1.0, "a hut works at its pace before the season")
	s.seasons.choose(s, 0)
	s.seasons.tick(s, 1.0)
	t.check(s.seasons.speed_factor(s, b) == Data.LEAN_PACE, "a food hut works at three fifths in a lean season")
	t.check(
		s.economy.eat_factor == Data.RATION_EAT and s.economy.births_paused,
		"rationing: a quarter less eaten and no births"
	)
	_run(s, Data.SEASON_LENGTH)
	t.check(s.seasons.phase == "idle", "the season ends after its length")
	t.check(s.economy.eat_factor == 1.0 and not s.economy.births_paused, "and the switches are back")
	t.check(s.seasons.speed_factor(s, b) == 1.0, "and the hut works at its pace again")


func test_a_lean_season_answered_with_foraging() -> void:
	var s: Sim = t.fresh()
	s.seasons.kind = "lean"
	s.seasons.phase = "pending"
	s.seasons.choose(s, 1)
	s.seasons.tick(s, 1.0)
	t.check(
		s.economy.forage_call and s.economy.forage_mult == Data.FORAGE_MULT,
		"foraging: idle hands go out and bring back twice as much"
	)
	t.check(not s.economy.births_paused and s.economy.eat_factor == 1.0, "and no one is rationed")
	s.economy.feed(3, 0.1)
	t.check(s.economy.famine, "the famine fallback is switched on at once")
	t.check(not s.economy.take_famine_card(), "but it is not the run's famine card")


func test_a_cold_snap_burns_fuel_or_slows_the_workshops() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["charcoal"] = 100
	s.seasons.kind = "cold"
	s.seasons.phase = "pending"
	s.seasons.choose(s, 0)
	_run(s, Data.SEASON_LENGTH - 1.0)
	var burnt: int = 100 - int(s.economy.inv["charcoal"])
	t.check(
		burnt == int((Data.SEASON_LENGTH - 1.0) / Data.COLD_BURN_SECONDS), "one charcoal every six seconds (%d)" % burnt
	)
	var s2: Sim = t.fresh()
	s2.economy.inv["charcoal"] = 100
	s2.seasons.kind = "cold"
	s2.seasons.phase = "pending"
	s2.seasons.choose(s2, 1)
	_run(s2, 30.0)
	t.check(s2.economy.inv["charcoal"] == 100, "huddling burns nothing")
	t.give(s2, 100)
	var kiln: Vector2i = s2.world.camp_pos + Vector2i(3, 0)
	t.place_free(s2, "charcoal_pit", kiln)
	var b: Dictionary = s2.town.buildings[s2.town.building_at[kiln]]
	t.check(s2.seasons.speed_factor(s2, b) == Data.HUDDLE_PACE, "but a workshop works at four fifths")


func test_a_bloom_surge_runs_the_tide_or_costs_coal() -> void:
	var s: Sim = t.fresh()
	s.seasons.kind = "surge"
	s.seasons.phase = "pending"
	s.seasons.choose(s, 0)
	t.check(
		s.seasons.tide_pace() == Data.SURGE_PACE and s.seasons.keeps_buildings(),
		"let it come: half again as fast, nothing lost"
	)
	var s2: Sim = t.fresh()
	s2.economy.inv["coal"] = 30
	s2.seasons.kind = "surge"
	s2.seasons.phase = "pending"
	s2.seasons.choose(s2, 1)
	t.check(s2.economy.inv["coal"] == 30 - Data.SURGE_COAL, "hold it back: the coal is paid")
	t.check(s2.seasons.tide_pace() == 1.0 and not s2.seasons.keeps_buildings(), "and the tide keeps its pace")
	var s3: Sim = t.fresh()
	s3.economy.inv["coal"] = 5
	s3.seasons.kind = "surge"
	s3.seasons.phase = "pending"
	s3.seasons.choose(s3, 1)
	t.check(s3.economy.inv["coal"] == 0, "with less coal than that, what there is goes and the stores never go under")


func test_a_season_is_remembered_by_a_save() -> void:
	var s: Sim = t.fresh()
	s.seasons.kind = "lean"
	s.seasons.phase = "pending"
	s.seasons.choose(s, 1)
	_run(s, 20.0)
	var copy := Sim.new()
	copy.generate(42)
	t.check(RunSave.restore(copy, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the save loads")
	t.check(copy.seasons.to_dict() == s.seasons.to_dict(), "and the season is as it was")
