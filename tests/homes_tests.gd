extends RefCounted
## PR 2 of the growth batch (design-system/17-needs-and-upgrades.md): dwelling tiers and their needs, the auto-upgrade
## with haulers, scaffolds and the player's caps, the needs in the UI, and the pacing the bots keep. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Homes = preload("res://scripts/homes.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Roads = preload("res://scripts/roads.gd")
const HomeLook = preload("res://scripts/home_look.gd")
const HomesStrip = preload("res://scripts/homes_strip.gd")
const Buildings = preload("res://scripts/buildings.gd")

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
	test_haulers_serve_homes_that_a_road_links()
	test_a_home_asks_to_upgrade_once_content_and_linked()
	test_haulers_carry_the_goods_in_and_the_household_uses_them()
	test_haulers_carry_the_materials_and_the_home_changes_tier()
	test_a_homestead_grows_into_a_longhouse_and_then_wants_three_foods()
	test_a_finished_home_must_show_its_needs_again()
	test_an_upgrade_is_never_free()
	test_scaffolds_are_limited_by_the_builders()
	test_the_scaffold_state_is_a_pure_function_of_the_home()
	test_the_cap_holds_back_the_next_tier()
	test_lowering_the_cap_cancels_a_scaffold_that_waits()
	test_the_cap_control_steps_and_saves()
	test_a_scaffold_survives_a_save()


## How many more Kith a home at `tier` houses than a Dwelling does.
func _more(tier: int) -> int:
	return Data.HOME_TIERS[tier]["housing"] - Data.HOME_TIERS[0]["housing"]


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
	t.check(
		s.town.housing() == base + _more(1) and Homes.name_of(b) == "Homestead", "a Homestead houses what its tier does"
	)
	b["tier"] = 2
	t.check(s.town.housing() == base + _more(2) and Homes.name_of(b) == "Longhouse", "and a Longhouse more again")
	s.tech_tree.researched["shelter"] = true
	t.check(s.town.housing() == base + _more(2) + 2, "Thatched Roofs add their 2 to every tier")
	t.check(Homes.name_of(s.town.buildings[0]) == "Hearth", "the Hearth keeps its own name")
	t.check(Homes.housing_of(b) == Data.HOME_TIERS[2]["housing"], "housing_of says the tier's own number")


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
	b["inbuf"]["rope"] = Data.HOME_TIERS[1]["goods"]["rope"]
	st = Homes.status(s, b)
	t.check(st["goods"][0]["have"] == st["goods"][0]["need"], "its own Rope counts, all of it")
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
	t.check(b["met"] <= Homes.after_of(b) * 2.0, "or past twice the wait, so a long good run cannot hide a bad one")
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
	t.check(not Homes.status(s, b)["met"] and not b["content"], "it is just not content")
	t.check(
		s.town.housing() == housing - _more(2), "so it houses only a Dwelling's worth: no new Kith are born into it"
	)
	var kith: int = s.people.kith.size()
	_run(s, 120.0)
	t.check(s.people.kith.size() >= kith, "and nobody leaves for it")
	for id in ["berries", "fish", "flour"]:
		s.economy.inv[id] = 200
	b["inbuf"]["brick"] = 20
	b["inbuf"]["charcoal"] = 20
	for i in 3:
		Homes.look(s, b)
	t.check(b["content"] and s.town.housing() == housing, "supplied again, it is content and houses its full share")


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
	t.check(lifted.town.housing() == s.town.housing() - _more(2), "housing as it was before tiers")


# --- Upgrading -------------------------------------------------------------------


## A stocked game with a Dwelling by the Hearth and a road to it, Paths & Haulers known: {"s", "b", "p"}. No home may
## reach a Longhouse unless a test lifts that cap, so a long run stops at the Homestead.
func _linked_game() -> Dictionary:
	var g := _home_game()
	var s: Sim = g["s"]
	s.town.set_home_cap(2, 0)
	t.give(s, 200)
	s.tech_tree.researched["haulers"] = true
	t.road_link(s, g["p"])
	return g


## Tick `s` for `seconds` in half-second steps, keeping the Kith fed.
func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds * 2.0):
		s.tick(0.5)
		s.economy.inv["berries"] = maxi(s.economy.inv["berries"], 200)


func test_haulers_serve_homes_that_a_road_links() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	t.check(not Roads.linked(s, b), "a home with no road is not linked")
	t.check(Buildings.served(b) and not Buildings.needs_worker(b), "homes are served by haulers but need no worker")
	t.road_link(s, g["p"])
	t.check(Roads.linked(s, b), "a road to the Hearth links it, as it does a workshop")
	t.check(not Buildings.served(s.town.buildings[0]), "the Hearth is a depot, not a customer")


func test_a_home_asks_to_upgrade_once_content_and_linked() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	t.give(s, 200)
	s.tech_tree.researched["haulers"] = true
	for i in 12:
		Homes.look(s, b)
	t.check(b["met"] >= Homes.after_of(b), "content for long enough")
	t.check(b["site"] == "" and Homes.stalled(s, b) != "", "but with no road it cannot ask: %s" % Homes.stalled(s, b))
	t.road_link(s, g["p"])
	t.check(Homes.stalled(s, b) == "", "with a road nothing holds it back")
	Homes.look(s, b)
	t.check(b["site"] == "waiting", "it asks, and a scaffold waits for materials")
	t.check(Homes.wanted(b).has("wood") and Homes.wanted(b).has("clay"), "wanting wood and clay")
	var fresh_home := {"s": s, "b": b}
	t.check(fresh_home["b"]["tier"] == 0, "still a Dwelling until the work is done")
	# a Dwelling that has food but not for long enough does not ask
	var g2 := _linked_game()
	var b2: Dictionary = g2["b"]
	for i in 3:
		Homes.look(g2["s"], b2)
	t.check(b2["site"] == "", "three looks are not enough")
	# and one that is short of food never does
	var g3 := _linked_game()
	for id in Data.FOOD_VALUE:
		g3["s"].economy.inv[id] = 0
	for i in 20:
		Homes.look(g3["s"], g3["b"])
	t.check(g3["b"]["site"] == "" and g3["b"]["met"] == 0.0, "no food, no ask")


func test_haulers_carry_the_goods_in_and_the_household_uses_them() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["tier"] = 1
	s.economy.inv["rope"] = 50
	_run(s, 60.0)
	t.check(b["inbuf"].get("rope", 0) >= 1, "haulers carried Rope to the Homestead (%d)" % b["inbuf"].get("rope", 0))
	t.check(
		b["inbuf"].get("rope", 0) <= Data.HOME_TIERS[1]["goods"]["rope"] * Data.HOME_GOOD_ROUNDS,
		"no more than two rounds"
	)
	var before: int = s.economy.inv["rope"]
	_run(s, Data.HOME_GOOD_SECONDS * 3.0)
	t.check(s.economy.inv["rope"] < before, "the household uses its Rope: %d to %d" % [before, s.economy.inv["rope"]])
	var used: int = 50 - s.economy.inv["rope"] - b["inbuf"].get("rope", 0)
	t.check(used >= 2 and used <= 12, "a round or so of it, not a flood (%d)" % used)
	b["inbuf"]["rope"] = 2
	Homes.use_goods(s, b)
	t.check(s.economy.flows.now.get("rope|dwelling", 0.0) <= -1.0, "and the flows show it used, under the home's name")
	b["inbuf"]["rope"] = Data.HOME_TIERS[1]["goods"]["rope"] * Data.HOME_GOOD_ROUNDS
	t.check(b["tier"] == 1 and Homes.status(s, b)["goods"][0]["have"] >= 1, "it stays supplied")
	s.economy.inv["rope"] = 0
	b["inbuf"]["rope"] = 0
	_run(s, 80.0)
	t.check(not Homes.status(s, b)["met"], "with no Rope in the stockpile the need goes unmet")
	t.check(b["tier"] == 1, "and the home stays a Homestead")


func test_haulers_carry_the_materials_and_the_home_changes_tier() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	var housing: int = s.town.housing()
	var wood: int = s.economy.inv["wood"]
	var clay: int = s.economy.inv["clay"]
	_run(s, Homes.after_of(b) + Data.HOME_CHECK_SECONDS * 2.0)
	t.check(b["site"] != "" or b["tier"] == 1, "content and linked, the home asks")
	_run(s, 120.0)
	t.check(b["tier"] == 1 and b["site"] == "", "haulers brought the materials and it became a Homestead")
	t.check(s.town.housing() == housing + _more(1), "which houses more")
	var up: Dictionary = Data.HOME_TIERS[0]["up"]
	t.check(
		s.economy.inv["wood"] <= wood - up["wood"],
		"the wood left the stockpile (%d to %d)" % [wood, s.economy.inv["wood"]]
	)
	t.check(s.economy.inv["clay"] <= clay - up["clay"], "and the clay")
	# a Homestead has more to show: it needs a second food and Rope
	t.check(Homes.status(s, b)["foods_need"] == 2, "its needs are the Homestead's now")


func test_a_homestead_grows_into_a_longhouse_and_then_wants_three_foods() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	s.town.set_home_cap(2, Data.HOME_CAP_OPEN)
	b["tier"] = 1
	var housing: int = s.town.housing()
	s.economy.inv["rope"] = 0
	_run(s, 400.0)
	t.check(b["tier"] == 1, "a Homestead with no Rope does not grow: it needs its own goods first")
	t.check(
		not Homes.status(s, b)["met"] and Homes.stalled(s, b).contains("Rope"),
		"and says Rope: %s" % Homes.stalled(s, b)
	)
	s.economy.inv["rope"] = 200
	_run(s, 500.0)
	t.check(b["tier"] == 2 and b["site"] == "", "two foods and Rope, and it grows")
	t.check(s.town.housing() == housing + _more(2) - _more(1), "a Longhouse houses more than a Homestead")
	var up: Dictionary = Data.HOME_TIERS[1]["up"]
	t.check(s.economy.inv["brick"] <= 200 - up["brick"], "the Brick left the stockpile")
	t.check(Homes.status(s, b)["goods"].size() == 2, "and it now wants two goods")
	s.economy.inv["fish"] = 0
	for id in ["berries", "flour"]:
		s.economy.inv[id] = 200
	_run(s, 200.0)
	t.check(
		Homes.status(s, b)["foods_have"] == 2 and not Homes.status(s, b)["met"], "with no fish it wants a third food"
	)
	t.check(b["tier"] == 2, "and stays a Longhouse")


func test_a_finished_home_must_show_its_needs_again() -> void:
	var g := _home_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["site"] = "building"
	b["met"] = 90.0
	b["site_t"] = Homes.build_of(b)
	Homes.tick(s, b, 0.1)
	t.check(b["tier"] == 1 and b["site"] == "" and b["met"] == 0.0, "the new tier counts its needs from nothing")


func test_an_upgrade_is_never_free() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	for id in Data.HOME_TIERS[0]["up"]:
		s.economy.inv[id] = 0
	_run(s, 400.0)
	t.check(b["tier"] == 0 and b["site"] == "", "with no wood or clay in the stockpile the home does not even ask")
	t.check(Homes.stalled(s, b).contains("Wood"), "it says what it waits for: %s" % Homes.stalled(s, b))
	s.economy.inv["wood"] = 100
	_run(s, 150.0)
	t.check(
		b["tier"] == 0 and Homes.stalled(s, b).contains("Clay"), "wood alone is not enough: %s" % Homes.stalled(s, b)
	)
	s.economy.inv["clay"] = 100
	var wood: int = s.economy.inv["wood"]
	_run(s, 200.0)
	t.check(b["tier"] == 1, "wood and clay are")
	t.check(s.economy.inv["wood"] <= wood - Data.HOME_TIERS[0]["up"]["wood"], "and they were paid out of the stockpile")
	t.check(Data.HOME_TIERS[0]["up"].size() >= 2, "the price is more than one thing")


func test_scaffolds_are_limited_by_the_builders() -> void:
	var g := _two_homes()
	var s: Sim = g["s"]
	var more: Array = []
	for n in Data.HOME_SITES_AT_ONCE + 1:
		var q: Vector2i = s.world.camp_pos + Vector2i(0, 3 + n)
		s.town.add_building("dwelling", q)
		t.road_link(s, q)
		more.append(s.town.buildings[s.town.building_at[q]])
	for b in s.town.buildings:
		if Homes.is_home(b):
			b["met"] = Homes.after_of(b)
	for i in 6:
		for b in s.town.buildings:
			if Homes.is_home(b):
				Homes.look(s, b)
	t.check(
		Homes.sites(s) == Data.HOME_SITES_AT_ONCE,
		"no more scaffolds stand at once than there are builders (%d)" % Homes.sites(s)
	)
	var waiting: Dictionary = {}
	for b in s.town.buildings:
		if Homes.is_home(b) and b["site"] == "":
			waiting = b
	t.check(Homes.stalled(s, waiting).contains("builders"), "the rest say so: %s" % Homes.stalled(s, waiting))


func test_the_scaffold_state_is_a_pure_function_of_the_home() -> void:
	var g := _linked_game()
	var b: Dictionary = g["b"]
	var look := HomeLook.state(b)
	t.check(look["tier"] == 0 and not look["scaffold"] and look["to"] == -1, "a settled Dwelling has no scaffold")
	t.check(look["sprite"] == "dwelling", "and borrows the Dwelling sprite until the tiers have art")
	b["site"] = "waiting"
	look = HomeLook.state(b)
	t.check(look["scaffold"] and look["site"] == "waiting" and look["to"] == 1, "waiting: a scaffold, becoming tier 2")
	t.check(look["fill"] == 0.0 and look["progress"] == 0.0, "nothing delivered, nothing built")
	b["inbuf"]["wood"] = Data.HOME_TIERS[0]["up"]["wood"]
	t.check(HomeLook.state(b)["fill"] > 0.0 and HomeLook.state(b)["fill"] < 1.0, "some of it in: partly filled")
	b["inbuf"]["clay"] = Data.HOME_TIERS[0]["up"]["clay"]
	t.check(HomeLook.state(b)["fill"] == 1.0, "all of it in: full")
	b["site"] = "building"
	b["site_t"] = Homes.build_of(b) * 0.5
	look = HomeLook.state(b)
	t.check(look["site"] == "building" and is_equal_approx(look["progress"], 0.5), "building: halfway")
	var copy := b.duplicate(true)
	HomeLook.state(b)
	t.check(copy == b, "asking changes nothing")
	b["tier"] = 2
	b["site"] = ""
	t.check(HomeLook.state(b)["to"] == -1 and HomeLook.state(b)["tier"] == 2, "the top tier has nothing to become")
	t.check(HomeLook.state(s_hearth(g))["sprite"] == "dwelling", "(the pure function reads any building dict)")


func s_hearth(g: Dictionary) -> Dictionary:
	return g["s"].town.buildings[0]


# --- The caps --------------------------------------------------------------------


func _two_homes() -> Dictionary:
	var g := _linked_game()
	var s: Sim = g["s"]
	var q: Vector2i = s.world.camp_pos + Vector2i(-3, 0)
	s.town.add_building("dwelling", q)
	t.road_link(s, q)
	return {"s": s, "a": g["b"], "b": s.town.buildings[s.town.building_at[q]]}


func test_the_cap_holds_back_the_next_tier() -> void:
	var g := _two_homes()
	var s: Sim = g["s"]
	t.check(Sim.new().town.home_cap(1) == Data.HOME_CAP_OPEN, "a new game has no cap")
	t.check(Sim.new().town.home_cap(2) == Data.HOME_CAP_OPEN, "on either tier")
	t.check(not s.town.set_home_cap(0, 3), "a Dwelling has no cap to set")
	t.check(not s.town.set_home_cap(3, 3), "and there is no fourth tier")
	t.check(s.town.set_home_cap(1, 1), "the cap on Homesteads can be set")
	_run(s, 700.0)
	var tiers := [g["a"]["tier"], g["b"]["tier"]]
	tiers.sort()
	t.check(tiers == [0, 1], "one home may reach it and the other stays a Dwelling (%s)" % [tiers])
	t.check(Homes.reaching(s, 1) == 1, "reaching counts the one that did")
	var held: Dictionary = g["a"] if g["a"]["tier"] == 0 else g["b"]
	t.check(Homes.stalled(s, held).contains("Homestead"), "and says why the other waits: %s" % Homes.stalled(s, held))
	s.town.set_home_cap(1, 0)
	t.check(s.town.home_cap(1) == 0, "a cap of nothing is allowed")
	s.town.set_home_cap(1, 2)
	_run(s, 400.0)
	t.check(g["a"]["tier"] == 1 and g["b"]["tier"] == 1, "raise it and the other one grows too")
	s.town.set_home_cap(1, 500)
	t.check(s.town.home_cap(1) == Data.HOME_CAP_OPEN, "the cap never passes the open number")
	s.town.set_home_cap(1, -4)
	t.check(s.town.home_cap(1) == 0, "or goes below nothing")


func test_lowering_the_cap_cancels_a_scaffold_that_waits() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["site"] = "waiting"  # a scaffold that stands, with nothing in the stockpile to build it with
	for id in Data.HOME_TIERS[0]["up"]:
		s.economy.inv[id] = 0
	_run(s, 100.0)
	t.check(b["site"] == "waiting", "a scaffold waits for its materials")
	s.town.set_home_cap(1, 0)
	_run(s, 60.0)
	t.check(b["site"] == "" and b["tier"] == 0, "lower the cap and the scaffold comes down")
	s.town.set_home_cap(1, 5)
	t.give(s, 200)
	t.check(Homes.can_ask(s, b), "and raising it lets the home ask again")


func test_the_cap_control_steps_and_saves() -> void:
	var g := _two_homes()
	var s: Sim = g["s"]
	var strip := HomesStrip.new()
	strip.setup(s)
	t.check(strip.values.size() == 2, "a control for Homesteads and one for Longhouses")
	t.check(strip.values[1].text == "0 of any", "it reads 0 of any: none yet, no cap")
	strip._step(1, 1)
	t.check(s.town.home_cap(1) == Data.HOME_CAP_OPEN and strip.plus[1].disabled, "plus at no limit does nothing")
	g["a"]["tier"] = 1
	strip._step(1, -1)
	t.check(s.town.home_cap(1) == 1, "the first step down settles on what has already reached it")
	t.check(strip.values[1].text == "1 of 1", "and reads 1 of 1")
	strip._step(1, -1)
	t.check(s.town.home_cap(1) == 0 and strip.minus[1].disabled, "down to nothing, then the button is off")
	strip._step(1, 1)
	t.check(s.town.home_cap(1) == 1, "plus raises it again")
	s.town.set_home_cap(2, 3)
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a saved game restores")
	t.check(copy.town.home_cap(1) == 1 and copy.town.home_cap(2) == 3, "the caps come back")
	var old: Dictionary = RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	old["buildings"].erase("home_caps")
	var lifted := Sim.new()
	t.check(RunSave.restore(lifted, old), "a save from before caps restores")
	t.check(lifted.town.home_cap(1) == Data.HOME_CAP_OPEN, "its caps are all open")
	strip.free()


func test_a_scaffold_survives_a_save() -> void:
	var g := _linked_game()
	var s: Sim = g["s"]
	var b: Dictionary = g["b"]
	b["site"] = "building"
	b["site_t"] = 12.5
	b["inbuf"]["wood"] = 10
	b["inbuf"]["clay"] = 6
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a saved game restores")
	var home: Dictionary = copy.town.buildings[copy.town.building_at[g["p"]]]
	t.check(home["site"] == "building" and is_equal_approx(home["site_t"], 12.5), "the scaffold comes back mid-build")
	t.check(is_equal_approx(HomeLook.state(home)["progress"], HomeLook.state(b)["progress"]), "looking the same")
	t.give(copy, 200)
	copy.tech_tree.researched["haulers"] = true
	_run(copy, Homes.build_of(home))
	t.check(home["tier"] == 1, "and finishes")
