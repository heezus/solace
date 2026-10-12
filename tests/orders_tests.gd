extends RefCounted
## Livewire stage 1, the Order Board (design-system/23-livewire.md): the Board and its standing orders, the Pause and Bring first
## verbs, the goals, the saves and the panels. Run from tests/livewire_tests.gd, which owns the helpers (town, meadow, put...).

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Power = preload("res://scripts/power.gd")
const Livewire = preload("res://scripts/livewire.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Buildings = preload("res://scripts/buildings.gd")
const OrdersPanel = preload("res://scripts/orders_panel.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const DebugKeys = preload("res://scripts/debug_keys.gd")

var t  # the runner, tests/run_tests.gd
var base  # the Livewire tests, for their helpers


func run(runner, helpers) -> void:
	t = runner
	base = helpers
	test_the_board_stands_once_near_the_hearth()
	test_orders_are_written_with_buttons()
	test_pause_finishes_the_job_then_waits()
	test_pause_cannot_stop_the_town()
	test_bring_first_serves_a_kind_ahead()
	test_pause_beats_bring_first()
	test_a_bring_first_that_cannot_be_met_lapses()
	test_orders_are_read_every_few_seconds_and_say_so_once_a_minute()
	test_an_order_that_never_fires_is_marked()
	test_orders_wait_without_a_board()
	test_the_goals()
	test_livewire_saves_and_loads()
	test_the_panels()


# --- Helpers (the Livewire tests' own, typed) -------------------------------------


func town() -> Sim:
	return base.town()


func meadow(s: Sim, half := 8) -> Vector2i:
	return base.meadow(s, half)


func put(s: Sim, type: String, p: Vector2i) -> Dictionary:
	return base.put(s, type, p)


func tick_for(s: Sim, seconds: float, step := 0.5) -> void:
	base.tick_for(s, seconds, step)


func net_of(s: Sim, p: Vector2i) -> Dictionary:
	return base.net_of(s, p)


# --- The Order Board -----------------------------------------------------------


func test_the_board_stands_once_near_the_hearth() -> void:
	var s := town()
	s.tech_tree.researched["order_board"] = true
	var camp: Vector2i = s.world.camp_pos
	var near := Vector2i(-1, -1)
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			var p := camp + Vector2i(dx, r)
			if s.town.placement_error("order_board", p) == "":
				near = p
				break
		if near.x >= 0:
			break
	t.check(near.x >= 0, "the Board has a spot by the Hearth")
	var far := camp + Vector2i(int(Data.HEARTH_RADIUS) + 3, 0)
	s.world.set_tile(far, "grass")
	t.check(s.town.placement_error("order_board", far).begins_with("Must be within"), "it will not stand far from it")
	t.check(s.place("order_board", near), "it goes down")
	t.check(s.town.placement_error("order_board", near + Vector2i(1, 0)).begins_with("Only one"), "only one")
	var b: Dictionary = s.town.buildings[s.town.building_at[near]]
	tick_for(s, 3.0)
	t.check(b["worker"] == -1 and not Buildings.served(b), "no worker, and no hauler serves it")
	t.check(s.livewire.has_board(s), "the town has a Board")
	s.demolish(near)
	t.check(not s.livewire.has_board(s), "and not once it is torn down")


func test_orders_are_written_with_buttons() -> void:
	var s := town()
	var lw: Livewire = s.livewire
	t.check(lw.slots(s) == 3, "three slots")
	t.check(lw.add(s) and lw.add(s) and lw.add(s), "three orders can be written")
	t.check(not lw.add(s) and lw.orders.size() == 3, "not a fourth")
	var o: Dictionary = lw.orders[0]
	t.check(o["target"] == "" and o["verb"] == "pause" and o["compare"] == "below", "a new order does nothing yet")
	t.check(lw.text(o).begins_with("When Coal is below 20"), "it reads: %s" % lw.text(o))
	lw.toggle_compare(0)
	t.check(o["compare"] == "above", "below becomes above")
	lw.toggle_compare(0)
	var seen := {}
	for i in 30:
		lw.cycle_item(s, 0)
		seen[o["item"]] = true
	t.check(seen.size() == lw.items_for(s).size(), "the good steps through every good the Kith have held")
	t.check(Data.ITEM_ORDER.has(o["item"]), "(%s)" % o["item"])
	o["number"] = 20
	lw.step_number(0, 1)
	t.check(o["number"] == 30, "+ steps 20 to 30")
	lw.step_number(0, -1)
	lw.step_number(0, -1)
	t.check(o["number"] == 10, "- steps back to 10")
	o["number"] = 5
	lw.step_number(0, -1)
	t.check(o["number"] == 5, "5 is the least")
	o["number"] = 500
	lw.step_number(0, 1)
	t.check(o["number"] == 500, "and 500 the most")
	o["number"] = 25
	lw.step_number(0, 1)
	t.check(o["number"] == 30, "from between two it goes to the next")
	lw.step_number(0, -1)
	t.check(o["number"] == 20, "and back to the one before")
	s.tech_tree.researched["bloomery"] = true
	var targets := lw.targets_for(s, "pause")
	t.check(not targets.is_empty() and "bloomery" in targets, "workshops can be named to Pause: %s" % [targets])
	lw.cycle_target(s, 0)
	var first: String = o["target"]
	t.check(first == targets[0], "the first click names the first kind")
	lw.cycle_target(s, 0)
	t.check(o["target"] == targets[1 % targets.size()], "the next click, the next")
	t.check(lw.text(o).begins_with("When ") and lw.text(o).contains("Pause "), "the line says it: %s" % lw.text(o))
	lw.cycle_verb(0)
	t.check(o["verb"] == "bring", "the verb steps to Bring first")
	t.check(lw.text(o).contains("bring %s first to" % Data.ITEMS[o["item"]]["name"]), "(%s)" % lw.text(o))
	lw.cycle_verb(0)
	t.check(o["verb"] == "pause", "and back to Pause")
	lw.clear(1)
	t.check(lw.orders.size() == 2 and lw.add(s), "an order cleared frees its slot")
	t.check(
		Livewire.plural("Kiln") == "Kilns" and Livewire.plural("Bloomery") == "Bloomeries", "plurals: Kilns, Bloomeries"
	)
	t.check(Livewire.plural("Press") == "Presses" and Livewire.plural("Key") == "Keys", "Presses, Keys")
	# the Foremen would give more slots
	s.tech_tree.researched["foremen"] = true
	t.check(lw.slots(s) == 6, "Foremen add 3 slots (later stage)")
	s.tech_tree.researched["chain_orders"] = true
	t.check(lw.slots(s) == 9, "and Chain Orders 3 more: the cap is 9")


func test_pause_finishes_the_job_then_waits() -> void:
	var s := town()
	var c := meadow(s)
	s.people.found(8)
	put(s, "order_board", s.world.camp_pos + Vector2i(2, 1))
	put(s, "power_pole", c)
	var gen := put(s, "generator", c + Vector2i(0, 2))
	gen["inbuf"] = {"coal": 99}
	gen["burn"] = 99999.0  # a fire that does not go out
	var forge := put(s, "forge", c + Vector2i(2, 0))
	forge["inbuf"] = {"iron": 60, "coal": 30}
	tick_for(s, 6.0)
	t.check(forge["progress"] > 0.0, "the Forge is at its work")
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "above", "number": 50, "verb": "pause", "target": "forge"}, true)
	s.economy.inv["coal"] = 200
	var made_before: int = forge["out"].get("steel", 0) + s.economy.inv.get("steel", 0)
	tick_for(s, 4.0)  # the order is read; the Forge is mid-job
	t.check(lw.is_held(forge) and lw.orders[0]["holding"], "the order holds while Coal is above 50")
	tick_for(s, 12.0)
	var made_after: int = forge["out"].get("steel", 0) + s.economy.inv.get("steel", 0)
	t.check(
		made_after == made_before + 1, "the Forge finished the job it was on (%d to %d)" % [made_before, made_after]
	)
	t.check(forge["progress"] == 0.0, "and then waited")
	t.check(forge["worker"] >= 0, "its worker stays in place")
	t.check(forge["inbuf"].get("iron", 0) > 0, "and its stock is kept")
	t.check(
		forge["status"] == Data.ORDER_PAUSED_STATUS and forge["alert"] == Data.ORDER_PAUSED_ALERT,
		"its card says: %s" % forge["status"]
	)
	t.check(not forge["paused"], "it is not paused by hand")
	t.check(BuildingPanel.worker_text(s, forge) == Data.ORDER_PAUSED_NOTE, "and the panel explains")
	tick_for(s, 20.0)
	var still: int = forge["out"].get("steel", 0) + s.economy.inv.get("steel", 0)
	t.check(still == made_after, "no more Steel while the rule holds")
	t.check(Haulers.stock_wanted(s, forge).is_empty(), "and haulers bring it nothing")
	s.economy.inv["coal"] = 10  # the When stops holding
	tick_for(s, 4.0)
	t.check(not lw.is_held(forge) and not lw.orders[0]["holding"], "it resumes the moment the When stops holding")
	tick_for(s, 20.0)
	var after: int = forge["out"].get("steel", 0) + s.economy.inv.get("steel", 0)
	t.check(after > still, "and the Forge makes Steel again")
	# a pause by hand is its own thing
	var i: int = s.town.buildings.find(forge)
	s.set_paused(i, true)
	t.check(forge["paused"] and not lw.is_held(forge), "the Pause button is separate")


func test_pause_cannot_stop_the_town() -> void:
	var s := town()
	for type in [
		"camp",
		"boiler",
		"water_wheel",
		"generator",
		"order_board",
		"dwelling",
		"gatherers_hut",
		"field",
		"power_pole",
		"storehouse"
	]:
		t.check(not Livewire.can_target("pause", type), "%s cannot be paused by an order" % type)
	for type in ["forge", "bloomery", "kiln", "smelter", "mine", "coal_mine", "wire_mill", "grindstone"]:
		t.check(Livewire.can_target("pause", type), "%s can be" % type)
	for type in ["camp", "order_board", "power_pole", "dwelling"]:
		t.check(not Livewire.can_target("bring", type), "nothing is brought first to %s" % type)
	t.check(
		Livewire.can_target("bring", "boiler") and Livewire.can_target("bring", "forge"),
		"but a Boiler and a Forge can be"
	)
	var lw: Livewire = s.livewire
	for type in lw.targets_for(s, "pause"):
		t.check(Data.BUILDINGS[type]["kind"] == "processor", "%s is a workshop or a mine" % type)
	lw.add(s)
	lw.orders[0]["target"] = "boiler"
	lw.cycle_verb(0)
	lw.orders[0]["target"] = "boiler"
	lw.cycle_verb(0)
	t.check(
		lw.orders[0]["verb"] == "pause" and lw.orders[0]["target"] == "", "a verb that cannot name the target clears it"
	)


func test_bring_first_serves_a_kind_ahead() -> void:
	var s := town()
	s.people.found(8)
	var camp: Vector2i = s.world.camp_pos
	var forge := put(s, "forge", camp + Vector2i(1, 0))
	var bloomery := put(s, "bloomery", camp + Vector2i(-1, 0))
	forge["worker"] = 0
	bloomery["worker"] = 1
	s.economy.inv = {"coal": 40, "berries": 999}
	s.economy.seen["coal"] = true
	var wanted_by_forge: Dictionary = Haulers.stock_wanted(s, forge)
	t.check(wanted_by_forge.has("coal") and Haulers.stock_wanted(s, bloomery).has("coal"), "both want Coal")
	t.check(not s.livewire.serves_first(forge), "with no rule, neither is first")
	var order := {"item": "coal", "compare": "below", "number": 100, "verb": "bring", "target": "bloomery"}
	put(s, "order_board", camp + Vector2i(0, 2))
	s.livewire.add(s)
	s.livewire.orders[0].merge(order, true)
	s.livewire.tick(s, 3.0)
	t.check(s.livewire.serves_first(bloomery) and not s.livewire.serves_first(forge), "the Bloomery is served first")
	var hauler := _hauler_at_hearth(s)
	t.check(not hauler.is_empty(), "a hauler waits at the Hearth")
	var got: Dictionary = {}
	if not hauler.is_empty() and Haulers._find_task(s, hauler):
		got = hauler["task"]
	t.check(
		not got.is_empty() and s.town.buildings[got["building"]]["type"] == "bloomery", "and the first trip is for it"
	)
	# the same town with no rule serves the first built
	var plain := town()
	plain.people.found(8)
	var pc: Vector2i = plain.world.camp_pos
	var pf := put(plain, "forge", pc + Vector2i(1, 0))
	var pb := put(plain, "bloomery", pc + Vector2i(-1, 0))
	pf["worker"] = 0
	pb["worker"] = 1
	plain.economy.inv = {"coal": 40, "berries": 999}
	var ph := _hauler_at_hearth(plain)
	var other: Dictionary = {}
	if not ph.is_empty() and Haulers._find_task(plain, ph):
		other = ph["task"]
	t.check(
		not other.is_empty() and plain.town.buildings[other["building"]]["type"] == "forge",
		"without it, the Forge (built first) is"
	)


func _hauler_at_hearth(s: Sim) -> Dictionary:
	s.people.assign_jobs()
	for k in s.people.kith:
		if k["job"] == "haul" and k["task"].is_empty():
			k["pos"] = Vector2(s.world.camp_pos)
			k["path"] = []
			return k
	return {}


func test_pause_beats_bring_first() -> void:
	var s := town()
	var camp: Vector2i = s.world.camp_pos
	var forge := put(s, "forge", camp + Vector2i(1, 0))
	forge["worker"] = 0
	put(s, "order_board", camp + Vector2i(0, 2))
	s.economy.inv = {"coal": 500, "berries": 999}
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "above", "number": 10, "verb": "bring", "target": "forge"}, true)
	lw.add(s)
	lw.orders[1].merge({"item": "coal", "compare": "above", "number": 10, "verb": "pause", "target": "forge"}, true)
	lw.tick(s, 3.0)
	t.check(lw.is_held(forge), "the Forge is held")
	t.check(not lw.serves_first(forge), "so it is not served first")
	t.check(Haulers.stock_wanted(s, forge).is_empty(), "and is brought nothing: the Pause wins")
	lw.clear(1)
	lw.tick(s, 3.0)
	t.check(not lw.is_held(forge) and lw.serves_first(forge), "with the Pause gone, the Bring first stands")


func test_a_bring_first_that_cannot_be_met_lapses() -> void:
	var s := town()
	var camp: Vector2i = s.world.camp_pos
	var forge := put(s, "forge", camp + Vector2i(1, 0))
	var bloomery := put(s, "bloomery", camp + Vector2i(-1, 0))
	forge["worker"] = 0
	bloomery["worker"] = 1
	put(s, "order_board", camp + Vector2i(0, 2))
	s.economy.inv = {"coal": 1, "berries": 999}
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "below", "number": 100, "verb": "bring", "target": "bloomery"}, true)
	lw.tick(s, 3.0)
	t.check(lw.kept_back(forge, "coal"), "the one Coal in store is kept for the Bloomery, from the Forge")
	t.check(not lw.kept_back(bloomery, "coal"), "but not from the Bloomery")
	t.check(not lw.kept_back(forge, "iron"), "nor any other good")
	for i in 19:
		lw.tick(s, 3.0)  # 60 seconds in all, and nobody brought it
	t.check(lw.kept_back(forge, "coal"), "just inside a minute, it still is")
	lw.tick(s, 3.0)
	lw.tick(s, 3.0)
	t.check(not lw.kept_back(forge, "coal"), "after 60 seconds the claim is skipped: a rule never stalls a hauler")
	t.check(lw.serves_first(bloomery), "though the Bloomery is still first in line")
	s.economy.inv["coal"] = 90  # enough for everyone: nothing is kept either way
	lw.tick(s, 3.0)
	t.check(not lw.kept_back(forge, "coal"), "with enough in store nothing is kept")
	lw.orders[0]["claim"] = 0.0
	s.economy.inv["coal"] = 1
	bloomery["inbuf"] = {"coal": 2, "iron_ore": 4}
	lw.tick(s, 3.0)
	t.check(not lw.kept_back(forge, "coal"), "and nothing when the Bloomery wants no more")


func test_orders_are_read_every_few_seconds_and_say_so_once_a_minute() -> void:
	var s := town()
	var camp: Vector2i = s.world.camp_pos
	put(s, "order_board", camp + Vector2i(0, 2))
	put(s, "forge", camp + Vector2i(1, 0))
	var lw: Livewire = s.livewire
	var said := []
	lw.said.connect(func(line): said.append(line))
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "below", "number": 20, "verb": "pause", "target": "forge"}, true)
	s.economy.inv["coal"] = 50
	lw.tick(s, 3.0)
	t.check(not lw.orders[0]["holding"] and said.is_empty(), "Coal is plenty: the rule does not hold")
	s.economy.inv["coal"] = 5
	lw.tick(s, 1.0)
	t.check(not lw.orders[0]["holding"], "it is read every few seconds, not every tick")
	lw.tick(s, 2.0)
	t.check(lw.orders[0]["holding"] and said.size() == 1, "and once it holds, the feed says so")
	t.check(said[0].begins_with("Standing order: When Coal is below 20"), "(%s)" % said[0])
	t.check(
		lw.orders[0]["fired"] >= 0.0 and lw.last_firing(lw.orders[0]) == Data.ORDER_NOW,
		"the order shows it is holding now"
	)
	s.economy.inv["coal"] = 50
	lw.tick(s, 3.0)
	t.check(not lw.orders[0]["holding"], "it lets go")
	t.check(
		lw.last_firing(lw.orders[0]).begins_with("Last fired"),
		"and shows when it last fired: %s" % lw.last_firing(lw.orders[0])
	)
	s.economy.inv["coal"] = 5
	lw.tick(s, 3.0)
	t.check(said.size() == 1, "it fires again within a minute without writing a second line")
	for i in 22:
		s.economy.inv["coal"] = 50 if i % 2 == 0 else 5
		lw.tick(s, 3.0)
	s.economy.inv["coal"] = 50
	lw.tick(s, 3.0)
	s.economy.inv["coal"] = 5
	lw.tick(s, 3.0)
	t.check(said.size() >= 2 and said.size() <= 3, "after a minute, it writes again (%d lines in all)" % said.size())
	t.check(Data.ORDER_FEED_SECONDS == 60.0, "at most one line a minute for each order")
	# a rule for a kind of building that does not stand does nothing
	var s2 := town()
	put(s2, "order_board", s2.world.camp_pos + Vector2i(0, 2))
	s2.livewire.add(s2)
	s2.livewire.orders[0].merge(
		{"item": "coal", "compare": "above", "number": 1, "verb": "pause", "target": "forge"}, true
	)
	s2.livewire.tick(s2, 3.0)
	t.check(not s2.livewire.orders[0]["holding"], "no Forge stands, so it does nothing")


func test_an_order_that_never_fires_is_marked() -> void:
	var s := town()
	put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "below", "number": 5, "verb": "pause", "target": "forge"}, true)
	put(s, "forge", s.world.camp_pos + Vector2i(1, 0))
	t.check(
		lw.last_firing(lw.orders[0]) == Data.ORDER_NEVER and not lw.is_stale(lw.orders[0]), "new: has not fired yet"
	)
	for i in 90:
		lw.tick(s, 3.0)
	t.check(not lw.is_stale(lw.orders[0]), "four and a half minutes in, not yet marked")
	for i in 12:
		lw.tick(s, 3.0)
	t.check(lw.is_stale(lw.orders[0]), "after five it is marked")
	t.check(lw.last_firing(lw.orders[0]).begins_with("Has not fired for 5 min"), "(%s)" % lw.last_firing(lw.orders[0]))
	s.economy.inv["coal"] = 0
	lw.tick(s, 3.0)
	t.check(not lw.is_stale(lw.orders[0]), "once it fires the mark goes")
	t.check(Livewire.span(30.0) == "30 s" and Livewire.span(200.0) == "3 min", "durations read in seconds and minutes")


func test_orders_wait_without_a_board() -> void:
	var s := town()
	var forge := put(s, "forge", s.world.camp_pos + Vector2i(1, 0))
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "coal", "compare": "above", "number": 1, "verb": "pause", "target": "forge"}, true)
	lw.tick(s, 3.0)
	t.check(not lw.is_held(forge) and not lw.orders[0]["holding"], "with no Board standing the orders wait")
	var board := put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	lw.tick(s, 3.0)
	t.check(lw.is_held(forge), "with one, they are read")
	s.demolish(board["pos"])
	lw.tick(s, 3.0)
	t.check(not lw.is_held(forge) and lw.orders.size() == 1, "tear it down and they wait again, still written")


# --- The goals ------------------------------------------------------------------


func test_the_goals() -> void:
	var s := town()
	s.story.record(Data.LIVEWIRE_BEGUN)
	t.check(s.story.goal_list() == Data.GOALS_ERA5, "Livewire has a checklist of its own")
	s.story.update(s)
	t.check(not s.story.goals_done.has("power_poles"), "nothing done yet")
	s.tech_tree.researched["power_poles"] = true
	s.story.update(s)
	t.check(s.story.goals_done.has("power_poles"), "Power Poles ticks its goal")
	var c := meadow(s)
	put(s, "power_pole", c)
	s.story.update(s)
	t.check(not s.story.goals_done.has("poles_laid"), "one pole is not a net")
	put(s, "power_pole", c + Vector2i(3, 0))
	s.livewire.tick(s, 0.0)
	s.story.update(s)
	t.check(s.story.goals_done.has("poles_laid"), "two joined poles are")
	t.check(not s.story.goals_done.has("net_machine"), "but not yet a machine on an engine's net")
	put(s, "forge", c + Vector2i(0, 2))
	put(s, "boiler", c + Vector2i(3, 2))
	s.livewire.tick(s, 0.0)
	s.story.update(s)
	t.check(s.story.goals_done.has("net_machine"), "a machine and an engine on one net")
	s.tech_tree.researched["generator"] = true
	put(s, "generator", c + Vector2i(-2, 0))
	s.story.update(s)
	t.check(s.story.goals_done.has("generator"), "a Generator stands")
	t.check(not s.story.goals_done.has("wire_made"), "no Wire yet")
	s.economy.inv["wire"] = 1
	s.story.update(s)
	t.check(s.story.goals_done.has("wire_made"), "the first Wire")
	t.check(not s.story.goals_done.has("first_order"), "no order yet")
	put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	s.livewire.add(s)
	s.story.update(s)
	t.check(
		s.story.goals_done.has("order_board") and not s.story.goals_done.has("first_order"),
		"a Board, but an order with no target is not a rule"
	)
	s.livewire.orders[0].merge(
		{"item": "coal", "compare": "above", "number": 1, "verb": "pause", "target": "forge"}, true
	)
	s.story.update(s)
	t.check(s.story.goals_done.has("first_order"), "a first order")
	t.check(not s.story.goals_done.has("order_fired"), "which has not fired")
	s.livewire.tick(s, 3.0)
	s.story.update(s)
	t.check(s.story.goals_done.has("order_fired"), "until it does")
	t.check(
		s.story.current_goal() == Data.GOALS_ERA5.size() and s.story.done_count() == Data.GOALS_ERA5.size(),
		"and all eight are done"
	)
	var early := town()
	early.story.record(Data.LIVEWIRE_BEGUN)
	early.tech_tree.researched["order_board"] = true
	put(early, "order_board", early.world.camp_pos + Vector2i(0, 2))
	early.story.update(early)
	t.check(
		early.story.done_count() == 1 and early.story.current_goal() == 0,
		"skipping ahead never hides the earlier goals"
	)


# --- Saves -----------------------------------------------------------------------


func test_livewire_saves_and_loads() -> void:
	var s := town()
	var c := meadow(s)
	s.people.found(6)
	put(s, "power_pole", c)
	put(s, "power_pole", c + Vector2i(3, 0))
	var gen := put(s, "generator", c + Vector2i(0, 2))
	gen["inbuf"] = {"coal": 5}
	put(s, "forge", c + Vector2i(3, 2))
	var board := put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	var lw: Livewire = s.livewire
	lw.add(s)
	lw.orders[0].merge({"item": "iron", "compare": "above", "number": 150, "verb": "bring", "target": "forge"}, true)
	lw.add(s)
	lw.orders[1].merge({"item": "coal", "compare": "above", "number": 10, "verb": "pause", "target": "wire_mill"}, true)
	put(s, "wire_mill", c + Vector2i(-2, 0))
	s.economy.inv["iron"] = 400
	tick_for(s, 8.0)
	t.check(lw.orders[0]["holding"] and lw.orders[1]["holding"], "two orders hold")
	var text := RunSave.to_json(RunSave.dump(s))
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, RunSave.from_json(text)), "a Livewire town loads")
	t.check(loaded.livewire.orders == lw.orders, "the orders are as they were")
	t.check(is_equal_approx(loaded.livewire.time, lw.time), "and the clock")
	var fired: float = lw.orders[0]["fired"]
	t.check(loaded.livewire.orders[0]["fired"] == fired, "an order remembers when it fired")
	var feed_lines := []
	loaded.livewire.said.connect(func(line): feed_lines.append(line))
	loaded.tick(0.5)
	t.check(feed_lines.is_empty(), "and a load does not make it fire again")
	t.check(
		loaded.livewire.nets.size() == 1 and loaded.livewire.nets[0]["poles"].size() == 2, "the net is rebuilt on load"
	)
	t.check(
		loaded.livewire.is_held(loaded.town.buildings[loaded.town.building_at[c + Vector2i(-2, 0)]]),
		"the Pause holds at once"
	)
	t.check(RunSave.to_json(RunSave.dump(loaded)).length() > 1000, "and it saves again")
	var again := Sim.new()
	t.check(RunSave.restore(again, RunSave.from_json(RunSave.to_json(RunSave.dump(loaded)))), "round trip")
	t.check(again.livewire.orders == loaded.livewire.orders, "twice over")
	# an older save has no livewire entry
	var d := RunSave.dump(s)
	d["game"].erase("livewire")
	var old := Sim.new()
	t.check(RunSave.restore(old, d), "a save from before Livewire loads")
	t.check(old.livewire.orders.is_empty() and old.livewire.time == 0.0, "with no orders")
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/save_before_ironfall.json")
	var past := Sim.new()
	t.check(RunSave.restore(past, RunSave.from_json(fixture)), "the frozen pre-Ironfall fixture loads unchanged")
	t.check(past.livewire.orders.is_empty() and RunSave.VERSION == 1, "Livewire empty, the version still 1")
	# an order about a building the game no longer has is dropped
	var odd := RunSave.dump(s)
	odd["game"]["livewire"]["orders"][0]["target"] = "no_such_building"
	var dropped := Sim.new()
	t.check(
		RunSave.restore(dropped, odd) and dropped.livewire.orders.size() == 1,
		"an order about a lost building is dropped"
	)
	t.check(board["type"] == "order_board", "(the Board stood)")


# --- The panels ----------------------------------------------------------------


func test_the_panels() -> void:
	var s := town()
	var c := meadow(s)
	var board := put(s, "order_board", s.world.camp_pos + Vector2i(0, 2))
	var panel := OrdersPanel.new()
	panel.setup(s)
	var forge := put(s, "forge", c)
	panel.show_for(forge)
	t.check(not panel.visible, "the orders show only on the Board")
	panel.show_for(board)
	t.check(panel.visible, "on the Board they do")
	var buttons := _buttons(panel)
	t.check(buttons.any(func(b): return b.text == Data.ORDER_NEW), "there is a button to write an order")
	var changed := []
	panel.changed.connect(func(): changed.append(true))
	buttons.filter(func(b): return b.text == Data.ORDER_NEW)[0].pressed.emit()
	t.check(s.livewire.orders.size() == 1 and changed.size() == 1, "which writes one")
	panel.show_for(board)
	for want in [Data.ORDER_CLEAR, "below", Data.ORDER_NUMBER_LESS, Data.ORDER_NUMBER_MORE, "Pause", "Choose", "Coal"]:
		t.check(_buttons(panel).any(func(b): return b.text == want), "the order has a '%s' button" % want)
	_buttons(panel).filter(func(b): return b.text == "below")[0].pressed.emit()
	t.check(s.livewire.orders[0]["compare"] == "above", "a click on below makes it above")
	panel.show_for(board)
	_buttons(panel).filter(func(b): return b.text == Data.ORDER_NUMBER_MORE)[0].pressed.emit()
	t.check(s.livewire.orders[0]["number"] == 30, "+ raises the number")
	panel.show_for(board)
	_buttons(panel).filter(func(b): return b.text == "Choose")[0].pressed.emit()
	t.check(s.livewire.orders[0]["target"] != "", "a click on Choose names a kind of building")
	panel.show_for(board)
	t.check(_labels(panel).any(func(l): return l.text == Data.ORDER_NEVER), "the order says it has not fired")
	_buttons(panel).filter(func(b): return b.text == Data.ORDER_CLEAR)[0].pressed.emit()
	t.check(s.livewire.orders.is_empty(), "Clear tears it up")
	panel.show_for(board)
	t.check(_labels(panel).any(func(l): return l.text == Data.ORDER_EMPTY), "an empty Board says how to begin")
	panel.free()
	# the building panel
	var bp := BuildingPanel.new()
	bp.setup(s)
	bp.select(board["pos"])
	t.check(bp.parts["orders"].visible, "the building card shows the orders for the Board")
	bp.select(forge["pos"])
	t.check(not bp.parts["orders"].visible, "and not for a Forge")
	var pole := put(s, "power_pole", c + Vector2i(1, 1))
	bp.select(pole["pos"])
	t.check(
		bp.parts["net"].visible and bp.parts["net"].text != "",
		"a pole's card describes its net: %s" % bp.parts["net"].text
	)
	t.check(not bp.parts["pause"].visible and not bp.parts["collect"].visible, "with no Pause or Collect")
	s.livewire.tick(s, 0.0)
	bp.refresh()
	t.check(bp.parts["net"].text.contains("poles"), "(%s)" % bp.parts["net"].text)
	bp.free()
	# save slots and the debug key know the age
	var d := RunSave.dump(s)
	d["story"]["events"].append(Data.LIVEWIRE_BEGUN)
	t.check(SaveSlots.meta_of(d)["era"] == Data.ERA_LIVEWIRE, "a slot says Livewire")
	s.story.record(Data.LIVEWIRE_BEGUN)
	s.economy.inv.erase("wire")
	DebugKeys.add_goods(s)
	t.check(s.economy.inv.get("wire", 0) > 0, "F1 adds Wire once the age has begun")


func _buttons(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func _labels(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels(c))
	return out
