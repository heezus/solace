extends RefCounted
## Step 8C, the cycles (design-system/32-skyreach.md): from the first true ending on, every telling is a cycle that adds a strain to
## the ones before: the tide runs 10% faster, each landfall wave has one more fall, the stores start 20% lean. Cap 5, repeating in
## that order. The title says "Cycle N"; the Chronicle draws the cycles as a second band. Run from tests/telling_tests.gd.

const Carry = preload("res://scripts/carry.gd")
const Data = preload("res://scripts/data.gd")
const Launch = preload("res://scripts/launch.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")
const Skyreach = preload("res://scripts/skyreach.gd")

const TEMP_PROFILE := "user://solace_test_cycles_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_cycle_counts_from_the_first_true_ending()
	test_the_strains_come_in_order_and_cap()
	test_the_tide_runs_faster()
	test_a_wave_carries_more_falls()
	test_the_stores_start_lean()
	test_a_new_telling_carries_the_cycle()
	DirAccess.remove_absolute(TEMP_PROFILE)


## A carry whose earlier tellings ended in `reached`.
func _carry(reached: Array) -> Carry:
	var c := Carry.new()
	c.exodus = reached.size()
	c.reached = reached.duplicate()
	return c


func test_the_cycle_counts_from_the_first_true_ending() -> void:
	t.check(_carry([]).cycle() == 0, "a first run is in no cycle")
	t.check(_carry(["exodus", "cataclysm", "loop"]).cycle() == 0, "nor are the tellings before a true ending")
	t.check(_carry(["exodus", "seal"]).cycle() == 1, "the first true ending makes cycle 1")
	t.check(_carry(["cataclysm", "heal", "exodus"]).cycle() == 2, "and any ending after it the next cycle")
	t.check(_carry(["seal", "leave"]).cycle() == 2, "a true ending again is the next cycle too")


func test_the_strains_come_in_order_and_cap() -> void:
	var counts := {}
	for n in range(1, 9):
		var before := ["seal"]
		for i in n - 1:
			before.append("exodus")
		var c := _carry(before)
		counts[n] = [c.strain_count("tide"), c.strain_count("falls"), c.strain_count("stock")]
	t.check(counts[1] == [1, 0, 0], "cycle 1: the tide only (%s)" % str(counts[1]))
	t.check(counts[2] == [1, 1, 0], "cycle 2: and a fall more (%s)" % str(counts[2]))
	t.check(counts[3] == [1, 1, 1], "cycle 3: and lean stores (%s)" % str(counts[3]))
	t.check(counts[4] == [2, 1, 1], "cycle 4: the order comes round, a faster tide again (%s)" % str(counts[4]))
	t.check(counts[5] == [2, 2, 1], "cycle 5: and a second fall (%s)" % str(counts[5]))
	t.check(counts[8] == counts[5], "and no more than five strains (%s)" % str(counts[8]))
	t.check(_carry(["exodus"]).strain_lines().is_empty(), "no strains outside the cycles")
	t.check(
		_carry(["seal"]).strain_lines().size() == 1 and _carry(["seal", "exodus", "exodus"]).strain_lines().size() == 3,
		"one line a kind"
	)


func test_the_tide_runs_faster() -> void:
	t.check(_carry([]).tide_factor() == 1.0, "the tide keeps its pace outside the cycles")
	t.check(is_equal_approx(_carry(["seal"]).tide_factor(), 1.1), "10% faster in cycle 1")
	t.check(is_equal_approx(_carry(["seal", "x", "x", "x"]).tide_factor(), 1.2), "20% in cycle 4")
	var slow := Sim.new()
	slow.generate(5)
	slow.tide.begun = true
	slow.tide.tick(slow, 10.0)
	var fast := Sim.new()
	fast.generate(5)
	fast.carry.reached = ["seal"]
	fast.tide.begun = true
	fast.tide.tick(fast, 10.0)
	t.check(
		is_equal_approx(fast.tide.time, slow.tide.time * 1.1),
		"and its clock runs 10%% faster (%.2f / %.2f)" % [fast.tide.time, slow.tide.time]
	)


func test_a_wave_carries_more_falls() -> void:
	var plain := Sim.new()
	plain.generate(5)
	plain.carry.exodus = 1
	plain.skyreach._plan(plain, 0)
	var strained := Sim.new()
	strained.generate(5)
	strained.carry.exodus = 2
	strained.carry.reached = ["seal", "exodus"]  # cycle 2: a faster tide and a fall more
	strained.skyreach._plan(strained, 0)
	t.check(
		plain.skyreach.falls.size() == Skyreach.wave_size(0),
		"a plain wave has its planned falls (%d)" % plain.skyreach.falls.size()
	)
	t.check(
		strained.skyreach.falls.size() == Skyreach.wave_size(0) + 1,
		"cycle 2 adds one fall to the wave (%d)" % strained.skyreach.falls.size()
	)


func test_the_stores_start_lean() -> void:
	var plain := Sim.new()
	plain.generate(5)
	var berries: int = plain.economy.inv["berries"]
	var lean := Sim.new()
	lean.generate(5)
	lean.carry.reached = ["seal", "exodus", "exodus"]  # cycle 3: the third strain is the stores
	lean.carry.apply_start(lean)
	t.check(
		lean.economy.inv["berries"] == floori(berries * 0.8),
		"the stores start 20%% lean (%d of %d)" % [lean.economy.inv["berries"], berries]
	)
	var first := Sim.new()
	first.generate(5)
	first.carry.reached = ["seal"]
	first.carry.apply_start(first)
	t.check(first.economy.inv["berries"] == berries, "cycle 1 leaves them as they were")


func test_a_new_telling_carries_the_cycle() -> void:
	DirAccess.remove_absolute(TEMP_PROFILE)
	var done := Sim.new()
	done.generate(5)
	Profile.set_out(done, TEMP_PROFILE, "seal")
	var s := Sim.new()
	Launch.begin_new(s, 11, TEMP_PROFILE)
	t.check(s.carry.cycle() == 1, "Another telling begins in cycle 1")
	t.check(s.carry.tide_factor() > 1.0, "with its strain")
	var p := Profile.new()
	p.load_file(TEMP_PROFILE)
	Profile.set_out(s, TEMP_PROFILE, "exodus")
	var next := Sim.new()
	Launch.begin_new(next, 12, TEMP_PROFILE)
	t.check(next.carry.cycle() == 2, "and the next telling, however it ended, in cycle 2")
