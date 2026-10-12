extends RefCounted
## Livewire stage 1 (design-system/23-livewire.md): wires and orders. The era's opening and its fifth tab and Goals list, the
## techs (three built, eleven locked), Power Poles and the net, the Generator, Wire and the Wire Mill, the Order Board with its
## Pause and Bring first verbs, the saves and the panels. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Land = preload("res://scripts/land.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Rules = preload("res://scripts/rules.gd")
const Power = preload("res://scripts/power.gd")
const Livewire = preload("res://scripts/livewire.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Buildings = preload("res://scripts/buildings.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")
const OrdersPanel = preload("res://scripts/orders_panel.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const DebugKeys = preload("res://scripts/debug_keys.gd")
const Art = preload("res://scripts/art.gd")
const OrdersTests = preload("res://tests/orders_tests.gd")

## The three techs the stage builds, and the eleven it leaves locked.
const STAGE_ONE := ["power_poles", "order_board", "generator"]
const LATER := [
	"tide_watch",
	"arc_lamps",
	"foremen",
	"powered_mines",
	"factory_floor",
	"scorcher",
	"firebreaks",
	"shard_dynamo",
	"chain_orders",
	"living_ground",
	"skyward"
]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_data_is_whole()
	test_the_age_begins_when_the_card_is_put_away()
	test_the_fifth_tab_and_the_tree()
	test_only_stage_one_can_be_bought()
	test_poles_join_into_nets()
	test_engines_and_machines_on_a_net()
	test_a_short_net_runs_everything_slower()
	test_the_old_reach_is_as_it_was()
	test_the_generator_burns_only_while_the_net_asks()
	test_the_wire_mill_draws_wire()
	OrdersTests.new().run(runner, self)  # the Order Board, the goals, the saves and the panels


# --- Helpers ------------------------------------------------------------------


## A town in Livewire: the map grown, the gate's techs learned, the fog lifted, a stocked stockpile and the Wires Hum card put away.
func town(map_seed := 2) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	for tech in ["bronze_dawn", "haulers", "coal_seams", "ironstone", "teardown", "bloomery", "iron_tools", "boiler"]:
		s.tech_tree.researched[tech] = true
	for tech in ["blast_furnace", "steel", "rails", "shard_boiler", "bloom_sampling", "livewire"]:
		s.tech_tree.researched[tech] = true
	Land.grow_if_due(s)
	s.fog.reveal_all()
	t.give(s, 400)
	s.economy.inv["wire"] = 0  # the age has made none yet
	s.story.record(Data.IRONFALL_EVENT)
	s.story.record(Data.LIVEWIRE_EVENT)
	s.story.update(s)
	return s


## A clear stretch of grass south of the Hearth, `half` tiles each way, and its middle.
func meadow(s: Sim, half := 8) -> Vector2i:
	var c: Vector2i = s.world.camp_pos + Vector2i(0, 10)
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var p := c + Vector2i(dx, dy)
			if s.world.in_bounds(p) and p != s.world.camp_pos:
				s.world.set_tile(p, "grass")
	s.pathing.build()
	return c


## Put a building down, unchecked, and tell the town the buildings changed (a placement does that itself).
func put(s: Sim, type: String, p: Vector2i) -> Dictionary:
	s.world.set_tile(p, "grass")
	s.town.add_building(type, p)
	s.town.road_rev += 1
	return s.town.buildings[s.town.building_at[p]]


func tick_for(s: Sim, seconds: float, step := 0.5) -> void:
	for i in int(seconds / step):
		s.economy.inv["berries"] = 999
		s.tick(step)


## The net that has a building on it, after the nets have been worked out.
func net_of(s: Sim, p: Vector2i) -> Dictionary:
	s.livewire.tick(s, 0.0)
	return s.livewire.net_at(p)


# --- The data -----------------------------------------------------------------


func test_the_data_is_whole() -> void:
	t.check(Data.BUILT_STAGE == 3, "Ironfall is still built to stage 3")
	t.check(Data.ERA_BUILT_STAGE == {5: 1}, "and Livewire to stage 1")
	for id in STAGE_ONE + LATER:
		t.check(Data.TECHS.has(id) and Data.TECH_ORDER.has(id), "%s is on the board" % id)
		t.check(Data.TECHS[id]["era"] == 5, "%s belongs to era 5" % id)
	t.check(STAGE_ONE.size() + LATER.size() == 14, "fourteen techs in all")
	for id in STAGE_ONE:
		t.check(int(Data.TECHS[id]["stage"]) == 1 and Rules.tech_enabled(id), "%s is built (stage 1)" % id)
	for id in LATER:
		t.check(int(Data.TECHS[id]["stage"]) >= 2 and not Rules.tech_enabled(id), "%s waits for a later stage" % id)
	t.check(Data.TECHS["skyward"]["lane"] == "gate", "Skyward is the gate")
	t.check(Rules.tech_enabled("livewire") and Rules.tech_enabled("steel"), "Ironfall's techs are all still on sale")
	t.check(
		Data.ERAS[5]["name"] == "Livewire" and Data.ERA_TIER_NAMES[5].size() == 5, "Livewire has a board of its own"
	)
	# the buildings of the stage
	t.check(Data.BUILDINGS["power_pole"]["cost"] == {"wood": 2, "iron": 1}, "a Power Pole is wood 2 and iron 1")
	t.check(
		Data.BUILDINGS["power_pole"]["kind"] == "pole" and "power_pole" in Data.BUILD_TABS["Logistics"], "in Logistics"
	)
	t.check("generator" in Data.BUILD_TABS["Workshops"], "the Generator is in Workshops")
	t.check("wire_mill" in Data.BUILD_TABS["Metal"] and "order_board" in Data.BUILD_TABS["Lore"], "Wire Mill and Board")
	t.check(Data.BUILDINGS["wire_mill"]["needs_power"] and Data.BUILDINGS["wire_mill"]["out"] == {"wire": 1}, "Wire")
	t.check(Data.BUILDINGS["wire_mill"]["in"] == {"copper": 1}, "from Copper")
	t.check(
		Data.ITEMS.has("wire") and Data.ITEM_ORDER.has("wire") and Data.ITEMS["wire"]["era"] == 5,
		"Wire is a good of era 5"
	)
	t.check(
		(
			Data.BUILDINGS["water_wheel"]["gives"] == 2
			and Data.BUILDINGS["boiler"]["gives"] == 3
			and Data.BUILDINGS["generator"]["gives"] == 8
		),
		"a Wheel gives 2, a Boiler 3 and a Generator 8"
	)
	t.check(
		Data.POLE_LINK == 3.0 and Data.POLE_REACH == 2.0 and Data.MACHINE_ASK == 1,
		"poles link at 3, reach 2, a machine asks 1"
	)
	t.check(Data.ORDER_SLOTS == 3 and Data.ORDER_EVAL_SECONDS > 0.0, "the Board holds 3 orders, read every few seconds")
	t.check(
		Data.BRING_SKIP_SECONDS == 60.0 and Data.ORDER_STALE_SECONDS == 300.0, "60 s to skip a haul, 5 minutes to mark"
	)
	t.check(
		Data.BUILDINGS["order_board"].get("unique", false) and Data.BUILDINGS["order_board"]["near_hearth"],
		"one Board, by the Hearth"
	)
	t.check(not Buildings.needs_worker({"type": "order_board"}), "the Board has no worker")
	t.check(
		Data.LIVEWIRE_TEXT.contains("far to the south") and not Data.LIVEWIRE_TEXT.contains("north"),
		"the end card says south"
	)
	for item in Data.ITEM_ORDER:
		t.check(Art.sprite("item_" + item) != null or Data.ITEMS[item].has("sprite"), "%s has an icon" % item)
	t.check(Data.GOALS_ERA5.size() == 8, "eight goals")
	var ids: Array = Data.GOALS_ERA5.map(func(g): return g["id"])
	t.check(ids.size() == ids.duplicate().filter(func(x): return ids.count(x) == 1).size(), "each once")
	t.check(RunSave.VERSION == 1, "the save version is unchanged")


# --- The opening ---------------------------------------------------------------


func test_the_age_begins_when_the_card_is_put_away() -> void:
	var s := Sim.new()
	s.generate(2)
	s.story.record(Data.IRONFALL_EVENT)
	s.story.card_up = true
	s.story.record(Data.LIVEWIRE_EVENT)
	s.story.update(s)
	t.check(not s.story.has_event(Data.LIVEWIRE_BEGUN), "Livewire waits while the Wires Hum card is up")
	t.check(s.story.goal_list() == Data.GOALS_ERA4, "and the goals are Ironfall's")
	s.story.card_up = false
	s.tick(0.5)
	t.check(s.story.has_event(Data.LIVEWIRE_BEGUN), "it begins the tick after the card is put away")
	t.check(s.story.goal_list() == Data.GOALS_ERA5, "with a list of its own")
	t.check(
		Data.LIVEWIRE_BEGUN in Data.STORY_EVENTS and Data.LIVEWIRE_BEGUN in Data.TECH_AFTER_EVENTS, "a story moment"
	)
	var before := Sim.new()
	before.generate(2)
	before.tick(0.5)
	t.check(not before.story.has_event(Data.LIVEWIRE_BEGUN), "and not before the gate is passed")


func test_the_fifth_tab_and_the_tree() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel.refresh()
	t.check(panel.era_buttons.size() == 4 and panel.era_buttons.has(5), "a tab for Livewire")
	t.check(panel.era_buttons[5].disabled, "locked until the wires hum")
	t.check(panel.era_buttons[5].tooltip_text == Data.ERA_TAB_LOCKED_LIVEWIRE, "and it says when it opens")
	s.story.record(Data.IRONFALL_EVENT)
	panel.refresh()
	t.check(panel.era_buttons[5].disabled, "Ironfall's start does not open it")
	s.story.record(Data.LIVEWIRE_EVENT)
	panel.refresh()
	t.check(panel.era_buttons[5].disabled, "nor does the gate on its own")
	s.story.record(Data.LIVEWIRE_BEGUN)
	panel.refresh()
	t.check(not panel.era_buttons[5].disabled, "the card put away opens it")
	panel._pick_era(5)
	t.check(
		panel.board.era == 5 and panel.title.text == Data.BOARD_TITLE % "Livewire", "and it shows the Livewire tree"
	)
	panel._pick_view("all")
	for tech in Rules.era_techs(5):
		t.check(panel.board.card_rect(tech).size.x > 0.0, "%s has a card on the board" % tech)
	var again := TechPanel.new()
	again.setup(s)
	again.visible = true
	again._on_open()
	t.check(again.board.era == 5, "the board opens on the newest era")
	again.free()
	panel.free()
	var lay := TechLayout.build(5)
	t.check(int(lay["overflow"]) == 0, "no line of the tree runs off its board")
	var rects: Dictionary = lay["rects"]
	t.check(rects.size() == 14, "all fourteen cards are laid out")
	for a in rects:
		for b in rects:
			if a < b:
				t.check(not rects[a].intersects(rects[b]), "%s and %s do not overlap" % [a, b])
	for tech in Rules.era_techs(5):
		t.check(Data.TECH_BLURBS.has(tech), "%s has a blurb" % tech)


func test_only_stage_one_can_be_bought() -> void:
	var s := town()
	s.story.record(Data.LIVEWIRE_BEGUN)
	for id in ["steel", "iron", "wire", "brick", "rope", "wood", "stone", "coal"]:
		s.economy.seen[id] = true
		s.economy.inv[id] = 999
	for id in STAGE_ONE:
		s.tech_tree.researched.erase(id)
	t.check(s.tech_tree.can_research("power_poles"), "Power Poles can be bought")
	t.check(s.tech_tree.can_research("order_board"), "and the Order Board")
	t.check(not s.tech_tree.can_research("generator"), "the Generator waits for Power Poles")
	t.check(s.research("power_poles"), "bought")
	t.check(s.tech_tree.can_research("generator"), "and then the Generator can be")
	for id in LATER:
		s.tech_tree.researched["boiler"] = true
		t.check(not s.tech_tree.can_research(id), "%s cannot be bought yet" % id)
	t.check(not s.town.unlocked("order_board"), "the Board is not on offer before its tech")
	s.research("order_board")
	t.check(s.town.unlocked("order_board"), "after it, it is")
	t.check(
		s.town.unlocked("power_pole") and s.town.unlocked("wire_mill"), "Power Poles open the pole and the Wire Mill"
	)
	var before := Sim.new()
	before.generate(2)
	before.tech_tree.researched["livewire"] = true
	t.check(not before.tech_tree.tech_visible("power_poles"), "the techs are out of view before the age begins")


# --- The net -------------------------------------------------------------------


func test_poles_join_into_nets() -> void:
	var s := town()
	var c := meadow(s)
	put(s, "power_pole", c)
	put(s, "power_pole", c + Vector2i(3, 0))
	put(s, "power_pole", c + Vector2i(7, 0))
	s.livewire.tick(s, 0.0)
	t.check(s.livewire.nets.size() == 2, "poles 3 tiles apart join, 4 apart do not (%d nets)" % s.livewire.nets.size())
	var big: Array = s.livewire.nets.filter(func(n): return n["poles"].size() == 2)
	t.check(big.size() == 1, "one net has the two joined poles")
	put(s, "power_pole", c + Vector2i(5, 0))
	s.livewire.tick(s, 0.0)
	t.check(
		s.livewire.nets.size() == 1 and s.livewire.nets[0]["poles"].size() == 4, "a pole between them joins all four"
	)
	t.check(Power.poles_joined(s), "the goal sees joined poles")
	t.check(s.town.price("power_pole") == {"wood": 2, "iron": 1}, "a Power Pole stays flat in price")
	var wood: int = s.economy.inv["wood"]
	var iron: int = s.economy.inv["iron"]
	s.tech_tree.researched["power_poles"] = true
	t.check(s.place("power_pole", c + Vector2i(0, 3)), "a pole goes down like any building")
	t.check(s.economy.inv["wood"] == wood - 2 and s.economy.inv["iron"] == iron - 1, "for 2 wood and 1 iron")
	tick_for(s, 1.0)
	t.check(s.town.buildings[s.town.building_at[c + Vector2i(0, 3)]]["worker"] == -1, "and needs no one to tend it")


func test_engines_and_machines_on_a_net() -> void:
	var s := town()
	var c := meadow(s)
	put(s, "power_pole", c)
	put(s, "power_pole", c + Vector2i(3, 0))
	var near := put(s, "forge", c + Vector2i(0, 2))  # 2 tiles from a pole: on the net
	var far := put(s, "forge", c + Vector2i(0, 3))  # 3 from the first pole, 3.6 from the second: off it
	var boiler := put(s, "boiler", c + Vector2i(3, 2))
	var wheel := put(s, "water_wheel", c + Vector2i(4, 1))
	var net := net_of(s, near["pos"])
	t.check(not net.is_empty() and near["pos"] in net["machines"], "a machine within 2 tiles of a pole is on its net")
	t.check(net_of(s, far["pos"]).is_empty(), "one 3 tiles off is not")
	t.check(boiler["pos"] in net["engines"] and wheel["pos"] in net["engines"], "engines within 2 tiles feed it")
	t.check(boiler["burn"] == 0.0, "a cold Boiler gives nothing")
	t.check(net["given"] == 2, "only the Wheel gives, 2 units (%d)" % net["given"])
	boiler["burn"] = 10.0
	t.check(net_of(s, near["pos"])["given"] == 5, "a lit Boiler adds its 3")
	near["worker"] = 0
	near["inbuf"] = {"iron": 4, "coal": 2}
	net = net_of(s, near["pos"])
	t.check(net["asks"] == 1, "a machine with a worker and its inputs asks 1 unit")
	t.check(s.town.is_powered(near["pos"]), "and is powered by the net")
	t.check(s.livewire.speed_of(near) == 1.0, "at full speed")
	var gone := s.town.buildings.find(wheel)
	s.demolish(wheel["pos"])
	t.check(gone >= 0 and net_of(s, near["pos"])["given"] == 3, "tearing the Wheel down takes its units off the net")
	t.check(Power.note(s, near).contains("3 units given, 1 asked"), "the card says so: %s" % Power.note(s, near))


func test_a_short_net_runs_everything_slower() -> void:
	var s := town()
	var c := meadow(s)
	put(s, "power_pole", c)
	var boiler := put(s, "boiler", c + Vector2i(0, 2))
	boiler["burn"] = 999.0
	var machines: Array = []
	for p in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)]:
		var mill := put(s, "grindstone", c + p)
		mill["worker"] = machines.size()
		mill["inbuf"] = {"wheat": 9, "grain": 9}
		machines.append(mill)
	var recipe: Dictionary = Buildings.recipe_in(machines[0])
	for each in machines:
		each["inbuf"] = recipe.duplicate()
		for id in recipe:
			each["inbuf"][id] = recipe[id] * 4
	var net := net_of(s, c)
	t.check(
		net["given"] == 3 and net["asks"] == 5,
		"five machines ask 5 of a net that gives 3 (%d of %d)" % [net["asks"], net["given"]]
	)
	t.check(Power.shortfall(net) == 2, "it is short by 2")
	t.check(is_equal_approx(s.livewire.speed_of(machines[0]), 0.6), "and every machine runs at 60%%")
	t.check(Power.note(s, machines[0]).contains("Net short by 2"), "the card says: %s" % Power.note(s, machines[0]))
	t.check(
		Power.note(s, boiler).contains("Net short by 2") or Power.note(s, boiler).contains("5 asked"),
		"so does the engine's"
	)
	t.check(s.town.is_powered(machines[0]["pos"]), "all of them are powered, none dark")
	# one machine's progress over a tick is the ratio of a full tick
	var m: Dictionary = machines[0]
	m["progress"] = 0.0
	var steps := 0
	var grew := 0.0
	var people: Sim = s
	people.people.found(10)
	for i in 40:
		s.economy.inv["berries"] = 999
		var was: float = m["progress"]
		s.tick(0.5)
		if m["progress"] > was and was > 0.0:
			grew = m["progress"] - was
			steps += 1
			break
	t.check(steps == 1 and absf(grew - 0.5 * 0.6) < 0.001, "a tick of work moves it 60%% as far (%.3f)" % grew)
	t.check(m["status"].begins_with("Working slowly"), "and its card says so: %s" % m["status"])
	# more power and the same net is whole again
	var gen := put(s, "generator", c + Vector2i(1, 1))
	gen["burn"] = 999.0
	net = net_of(s, c)
	t.check(net["given"] == 11 and s.livewire.speed_of(m) == 1.0, "a lit Generator makes it whole")
	t.check(not Power.note(s, m).contains("short"), "and the card stops saying short")
	var dark := town()
	var dc := meadow(dark)
	put(dark, "power_pole", dc)
	var lone := put(dark, "grindstone", dc + Vector2i(1, 1))
	lone["worker"] = 0
	lone["inbuf"] = Buildings.recipe_in(lone).duplicate()
	for id in lone["inbuf"]:
		lone["inbuf"][id] *= 3
	net_of(dark, lone["pos"])
	t.check(not dark.town.is_powered(lone["pos"]), "a net that gives nothing powers nothing")
	t.check(Power.note(dark, lone).contains("No power"), "and says: %s" % Power.note(dark, lone))


func test_the_old_reach_is_as_it_was() -> void:
	var s := town()
	var c := meadow(s)
	var boiler := put(s, "boiler", c)
	var forge := put(s, "forge", c + Vector2i(4, 0))
	boiler["burn"] = 10.0
	s.livewire.tick(s, 0.0)
	t.check(s.livewire.nets.is_empty(), "with no pole standing there is no net")
	t.check(s.town.is_powered(forge["pos"]), "a Forge within a lit Boiler's 5 tiles is powered")
	t.check(
		s.livewire.speed_of(forge) == 1.0 and Power.note(s, forge) == "", "at full speed, with nothing said of a net"
	)
	put(s, "power_pole", c + Vector2i(8, 8))
	s.livewire.tick(s, 0.0)
	t.check(s.town.is_powered(forge["pos"]) and s.livewire.speed_of(forge) == 1.0, "a pole elsewhere changes nothing")
	var far := put(s, "forge", c + Vector2i(7, 0))
	t.check(not s.town.is_powered(far["pos"]), "and a Forge out of its reach is unpowered")
	boiler["burn"] = 0.0
	t.check(not s.town.is_powered(forge["pos"]), "a cold Boiler powers nothing, as before")
	# a Water Wheel by a Grindstone, as before
	var wheel := put(s, "water_wheel", c + Vector2i(-6, 0))
	var mill := put(s, "grindstone", c + Vector2i(-6, 2))
	t.check(s.town.is_powered(mill["pos"]) and wheel["burn"] == 0.0, "a Grindstone by a Wheel is powered")
	# a hand-lit Boiler on a net also still lights for a machine in its reach
	var live := town()
	var lc := meadow(live)
	var lb := put(live, "boiler", lc)
	var lf := put(live, "forge", lc + Vector2i(3, 0))
	lf["worker"] = 0
	lf["inbuf"] = {"iron": 4, "coal": 2}
	lb["inbuf"] = {"coal": 3}
	live.people.found(6)
	tick_for(live, 2.0)
	t.check(lb["burn"] > 0.0, "a Boiler lights for a Forge in its reach with no pole in sight")


func test_the_generator_burns_only_while_the_net_asks() -> void:
	var s := town()
	var c := meadow(s)
	s.people.found(8)
	put(s, "power_pole", c)
	var gen := put(s, "generator", c + Vector2i(0, 2))
	t.check(
		Buildings.served(gen) and not Buildings.needs_worker(gen), "haulers feed a Generator, which needs no worker"
	)
	gen["inbuf"] = {"coal": 5}
	tick_for(s, 3.0)
	t.check(gen["burn"] == 0.0 and gen["inbuf"]["coal"] == 5, "with nothing asking it stays banked")
	t.check(gen["status"].begins_with("Banked"), "and says so: %s" % gen["status"])
	var forge := put(s, "forge", c + Vector2i(2, 0))
	forge["inbuf"] = {"iron": 6, "coal": 3}
	tick_for(s, 3.0)
	t.check(gen["burn"] > 0.0 and gen["inbuf"]["coal"] == 4, "when a machine on the net asks it lights, burning 1 Coal")
	t.check(s.town.is_powered(forge["pos"]) and net_of(s, c)["given"] == 8, "and gives the net 8 units")
	t.check(gen["status"].begins_with("Burning"), "(%s)" % gen["status"])
	t.check(Power.note(s, gen).contains("Gives its net 8 units"), "its card: %s" % Power.note(s, gen))
	var left: float = gen["burn"]
	tick_for(s, 4.0)
	t.check(gen["burn"] < left, "the fire burns down")
	# the machine goes: the Generator is not relit
	forge["inbuf"] = {}
	gen["burn"] = 0.5
	tick_for(s, 4.0)
	var coal: int = gen["inbuf"]["coal"]
	tick_for(s, 20.0)
	t.check(gen["burn"] == 0.0 and gen["inbuf"]["coal"] == coal, "once nothing asks, it burns no more Coal")
	# it stands off every net
	var lone := put(s, "generator", c + Vector2i(-7, 0))
	lone["inbuf"] = {"coal": 3}
	tick_for(s, 3.0)
	t.check(lone["burn"] == 0.0 and lone["status"] == Data.NET_NONE, "a Generator off every net says so")
	# a Boiler and a Generator on one net: the Boiler (built first) takes the first units, the Generator the rest
	var duo := town()
	var dc := meadow(duo)
	duo.people.found(10)
	put(duo, "power_pole", dc)
	var boiler := put(duo, "boiler", dc + Vector2i(0, 2))
	var gen2 := put(duo, "generator", dc + Vector2i(1, 1))
	boiler["inbuf"] = {"coal": 5}
	gen2["inbuf"] = {"coal": 5}
	var forges: Array = []
	for p in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)]:
		var f := put(duo, "forge", dc + p)
		f["inbuf"] = {"iron": 8, "coal": 4}
		forges.append(f)
	tick_for(duo, 4.0)
	t.check(
		boiler["burn"] > 0.0 and gen2["burn"] > 0.0,
		"five machines ask more than a Boiler gives, so the Generator lights too"
	)


func test_the_wire_mill_draws_wire() -> void:
	var s := town()
	var c := meadow(s)
	s.people.found(8)
	put(s, "power_pole", c)
	var gen := put(s, "generator", c + Vector2i(0, 2))
	gen["inbuf"] = {"coal": 5}
	var mill := put(s, "wire_mill", c + Vector2i(2, 0))
	mill["inbuf"] = {"copper": 4}
	t.check(Data.BUILDINGS["wire_mill"]["job"] == "Wiredrawer", "a Wiredrawer works it")
	tick_for(s, 45.0)
	t.check(
		mill["out"].get("wire", 0) + s.economy.inv.get("wire", 0) > 0, "it draws Copper into Wire (%s)" % [mill["out"]]
	)
	t.check(mill["inbuf"].get("copper", 0) < 4, "using the Copper")
	var dry := town()
	var dc := meadow(dry)
	dry.people.found(8)
	var cold := put(dry, "wire_mill", dc)
	cold["inbuf"] = {"copper": 4}
	var before: int = dry.economy.inv.get("wire", 0)
	tick_for(dry, 30.0)
	t.check(
		cold["out"].get("wire", 0) == 0 and dry.economy.inv.get("wire", 0) == before,
		"a Wire Mill with no power makes none"
	)
	t.check(cold["status"].begins_with("No power") or cold["alert"] == "No power", "and says so: %s" % cold["status"])
