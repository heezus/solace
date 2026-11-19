extends RefCounted
## Rate gates and the Hearthfire (Step 9C-2 and 9C-3): a gate asks a rate and a quarter of the pile, holds it for a minute, shows its
## line and the sum of one more maker; the fire feeds itself from what would spill, never draws a good the goal or the next gate is short
## of, and lights tiers that add work speed. Run with the Goal first tests (tests/goal_first_tests.gd).

const Bonuses = preload("res://scripts/bonuses.gd")
const Data = preload("res://scripts/data.gd")
const FireTiers = preload("res://scripts/fire_tiers.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const GoalFirst = preload("res://scripts/goal_first.gd")
const Hearthfire = preload("res://scripts/hearthfire.gd")
const RateData = preload("res://scripts/rate_data.gd")
const RateGate = preload("res://scripts/rate_gate.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_gate_asks_a_quarter_of_the_pile_for_its_rated_goods_only()
	test_a_rate_is_held_for_a_minute_and_a_dip_loses_ground_but_not_all()
	test_a_dip_costs_ground_a_little_at_a_time_and_a_burst_makes_it_up()
	test_a_full_store_counts_as_made_at_full_speed()
	test_makers_paused_by_a_standing_order_count_and_the_line_names_it()
	test_the_pace_of_one_more_maker_is_the_real_one()
	test_one_more_maker_is_not_promised_when_no_kith_is_free()
	test_hand_work_never_counts_toward_a_rate()
	test_a_gate_needs_its_rates_held_before_it_can_be_learned()
	test_every_rate_gate_shows_its_line_and_the_sum_of_one_more()
	test_the_goods_of_the_next_gate_are_asked_and_their_makers_never_hold()
	test_the_fire_takes_what_would_spill_and_lights_tiers()
	test_the_fire_never_draws_a_good_the_goal_or_the_gate_is_short_of()
	test_the_fire_adds_work_speed_and_the_switch_and_the_state_are_saved()


func _town() -> Sim:
	var s: Sim = t.fresh()
	t.give(s, 0)
	s.tech_tree.rate_held.clear()  # `give` holds every rate and puts the fire out: these tests want the real thing
	s.economy.fire["auto"] = true
	return s


## Close `seconds` game seconds of making `per_min` of `good` at `source`, one second at a time, looking each second as the Sim does.
func _make(s: Sim, good: String, per_min: float, source: String, seconds: int) -> void:
	for i in seconds:
		s.economy.flows.add(good, per_min / 60.0, source)
		s.economy.flows.advance(1.0)
		RateGate.update(s, 1.0)


## Feeds the flow window without looking at the gates: the window counts a start as the little it is, so a test warms it first.
func _warm(s: Sim, goods: Array, per_min: float, seconds: int) -> void:
	for i in seconds:
		for good in goods:
			s.economy.flows.add(good, per_min / 60.0, "kiln")
		s.economy.flows.advance(1.0)


func test_a_gate_asks_a_quarter_of_the_pile_for_its_rated_goods_only() -> void:
	var s := _town()
	for tech in RateData.GATES:
		var full: Dictionary = Data.TECHS[tech]["cost"]
		var now: Dictionary = s.tech_tree.cost_of(tech)
		for id in full:
			if RateData.rates(tech).has(id):
				t.check(
					now[id] == maxi(roundi(full[id] * 0.25), 1),
					"%s: %s is a quarter of %d (%d)" % [tech, id, full[id], now[id]]
				)
			else:
				t.check(now[id] == full[id], "%s: %s stays a pile of %d (%d)" % [tech, id, full[id], now[id]])
	t.check(
		s.tech_tree.cost_of("pottery") == Data.TECHS["pottery"]["cost"], "a tech that is not a gate keeps its price"
	)


func test_a_rate_is_held_for_a_minute_and_a_dip_loses_ground_but_not_all() -> void:
	var s := _town()
	_warm(s, ["brick"], 50.0, 30)
	_make(s, "brick", 50.0, "kiln", 59)
	t.check(RateGate.held(s, "bronze_dawn", "brick") == 59.0, "brick at 50 a minute has been held 59 s")
	t.check(not RateGate.met(s, "bronze_dawn"), "and the gate is not met: its other goods are not made")
	_make(s, "brick", 10.0, "kiln", 40)  # the 30-second window takes a while to fall under 40
	var after := RateGate.held(s, "bronze_dawn", "brick")
	t.check(after < 59.0 and after > 0.0, "a dip below R loses ground and not all of it (%.0f s left)" % after)
	_warm(s, ["brick"], 50.0, 30)
	_make(s, "brick", 50.0, "kiln", 120)
	t.check(RateGate.held(s, "bronze_dawn", "brick") == RateData.HOLD, "held for a minute it stays at a minute")
	var every := ["brick", "charcoal", "flour", "rope"]
	_warm(s, every, 100.0, 30)
	for i in 70:
		for good in every:
			s.economy.flows.add(good, 100.0 / 60.0, "kiln")
		s.economy.flows.advance(1.0)
		RateGate.update(s, 1.0)
	t.check(RateGate.met(s, "bronze_dawn"), "every rated good held: the gate is met")


func test_hand_work_never_counts_toward_a_rate() -> void:
	var s := _town()
	_make(s, "brick", 500.0, "hand", 40)
	_make(s, "brick", 500.0, "craft", 40)
	t.check(RateGate.made(s, "brick") == 0.0, "hand gathering and hand crafting are not the machine")
	t.check(RateGate.held(s, "bronze_dawn", "brick") == 0.0, "so nothing is held")


func test_a_gate_needs_its_rates_held_before_it_can_be_learned() -> void:
	var s := _town()
	var needs: Array = s.tech_tree.open_needs("bronze_dawn")
	var lines := needs.filter(func(l): return "a min (held 0:00 of 1:00)" in l)
	t.check(lines.size() == 4, "Bronze Dawn names its four rates as open needs (%d): %s" % [lines.size(), needs])
	t.check("Brick 0 of 40 a min (held 0:00 of 1:00)" in needs, "in the player's words: %s" % [needs])
	for good in RateData.rates("bronze_dawn"):
		s.tech_tree.rate_held["bronze_dawn|" + good] = RateData.HOLD
	t.check(s.tech_tree.open_needs("bronze_dawn").is_empty(), "held, nothing is open")
	t.check(s.tech_tree.open_needs("pottery").is_empty(), "a tech that is not a gate asks no rate")


func test_every_rate_gate_shows_its_line_and_the_sum_of_one_more() -> void:
	for tech in RateData.GATES:
		for good in RateData.rates(tech):
			var s := _town()
			for id in Data.BUILDINGS:  # every maker is open, so a maker can be named
				if Data.BUILDINGS[id]["tech"] != "":
					s.tech_tree.researched[Data.BUILDINGS[id]["tech"]] = true
			for other in RateData.rates(tech):
				s.tech_tree.rate_held["%s|%s" % [tech, other]] = RateData.HOLD if other != good else 20.0
			var line := RateGate.line(s, tech)
			var name: String = Data.ITEMS[good]["name"]
			var want := "%s 0 of %d a min (held 0:20 of 1:00)." % [name, RateData.rates(tech)[good]]
			t.check(line.begins_with(want), '%s, %s: the line reads "%s..." (%s)' % [tech, good, want, line])
			t.check("One more " in line, "%s, %s: the line adds the sum of one more maker (%s)" % [tech, good, line])
			t.check(
				"+" in line or "won't help" in line,
				"%s, %s: it says what one more adds or why it will not (%s)" % [tech, good, line]
			)
	var held := _town()
	for good in RateData.rates("bronze_dawn"):
		held.tech_tree.rate_held["bronze_dawn|" + good] = RateData.HOLD
	t.check(RateGate.line(held, "bronze_dawn") == "", "a gate whose rates are all held has no line")


func test_the_goods_of_the_next_gate_are_asked_and_their_makers_never_hold() -> void:
	var s := _town()
	var asked := GoalFirst.asked(s)
	for good in RateData.rates("bronze_dawn"):
		t.check(asked.get(good, 0) == GoalFirst.RATED, "%s is asked for the next gate" % good)
	t.check(s.goal_first, "Goal first is on")
	s.economy.inv["brick"] = 500  # nothing open asks for a pile of Brick, but the gate asks a rate of it
	s.town.add_building("kiln", s.world.camp_pos + Vector2i(3, 2))
	var kiln: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(3, 2)]]
	GoalFirst.update(s)
	t.check(
		String(kiln["goal_hold"]) == "" and not kiln["paused"],
		"a Kiln does not rest while the gate asks a rate of Brick"
	)
	t.check(
		RateData.asked({"bronze_dawn": true}).keys() == ["brick", "bronze", "flour", "rope"],
		"after Bronze Dawn the gate asks for the next goods"
	)
	t.check(
		RateData.asked({"bronze_dawn": true, "falling_star": true, "livewire": true, "skyward": true}).is_empty(),
		"after the last gate none"
	)


func _all_gates(s: Sim) -> void:
	for tech in RateData.GATES:
		s.tech_tree.researched[tech] = true


func test_the_fire_takes_what_would_spill_and_lights_tiers() -> void:
	var s := _town()
	_all_gates(s)
	s.economy.refresh_caps(s.town.buildings)
	var cap: int = s.economy.caps["wood"]
	s.economy.inv["wood"] = cap
	s.economy.inv["stone"] = 100  # far from its cap: untouched
	t.check(Hearthfire.tier(s) == 0 and Hearthfire.bonus(s) == 0.0, "no fire at the start")
	GoalFirst.update(s)
	t.check(
		s.economy.inv["wood"] == roundi(Hearthfire.KEEP_AT * cap),
		"a good at its cap is burnt down to %d%% of it" % roundi(Hearthfire.KEEP_AT * 100)
	)
	t.check(s.economy.inv["stone"] == 100, "a good not near its cap is left alone")
	var burnt: int = cap - int(s.economy.inv["wood"])
	t.check(Hearthfire.given(s) == float(burnt), "Wood is worth 1 each: %d given" % burnt)
	t.check(Hearthfire.tier(s) == (1 if burnt >= 600 else 0), "tier 1 lights at 600 worth")
	t.check(
		FireTiers.tier_of(599.0) == 0 and FireTiers.tier_of(600.0) == 1 and FireTiers.tier_of(1500.0) == 2,
		"the tiers start at 600 and 1500"
	)
	t.check(FireTiers.tier_of(8000.0) == 5 and FireTiers.tier_of(99999.0) == 5, "five tiers in all")
	t.check(is_equal_approx(FireTiers.bonus_of(8000.0), 0.15), "five tiers are +15%")
	s.economy.fire["worth"] = 590.0
	s.starfall.pops.clear()
	s.economy.inv["brick"] = 200
	t.check(Hearthfire.give(s, "brick", 10, {}) == 15.0, "Brick is worth 1.5 each")
	t.check(Hearthfire.tier(s) == 1, "the 600th worth lights tier 1")
	t.check(
		s.starfall.pops.size() == 1 and "tier 1" in String(s.starfall.pops[0]),
		"and the Hearth says so: %s" % [s.starfall.pops]
	)


func test_the_fire_never_draws_a_good_the_goal_or_the_gate_is_short_of() -> void:
	var s := _town()
	s.economy.refresh_caps(s.town.buildings)
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = s.economy.caps[id]
	var before: Dictionary = s.economy.inv.duplicate()
	s.tech_tree.queue = ["arc_lamps"]  # asks Brick 40, Steel 12, Wire 20 and the goods down the recipes
	var asked := GoalFirst.asked(s)
	GoalFirst.update(s)
	for id in asked:
		var ask: int = asked[id]
		if ask == GoalFirst.RATED:
			ask = RateData.keep(s.tech_tree.researched, id)
		t.check(
			s.economy.inv[id] >= mini(ask, before[id]),
			"%s stays at or above what is asked (%d): %d of %d" % [id, ask, s.economy.inv[id], before[id]]
		)
	for id in Hearthfire.BASIC:
		t.check(s.economy.inv[id] >= Hearthfire.FLOOR, "%s keeps its floor of 40" % id)
	for id in Hearthfire.NEVER:
		t.check(s.economy.inv[id] == before[id], "%s are what the Kin work with: never burnt" % id)
	s.economy.inv["rope"] = 90  # short of what the gate wants kept (3 minutes of 45 = 135): nothing is spare
	t.check(Hearthfire.spare(s, "rope", GoalFirst.asked(s)) == 0, "a good below what the gate keeps has nothing spare")
	t.check(
		Hearthfire.give(s, "rope", 50, GoalFirst.asked(s)) == 0.0 and s.economy.inv["rope"] == 90,
		"and give takes none of it"
	)
	s.economy.fire["auto"] = false
	var worth := Hearthfire.given(s)
	s.economy.inv["wood"] = s.economy.caps["wood"]
	GoalFirst.update(s)
	t.check(Hearthfire.given(s) == worth, "with the switch off nothing is fed")


func test_the_fire_adds_work_speed_and_the_switch_and_the_state_are_saved() -> void:
	var s := _town()
	var at := s.world.camp_pos + Vector2i(3, 2)
	s.town.add_building("gatherers_hut", at)
	var hut: Dictionary = s.town.buildings[s.town.building_at[at]]
	var plain := Bonuses.speed(s, hut)
	s.economy.fire["worth"] = 1500.0
	var gain := Bonuses.speed(s, hut) - plain
	t.check(is_equal_approx(gain, 0.06 * s.seasons.speed_factor(s, hut)), "two tiers speed a hut up by 6%% (%s)" % gain)
	t.check("Hearthfire +6%" in Bonuses.text(s, hut), "the pace line names the fire: %s" % Bonuses.text(s, hut))
	s.economy.fire["auto"] = false
	var back := Sim.new()
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run is saved and loaded")
	t.check(
		back.economy.fire["worth"] == 1500.0 and back.economy.fire["auto"] == false, "the fire and its switch come back"
	)
	s.tech_tree.rate_held["bronze_dawn|brick"] = 35.0
	var again := Sim.new()
	RunSave.restore(again, RunSave.from_json(RunSave.to_json(RunSave.dump(s))))
	t.check(
		again.tech_tree.rate_held.get("bronze_dawn|brick", 0.0) == 35.0, "and so do the seconds a rate has been held"
	)
	t.check(
		Hearthfire.text(s).begins_with("Hearthfire: tier 2 of 5, +6% work, 0 of 1500 to the next."),
		"the Hearth card says %s" % Hearthfire.text(s)
	)


## Fun playtest 7: a dip below R reset the minute to nothing, and a player stood 35 minutes at a gate. The gate is met when the last
## minute's average is at or above R: a dip loses ground a little at a time, and a burst after it makes it up.
func test_a_dip_costs_ground_a_little_at_a_time_and_a_burst_makes_it_up() -> void:
	var s := _town()
	_warm(s, ["brick"], 50.0, 30)
	_make(s, "brick", 50.0, "kiln", 60)
	t.check(RateGate.held(s, "bronze_dawn", "brick") == RateData.HOLD, "a minute at 50 holds R = 40")
	_make(s, "brick", 0.0, "kiln", 5)
	var dip := RateGate.held(s, "bronze_dawn", "brick")
	t.check(dip == RateData.HOLD, "five slow seconds do not pull the minute's average under R (%.0f)" % dip)
	_make(s, "brick", 0.0, "kiln", 40)
	var low := RateGate.held(s, "bronze_dawn", "brick")
	t.check(low < RateData.HOLD and low > 0.0, "a longer dip loses ground, not all of it (%.0f s left)" % low)
	_make(s, "brick", 80.0, "kiln", 70)
	t.check(RateGate.held(s, "bronze_dawn", "brick") == RateData.HOLD, "and a burst over R makes it up")
	t.check(
		RateGate.held_of([], 40.0) == 0.0 and RateGate.held_of([40.0, 40.0], 40.0) == 2.0,
		"a short run counts the seconds it has"
	)
	var back := Sim.new()
	RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s))))
	t.check(
		back.tech_tree.rate_ring.get("bronze_dawn|brick", []).size() == 60,
		"the minute's samples are saved with the run"
	)


## A Kiln resting at its Brick cap made nothing in the window, and the gate read Brick 0. A maker held up only by a full store counts
## at its full speed, and the line says so.
func test_a_full_store_counts_as_made_at_full_speed() -> void:
	var s := _town()
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id]["tech"] != "":
			s.tech_tree.researched[Data.BUILDINGS[id]["tech"]] = true
	var kilns: Array = []
	for i in 3:
		var at: Vector2i = s.world.camp_pos + Vector2i(3 + i, 2)
		s.town.add_building("kiln", at)
		kilns.append(s.town.buildings[s.town.building_at[at]])
	t.check(RateGate.made(s, "brick") == 0.0, "three idle Kilns made nothing in the window")
	for b in kilns:
		b["status"] = "Store full: Brick"
	t.check(
		FlowView.store_full(kilns[0]) and RateGate.full_makers(s, "brick").size() == 3, "all three rest on a full store"
	)
	var each := FlowView.full_rate(s, kilns[0], "brick")
	t.check(is_equal_approx(each, 24.0), "a Kiln makes 24 Brick a minute at full speed (%.1f)" % each)
	t.check(
		RateGate.made(s, "brick") >= 72.0 - 0.01,
		"three of them count as 72 a minute (%.1f)" % RateGate.made(s, "brick")
	)
	RateGate.update(s, 1.0)
	t.check(RateGate.held(s, "bronze_dawn", "brick") == 1.0, "so Brick is held, a second at a time")
	var line := RateGate.good_line(s, "bronze_dawn", "brick")
	t.check(line.begins_with("Brick: stores full, counts as made"), "the line says so: %s" % line)
	kilns[2]["status"] = "Working"
	t.check(not FlowView.store_full(kilns[2]), "a Kiln that is working is not resting on a full store")
	kilns[2]["paused"] = true
	kilns[0]["paused"] = true
	kilns[1]["paused"] = true
	t.check(RateGate.made(s, "brick") == 0.0, "a paused Kiln is not a Kiln on a full store")


## "One more Kiln: +N" is the pace of a Kiln as this player has it: a Kiln that has the Flint Tool's worker is quicker than one without.
func test_the_pace_of_one_more_maker_is_the_real_one() -> void:
	var s := _town()
	s.tech_tree.researched["pottery"] = true
	var bare := FlowView.added_rate(s, "kiln", "brick")
	t.check(is_equal_approx(bare, 24.0), "with none standing, a new Kiln adds its own 24 a minute (%.1f)" % bare)
	var at: Vector2i = s.world.camp_pos + Vector2i(3, 2)
	s.town.add_building("kiln", at)
	var b: Dictionary = s.town.buildings[s.town.building_at[at]]
	s.tech_tree.researched["kilns_ii"] = true
	var quicker := FlowView.added_rate(s, "kiln", "brick")
	t.check(
		quicker >= bare, "a standing Kiln's own bonuses are in what one more adds (%.1f against %.1f)" % [quicker, bare]
	)
	t.check(is_equal_approx(quicker, FlowView.full_rate(s, b, "brick")), "and it is that Kiln's full pace")


## Fun playtest 7: "Brick above 500 pause Kilns" held the Kilns and the gate read Brick 0. A held Kiln counts at its full speed, and the
## line names the order.
func test_makers_paused_by_a_standing_order_count_and_the_line_names_it() -> void:
	var s := _town()
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id]["tech"] != "":
			s.tech_tree.researched[Data.BUILDINGS[id]["tech"]] = true
	for i in 2:
		var at: Vector2i = s.world.camp_pos + Vector2i(3 + i, 2)
		s.town.add_building("kiln", at)
		var b: Dictionary = s.town.buildings[s.town.building_at[at]]
		b["alert"] = Data.ORDER_PAUSED_ALERT
		b["status"] = Data.ORDER_PAUSED_STATUS
	s.livewire._held = {"kiln": true}
	s.livewire.add(s)
	var order: Dictionary = s.livewire.orders[0]
	order["item"] = "brick"
	order["compare"] = "above"
	order["number"] = 500
	order["verb"] = "pause"
	order["target"] = "kiln"
	order["holding"] = true
	t.check(
		RateGate.made(s, "brick") >= 48.0 - 0.01,
		"two held Kilns count as 48 a minute (%.1f)" % RateGate.made(s, "brick")
	)
	RateGate.update(s, 1.0)
	var line := RateGate.good_line(s, "bronze_dawn", "brick")
	t.check(
		"Your order 'When Brick is above 500" in line and "pauses 2 Kilns" in line,
		"the line names the order: %s" % line
	)


## Fun playtest 7: "One more Kiln: +32" when the Kilns lacked Kith. With no free Kith the line says the one more will not be worked.
func test_one_more_maker_is_not_promised_when_no_kith_is_free() -> void:
	var s := _town()
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id]["tech"] != "":
			s.tech_tree.researched[Data.BUILDINGS[id]["tech"]] = true
	for other in RateData.rates("bronze_dawn"):
		s.tech_tree.rate_held["bronze_dawn|" + other] = RateData.HOLD if other != "brick" else 20.0
	s.people.idle_now = 0
	var line := RateGate.line(s, "bronze_dawn")
	t.check("won't help: no free Kith to work it" in line, "no free hand: %s" % line)
	s.people.idle_now = 2
	line = RateGate.line(s, "bronze_dawn")
	t.check("One more Kiln: +" in line, "a free hand: %s" % line)
