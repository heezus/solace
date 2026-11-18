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
	test_a_fever_costs_food_or_pace()
	test_a_blight_a_bad_vein_and_a_storm_cost_stores_or_pace()
	test_no_kind_comes_twice_in_an_era_and_none_comes_inside_ten_minutes_of_another()
	test_a_new_era_lets_the_kinds_come_again_and_the_card_shows_its_auto_answer()
	test_each_era_adds_kinds_and_no_kind_comes_before_its_era()
	test_what_a_season_takes_is_counted_told_and_floated()
	test_a_season_is_remembered_by_a_save()
	test_a_card_nobody_answers_takes_the_answer_that_costs_the_fewest_goods()


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
		s.seasons.phase == "pending" and s.seasons.kind in ["lean", "fever"],
		"the first is a lean season or a fever: nothing else could come yet"
	)
	t.check(s.economy.eat_factor == 1.0, "and nothing changes until the player answers")
	s.seasons.kind = "lean"  # the rest of this test is about a lean season
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
	while out.size() < seasons and s.seasons.time < 200000.0:
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


## Fun playtest 5: a Surge card that answered itself with "let it come" cost about 200 goods; the cheaper answer cost 20 Coal.
func test_a_card_nobody_answers_takes_the_answer_that_costs_the_fewest_goods() -> void:
	var s: Sim = t.fresh()
	for id in ["wood", "grain", "fiber", "stone", "clay", "berries"]:
		s.economy.inv[id] = 200
	s.economy.inv["coal"] = 30
	s.seasons.kind = "surge"
	s.seasons.phase = "pending"
	t.check(s.seasons.cheapest(s) == 1, "holding it back (20 Coal) beats losing a fifth of 1200 raw goods")
	s.seasons.tick(s, Data.SEASON_AUTO + 1.0)
	t.check(s.seasons.phase == "active" and s.seasons.answer == 1, "and the unanswered card takes it")
	t.check(s.economy.inv["coal"] == 10 and s.economy.inv["wood"] == 200, "the Coal is paid, the Wood kept")


func test_a_bloom_surge_runs_the_tide_or_costs_coal() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["wood"] = 100
	s.economy.inv["grain"] = 50
	s.seasons.kind = "surge"
	s.seasons.phase = "pending"
	s.seasons.choose(s, 0)
	t.check(
		s.seasons.tide_pace() == Data.SURGE_PACE and s.seasons.keeps_buildings(),
		"let it come: half again as fast, nothing lost"
	)
	t.check(
		s.economy.inv["wood"] == 80 and s.economy.inv["grain"] == 40,
		"but the Bloom takes a fifth of the raw goods: %s" % [s.seasons.spent]
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
	s3.economy.inv["wood"] = 10
	s3.seasons.kind = "surge"
	s3.seasons.phase = "pending"
	s3.seasons.choose(s3, 1)
	t.check(
		s3.economy.inv["coal"] == 5 and s3.economy.inv["wood"] == 0,
		"with too little coal the wood goes instead, as far as it goes, and the stores never go under"
	)


func _answered(s: Sim, kind: String, index: int) -> void:
	s.seasons.kind = kind
	s.seasons.phase = "pending"
	s.seasons.choose(s, index)
	s.seasons.tick(s, 1.0)


func _building(s: Sim, type: String, at: Vector2i) -> Dictionary:
	s.town.add_building(type, at)
	return s.town.buildings[s.town.building_at[at]]


func test_a_fever_costs_food_or_pace() -> void:
	var s: Sim = t.fresh()
	_answered(s, "fever", 0)
	t.check(s.economy.eat_factor == Data.TEND_EAT, "tending the sick: everyone eats a quarter more")
	var hut := _building(s, "gatherers_hut", s.world.camp_pos + Vector2i(3, 0))
	t.check(s.seasons.speed_factor(s, hut) == 1.0, "and work goes on at its pace")
	var s2: Sim = t.fresh()
	_answered(s2, "fever", 1)
	var hut2 := _building(s2, "gatherers_hut", s2.world.camp_pos + Vector2i(3, 0))
	t.check(s2.economy.eat_factor == 1.0, "pushing on: no one eats more")
	t.check(s2.seasons.speed_factor(s2, hut2) == Data.PUSH_PACE, "but every building works at seven tenths")


func test_a_blight_a_bad_vein_and_a_storm_cost_stores_or_pace() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["wood"] = 100
	_answered(s, "blight", 1)
	var field := _building(s, "field", s.world.camp_pos + Vector2i(3, 0))
	var hut := _building(s, "gatherers_hut", s.world.camp_pos + Vector2i(0, 3))
	t.check(s.economy.inv["wood"] == 60, "treating the rows costs 40 Wood")
	t.check(is_equal_approx(s.seasons.speed_factor(s, field), 0.75), "and the fields keep three quarters of their pace")
	t.check(s.seasons.speed_factor(s, hut) == 1.0, "while a hut is not touched")
	var s2: Sim = t.fresh()
	_answered(s2, "blight", 0)
	var field2 := _building(s2, "field", s2.world.camp_pos + Vector2i(3, 0))
	t.check(
		s2.seasons.speed_factor(s2, field2) == Data.BLIGHT_PACE,
		"waiting it out: the fields at two fifths, nothing spent"
	)
	var s3: Sim = t.fresh()
	_answered(s3, "vein", 1)
	var mine := _building(s3, "mine", s3.world.camp_pos + Vector2i(3, 0))
	t.check(s3.seasons.speed_factor(s3, mine) == Data.VEIN_PACE, "digging round it: a mine at half its pace")
	var s4: Sim = t.fresh()
	s4.economy.inv["iron"] = 15
	s4.economy.inv["wood"] = 100
	_answered(s4, "storm", 1)
	var hut4 := _building(s4, "gatherers_hut", s4.world.camp_pos + Vector2i(3, 0))
	t.check(is_equal_approx(s4.seasons.speed_factor(s4, hut4), 0.9), "braving the storm: every building at nine tenths")
	t.check(
		s4.economy.inv["wood"] == 40 and s4.economy.inv["iron"] == 15,
		"(15 Iron is not the 20 asked: the Wood goes instead)"
	)


func test_no_kind_comes_twice_in_an_era_and_none_comes_inside_ten_minutes_of_another() -> void:
	var s := Sim.new()
	s.generate(42)
	_everything(s)
	var pool_size: int = s.seasons.pool(s).size()
	var kinds: Array = _kinds(42, pool_size + 3)
	t.check(
		kinds.size() == pool_size,
		"the era's kinds come once each and then no card follows: %d of %d" % [kinds.size(), pool_size]
	)
	var names: Array = kinds.map(func(x): return x.split("@")[0])
	var seen := {}
	for n in names:
		seen[n] = true
	t.check(seen.size() == names.size(), "no kind comes twice in an era: %s" % [names])
	for i in range(1, kinds.size()):
		var gap: int = int(kinds[i].split("@")[1]) - int(kinds[i - 1].split("@")[1])
		t.check(gap >= 600, "at most one in 10 game minutes: %d s between seasons %d and %d" % [gap, i - 1, i])


func test_a_new_era_lets_the_kinds_come_again_and_the_card_shows_its_auto_answer() -> void:
	var s: Sim = t.fresh()
	s.seasons.used = ["lean", "fever"]
	s.seasons.kept_era = 1
	t.check(s.seasons.eligible(s).is_empty(), "the stone age has used both its kinds")
	s.story.record("bronze_dawn")
	t.check(not s.seasons.eligible(s).is_empty() and s.seasons.used.is_empty(), "Bronze Dawn starts the list over")
	var def: Dictionary = Data.SEASONS["lean"]
	s.seasons.kind = "lean"
	var pick: int = s.seasons.cheapest(s)
	t.check(
		pick in [0, 1] and def["options"][pick]["label"] != "", "the answer a card takes by itself has a label to show"
	)


func test_each_era_adds_kinds_and_no_kind_comes_before_its_era() -> void:
	var s: Sim = t.fresh()
	t.check(
		s.seasons.pool(s) == ["lean", "fever"], "the stone age meets a lean season or a fever: %s" % [s.seasons.pool(s)]
	)
	s.story.record("bronze_dawn")
	t.check("cold" in s.seasons.pool(s) and not "surge" in s.seasons.pool(s), "Bronze Dawn adds the cold snap")
	s.tide.begun = true
	t.check("surge" in s.seasons.pool(s), "and the tide adds the surge")
	t.check(not "blight" in s.seasons.pool(s), "no blight yet")
	s.story.record("star_falling")
	t.check("blight" in s.seasons.pool(s) and not "vein" in s.seasons.pool(s), "the Falling Star adds the blight")
	s.story.record(Data.IRONFALL_EVENT)
	t.check("vein" in s.seasons.pool(s) and not "storm" in s.seasons.pool(s), "Ironfall adds the bad vein")
	s.story.record(Data.LIVEWIRE_BEGUN)
	t.check(s.seasons.pool(s).size() == Data.SEASONS.size(), "Livewire adds the storm: every kind")


func test_what_a_season_takes_is_counted_told_and_floated() -> void:
	var s: Sim = t.fresh()
	s.economy.inv["charcoal"] = 100
	_answered(s, "cold", 0)
	_run(s, 20.0)
	t.check(s.seasons.spent.get("charcoal", 0) == 10, "ten Charcoal burnt in twenty seconds: %s" % [s.seasons.spent])
	t.check(
		s.seasons.pops.size() == 10 and s.seasons.pops[0] == "-1 Charcoal",
		"each one floats over the Hearth: %s" % [s.seasons.pops]
	)
	t.check(s.seasons.spent_text() == "10 Charcoal", "and the season can say what it cost")
	s.events.clear()
	_run(s, Data.SEASON_LENGTH)
	t.check(
		s.events.any(
			func(e): return e.begins_with(Data.SEASONS["cold"]["over"]) and e.contains("It cost 45 Charcoal in all")
		),
		"the end says the whole bill: %s" % [s.events]
	)


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
