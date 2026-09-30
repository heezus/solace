extends RefCounted
## Unit testbench for the Economy block (scripts/economy.gd): stockpile, food and eating, item flows.
## Economy is built alone, with a hand-set stockpile and a hand-set set of researched techs; no map,
## no Kith and no Sim. The last test checks that the Sim's blocks share its techs.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_new_stockpile()
	test_add_and_seen()
	test_can_afford()
	test_pay()
	test_try_pay_refuses_a_shortfall()
	test_food_value_follows_research()
	test_food_total()
	test_eating_order()
	test_eating_uses_credit_first()
	test_eating_with_too_little_food()
	test_flour_reserve()
	test_feed_sets_use_and_starving()
	test_preservation_cuts_food_use()
	test_flows_and_rates()
	test_eating_shows_up_as_a_flow()
	test_flow_window_forgets()
	test_economy_stands_alone()
	test_to_dict_and_from_dict()
	test_sim_shares_the_techs_with_the_economy()


## An Economy with every count zeroed, so a test sets exactly the stock it needs.
func _empty(techs: Dictionary = {}) -> Economy:
	var e := Economy.new(techs)
	for id in e.inv:
		e.inv[id] = 0
	e.food_credit = 0.0
	return e


## The techs that cost flour, researched, so no flour is held back for research. (Baking is one, so
## flour is worth its baked value here; berries and fish keep their base worth.)
func _no_reserve() -> Dictionary:
	var techs := {}
	for id in Data.TECHS:
		if Data.TECHS[id]["cost"].get("flour", 0) > 0:
			techs[id] = true
	return techs


func test_a_new_stockpile() -> void:
	var e := Economy.new()
	for id in Data.ITEM_ORDER:
		t.check(e.inv.has(id), "every item has a slot: " + id)
	t.check(e.inv["berries"] == 10, "the camp starts with 10 berries")
	t.check(e.inv["wood"] == 0 and e.inv["stone"] == 0, "and nothing else")
	t.check(
		e.seen.has("berries") and e.seen.has("wood") and e.seen.has("stone") and e.seen.has("flint"),
		"four items shown from the start"
	)
	t.check(not e.seen.has("clay"), "the rest appear once held")
	t.check(is_equal_approx(e.food_credit, 5.0), "a little food credit to start")
	t.check(not e.starving and is_equal_approx(e.food_use, 0.0), "not starving, nothing eaten yet")


func test_add_and_seen() -> void:
	var e := _empty()
	e.add("clay", 3)
	t.check(e.inv["clay"] == 3, "add puts items in the stockpile")
	t.check(e.seen.has("clay"), "and marks the item as seen")
	e.add("clay", 2)
	t.check(e.inv["clay"] == 5, "adds stack")
	e.add("clay", 0)
	t.check(e.inv["clay"] == 5, "adding nothing changes nothing")
	e.add("rope", 4)
	t.check(e.inv["rope"] == 4 and e.seen.has("rope"), "an item with no slot yet gets one")
	e.add("wood", -2)
	t.check(e.inv["wood"] == -2, "add takes its sign at face value: callers don't add negatives")


func test_can_afford() -> void:
	var e := _empty()
	e.inv["wood"] = 5
	e.inv["stone"] = 2
	t.check(e.can_afford({}), "an empty cost is always affordable")
	t.check(e.can_afford({"wood": 5}), "exactly enough is enough")
	t.check(e.can_afford({"wood": 3, "stone": 2}), "a cost of two items")
	t.check(not e.can_afford({"wood": 6}), "one short is not enough")
	t.check(not e.can_afford({"wood": 1, "stone": 3}), "every item must be covered")
	t.check(not e.can_afford({"gold": 1}), "an item never held counts as zero")
	t.check(e.can_afford({"gold": 0}), "and a zero cost of it is free")
	t.check(e.inv["wood"] == 5 and e.inv["stone"] == 2, "asking doesn't take anything")


func test_pay() -> void:
	var e := _empty()
	e.inv["wood"] = 5
	e.inv["stone"] = 2
	e.pay({"wood": 3, "stone": 2})
	t.check(e.inv["wood"] == 2 and e.inv["stone"] == 0, "pay takes each item in the cost")
	e.pay({})
	t.check(e.inv["wood"] == 2 and e.inv["stone"] == 0, "an empty cost takes nothing")
	e.pay({"wood": 2})
	t.check(e.inv["wood"] == 0, "pay can empty an item")
	t.check(not e.can_afford({"wood": 1}), "and then it can't be afforded")
	t.check(e.seen.has("wood"), "paying doesn't un-see an item")


func test_try_pay_refuses_a_shortfall() -> void:
	var e := _empty()
	e.inv["wood"] = 4
	e.inv["stone"] = 1
	t.check(not e.try_pay({"wood": 5}), "try_pay says no when short")
	t.check(e.inv["wood"] == 4, "and takes nothing")
	t.check(not e.try_pay({"wood": 2, "stone": 2}), "short on one item of two")
	t.check(e.inv["wood"] == 4 and e.inv["stone"] == 1, "leaves the covered item alone too")
	t.check(e.try_pay({"wood": 2, "stone": 1}), "try_pay says yes when covered")
	t.check(e.inv["wood"] == 2 and e.inv["stone"] == 0, "and takes the cost")
	t.check(e.try_pay({}), "an empty cost always goes through")
	for id in e.inv:
		t.check(e.inv[id] >= 0, "no count went negative: " + id)


func test_food_value_follows_research() -> void:
	var techs := {}
	var e := _empty(techs)
	t.check(e.food_value("berries") == Data.FOOD_VALUE["berries"], "berries have their base worth")
	t.check(e.food_value("fish") == Data.FOOD_VALUE["fish"], "fish have theirs")
	t.check(e.food_value("flour") == Data.FOOD_VALUE["flour"], "and so does flour")
	techs["smoking"] = true  # the same dictionary the Economy was built with: it sees the change
	t.check(e.food_value("berries") == Data.SMOKED_BERRY_FOOD, "Smoking makes berries worth more")
	t.check(e.food_value("fish") == Data.FOOD_VALUE["fish"], "but not fish")
	t.check(e.food_value("flour") == Data.FOOD_VALUE["flour"], "or flour")
	techs["baking"] = true
	t.check(e.food_value("flour") == Data.BAKED_FLOUR_FOOD, "Baking makes flour worth more")


func test_food_total() -> void:
	var techs := {}
	var e := _empty(techs)
	t.check(e.food_total() == 0.0, "no food, no total")
	e.inv["berries"] = 4
	e.inv["fish"] = 2
	e.inv["flour"] = 1
	var want: float = 4 * Data.FOOD_VALUE["berries"] + 2 * Data.FOOD_VALUE["fish"] + Data.FOOD_VALUE["flour"]
	t.check(is_equal_approx(e.food_total(), want), "the total counts each item at its worth")
	e.inv["wood"] = 50
	t.check(is_equal_approx(e.food_total(), want), "things you can't eat don't count")
	techs["smoking"] = true
	t.check(
		is_equal_approx(e.food_total(), want + 4 * (Data.SMOKED_BERRY_FOOD - Data.FOOD_VALUE["berries"])),
		"research changes it"
	)
	e.food_credit = 3.0
	t.check(e.inv["berries"] == 4, "asking for the total eats nothing")


func test_eating_order() -> void:
	var e := _empty(_no_reserve())  # nothing held back for research
	e.inv["berries"] = 1
	e.inv["fish"] = 1
	e.inv["flour"] = 1
	t.check(e.eat(Data.FOOD_VALUE["berries"]), "one meal of berries")
	t.check(e.inv["berries"] == 0 and e.inv["fish"] == 1 and e.inv["flour"] == 1, "berries go first")
	t.check(e.eat(Data.FOOD_VALUE["fish"]), "the next meal")
	t.check(e.inv["fish"] == 0 and e.inv["flour"] == 1, "fish go second")
	t.check(e.eat(e.food_value("flour")), "the last meal")
	t.check(e.inv["flour"] == 0, "flour goes last")
	t.check(is_equal_approx(e.food_credit, 0.0), "each item paid for exactly its meal")
	t.check(not e.eat(0.5), "and now there is nothing left to eat")


func test_eating_uses_credit_first() -> void:
	var e := _empty(_no_reserve())
	e.inv["fish"] = 3
	e.food_credit = 1.5
	t.check(e.eat(1.0), "a meal the credit covers")
	t.check(e.inv["fish"] == 3, "takes no item")
	t.check(is_equal_approx(e.food_credit, 0.5), "and uses up credit")
	t.check(e.eat(0.75), "a meal the credit can't cover")
	t.check(e.inv["fish"] == 2, "takes one whole item")
	t.check(is_equal_approx(e.food_credit, 0.5 + Data.FOOD_VALUE["fish"] - 0.75), "and keeps the change as credit")
	t.check(e.eat(0.0), "eating nothing always works")
	t.check(e.inv["fish"] == 2, "and takes nothing")


func test_eating_with_too_little_food() -> void:
	var e := _empty(_no_reserve())
	e.inv["berries"] = 1
	t.check(not e.eat(3.0), "three food from one berry can't be done")
	t.check(e.inv["berries"] == 0, "the berry was still eaten")
	t.check(is_equal_approx(e.food_credit, Data.FOOD_VALUE["berries"]), "and its worth is kept as credit")
	t.check(not e.eat(3.0), "still short")
	t.check(
		is_equal_approx(e.food_credit, Data.FOOD_VALUE["berries"]),
		"the credit is only spent on a meal that's served in full"
	)
	e.inv["berries"] = 2
	t.check(e.eat(3.0), "two more berries make the meal")
	t.check(e.inv["berries"] == 0 and is_equal_approx(e.food_credit, 0.0), "all eaten, none left over")


func test_flour_reserve() -> void:
	var techs := {}
	var e := _empty(techs)
	var keep := 0
	for id in Data.TECHS:
		keep += Data.TECHS[id]["cost"].get("flour", 0)
	t.check(keep > 0 and e.flour_reserve() == keep, "flour that research still needs is reserved")
	e.inv["flour"] = keep
	t.check(not e.eat(1.0), "reserved flour is not eaten")
	t.check(e.inv["flour"] == keep, "flour untouched")
	e.inv["flour"] = keep + 1
	t.check(e.eat(1.0), "flour above the reserve is eaten")
	t.check(e.inv["flour"] == keep, "only the spare flour was eaten")
	e.inv["berries"] = 5
	e.inv["flour"] = keep + 5
	e.food_credit = 0.0
	t.check(
		e.eat(1.0) and e.inv["berries"] == 4 and e.inv["flour"] == keep + 5, "berries still come before spare flour"
	)
	var flour_techs: Array = []
	for id in Data.TECHS:
		if Data.TECHS[id]["cost"].get("flour", 0) > 0:
			flour_techs.append(id)
	for id in flour_techs:
		techs[id] = true
	t.check(e.flour_reserve() == 0, "no reserve once those techs are researched")


func test_feed_sets_use_and_starving() -> void:
	var e := _empty()
	e.inv["berries"] = 50
	e.food_credit = 0.0
	t.check(e.feed(3, 1.0), "three mouths eat")
	t.check(is_equal_approx(e.food_use, 3.0 * Data.FOOD_PER_KITH_PER_SEC), "at the per-mouth rate")
	t.check(not e.starving, "so nobody starves")
	var eaten: float = float(50 - e.inv["berries"]) * Data.FOOD_VALUE["berries"] - e.food_credit
	t.check(is_equal_approx(eaten, 3.0 * Data.FOOD_PER_KITH_PER_SEC), "and the stockpile paid for exactly that")
	t.check(e.feed(0, 1.0) and is_equal_approx(e.food_use, 0.0), "no mouths, no use")
	e.inv["berries"] = 0
	e.food_credit = 0.0
	t.check(not e.feed(3, 1.0), "with no food the feed fails")
	t.check(e.starving, "and the starving flag goes up")
	t.check(is_equal_approx(e.food_use, 3.0 * Data.FOOD_PER_KITH_PER_SEC), "food_use still says what they'd eat")
	e.inv["berries"] = 5
	t.check(e.feed(3, 1.0), "food comes back")
	t.check(not e.starving, "and the flag goes down")


func test_preservation_cuts_food_use() -> void:
	var techs := {}
	var e := _empty(techs)
	e.feed(4, 1.0)
	var plain: float = e.food_use
	t.check(is_equal_approx(plain, 4.0 * Data.FOOD_PER_KITH_PER_SEC), "plain use")
	techs["preservation"] = true
	e.feed(4, 1.0)
	t.check(is_equal_approx(e.food_use, plain * 0.75), "Preservation cuts it by a quarter")


func test_flows_and_rates() -> void:
	var e := _empty()
	t.check(e.rate("wood") == 0.0, "no rate before anything happens")
	t.check(e.parts("wood").is_empty(), "and no sources")
	e.note("wood", 6, "gatherers_hut")
	e.note("wood", -2, "charcoal_pit")
	t.check(e.rate("wood") == 0.0, "a second in progress isn't counted yet")
	e.advance(0.5)
	t.check(e.rate("wood") == 0.0, "half a second later, still not")
	e.advance(0.5)
	t.check(is_equal_approx(e.rate("wood"), 4.0), "net rate: made minus used, per second")
	var parts := e.parts("wood")
	t.check(is_equal_approx(parts.get("gatherers_hut", 0.0), 6.0), "the hut made 6 a second")
	t.check(is_equal_approx(parts.get("charcoal_pit", 0.0), -2.0), "the pit used 2 a second")
	t.check(e.rate("stone") == 0.0, "another item has its own rate")
	e.note("wood", 3, "gatherers_hut")
	e.advance(1.0)
	t.check(is_equal_approx(e.rate("wood"), (4.0 + 3.0) / 2.0), "the rate is averaged over the seconds so far")
	t.check(is_equal_approx(e.parts("wood")["gatherers_hut"], (6.0 + 3.0) / 2.0), "and so is each source")
	t.check(e.inv["wood"] == 0, "noting a flow doesn't touch the stockpile")


func test_eating_shows_up_as_a_flow() -> void:
	var e := _empty(_no_reserve())
	e.inv["berries"] = 10
	e.food_credit = 0.0
	e.eat(3.0)  # three berries
	e.advance(1.0)
	t.check(is_equal_approx(e.rate("berries"), -3.0), "eaten berries are a negative rate")
	t.check(e.parts("berries").has(Data.FLOW_EAT_SOURCE), "under the eating source")
	t.check(e.parts("fish").is_empty(), "and only for what was eaten")


func test_flow_window_forgets() -> void:
	var e := _empty()
	e.note("wood", 6, "gatherers_hut")
	e.advance(1.0)
	for i in Data.RATE_WINDOW - 1:
		e.advance(1.0)
	t.check(e.rate("wood") > 0.0, "a flow counts while it's inside the window")
	e.advance(1.0)
	t.check(e.rate("wood") == 0.0, "old flows drop out of the window")
	t.check(e.parts("wood").is_empty(), "sources too")


## The stockpile, what was ever held, the food credit and the flow window survive a dict and a JSON round trip.
func test_to_dict_and_from_dict() -> void:
	var a := _empty()
	a.add("wood", 7)
	a.add("clay", 2)
	a.inv["berries"] = 12
	a.food_credit = 0.35
	a.feed(3, 0.5)
	a.note("wood", 6, "gatherers_hut")
	a.advance(1.5)
	a.note("wood", -1, "craft")
	var d := a.to_dict()
	var b := Economy.new({})
	b.from_dict(d)
	t.check(RunSave.to_json(b.to_dict()) == RunSave.to_json(d), "an Economy restored from a dict writes the same dict")
	t.check(
		b.inv == a.inv and b.seen == a.seen and b.food_credit == a.food_credit,
		"the stock, the seen items and the credit"
	)
	t.check(b.starving == a.starving and b.food_use == a.food_use, "and the eating state")
	t.check(is_equal_approx(b.rate("wood"), a.rate("wood")) and b.parts("wood") == a.parts("wood"), "and the rates")
	var c := Economy.new({})
	c.from_dict(RunSave.from_json(RunSave.to_json(d)))
	t.check(RunSave.to_json(c.to_dict()) == RunSave.to_json(d), "the same after a trip through JSON text")
	t.check(c.inv["wood"] is int and c.inv.keys() == a.inv.keys(), "counts are ints again, in the same order")
	c.advance(1.0)
	b.advance(1.0)
	t.check(c.flows.hist == b.flows.hist, "the flow window carries on the same")
	var held := c.inv
	c.from_dict({})
	t.check(
		is_same(held, c.inv) and c.inv["wood"] == 0 and c.inv.size() == Data.ITEM_ORDER.size(),
		"a partial dict loads in place"
	)


func test_economy_stands_alone() -> void:
	var techs := {"baking": true}
	var e := _empty(techs)
	e.inv["flour"] = 100
	e.add("wood", 1)
	e.pay({"wood": 1})
	e.feed(5, 1.0)
	t.check(techs.size() == 1 and techs.has("baking"), "the researched set is only read, never written")
	var a := Economy.new()
	var b := Economy.new()
	a.add("clay", 7)
	t.check(not b.inv.has("clay") or b.inv["clay"] == 0, "two Economies don't share a stockpile")
	a.note("wood", 1, "hand")
	a.advance(1.0)
	t.check(b.rate("wood") == 0.0, "or their flows")
	t.check(
		Economy.new(techs).food_value("flour") == Data.BAKED_FLOUR_FOOD, "the researched set comes in at construction"
	)


func test_sim_shares_the_techs_with_the_economy() -> void:
	var s := Sim.new()
	s.economy.inv["wood"] = 9
	t.check(s.economy.can_afford({"wood": 9}), "a write to the stockpile is what can_afford reads")
	s.economy.add("clay", 2)
	t.check(s.economy.inv["clay"] == 2 and s.economy.seen.has("clay"), "add reaches the stockpile")
	s.economy.pay({"wood": 4})
	t.check(s.economy.inv["wood"] == 5, "so does paying")
	s.economy.starving = true
	s.economy.inv["berries"] = 0
	s.economy.inv["fish"] = 0
	s.economy.inv["flour"] = 0
	s.economy.food_credit = 0.0
	t.check(not s.economy.eat(1.0) and s.economy.starving, "eating with no food fails, and the flag stays as set")
	s.economy.inv["berries"] = 3
	t.check(
		is_equal_approx(s.economy.food_total(), 3.0) and s.economy.food_value("berries") == 1.0, "food queries agree"
	)
	s.tech_tree.researched["smoking"] = true
	t.check(s.economy.food_value("berries") == Data.SMOKED_BERRY_FOOD, "the block sees the researched techs")
	s.economy.note("wood", 2, "hand")
	s.economy.flows.advance(1.0)
	t.check(is_equal_approx(s.economy.flows.rate("wood"), 2.0), "flows are the block's flows")
