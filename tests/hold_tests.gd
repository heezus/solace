extends RefCounted
## Hold to harvest forgives a shaky hand (design-system/14-hands-to-haulers.md, found by Jon's playtest of 2026-10-03:
## "the early game is kinda slow and wonky with clicking"). A pointer that drifts off the tile or a click that lets go early
## keeps its progress for Data.HOLD_KEEP seconds; a pointer that slides to the next tile of the same kind keeps the ring
## at once. The first resource a Kith learns takes Data.LEARN_FIRST harvests, the rest Data.LEARN_CLICKS. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Hands = preload("res://scripts/hands.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_numbers_are_forgiving_but_still_a_hold()
	test_sliding_to_the_next_tile_of_the_same_kind_keeps_the_ring()
	test_a_slip_off_the_tile_and_back_keeps_the_progress()
	test_a_slip_onto_another_kind_of_tile_and_back()
	test_a_slip_that_lasts_too_long_loses_the_progress()
	test_letting_go_early_keeps_the_progress_for_the_next_press()
	test_taps_add_up_but_a_hold_is_faster()
	test_letting_go_for_good_empties_the_ring()
	test_the_first_lesson_takes_fewer_harvests()
	test_the_early_numbers_stay_quick()


## A game with a cleared square of grass, then a tree at A, a tree beside it at B (next door), a rock at R (beside A on
## the other side) and a tree far from them at F. Returns {a, b, r, f, bare} (bare is plain grass).
func _arena() -> Dictionary:
	var s: Sim = t.fresh()
	var c := s.world.camp_pos + Vector2i(9, 0)
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			s.world.set_tile(c + Vector2i(dx, dy), "grass")
	var a := c
	var b := c + Vector2i(1, 0)
	var r := c + Vector2i(-1, 0)
	var f := c + Vector2i(5, 3)
	s.world.set_tile(a, "tree")
	s.world.set_tile(b, "tree")
	s.world.set_tile(r, "rock")
	s.world.set_tile(f, "tree")
	return {"s": s, "a": a, "b": b, "r": r, "f": f, "bare": c + Vector2i(0, 2)}


## Hold `p` for `seconds`, in 0.02 s steps (a frame), returning how much wood and stone came in.
func _hold(s: Sim, p: Vector2i, seconds: float) -> int:
	var before: int = s.economy.inv.get("wood", 0) + s.economy.inv.get("stone", 0)
	for i in roundi(seconds / 0.02):
		s.hold_harvest(p, 0.02)
	return s.economy.inv.get("wood", 0) + s.economy.inv.get("stone", 0) - before


## Let `seconds` of game time pass (the waiting progress runs down in game time).
func _wait(s: Sim, seconds: float) -> void:
	for i in roundi(seconds * 10.0):
		s.tick(0.1)


func test_the_numbers_are_forgiving_but_still_a_hold() -> void:
	t.check(Data.HOLD_KEEP >= 0.3 and Data.HOLD_KEEP <= Data.HOLD_TIME, "a slip is forgiven for a moment, not for long")
	t.check(
		Data.LEARN_FIRST < Data.LEARN_CLICKS and Data.LEARN_FIRST >= 3, "the first lesson is quicker but still a lesson"
	)


func test_sliding_to_the_next_tile_of_the_same_kind_keeps_the_ring() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	t.check(_hold(s, g["a"], need * 0.5) == 0, "half a ring on the first tree")
	t.check(_hold(s, g["b"], need * 0.5 + 0.05) == 1, "slide to the tree next door: the ring goes on and pops")
	t.check(
		s.harvest_tile == g["b"] and s.harvest_ring["aside"].is_empty(),
		"the ring is on the new tree, nothing is put aside"
	)
	# diagonal counts as next door; a tree further off does not
	var g2 := _arena()
	var s2: Sim = g2["s"]
	s2.world.set_tile(g2["a"] + Vector2i(1, 1), "tree")
	_hold(s2, g2["a"], need * 0.5)
	t.check(_hold(s2, g2["a"] + Vector2i(1, 1), need * 0.5 + 0.05) == 1, "a diagonal neighbour is next door too")
	var g3 := _arena()
	var s3: Sim = g3["s"]
	_hold(s3, g3["a"], need * 0.5)
	t.check(_hold(s3, g3["f"], need * 0.5 + 0.05) == 0, "a tree far away starts a new ring")
	t.check(not s3.harvest_ring["aside"].is_empty(), "and the first ring's progress waits")


func test_a_slip_off_the_tile_and_back_keeps_the_progress() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	_hold(s, g["a"], need * 0.5)
	t.check(_hold(s, g["bare"], 0.2) == 0 and s.harvest_frac == 0.0, "a slip onto bare ground gathers nothing")
	t.check(not s.harvest_ring["aside"].is_empty(), "but the progress waits")
	t.check(_hold(s, g["a"], need * 0.5 + 0.05) == 1, "back on the tree in time: the ring picks up where it was")
	t.check(s.harvest_ring["aside"].is_empty(), "nothing is left waiting")


func test_a_slip_onto_another_kind_of_tile_and_back() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	_hold(s, g["a"], need * 0.6)
	_hold(s, g["r"], 0.1)  # the pointer crosses the border onto the rock for a moment
	t.check(s.economy.inv.get("stone", 0) == 0, "no stone from a moment on the rock")
	t.check(_hold(s, g["a"], need * 0.4 + 0.05) == 1, "back on the tree: its 60% is still there")
	t.check(s.harvest_ring["aside"].get("tile") == g["r"], "and the rock's moment waits in turn")


func test_a_slip_that_lasts_too_long_loses_the_progress() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	_hold(s, g["a"], need * 0.6)
	_hold(s, g["bare"], 0.1)
	_wait(s, Data.HOLD_KEEP + 0.2)
	t.check(s.harvest_ring["aside"].is_empty(), "the waiting progress runs out")
	t.check(_hold(s, g["a"], need * 0.4 + 0.05) == 0, "so the ring starts again from nothing")


func test_letting_go_early_keeps_the_progress_for_the_next_press() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	_hold(s, g["a"], need * 0.4)
	s.release_harvest(true)
	t.check(s.harvest_frac == 0.0 and s.harvest_tile == Vector2i(-1, -1), "let go: the live ring is empty")
	t.check(is_equal_approx(s.harvest_ring["aside"]["held"], need * 0.4), "but its progress waits")
	_wait(s, 0.3)
	t.check(_hold(s, g["a"], need * 0.6 + 0.05) == 1, "a press on the same tile soon after carries on")
	_hold(s, g["a"], need * 0.5)
	s.release_harvest(true)
	_wait(s, Data.HOLD_KEEP + 0.2)
	t.check(_hold(s, g["a"], need * 0.5 + 0.05) == 0, "a press after the wait starts again")
	_hold(s, g["a"], need * 0.5)
	s.release_harvest(true)
	t.check(_hold(s, g["f"], need * 0.6) == 0, "a press on another tile does not use it")


func test_taps_add_up_but_a_hold_is_faster() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	var taps := 0
	var got := 0
	while got == 0 and taps < 20:
		got += _hold(s, g["a"], 0.2)
		s.release_harvest(true)
		_wait(s, 0.1)  # the gap between taps is shorter than Data.HOLD_KEEP
		taps += 1
	t.check(got == 1 and taps <= ceili(need / 0.2) + 1, "short taps add up to a harvest (%d taps)" % taps)
	var held := 0.0
	var g2 := _arena()
	var s2: Sim = g2["s"]
	while _hold(s2, g2["a"], 0.1) == 0:
		held += 0.1
	t.check(
		held + 0.15 < taps * 0.3,
		"holding is still quicker than tapping (%.1f s held, %.1f s tapping)" % [held, taps * 0.3]
	)


func test_letting_go_for_good_empties_the_ring() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	var need := Hands.hold_time(s, "wood")
	_hold(s, g["a"], need * 0.5)
	s.release_harvest(true)
	s.release_harvest()
	t.check(s.harvest_ring["aside"].is_empty(), "a full release forgets what was waiting")
	t.check(_hold(s, g["a"], need * 0.5 + 0.05) == 0, "and nothing carries over")


func test_the_first_lesson_takes_fewer_harvests() -> void:
	var g := _arena()
	var s: Sim = g["s"]
	t.check(Hands.learn_needed(s) == Data.LEARN_FIRST, "nobody has learned anything: the first lesson is the short one")
	for i in Data.LEARN_FIRST - 1:
		s.gather_by_hand(g["a"])
	t.check(not s.people.knows("wood"), "one harvest short of the first lesson")
	s.gather_by_hand(g["a"])
	t.check(s.people.knows("wood"), "after %d harvests a Kith knows Wood" % Data.LEARN_FIRST)
	t.check(Hands.learn_needed(s) == Data.LEARN_CLICKS, "every lesson after that takes the full count")
	for i in Data.LEARN_CLICKS - 1:
		s.gather_by_hand(g["r"])
	t.check(not s.people.knows("stone"), "stone is not learned after %d" % (Data.LEARN_CLICKS - 1))
	s.gather_by_hand(g["r"])
	t.check(s.people.knows("stone"), "but after %d it is" % Data.LEARN_CLICKS)


## Jon's playtest of 2026-10-03: the first minutes by hand were slow and roads came late. These are the numbers that keep
## them quick; tests/tools/pace.gd (the pacing bot) says what they do to a whole run.
func test_the_early_numbers_stay_quick() -> void:
	var flint: float = Data.HAND_TOOLS["flint_tools"]["hold"]
	var bronze: float = Data.HAND_TOOLS["bronze_tools"]["hold"]
	t.check(Data.HOLD_TIME <= 0.8, "a bare-handed harvest takes at most 0.8 s (%.1f)" % Data.HOLD_TIME)
	t.check(bronze < flint and flint < Data.HOLD_TIME, "each tool is quicker than the last")
	var haulers: Dictionary = Data.TECHS["haulers"]
	t.check(haulers["requires"] == ["cordage", "gatherers_hut"], "Paths & Haulers needs only Cordage and the hut")
	var cost := 0
	for id in haulers["cost"]:
		cost += int(haulers["cost"][id])
	t.check(
		cost <= 60 and haulers["cost"].get("rope", 0) <= 20, "and costs at most 60 goods, 20 of them Rope (%d)" % cost
	)
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	t.check(ids.find("twine") < ids.find("haulers"), "the Goals ask for Rope before Haulers")
	t.check(ids.find("road") == ids.find("haulers") + 1, "and the road goal follows Haulers at once")
	t.check(ids.find("haulers") < ids.find("charcoal"), "Roads come before the Charcoal Pit, which no road waits for")
