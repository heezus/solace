extends RefCounted
## Era 2, Bronze Dawn, stage 2 (design-system/10-bronze-dawn.md): carts and the Cart Shed, Causeways and the Stone
## Bridge, Bronze Tools and their wear, the Bronze Ploughshare and Granaries. Run from tests/run_tests.gd, which owns
## check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const Roads = preload("res://scripts/roads.gd")
const Hands = preload("res://scripts/hands.gd")
const Work = preload("res://scripts/work.gd")
const Kith = preload("res://scripts/kith.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Haulers = preload("res://scripts/haulers.gd")
const RunSave = preload("res://scripts/run_save.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const TradePicker = preload("res://scripts/trade_picker.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_causeways_make_roads_stone_and_fast()
	test_the_stone_bridge()
	test_a_cart_shed_makes_carts()
	test_a_cart_keeps_to_the_roads()
	test_a_cart_will_not_cross_a_wooden_bridge()
	test_bronze_tools_are_crafted_and_worn()
	test_bronze_tools_speed_work()
	test_the_ploughshare()
	test_granaries_house_more()
	test_a_trading_post_must_be_set()
	test_a_trading_post_swaps_goods()
	test_a_trading_post_is_served_by_haulers()
	test_the_trade_picker_cycles_goods()


## A game with the techs in `have` researched, the whole map in sight and plenty of everything.
func game(have: Array) -> Sim:
	var s: Sim = t.fresh()
	t.give(s, 999)
	for tech in have:
		s.tech_tree.researched[tech] = true
	s.pathing.refresh()
	return s


## The n-th open grass tile near the Hearth (not touching the river, nothing built on it), in a fixed order.
func spot(s: Sim, n: int) -> Vector2i:
	var found := 0
	for r in range(2, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != r or s.world.tile_at(p) != "grass" or s.world.touches_river(p):
					continue
				if s.town.building_at.has(p) or s.world.roads.has(p):
					continue
				if found == n:
					return p
				found += 1
	return Vector2i(-1, -1)


# --- Causeways and the Stone Bridge --------------------------------------------


func test_causeways_make_roads_stone_and_fast() -> void:
	var s := game(["haulers"])
	var grass: Vector2i = t.find_grass(s, false)
	t.check(Rules.cost_at("road", "grass") == Data.BUILDINGS["road"]["cost"], "a road is wood before Causeways")
	t.check(Rules.cost_at("road", "grass", true) == {"stone": 1, "brick": 1}, "and 1 Stone and 1 Brick after")
	t.check(Rules.cost_at("road", "rock", true) == Data.PASS_COST, "a pass through Rocks costs the same either way")
	s.economy.inv["wood"] = 2
	s.economy.inv["stone"] = 0
	s.economy.inv["brick"] = 0
	t.check(s.town.placement_error("road", grass) == "", "wood buys a road before Causeways")
	s.tech_tree.researched["causeways"] = true
	t.check(s.town.placement_error("road", grass) == "Not enough materials", "after it, wood no longer does")
	s.economy.inv["stone"] = 1
	s.economy.inv["brick"] = 1
	t.check(s.place("road", grass), "1 Stone and 1 Brick lay a road")
	t.check(
		s.economy.inv["stone"] == 0 and s.economy.inv["brick"] == 0 and s.economy.inv["wood"] == 2, "and only those"
	)
	# Five times as fast as open ground, paved or not.
	t.check(is_equal_approx(s.pathing.walk_cost(grass), Data.CAUSEWAY_WALK_COST), "a road walks at the Causeway cost")
	t.check(is_equal_approx(1.0 / Data.CAUSEWAY_WALK_COST, 5.0), "which is 5x open ground")
	s.tech_tree.researched["paved_roads"] = true
	s.pathing.refresh()
	t.check(is_equal_approx(s.pathing.walk_cost(grass), Data.CAUSEWAY_WALK_COST), "paving does not slow it again")
	# A Kith really covers five tiles in half a second.
	var row: Array = []
	for i in 7:
		var p := grass + Vector2i(i, 0)
		if s.world.tile_at(p) == "grass" and not s.town.building_at.has(p):
			s.world.roads[p] = true
			s.pathing.update_cell(p)
			row.append(p)
	t.check(row.size() == 7, "a straight row of road tiles")
	var k: Dictionary = s.people.kith[0]
	k["pos"] = Vector2(row[0])
	t.check(s.people.walk_to(k, row[6]), "there is a way along it")
	s.people.step(k, 0.5)
	t.check(
		absf(Vector2(k["pos"]).distance_to(Vector2(row[0])) - 5.0) < 0.01, "5 tiles in half a second: %s" % [k["pos"]]
	)
	var plain := game(["haulers"])
	var q: Vector2i = t.find_grass(plain, false)
	plain.world.roads[q] = true
	plain.pathing.update_cell(q)
	t.check(is_equal_approx(plain.pathing.walk_cost(q), Data.WALK_COST["road"]), "without it a road keeps its own pace")


func test_the_stone_bridge() -> void:
	var s := game(["haulers"])
	var cross: Dictionary = t._find_crossing(s)
	var river: Vector2i = cross["river"]
	t.check(s.town.placement_error("stone_bridge", river) == "Not discovered yet", "the Stone Bridge needs Causeways")
	s.tech_tree.researched["causeways"] = true
	var grass: Vector2i = t.find_grass(s, false)
	t.check(s.town.placement_error("stone_bridge", grass) == "Bridges go on river tiles", "it goes on the river")
	s.economy.inv["stone"] = 5
	s.economy.inv["brick"] = 4
	t.check(s.town.placement_error("stone_bridge", river) == "Not enough materials", "it costs 6 Stone and 4 Brick")
	s.economy.inv["stone"] = 6
	t.check(s.place("stone_bridge", river), "and goes down when paid for")
	t.check(s.economy.inv["stone"] == 0 and s.economy.inv["brick"] == 0, "paying exactly that")
	t.check(s.world.roads.has(river) and s.world.stone_bridges.has(river), "it is a road over the river, and stone")
	t.check(s.town.built_type(river) == "stone_bridge", "it is told apart from a Wooden Bridge")
	t.check(not s.world.is_wooden_bridge(river), "which it is not")
	t.check(is_equal_approx(s.pathing.walk_cost(river), Data.CAUSEWAY_WALK_COST), "it walks at the Causeway pace")
	var other: Vector2i = river + cross["side"]
	t.check(s.place("bridge", other), "a Wooden Bridge goes beside it")
	t.check(s.town.built_type(other) == "bridge" and s.world.is_wooden_bridge(other), "and is wooden")
	t.check(is_equal_approx(s.pathing.walk_cost(other), Data.WALK_COST["road"]), "at the pace it always had")
	t.check(not s.pathing.astar.is_point_solid(river), "the Kith cross the Stone Bridge")
	# It saves and loads, and tearing it down gives half back.
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d) and copy.world.stone_bridges.has(river), "a saved game keeps the Stone Bridge")
	t.check(not copy.world.stone_bridges.has(other), "and not the wooden one")
	var refund: Dictionary = s.demolish(river)
	t.check(refund == {"stone": 3, "brick": 2}, "tearing it down gives half back: %s" % [refund])
	t.check(not s.world.roads.has(river) and not s.world.stone_bridges.has(river), "and the river is open water again")


# --- Carts -------------------------------------------------------------------


func test_a_cart_shed_makes_carts() -> void:
	var s := game(["haulers", "the_wheel"])
	t.check(s.town.carts_allowed() == 0, "no Cart Shed, no carts")
	s.people.found(6)
	s.tick(0.1)
	var carts := s.people.kith.filter(func(k): return k["cart"])
	t.check(carts.is_empty(), "so every hauler walks")
	var shed: Vector2i = spot(s, 0)
	var shed2: Vector2i = spot(s, 1)
	t.check(t.place_free(s, "cart_shed", shed), "a Cart Shed goes by the Hearth")
	t.check(s.town.carts_allowed() == Data.CARTS_PER_SHED, "it turns %d haulers into carts" % Data.CARTS_PER_SHED)
	s.tick(0.1)
	carts = s.people.kith.filter(func(k): return k["cart"])
	t.check(carts.size() == Data.CARTS_PER_SHED, "that many are carts (%d)" % carts.size())
	t.check(s.people.kith[0]["cart"] and s.people.kith[1]["cart"], "the first haulers in the list push them")
	t.check(Haulers.carry_cap(s, carts[0]) == Data.CARRY * Data.CART_LOAD, "a cart carries 20")
	t.check(Haulers.carry_cap(s, s.people.kith[5]) == Data.CARRY, "a hauler carries 10")
	t.check(Haulers.carry_cap(s) == Data.CARRY, "and carry_cap with no one named is a hauler's")
	s.tech_tree.researched["carrying_poles"] = true
	t.check(Haulers.carry_cap(s, carts[0]) == Data.CARRY * 4, "Carrying Poles double a cart's load too")
	t.check(t.place_free(s, "cart_shed", shed2), "a second Cart Shed")
	s.tick(0.1)
	t.check(s.people.kith.filter(func(k): return k["cart"]).size() == 4, "makes two more carts")
	t.check(Data.BUILDINGS["cart_shed"]["tech"] == "the_wheel", "the Cart Shed comes with The Wheel")
	s.demolish(shed)
	s.demolish(shed2)
	s.tick(0.1)
	t.check(s.people.kith.filter(func(k): return k["cart"]).is_empty(), "without the sheds the carts are haulers again")
	# A Kith at work is never a cart.
	t.place_free(s, "cart_shed", shed)
	t.place_free(s, "twine_post", shed2)
	s.tick(0.1)
	for k in s.people.kith:
		t.check(not k["cart"] or k["job"] == "haul", "only haulers push carts")


func test_a_cart_keeps_to_the_roads() -> void:
	var s := game(["haulers", "the_wheel", "cordage"])
	s.people.found(6)
	t.check(t.place_free(s, "cart_shed", spot(s, 0)), "a Cart Shed")
	s.tick(0.1)
	var cart: Dictionary = s.people.kith[0]
	var walker: Dictionary = s.people.kith[5]
	t.check(cart["cart"] and not walker["cart"], "one is a cart, one a hauler")
	var off: Vector2i = spot(s, 12)
	t.check(not s.world.roads.has(off) and s.world.tile_at(off) != "river", "an open spot off every road")
	cart["pos"] = Vector2(off)
	walker["pos"] = Vector2(off)
	s.tick(0.1)
	t.check(cart["path"].is_empty() and Kith.tile_of(cart) == off, "a cart off the road waits where it stands")
	t.check(not walker["path"].is_empty() or Kith.tile_of(walker) != off, "a hauler walks home across country")
	# Put it on a road that reaches the Hearth, and it rolls home.
	var post: Vector2i = spot(s, 0)
	t.check(s.place("twine_post", post), "a Twine Post")
	t.road_link(s, post)
	var on_road: Vector2i = Vector2i(-1, -1)
	for p in s.world.roads:
		on_road = p
	cart["pos"] = Vector2(on_road)
	for i in 80:
		s.tick(0.1)
	t.check(Vector2(cart["pos"]).distance_to(Vector2(s.world.camp_pos)) < 4.0, "a cart on a road finds its way back")


func test_a_cart_will_not_cross_a_wooden_bridge() -> void:
	var s := game(["haulers", "the_wheel", "causeways"])
	var cross: Dictionary = t._find_crossing(s)
	var river: Vector2i = cross["river"]
	var side: Vector2i = cross["side"]
	var near: Vector2i = river - side
	var far: Vector2i = river + side * 2
	for p in [near, far]:
		s.world.roads[p] = true
		s.pathing.update_cell(p)
	t.check(s.place("bridge", river) and s.place("bridge", river + side), "two Wooden Bridges span the river")
	var kith: Dictionary = s.people.kith[0]
	kith["pos"] = Vector2(near)
	kith["cart"] = false
	t.check(Roads.walk(s, kith, far), "a hauler crosses a Wooden Bridge")
	t.check(not Roads.cart_can_reach(s, near, far), "a cart cannot")
	kith["cart"] = true
	kith["pos"] = Vector2(near)
	t.check(not Roads.walk(s, kith, far), "so a cart has no road to the far bank")
	t.check(Roads.cart_can_reach(s, near, near), "though it can stand where it is")
	s.demolish(river)
	s.demolish(river + side)
	t.check(s.place("stone_bridge", river) and s.place("stone_bridge", river + side), "the Wooden Bridges become stone")
	t.check(Roads.cart_can_reach(s, near, far), "and then a cart rolls across")
	kith["pos"] = Vector2(near)
	t.check(Roads.walk(s, kith, far), "by road")


# --- Bronze Tools --------------------------------------------------------------


func test_bronze_tools_are_crafted_and_worn() -> void:
	var s := game([])
	s.economy.inv["bronze"] = 1
	s.economy.inv["bronze_tools"] = 0
	t.check(not Hands.recipe_unlocked(s, "bronze_tools"), "Bronze Tools are crafted only once discovered")
	t.check(not Hands.craft(s, "bronze_tools"), "so nothing is made yet")
	s.tech_tree.researched["bronze_tools"] = true
	s.economy.inv["wood"] = 1
	t.check(not Hands.craft(s, "bronze_tools"), "a Bronze Tool takes 1 Bronze and 2 Wood: one Wood is not enough")
	s.economy.inv["wood"] = 2
	t.check(Hands.craft(s, "bronze_tools"), "with them it is made")
	t.check(
		s.economy.inv["bronze_tools"] == 1 and s.economy.inv["bronze"] == 0 and s.economy.inv["wood"] == 0, "by hand"
	)
	t.check(Data.RECIPES["bronze_tools"]["out"] == {"bronze_tools": 1}, "one at a time")
	# A worker takes the best tool there is, and it lasts 200 jobs.
	var k: Dictionary = s.people.kith[0]
	s.economy.inv["flint_tools"] = 1
	s.people.equip(k)
	t.check(Kith.tool_of(k) == "bronze_tools", "Bronze Tools before Flint Tools")
	t.check(k["tool"] == Data.BRONZE_TOOL_JOBS and Data.BRONZE_TOOL_JOBS == 200, "a Bronze Tool lasts 200 jobs")
	t.check(
		s.economy.inv["bronze_tools"] == 0 and s.economy.inv["flint_tools"] == 1, "the stockpile gave the bronze one"
	)
	t.check(Kith.tool_jobs("flint_tools") == Data.TOOL_JOBS, "a Flint Tool still lasts its 40")
	# Wear: a job a tool, and the player hears when one breaks.
	var hut: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	s.tick(0.1)
	var worker: Dictionary = s.people.kith[b["worker"]]
	worker["tool"] = 3
	worker["tool_id"] = "bronze_tools"
	s.economy.inv["bronze_tools"] = 0
	s.economy.inv["flint_tools"] = 0
	s.events.clear()
	for i in 2:
		s.people.wear(b)
	t.check(worker["tool"] == 1 and s.events.is_empty(), "each job wears it by one")
	s.people.wear(b)
	t.check(worker["tool"] == 0 and worker["tool_id"] == "", "the last job breaks it")
	t.check(s.events == ["A Bronze Tool wore out"], "and says which: %s" % [s.events])
	s.economy.inv["bronze_tools"] = 1
	s.people.wear(b)
	t.check(Kith.tool_of(worker) == "bronze_tools" and worker["tool"] == 200, "a spare is picked up at once")
	t.check(Kith.tool_of({"tool": 5}) == "flint_tools", "a save from before Bronze Tools holds a flint one")
	t.check(Kith.tool_of({"tool": 0, "tool_id": "bronze_tools"}) == "", "and a broken tool is none")
	var saved := Sim.new()
	saved.generate(42)
	t.check(RunSave.restore(saved, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a save with tools loads")
	t.check(Kith.tool_of(saved.people.kith[b["worker"]]) == "bronze_tools", "and the worker still holds bronze")


func test_bronze_tools_speed_work() -> void:
	var s := game([])
	var hut: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	s.economy.inv["bronze_tools"] = 1
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	s.tick(0.1)
	var k: Dictionary = s.people.kith[b["worker"]]
	t.check(Kith.tool_of(k) == "bronze_tools", "the hut's worker took the Bronze Tool")
	t.check(is_equal_approx(Bonuses.speed(s, b), 2.0), "Bronze Tools double the speed (%.2f)" % Bonuses.speed(s, b))
	k["tool_id"] = "flint_tools"
	t.check(is_equal_approx(Bonuses.speed(s, b), 1.5), "Flint Tools give half as much again")
	k["tool"] = 0
	t.check(is_equal_approx(Bonuses.speed(s, b), 1.0), "and nothing, none")
	t.check(Bonuses.tool_bonus("bronze_tools") == 1.0 and Bonuses.tool_bonus("flint_tools") == 0.5, "the two shares")
	t.check(Bonuses.tool_bonus("wood") == 0.0, "no other item is a tool")
	s.hand_tools = true
	t.check(
		is_equal_approx(Hands.hold_time(s, "wood"), Data.HAND_TOOLS["flint_tools"]["hold"]),
		"by hand, with Flint Tools: %.1f s" % Data.HAND_TOOLS["flint_tools"]["hold"]
	)
	s.tech_tree.researched["bronze_tools"] = true
	t.check(is_equal_approx(Hands.hold_time(s, "wood"), 0.4), "after Bronze Tools: 0.4 s")
	k["tool"] = 10
	k["tool_id"] = "bronze_tools"
	var line := BuildingPanel.worker_text(s, b)
	t.check(line.contains("bronze tool has 10 uses left"), "the card says which tool and how many uses: " + line)
	k["tool"] = 0
	line = BuildingPanel.worker_text(s, b)
	t.check(
		line.contains("no bronze tool") and line.contains("100%"),
		"an empty hand is told what a Bronze Tool gives: " + line
	)
	t.check(Data.BONUSES["bronze_tools"]["add"] > Data.BONUSES["tools"]["add"], "bronze beats flint")


# --- The Ploughshare and Granaries ---------------------------------------------


func test_the_ploughshare() -> void:
	var s := game(["plough"])
	var hut: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	var grass: Vector2i = t.find_grass(s, false)
	s.world.fields[grass] = true
	var n: int = Work.bundle_size(s, b, "grain")
	var total := 0
	for i in 20:
		total += Work.harvest_amount(s, b, grass, "grain")
	var want := roundi(20.0 * n * (1.0 + Data.PLOUGH_FIELD_BONUS))
	t.check(absi(total - want) <= 1, "a Field with the Plough gives half again (%d, want %d)" % [total, want])
	s.tech_tree.researched["bronze_ploughshare"] = true
	b["field_extra"] = 0.0
	total = 0
	for i in 20:
		total += Work.harvest_amount(s, b, grass, "grain")
	want = roundi(20.0 * n * (1.0 + Data.PLOUGH_FIELD_BONUS + Data.PLOUGHSHARE_FIELD_BONUS))
	t.check(absi(total - want) <= 1, "the Ploughshare adds another half (%d, want %d)" % [total, want])
	s.tech_tree.researched["calendar"] = true
	b["field_extra"] = 0.0
	total = 0
	for i in 20:
		total += Work.harvest_amount(s, b, grass, "grain")
	want = roundi(20.0 * n * (1.0 + Data.PLOUGH_FIELD_BONUS + Data.PLOUGHSHARE_FIELD_BONUS + Data.CALENDAR_FIELD_BONUS))
	t.check(absi(total - want) <= 1, "and the Calendar's share still counts (%d, want %d)" % [total, want])
	var bare := game([])
	bare.world.fields[grass] = true
	var hut2: Vector2i = bare.world.camp_pos + Vector2i(-2, 0)
	t.place_free(bare, "gatherers_hut", hut2)
	var b2: Dictionary = bare.town.buildings[bare.town.building_at[hut2]]
	var plain := 0
	for i in 20:
		plain += Work.harvest_amount(bare, b2, grass, "grain")
	t.check(plain == 20 * Work.bundle_size(bare, b2, "grain"), "and with none of them a Field gives its bundle")


func test_granaries_house_more() -> void:
	var s := game([])
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0
	s.economy.inv["berries"] = 100
	var base: int = s.town.housing()
	t.check(s.town.granary_homes() == 0, "no Granaries, no extra homes")
	s.tech_tree.researched["granaries"] = true
	t.check(s.town.granary_homes() == 5, "100 food houses 5 more (%d)" % s.town.granary_homes())
	t.check(s.town.housing() == base + 5, "and the housing says so")
	s.economy.inv["berries"] = 39
	t.check(s.town.granary_homes() == 1, "every 20 food counts, a part of 20 does not")
	s.economy.inv["berries"] = 0
	s.economy.inv["flour"] = 10  # flour is worth 3 food each, 5 once Baking is known
	t.check(s.town.granary_homes() == 1, "any food counts, flour too (30 food)")
	s.economy.inv["flour"] = 0
	s.economy.inv["berries"] = 100000
	t.check(s.town.granary_homes() == Data.GRANARY_HOMES, "a full store houses at most %d" % Data.GRANARY_HOMES)
	s.economy.inv["berries"] = 0
	t.check(s.town.granary_homes() == 0 and s.town.housing() == base, "and an empty one adds nothing")
	# More room means more births: the Kith grow past a housing that was full.
	var g := game(["granaries"])
	for id in Data.ITEM_ORDER:
		g.economy.inv[id] = 0
	g.economy.inv["berries"] = 400
	t.check(g.town.housing() > Data.BUILDINGS["camp"]["housing"], "a stocked Granary makes room beyond the Hearth")


# --- The Trading Post ---------------------------------------------------------


## A Trading Post by the Hearth in a game that has Markets, and its index in the building list.
func _post(s: Sim, n: int = 0) -> int:
	var at: Vector2i = spot(s, n)
	t.check(t.place_free(s, "trading_post", at), "a Trading Post")
	return s.town.building_at[at]


func test_a_trading_post_must_be_set() -> void:
	var s := game(["haulers", "markets"])
	s.people.found(4)
	var i := _post(s)
	var b: Dictionary = s.town.buildings[i]
	t.check(not Buildings.is_trading(b), "a new Trading Post trades nothing")
	t.check(Buildings.recipe_in(b).is_empty() and Buildings.recipe_out(b).is_empty(), "it has no recipe to run")
	t.check(not s.town.wants_to_work(b), "so there is nothing for a worker to do")
	for n in 150:
		s.tick(0.1)
	t.check(b["status"] == Data.TRADE_UNSET, "and it says to choose (%s)" % b["status"])
	t.check(not s.town.set_trade(i, "wood", "wood"), "swapping a good for itself is refused")
	t.check(not s.town.set_trade(i, "wood", "unobtainium"), "and so is a good that doesn't exist")
	t.check(not s.town.set_trade(s.town.building_at[s.world.camp_pos], "wood", "stone"), "only a Trading Post trades")
	t.check(s.town.set_trade(i, "wood", ""), "giving first, getting later")
	t.check(not Buildings.is_trading(b), "is still not trading")
	t.check(s.town.set_trade(i, "wood", "flint"), "then both")
	t.check(Buildings.is_trading(b), "now it trades")
	t.check(Buildings.recipe_in(b) == {"wood": Data.TRADE_GIVE}, "it takes %d Wood" % Data.TRADE_GIVE)
	t.check(Buildings.recipe_out(b) == {"flint": Data.TRADE_GET}, "and makes %d Flint" % Data.TRADE_GET)
	t.check(Data.BUILDINGS["trading_post"]["tech"] == "markets", "the Trading Post comes with Markets")
	t.check(not Data.TECHS["markets"]["unlock"].is_empty(), "and Markets says so")


func test_a_trading_post_swaps_goods() -> void:
	var s := game(["haulers", "markets"])
	s.people.found(4)
	var i := _post(s)
	var b: Dictionary = s.town.buildings[i]
	t.check(s.town.set_trade(i, "wood", "flint"), "wood for flint")
	s.economy.inv["wood"] = 30
	s.economy.inv["flint"] = 0
	s.town.haul(i)
	t.check(b["inbuf"].get("wood", 0) == Data.TRADE_GIVE * 2, "the hand-carry loads two swaps' worth")
	t.check(s.economy.inv["wood"] == 30 - Data.TRADE_GIVE * 2, "out of the stockpile")
	for n in 400:
		s.tick(0.1)
	var flint: int = int(s.economy.inv["flint"]) + Buildings.buffered(b["out"])
	t.check(flint >= 1, "a swap came out in 40 s (%d Flint)" % flint)
	t.check(flint <= 2, "and no more than the two that were loaded (%d)" % flint)
	# Changing what it gives returns what it had loaded.
	s.economy.inv["wood"] = 30
	s.town.haul(i)
	var loaded: int = int(b["inbuf"].get("wood", 0))
	var before: int = s.economy.inv["wood"]
	t.check(s.town.set_trade(i, "stone", "wood"), "turned round: stone for wood")
	t.check(b["inbuf"].is_empty() and s.economy.inv["wood"] == before + loaded, "the loaded Wood went back")
	# It saves and loads with what it was set to.
	var copy := Sim.new()
	RunSave.restore(copy, RunSave.dump(s))
	var c: Dictionary = copy.town.buildings[i]
	t.check(c["give"] == "stone" and c["get"] == "wood" and Buildings.is_trading(c), "a save keeps the trade")
	var unset := game(["markets"])
	var u := _post(unset)
	var again := Sim.new()
	RunSave.restore(again, RunSave.dump(unset))
	t.check(not Buildings.is_trading(again.town.buildings[u]), "and an unset one stays unset")
	t.check(again.town.buildings[u]["give"] == "" and again.town.buildings[u]["get"] == "", "with nothing chosen")


func test_a_trading_post_is_served_by_haulers() -> void:
	var s := game(["haulers", "markets", "cordage"])
	s.people.found(8)
	var i := _post(s)
	t.road_link(s, s.town.buildings[i]["pos"])
	t.check(s.town.set_trade(i, "wood", "flint"), "wood for flint")
	s.economy.inv["wood"] = 60
	s.economy.inv["flint"] = 0
	for n in 2000:
		s.tick(0.1)
	t.check(s.economy.inv["flint"] >= 3, "haulers kept it fed for 200 s (%d Flint)" % s.economy.inv["flint"])
	t.check(s.economy.inv["wood"] < 60, "and paid for it in Wood (%d left)" % s.economy.inv["wood"])
	var made: float = s.economy.flows.rate("flint")
	t.check(made != 0.0 or s.economy.inv["flint"] > 0, "the flows count it")


func test_the_trade_picker_cycles_goods() -> void:
	var seen := {"wood": true, "stone": true, "flint": true}
	t.check(TradePicker.next_good(seen, "", "") == "wood", "the first good held is first")
	t.check(TradePicker.next_good(seen, "wood", "") == "stone", "then the next in the bar's order")
	t.check(TradePicker.next_good(seen, "flint", "") == "wood", "and round again")
	t.check(TradePicker.next_good(seen, "wood", "stone") == "flint", "never the one on the other line")
	t.check(TradePicker.next_good({}, "", "") == "", "nothing held, nothing to choose")
	t.check(TradePicker.next_good({"wood": true}, "", "wood") == "", "only the other line's good: none")
	t.check(TradePicker.label_text(Data.TRADE_GIVES, "") == Data.TRADE_GIVES % Data.TRADE_NONE, "an unchosen line")
	t.check(TradePicker.label_text(Data.TRADE_GETS, "flint").contains("Flint"), "a chosen one names the good")
