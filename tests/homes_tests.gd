extends RefCounted
## PR 2 of the growth batch (design-system/17-needs-and-upgrades.md): dwelling tiers and their needs, the auto-upgrade
## with haulers, scaffolds and the player's caps, the needs in the UI, and the pacing the bots keep. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Homes = preload("res://scripts/homes.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_three_tiers_with_the_page_needs()
	test_housing_follows_the_tier()
	test_a_food_kind_counts_once_enough_is_stocked()
	test_status_reads_the_homes_own_tier()
	test_needs_are_looked_at_slowly_and_a_miss_costs_what_it_lasted()
	test_unmet_needs_never_drop_a_tier()
	test_tiers_save_and_old_saves_load_at_the_first()


## A game with one Dwelling by the Hearth: {"s", "b" (the home), "p"}.
func _home_game() -> Dictionary:
	var s: Sim = t.fresh()
	var p: Vector2i = s.world.camp_pos + Vector2i(3, 0)
	s.town.add_building("dwelling", p)
	return {"s": s, "b": s.town.buildings[s.town.building_at[p]], "p": p}


# --- The tiers -------------------------------------------------------------------


func test_three_tiers_with_the_page_needs() -> void:
	var tiers: Array = Data.HOME_TIERS
	t.check(tiers.size() == 3 and Data.HOME_NAMES.size() == 3, "three tiers, each with a name")
	t.check(Data.HOME_NAMES == ["Dwelling", "Homestead", "Longhouse"], "Dwelling, Homestead, Longhouse")
	t.check(tiers[0]["foods"] == 1 and tiers[0]["goods"].is_empty(), "a Dwelling needs food, one kind, and no goods")
	t.check(tiers[1]["foods"] == 2 and tiers[1]["goods"].size() == 1, "a Homestead needs two foods and one good")
	t.check(tiers[1]["goods"].has("rope"), "that good is cordage (Rope)")
	t.check(tiers[2]["foods"] == 3 and tiers[2]["goods"].size() == 2, "a Longhouse needs three foods and two goods")
	t.check(tiers[2]["up"].is_empty(), "the top tier has nowhere to go")
	t.check(not tiers[0]["up"].is_empty() and not tiers[1]["up"].is_empty(), "the others ask for materials")
	t.check(tiers[0]["housing"] == Data.BUILDINGS["dwelling"]["housing"], "a Dwelling still houses what it always did")
	t.check(
		tiers[0]["housing"] < tiers[1]["housing"] and tiers[1]["housing"] < tiers[2]["housing"],
		"each tier houses more Kith"
	)
	for id in Data.FOOD_VALUE:
		t.check(Data.ITEMS.has(id), "%s is an item" % id)
	t.check(Data.FOOD_VALUE.size() >= 3, "there are three kinds of food to ask for")
	for tier in tiers:
		for id in tier["goods"]:
			t.check(Data.ITEMS.has(id) and not Data.FOOD_VALUE.has(id), "%s is a good, not a food" % id)
		for id in tier["up"]:
			t.check(Data.ITEMS.has(id), "%s is an item" % id)
	t.check(Data.HOME_CHECK_SECONDS >= 10.0, "needs are looked at slowly (every %d s)" % int(Data.HOME_CHECK_SECONDS))


func test_housing_follows_the_tier() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	var base: int = s.town.housing()
	t.check(Homes.tier_of(b) == 0 and Homes.name_of(b) == "Dwelling", "a new home is a Dwelling")
	b["tier"] = 1
	t.check(s.town.housing() == base + 2 and Homes.name_of(b) == "Homestead", "a Homestead houses 2 more")
	b["tier"] = 2
	t.check(s.town.housing() == base + 5 and Homes.name_of(b) == "Longhouse", "a Longhouse 5 more than a Dwelling")
	s.tech_tree.researched["shelter"] = true
	t.check(s.town.housing() == base + 7, "Thatched Roofs add their 2 to every tier")
	t.check(Homes.name_of(s.town.buildings[0]) == "Hearth", "the Hearth keeps its own name")
	t.check(Homes.housing_of(b) == 8, "housing_of says the tier's own number")


# --- Needs -----------------------------------------------------------------------


func test_a_food_kind_counts_once_enough_is_stocked() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	for id in Data.FOOD_VALUE:
		s.economy.inv[id] = 0
	t.check(Homes.foods_held(s).is_empty(), "no stock, no kind")
	s.economy.inv["berries"] = Data.HOME_FOOD_STOCK - 1
	t.check(Homes.foods_held(s).is_empty(), "a little of it is not a kind in stock")
	s.economy.inv["berries"] = Data.HOME_FOOD_STOCK
	t.check(Homes.foods_held(s) == ["berries"], "enough of one counts")
	s.economy.inv["fish"] = 500
	s.economy.inv["flour"] = Data.HOME_FOOD_STOCK
	t.check(Homes.foods_held(s).size() == 3, "variety is the count: three kinds")
	s.economy.inv["berries"] = 900
	t.check(Homes.foods_held(s).size() == 3, "and a mountain of one is still one kind")


func test_status_reads_the_homes_own_tier() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	for id in Data.FOOD_VALUE:
		s.economy.inv[id] = 0
	var st: Dictionary = Homes.status(s, b)
	t.check(not st["met"] and st["foods_need"] == 1 and st["foods_have"] == 0, "a Dwelling with no food is short")
	t.check(st["missing"].size() == 1 and st["missing"][0].contains("food"), "and says food: %s" % [st["missing"]])
	s.economy.inv["berries"] = 20
	t.check(Homes.status(s, b)["met"], "one stocked food meets a Dwelling")
	b["tier"] = 1
	st = Homes.status(s, b)
	t.check(not st["met"] and st["foods_need"] == 2, "a Homestead wants a second food")
	t.check(st["missing"].size() == 3, "and Rope, and a way to carry it in: %s" % [st["missing"]])
	t.check(st["missing"].any(func(m): return m.contains("Rope")), "the missing words name the Rope")
	t.check(st["missing"].any(func(m): return m.contains("Haulers")), "and Paths & Haulers while it is unknown")
	s.economy.inv["flour"] = 20
	s.tech_tree.researched["haulers"] = true
	st = Homes.status(s, b)
	t.check(st["foods_have"] == 2 and st["missing"].size() == 2, "two foods: Rope and a road are left")
	t.check(st["missing"].any(func(m): return m.contains("road")), "it is short of a road to the Hearth")
	b["inbuf"]["rope"] = 1
	st = Homes.status(s, b)
	t.check(st["goods"][0]["have"] == 1 and st["goods"][0]["need"] == 1, "its own Rope counts, one of one")
	t.check(st["met"] and st["missing"].is_empty(), "the Rope is in and so are two foods: met, road or not")
	b["tier"] = 2
	st = Homes.status(s, b)
	t.check(st["foods_need"] == 3 and st["goods"].size() == 2, "a Longhouse reads three foods and two goods")


func test_needs_are_looked_at_slowly_and_a_miss_costs_what_it_lasted() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	s.economy.inv["berries"] = 500
	var step := Data.HOME_CHECK_SECONDS
	Homes.tick(s, b, step * 0.9)
	t.check(b["met"] == 0.0, "no look before the wait is over")
	Homes.tick(s, b, step * 0.2)
	t.check(is_equal_approx(b["met"], step), "a look when it is: needs met, one step counted")
	Homes.tick(s, b, step * 3.0)
	t.check(is_equal_approx(b["met"], step * 4.0), "a long tick takes every look it owes")
	s.economy.inv["berries"] = 0
	for id in Data.FOOD_VALUE:
		s.economy.inv[id] = 0
	Homes.tick(s, b, step)
	t.check(is_equal_approx(b["met"], step * 3.0), "a miss takes off what it lasted, not everything")
	for i in 10:
		Homes.tick(s, b, step)
	t.check(b["met"] == 0.0, "and it never goes below nothing")
	s.economy.inv["berries"] = 500
	for i in 30:
		Homes.tick(s, b, step)
	t.check(
		b["met"] <= Data.HOME_UPGRADE_AFTER * 2.0, "or past twice the wait, so a long good run cannot hide a bad one"
	)
	var other: Dictionary = s.town.buildings[0]  # the Hearth
	Homes.tick(s, other, 999.0)
	t.check(other["met"] == 0.0 and other["check"] == 0.0, "nothing but a home looks at needs")


func test_unmet_needs_never_drop_a_tier() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["tier"] = 2
	var housing: int = s.town.housing()
	for id in Data.FOOD_VALUE:
		s.economy.inv[id] = 0
	for i in 200:
		s.tick(5.0)
		s.economy.inv["berries"] = maxi(s.economy.inv["berries"], 5)  # the Kith are kept alive: only the needs go unmet
	t.check(b["tier"] == 2, "a Longhouse with nothing it needs is still a Longhouse")
	t.check(s.town.housing() >= housing, "and houses what it did")
	t.check(not Homes.status(s, b)["met"], "it is just not content")


# --- Saves -----------------------------------------------------------------------


func test_tiers_save_and_old_saves_load_at_the_first() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["tier"] = 2
	b["met"] = 60.0
	b["check"] = 7.0
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a saved game restores")
	var home: Dictionary = copy.town.buildings[copy.town.building_at[g["p"]]]
	t.check(home["tier"] == 2 and typeof(home["tier"]) == TYPE_INT, "the tier comes back, as a whole number")
	t.check(
		is_equal_approx(home["met"], 60.0) and is_equal_approx(home["check"], 7.0), "so does how long needs were met"
	)
	t.check(copy.town.housing() == s.town.housing(), "and the room it makes")
	var old: Dictionary = RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	for saved in old["buildings"]["buildings"]:
		for key in ["tier", "check", "met"]:
			saved.erase(key)
	var lifted := Sim.new()
	t.check(RunSave.restore(lifted, old), "a save from before tiers restores")
	var plain: Dictionary = lifted.town.buildings[lifted.town.building_at[g["p"]]]
	t.check(plain["tier"] == 0 and plain["met"] == 0.0, "its homes load at tier 1, a Dwelling")
	t.check(lifted.town.housing() == s.town.housing() - 5, "housing as it was before tiers")
