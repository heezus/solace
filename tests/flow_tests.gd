extends RefCounted
## Step 9C-1: the flow view's numbers match the ledger, the bottleneck line walks one step back, every gate goal shows an "at this rate"
## sum, and a telling that finished the Starfall before runs its story clocks at 40% and puts the marks it read onto the Wall at once.
## Run from run_tests.gd.

const Autoplay = preload("res://tests/autoplay.gd")
const Data = preload("res://scripts/data.gd")
const Founding = preload("res://scripts/founding.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const GoalSums = preload("res://scripts/goal_sums.gd")
const Ledger = preload("res://tests/tools/ledger.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_views_made_per_minute_match_the_ledger_over_five_minutes()
	test_a_goal_sum_says_how_long_at_this_rate_and_with_one_more_maker()
	test_one_more_maker_that_cannot_be_fed_says_what_is_short()
	test_every_gate_goal_shows_a_sum()
	test_the_bottleneck_walks_one_step_back_to_the_input()
	test_a_short_input_names_the_rival_maker_that_eats_it()
	test_a_maker_running_flat_out_with_its_ore_piling_up_says_one_more_is_short()
	test_the_table_page_prints_the_flow_and_the_flow_move_works()
	test_a_remembered_starfall_runs_its_story_clocks_at_forty_percent()
	test_a_remembered_starfall_puts_the_marks_it_read_onto_the_wall()


## Fill the flows' whole window: `made` is {item: [a minute, source]}, steady for every second of it.
func _flow(s: Sim, made: Dictionary) -> void:
	for i in Data.RATE_WINDOW:
		for item in made:
			s.economy.flows.add(item, float(made[item][0]) / 60.0, made[item][1])
		s.economy.flows.advance(1.0)


func test_the_views_made_per_minute_match_the_ledger_over_five_minutes() -> void:
	var s := Sim.new()
	s.generate(1)
	var bot := Autoplay.new()
	bot.attach(s)
	var ledger := Ledger.new()
	ledger.begin("test", s)
	var second := [floori(s.economy.flows.clock)]
	var sums := {}
	var samples := [0]
	var next := [float(Data.RATE_WINDOW)]
	bot.probe = func(g):
		if floori(g.economy.flows.clock) != second[0]:
			second[0] = floori(g.economy.flows.clock)
			ledger.sample(g)
		if g.seasons.time >= next[0]:  # one reading a window: the windows do not overlap, so their mean is the era's
			next[0] += float(Data.RATE_WINDOW)
			samples[0] += 1
			for id in ["wood", "berries", "stone"]:
				sums[id] = sums.get(id, 0.0) + FlowView.row(g, id)["made"]
	while bot.clock < 300.0:
		bot.step(true)
	var goods: Dictionary = ledger.finish(s)["goods"]
	for id in ["wood", "berries"]:
		var made := 0.0
		for source in goods[id]["made_per_min"]:
			made += goods[id]["made_per_min"][source]
		var seen: float = sums[id] / samples[0]
		t.check(made > 5.0, "the ledger saw %s made (%.1f a minute)" % [id, made])
		t.check(
			absf(seen - made) <= 0.02 * made + 0.05,
			"%s: the view's %.2f a minute is the ledger's %.2f within 2%%" % [id, seen, made]
		)


func test_a_goal_sum_says_how_long_at_this_rate_and_with_one_more_maker() -> void:
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["pottery"] = true
	var g := {"id": "t", "tech": "tally_sticks"}  # wood 60, rope 110, clay 60, charcoal 110, brick 25
	for id in ["wood", "rope", "clay", "charcoal"]:
		s.economy.inv[id] = 500
	s.economy.inv["brick"] = 10
	_flow(s, {"brick": [6.0, "kiln"], "clay": [30.0, "gatherers_hut"], "charcoal": [30.0, "charcoal_pit"]})
	var line := GoalSums.line(s, g)
	t.check(line.begins_with("Brick 10/25."), "the good that holds the goal, with its stock and price: " + line)
	t.check(line.contains("At this rate: 2.5 min."), "15 more at 6 a minute: " + line)
	t.check(line.contains("One more Kiln: "), "and what one more Kiln would do: " + line)
	s.economy.inv["brick"] = 25
	t.check(GoalSums.line(s, g) == "", "a goal whose goods are all in hand has no sum")


func test_one_more_maker_that_cannot_be_fed_says_what_is_short() -> void:
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["pottery"] = true
	var g := {"id": "t", "tech": "tally_sticks"}
	for id in ["wood", "rope", "charcoal"]:
		s.economy.inv[id] = 500
	s.economy.inv["clay"] = 500
	s.economy.inv["brick"] = 10
	_flow(s, {"brick": [6.0, "kiln"]})
	var line := GoalSums.line(s, g)
	t.check(line.contains("One more Kiln won't help: "), "no Clay or Charcoal comes in to feed it: " + line)
	_flow(s, {"brick": [0.0, "kiln"]})
	line = GoalSums.line(s, g)
	t.check(line.contains("not rising"), "a good that is not rising says so: " + line)


func test_every_gate_goal_shows_a_sum() -> void:
	var s := Sim.new()
	s.generate(5)
	var lists := [Data.GOALS, Data.GOALS_ERA2, Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5]
	for i in lists.size():
		var gate: Dictionary = {}
		for g in lists[i]:
			if g["id"] == Founding.GATE_GOALS[i]:
				gate = g
		t.check(not gate.is_empty(), "era %d has its gate goal" % i)
		var plain := GoalSums.line(s, gate)
		var reach := GoalSums.line(s, Founding.reach_goal(i))
		if gate.has("tech") or gate.has("building"):
			t.check(plain.contains("At this rate"), "the gate of era %d shows a sum: %s" % [i, plain])
			t.check(reach.contains("At this rate"), "and so does its remembered goal: %s" % reach)


func test_the_bottleneck_walks_one_step_back_to_the_input() -> void:
	var s := Sim.new()
	s.generate(5)
	var kiln := s.world.camp_pos + Vector2i(3, 2)
	s.town.add_building("kiln", kiln)
	var b: Dictionary = s.town.buildings[s.town.building_at[kiln]]
	b["alert"] = "Needs Clay"
	t.check(FlowView.wait_code(b) == "input", "a Kiln that needs Clay waits on an input")
	var held := FlowView.bottleneck(s, "brick")
	t.check(held["pos"] == kiln, "the light is on the Kiln: %s" % [held["pos"]])
	t.check(held["line"].contains("Brick is held by Clay"), "the line names the input: " + held["line"])
	var hut := s.world.camp_pos + Vector2i(5, 2)
	s.town.add_building("gatherers_hut", hut)
	var h: Dictionary = s.town.buildings[s.town.building_at[hut]]
	h["focus"] = "clay"
	held = FlowView.bottleneck(s, "brick")
	t.check(
		held["line"].contains("1 Clay hut") and held["line"].contains("add a hut"),
		"a working Clay hut: " + held["line"]
	)
	h["alert"] = "Waiting for hands"
	held = FlowView.bottleneck(s, "brick")
	t.check(
		held["pos"] == hut and held["line"].contains("no free Kith"),
		"a hut with no hands is the one lit: " + held["line"]
	)
	var row: Dictionary = FlowView.row(s, "clay")
	t.check(
		row["makers"].size() == 1 and row["makers"][0]["waits"].get("hands", 0) == 1, "and the row counts it waiting"
	)


## Fun playtest 5: one smelter chokes the line while ore piles up, and nothing said "build a second smelter".
func test_a_maker_running_flat_out_with_its_ore_piling_up_says_one_more_is_short() -> void:
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["smelting"] = true
	var at := s.world.camp_pos + Vector2i(3, 2)
	s.town.add_building("smelter", at)
	t.check(s.town.unlocked("smelter"), "the Smelter is open")
	s.economy.inv["copper_ore"] = 80
	s.economy.inv["charcoal"] = 80
	_flow(s, {"copper": [6.0, "smelter"], "copper_ore": [4.0, "gatherers_hut"]})
	var held := FlowView.bottleneck(s, "copper")
	var line: String = held["line"]
	t.check(
		line.begins_with("Copper is held by Smelters: 1 Smelter, copper ore piling up. One more Smelter: +6.0 a min."),
		"the line names the shortage and what one more adds: " + line
	)
	t.check(held["pos"] == at, "and lights the Smelter")
	s.economy.inv["copper_ore"] = 5
	s.economy.inv["charcoal"] = 5
	line = FlowView.bottleneck(s, "copper")["line"]
	t.check(line.contains("all working; add one"), "with no ore piling up it says what it did before: " + line)


## Fun playtest 5: the table's page never printed the flow view, so the journalist never saw "at this rate" or what held a goal up.
func test_the_table_page_prints_the_flow_and_the_flow_move_works() -> void:
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["pottery"] = true
	for g in s.story.goal_list():
		if g["id"] != "calendar":
			s.story.goals_done[g["id"]] = true  # the goal in front of the player: the Calendar (Brick 30, Grain, Stone, Wood, Rope)
	for id in ["grain", "stone", "wood", "rope"]:
		s.economy.inv[id] = 500
	s.economy.inv["brick"] = 10
	_flow(s, {"brick": [6.0, "kiln"], "clay": [30.0, "gatherers_hut"], "charcoal": [30.0, "charcoal_pit"]})
	var page := Snapshot.text(s, 1, [], [])
	t.check(
		page.contains("AT THIS RATE: Brick 10/30. At this rate: 3.5 min."),
		"the page carries the goal's at-this-rate line"
	)
	t.check(page.contains("FLOW (the goal's goods, a minute): "), "and the goal's goods with made and used")
	t.check(page.contains("Brick 10 in stock, made 6.0, used 0.0, net +6.0"), "with the numbers of the flow view")
	t.check(Snapshot.HELP.contains('"do":"flow"'), "and the help lists the flow move")
	t.check(Snapshot.apply(s, [{"do": "flow"}]).is_empty(), "the flow move is taken")
	page = Snapshot.text(s, 2, [], [])
	t.check(page.contains("FLOW VIEW (every good"), "and the next page lists every good")
	t.check(not Snapshot.text(s, 3, [], []).contains("FLOW VIEW (every good"), "for that page only")
	# a rival line carries the Pause them button; the move presses it
	var mill := s.world.camp_pos + Vector2i(3, 2)
	var pot := s.world.camp_pos + Vector2i(6, 2)
	s.town.add_building("wire_mill", mill)
	s.town.add_building("crucible", pot)
	s.town.buildings[s.town.building_at[mill]]["alert"] = "Needs Copper"
	t.check(
		Snapshot.apply(s, [{"do": "flow", "pause_them": true}]).size() == 1,
		"with no rival named, Pause them is refused"
	)


## Players fall into the Livewire trap too: the Crucibles eat the Copper the Wire Mills wait for, to make Bronze nothing open asks for.
func test_a_short_input_names_the_rival_maker_that_eats_it() -> void:
	var s := Sim.new()
	s.generate(5)
	var mill := s.world.camp_pos + Vector2i(3, 2)
	var pot := s.world.camp_pos + Vector2i(6, 2)
	s.town.add_building("wire_mill", mill)
	s.town.add_building("crucible", pot)
	s.town.buildings[s.town.building_at[mill]]["alert"] = "Needs Copper"
	s.economy.inv["copper"] = 0
	s.economy.inv["bronze"] = 100
	_flow(s, {"copper": [-27.0, "crucible"]})
	var held := FlowView.bottleneck(s, "wire")
	var line: String = held["line"]
	t.check(line.contains("Wire is held by Copper"), "the line names the short input: " + line)
	t.check(
		line.contains("Crucibles take 100% of it to make Bronze, which nothing open needs. Pause them?"),
		"and the rival, its share and what it makes: " + line
	)
	t.check(held["pos"] == pot and held["pause"] == [pot], "the light and the pause are on the Crucible: %s" % [held])
	s.economy.inv["bronze"] = 5
	line = FlowView.bottleneck(s, "wire")["line"]
	t.check(not line.contains("Pause them"), "with little Bronze in the stores there is no rival line: " + line)
	s.economy.inv["bronze"] = 100
	s.set_paused(s.town.building_at[pot], true)
	line = FlowView.bottleneck(s, "wire")["line"]
	t.check(not line.contains("Pause them"), "a paused rival is not named again: " + line)


func _remembering(s: Sim) -> void:
	s.carry.exodus = 1
	s.carry.last_eras = [10.0, 10.0, 10.0, 10.0]


func test_a_remembered_starfall_runs_its_story_clocks_at_forty_percent() -> void:
	var first := Sim.new()
	first.generate(5)
	first.starfall.begin(true)
	for i in 30:
		first.starfall.tick(1.0)
	var again := Sim.new()
	again.generate(5)
	_remembering(again)
	again.starfall.carry = again.carry
	again.starfall.begin(true)
	for i in 30:
		again.starfall.tick(1.0)
	t.check(first.starfall.story_pace() == 1.0 and again.starfall.story_pace() == 2.5, "the pace is 1 and then 2.5")
	t.check(
		first.starfall.stage == "landed" and again.starfall.stage == "arrived",
		"after 30 s the strangers have come sooner (%s against %s)" % [again.starfall.stage, first.starfall.stage]
	)


func test_a_remembered_starfall_puts_the_marks_it_read_onto_the_wall() -> void:
	var s := Sim.new()
	s.generate(5)
	_remembering(s)
	s.starfall.carry = s.carry
	var glyphs: Array = Data.GLYPH_SETS[1]["glyphs"]
	s.carry.marks = glyphs.duplicate()
	s.starfall.begin(true)
	s.starfall.stage = "arrived"
	s.town.add_building("glyph_wall", s.world.camp_pos + Vector2i(3, 2))
	s.starfall.tick(1.0)
	t.check(
		s.starfall.copied.size() == glyphs.size(),
		"every mark of the set is on the Wall at once (%d)" % s.starfall.copied.size()
	)
	s.starfall.tick(1.0)
	t.check(s.starfall.locked.has("name"), "and the set is read at the next look")
	var fresh := Sim.new()
	fresh.generate(5)
	fresh.starfall.begin(true)
	fresh.starfall.stage = "arrived"
	fresh.town.add_building("glyph_wall", fresh.world.camp_pos + Vector2i(3, 2))
	fresh.starfall.tick(1.0)
	t.check(fresh.starfall.copied.is_empty(), "a first telling has nothing on the Wall yet")
