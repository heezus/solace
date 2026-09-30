extends RefCounted
## Growth needs steady food (found by the newcomer playtest of 2026-09-30: the Kith grew to the housing cap on the
## starting berries and then starved back down). A birth needs the stockpile to cover its cost and the food coming
## in over the last RATE_WINDOW seconds, from huts, haulers, fields and the player's hands while they gather, to
## cover what everyone eats. A big stockpile alone never grows anyone. Run from tests/run_tests.gd.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_food_supply_counts_what_comes_in()
	test_a_young_window_counts_as_little()
	test_hands_count_only_while_they_gather()
	test_steady_means_income_covers_eating()
	test_a_birth_needs_steady_income()
	test_a_big_stockpile_with_no_income_does_not_grow()
	test_a_falling_income_stops_births()
	test_births_respect_housing()
	test_storytelling_and_shelter_still_count()
	test_the_starting_food_gives_no_fourth_kith()
	test_a_hut_on_berries_feeds_growth()
	test_the_note_and_the_goal_say_steady_food()


## A game with `count` people, a Hearth and `stock` berries in a stockpile that holds nothing else.
func _camp(count: int, stock: int) -> Sim:
	var s: Sim = t.fresh()
	for id in s.economy.inv:
		s.economy.inv[id] = 0
	s.economy.inv["berries"] = stock
	s.economy.food_credit = 0.0
	s.people.found(count)
	return s


## Give the food flows a full window of `per_sec` berries a second from `source` and set the eating rate
## as the feed would.
func _income(s: Sim, per_sec: float, source: String = "gatherers_hut") -> void:
	s.economy.flows.hist = []
	for _n in Data.RATE_WINDOW:
		s.economy.flows.hist.append({"berries|" + source: per_sec})
	s.economy.food_use = s.people.kith.size() * Data.FOOD_PER_KITH_PER_SEC


func _eating(s: Sim) -> float:
	return s.people.kith.size() * Data.FOOD_PER_KITH_PER_SEC


## Tick the people's growth for `seconds` seconds with the income held steady at `per_sec`.
func _grow(s: Sim, seconds: int, per_sec: float) -> void:
	for _n in seconds:
		_income(s, per_sec)
		s.people.grow(1.0, true)


func test_food_supply_counts_what_comes_in() -> void:
	var s := _camp(3, 10)
	t.check(s.economy.food_supply() == 0.0, "a new camp has no food coming in")
	_income(s, 0.5)
	t.check(is_equal_approx(s.economy.food_supply(), 0.5), "a hut's berries are income: %.2f" % s.economy.food_supply())
	s.economy.flows.hist[0]["berries|" + Data.FLOW_EAT_SOURCE] = -30.0
	t.check(is_equal_approx(s.economy.food_supply(), 0.5), "eating is not income, and is not taken off it")
	s.economy.flows.hist = [{"fish|fishing_weir": 3.0 * Data.RATE_WINDOW}]
	t.check(
		is_equal_approx(s.economy.food_supply(), 3.0 * Data.FOOD_VALUE["fish"]),
		"a Fish is worth what it feeds, so it counts for more than a berry"
	)


func test_a_young_window_counts_as_little() -> void:
	var s := _camp(3, 10)
	s.economy.flows.hist = [{"berries|gatherers_hut": 6.0}]
	t.check(
		is_equal_approx(s.economy.food_supply(), 6.0 / Data.RATE_WINDOW),
		"one delivery in the first second is spread over the whole window, not a rate of 6 a second"
	)


func test_hands_count_only_while_they_gather() -> void:
	var s := _camp(3, 10)
	_income(s, 0.4, "hand")
	s.economy.food_use = _eating(s)
	t.check(s.economy.food_is_steady(), "a player gathering berries feeds growth while they do")
	for _n in Data.RATE_WINDOW:
		s.economy.advance(1.0)  # thirty quiet seconds: the window forgets
	t.check(s.economy.food_supply() == 0.0 and not s.economy.food_is_steady(), "and once they stop it fades away")


func test_steady_means_income_covers_eating() -> void:
	var s := _camp(4, 10)
	_income(s, _eating(s) * 0.99)
	t.check(not s.economy.food_is_steady(), "a little less than everyone eats is not steady")
	_income(s, _eating(s))
	t.check(s.economy.food_is_steady(), "exactly what they eat is")
	_income(s, _eating(s) * 3.0)
	t.check(s.economy.food_is_steady(), "and more is")
	s.economy.flows.hist = []
	s.economy.food_use = 0.0
	t.check(s.economy.food_is_steady(), "no mouths to feed is steady too")


func test_a_birth_needs_steady_income() -> void:
	var s := _camp(3, 40)
	_grow(s, int(Data.GROW_TIME) - 1, 0.5)
	t.check(s.people.kith.size() == 3 and s.people.grow_timer > 0.0, "with steady income the timer runs")
	_grow(s, 1, 0.5)
	t.check(s.people.kith.size() == 4, "and a birth comes after GROW_TIME seconds: %d" % s.people.kith.size())
	t.check(s.economy.inv["berries"] < 40, "a birth still eats its food")
	var poor := _camp(3, int(3 * Data.BIRTH_RESERVE + Data.BIRTH_FOOD) - 1)
	_grow(poor, int(Data.GROW_TIME) * 2, 0.5)
	t.check(poor.people.kith.size() == 3, "steady income is not enough if the stockpile can't cover a birth")
	var exact := _camp(3, int(3 * Data.BIRTH_RESERVE + Data.BIRTH_FOOD))
	_grow(exact, int(Data.GROW_TIME), 0.5)
	t.check(exact.people.kith.size() == 4, "exactly enough stock and steady income is enough")


func test_a_big_stockpile_with_no_income_does_not_grow() -> void:
	var s := _camp(3, 500)
	_grow(s, int(Data.GROW_TIME) * 5, 0.0)
	t.check(s.people.kith.size() == 3, "500 berries in the stockpile and none coming in: nobody is born")
	t.check(s.people.grow_timer == 0.0, "and the birth timer stays at zero")


func test_a_falling_income_stops_births() -> void:
	var s := _camp(3, 500)
	var eating := _eating(s)
	_grow(s, int(Data.GROW_TIME) * 2, eating * 0.5)
	t.check(s.people.kith.size() == 3, "income that covers half of what they eat: nobody is born")
	s.people.grow_timer = Data.GROW_TIME - 1.0
	_grow(s, 3, eating * 2.0)
	t.check(s.people.kith.size() == 4, "the income rises above it: a birth follows")
	s.people.grow_timer = Data.GROW_TIME - 1.0
	_grow(s, 1, 0.0)
	t.check(s.people.kith.size() == 4 and s.people.grow_timer == 0.0, "and if it stops the timer is reset")


func test_births_respect_housing() -> void:
	var s := _camp(4, 500)
	_grow(s, int(Data.GROW_TIME) * 3, 1.0)
	t.check(s.people.kith.size() == 4, "a full Hearth grows no more, however steady the food")
	t.check(t.place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2)), "a Dwelling goes up")
	_grow(s, int(Data.GROW_TIME) * 10, 1.0)
	t.check(s.people.kith.size() == s.town.housing() and s.people.kith.size() == 7, "and they fill it and stop")


func test_storytelling_and_shelter_still_count() -> void:
	var s := _camp(4, 500)
	t.place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2))
	s.tech_tree.researched["storytelling"] = true
	s.tech_tree.researched["shelter"] = true
	var wait := ceili(s.people.grow_time())
	t.check(s.people.grow_time() < Data.GROW_TIME, "Storytelling still shortens the wait")
	_grow(s, wait, 1.0)
	t.check(s.people.kith.size() == 5, "and a birth comes in that time")
	_grow(s, wait * 8, 1.0)
	t.check(s.people.kith.size() == 9, "Shelter gives each Dwelling two more places (%d)" % s.people.kith.size())


## Ticking the whole game: three people, the starting berries, room for more and nothing coming in.
func test_the_starting_food_gives_no_fourth_kith() -> void:
	var s: Sim = t.fresh()
	t.check(s.people.kith.size() == Data.KITH_START, "three to begin with")
	for _n in 240:
		s.tick(1.0)
	t.check(s.people.kith.size() == Data.KITH_START, "four minutes on the starting berries alone: still three")
	t.check(Ui.growth_note(s) == Data.GROW_NOTE_FOOD, "and the note says why")


## The real thing: a hut on berries, its worker sent on trips as a player clicking would, and a Dwelling.
func test_a_hut_on_berries_feeds_growth() -> void:
	var s: Sim = t.fresh()
	var camp := s.world.camp_pos
	var spot := Vector2i(-1, -1)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(camp + Vector2i(dx + 8 * (1 if camp.x < 12 else -1), dy), "grass")
	spot = camp + Vector2i(8 * (1 if camp.x < 12 else -1), 0)
	s.world.set_tile(spot + Vector2i(1, 0), "berry")
	s.world.set_tile(spot + Vector2i(-1, 1), "berry")
	s.pathing.build()
	s.people.learned_by["berries"] = "Aro"
	s.economy.inv["berries"] = 30
	t.place_free(s, "gatherers_hut", spot)
	t.place_free(s, "dwelling", camp + Vector2i(0, 2))
	var i: int = s.town.building_at[spot]
	t.check(s.town.buildings[i]["focus"] == "berries", "a hut on the bushes")
	for _n in 900:  # 90 s, a trip always queued
		s.town.buildings[i]["trips"] = 3
		s.tick(0.1)
	print("Hut on berries: %d Kith after 90 s, food %d" % [s.people.kith.size(), int(s.economy.food_total())])
	t.check(s.economy.food_supply() >= s.economy.food_use, "the hut's berries cover what the Kith eat")
	t.check(s.people.kith.size() > Data.KITH_START, "and a new Kith is born")


func test_the_note_and_the_goal_say_steady_food() -> void:
	var s := _camp(3, 500)
	_income(s, 0.0)
	t.check(Ui.growth_note(s) == Data.GROW_NOTE_FOOD, "the note beside the count: " + Data.GROW_NOTE_FOOD)
	t.check(Data.GROW_NOTE_FOOD.contains("steady food"), "in words a newcomer can act on")
	_income(s, 1.0)
	t.check(Ui.growth_note(s) == "", "and it goes away once the food is steady")
	s.economy.starving = true
	t.check(Ui.growth_note(s).begins_with("Starving"), "starving still comes first")
	var goal := ""
	for g in Data.GOALS:
		if g["id"] == "dwelling":
			goal = g["text"]
	t.check(goal.contains("steady food") and not goal.contains("spare"), "the Dwelling goal says the same: " + goal)
	var e := Economy.new()
	t.check(e.food_supply() == 0.0, "an Economy alone reports no supply")
