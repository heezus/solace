extends RefCounted
## Sight (scripts/sight.gd): every reason a workshop waits has a gap label, the flows add up to the deliveries, and Sight changes
## nothing in the sim. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")
const Sight = preload("res://scripts/sight.gd")
const Sim = preload("res://scripts/sim.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_every_wait_reason_has_a_gap_label()
	test_quiet_states_are_dots_and_a_held_workshop_is_named()
	test_flows_match_the_deliveries()
	test_depots_nets_and_what_slows_the_bloom()
	test_sight_changes_nothing_in_the_sim()


func _town() -> Sim:
	var s: Sim = t.fresh()
	t.give(s, 200)
	for id in ["storehouse", "fire", "haulers"]:
		s.tech_tree.researched[id] = true
	var camp := s.world.camp_pos
	var far := camp + Vector2i(8 if camp.x < 14 else -8, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s.world.set_tile(far + Vector2i(dx, dy), "grass")
	s.pathing.build()
	s.place("storehouse", far)
	s.place("charcoal_pit", far + Vector2i(1, 0))
	s.place("charcoal_pit", camp + Vector2i(1, 0))
	s.people.found(10)
	return s


func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds * 10.0):
		s.tick(0.1)


## The gap Sight lists for the pit at `at` after `s` is read afresh.
func _gap(s: Sim, at: Vector2i) -> Dictionary:
	s.hauling._census_at = -1.0
	var sight := Sight.new()
	sight.gather(s)
	return sight.gap_at(at)


func test_every_wait_reason_has_a_gap_label() -> void:
	var s := _town()
	_run(s, 40.0)
	var at: Vector2i = s.world.camp_pos + Vector2i(1, 0)
	var pit: Dictionary = s.town.buildings[s.town.building_at[at]]
	pit["alert"] = "Needs Wood"
	pit["status"] = "Needs Wood"
	pit["inbuf"] = {}
	pit["incoming"] = {}
	s.economy.inv["wood"] = 0
	var g := _gap(s, at)
	t.check(g.get("code") == "out" and g["text"] == Data.SIGHT_OUT % "Wood" and g["loud"], "out: %s" % [g])
	s.economy.inv["wood"] = 200
	pit["incoming"] = {"wood": 4}
	g = _gap(s, at)
	t.check(g.get("code") == "on_the_way" and not g["loud"], "on the way: a quiet dot (%s)" % [g])
	pit["incoming"] = {}
	var haulers: Array = []
	for k in s.people.kith:
		if k["job"] == "haul":
			haulers.append(k)
	for k in haulers:
		k["task"] = {"kind": "pickup", "building": 0, "depot": s.world.camp_pos}
	g = _gap(s, at)
	t.check(g.get("code") == "busy" and "Haulers busy" in g["text"] and g["loud"], "busy: %s" % [g])
	for k in haulers:
		k["task"] = {}
		k["pos"] = Vector2(k["depot"])
	g = _gap(s, at)
	t.check(g.get("code") == "free_hauler" and g["text"] == Data.SIGHT_FREE, "free hauler: %s" % [g])
	for k in haulers:
		k["pos"] = Vector2(k["depot"]) + Vector2(3, 3)
	g = _gap(s, at)
	t.check(g.get("code") == "walking" and g["text"] == Data.SIGHT_WALKING, "walking back: %s" % [g])
	for k in haulers:
		k["job"] = "gather"
	g = _gap(s, at)
	t.check(g.get("code") == "no_hauler" and "No hauler" in g["text"], "no hauler: %s" % [g])
	for k in haulers:
		k["job"] = "haul"
		k["pos"] = Vector2(k["depot"])
	pit["unreachable"] = 2.0
	g = _gap(s, at)
	t.check(g.get("code") == "cut" and g["text"] == Data.SIGHT_CUT, "road cut: %s" % [g])
	pit["unreachable"] = 0.0
	# a pit no road reaches, once haulers are learned
	var lone := Vector2i(-1, -1)
	for dy in range(-7, 8):
		for dx in range(-7, 8):
			var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
			if lone.x < 0 and absi(dx) + absi(dy) > 6 and s.place("charcoal_pit", p):
				lone = p
	t.check(lone.x >= 0, "a pit stands away from the roads")
	if lone.x >= 0:
		var far: Dictionary = s.town.buildings[s.town.building_at[lone]]
		t.check(not Roads.automated(s, far), "no road reaches it")
		far["alert"] = "Needs Wood"
		g = _gap(s, lone)
		t.check(g.get("code") == "no_road" and g["text"] == Data.SIGHT_NO_ROAD, "no road: %s" % [g])
	# the two reasons an order gives, in Sight's words (their fixtures live in tests/orders_tests.gd)
	var sight := Sight.new()
	var kept := sight.words(s, pit, "wood", "kept_back")
	var ahead := sight.words(s, pit, "wood", "order_first")
	t.check(kept["text"] == Data.SIGHT_KEPT and kept["loud"], "kept for an order: %s" % [kept])
	t.check(ahead["text"] == Data.SIGHT_AHEAD and ahead["loud"], "an order serves others first: %s" % [ahead])


func test_quiet_states_are_dots_and_a_held_workshop_is_named() -> void:
	var s := _town()
	_run(s, 10.0)
	var at: Vector2i = s.world.camp_pos + Vector2i(1, 0)
	var pit: Dictionary = s.town.buildings[s.town.building_at[at]]
	pit["alert"] = ""
	pit["status"] = Data.STORE_FULL_STATUS
	var g := _gap(s, at)
	t.check(g.get("code") == "resting" and not g["loud"], "resting at a full store: a dot (%s)" % [g])
	pit["status"] = "Working"
	pit["paused"] = true
	g = _gap(s, at)
	t.check(g.get("code") == "paused" and not g["loud"], "paused: a dot (%s)" % [g])
	pit["paused"] = false
	pit["alert"] = Data.HOLD_BACK_ALERT
	g = _gap(s, at)
	t.check(g.get("code") == "held" and g["text"] == Data.SIGHT_HELD, "held for haulers: %s" % [g])
	pit["alert"] = "Full: waiting for a hauler"
	g = _gap(s, at)
	t.check(g.get("code") == "full" and g["loud"], "output full: %s" % [g])
	pit["alert"] = "No power: no pole"
	g = _gap(s, at)
	t.check(g.get("code") == "alert" and g["text"] == "No power: no pole", "a power gap keeps its words: %s" % [g])
	pit["alert"] = ""
	t.check(_gap(s, at).is_empty(), "a working building is no gap")


## What the haulers carried into buildings in 50 s, counted from the buildings' own stocks, against Sight's flows.
func test_flows_match_the_deliveries() -> void:
	var s := _town()
	for p in [Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2)]:
		s.place("charcoal_pit", s.world.camp_pos + p)
	for b in s.town.buildings:
		if b["type"] == "charcoal_pit":
			b["worker"] = 0
	var seen := {}  # building tile -> {item: stock last tick}
	var counted := {}  # item -> units delivered into buildings
	for i in 500:
		s.tick(0.1)
		for b in s.town.buildings:
			var last: Dictionary = seen.get(b["pos"], {})
			for id in b["inbuf"]:
				var gain: int = b["inbuf"][id] - last.get(id, 0)
				if gain > 0 and seen.has(b["pos"]):
					counted[id] = counted.get(id, 0) + gain
			seen[b["pos"]] = b["inbuf"].duplicate()
	var sight := Sight.new()
	sight.gather(s)
	var into := {}
	for f in sight.flows:
		if s.town.building_at.has(f["to"]) and not f["to"] in Roads.depots(s):
			into[f["item"]] = into.get(f["item"], 0.0) + f["per_min"] * s.hauling.LOG_WINDOW / 60.0
	var delivered := 0.0
	for id in counted:
		delivered += counted[id]
	var drawn := 0.0
	for id in into:
		drawn += into[id]
	t.check(delivered > 0.0, "the haulers delivered goods in 50 s (%d)" % delivered)
	t.check(
		absf(drawn - delivered) <= 0.05 * delivered,
		"the flows into buildings match within 5%% (%.1f drawn, %d delivered)" % [drawn, delivered]
	)


func test_depots_nets_and_what_slows_the_bloom() -> void:
	var s := _town()
	_run(s, 40.0)
	var sight := Sight.new()
	sight.gather(s)
	t.check(sight.depots.size() >= 1, "a depot with haulers is listed (%d)" % sight.depots.size())
	for d in sight.depots:
		t.check(
			d["have"] == s.hauling.have(d["pos"]) and d["want"] == s.hauling.wanted(d["pos"]), "its haulers: %s" % [d]
		)
	t.check(sight.nets.is_empty() and sight.lamps.is_empty(), "no poles or lamps in a stone age town")


func test_sight_changes_nothing_in_the_sim() -> void:
	var a := _town()
	var b := _town()
	_run(a, 60.0)
	for i in 600:
		b.tick(0.1)
		if i % 10 == 0:
			Sight.new().gather(b)
	t.check(
		JSON.stringify(a.economy.inv) == JSON.stringify(b.economy.inv),
		"reading the town once a second leaves the stockpile exactly as it was"
	)
