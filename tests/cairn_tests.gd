extends RefCounted
## The Shard Cairn's two payoffs: its hum cuts every tech's cost a little while one stands (one counts, however many
## stand), and a cairn raised before the Falling Star lands is kept as a saved run flag and a story moment. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const World = preload("res://scripts/world.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Stage2Tests = preload("res://tests/stage2_tests.gd")

## A tech with big costs, so a few percent still shows after rounding.
const BIG_TECH := "megaliths"

var t  # the runner, tests/run_tests.gd
var helper := Stage2Tests.new()  # for game()


func run(runner) -> void:
	t = runner
	helper.t = runner
	test_the_cairn_lowers_research_cost_while_it_stands()
	test_only_one_cairn_counts()
	test_the_cairn_stacks_with_tally_sticks()
	test_the_flag_is_set_only_before_the_star_falls()
	test_the_flag_and_the_story_save()
	test_the_cairn_text_hints_without_spoiling()


## A game with Star Lore known and the Strange Stone found, so the cairn can be built.
func _game() -> Sim:
	var s := helper.game(["star_lore", "masonry"])
	s.shard_seen = true
	return s


## Every free grass tile beside the Strange Stone.
func _spots(s: Sim) -> Array:
	var out: Array = []
	for n in World.NEIGHBORS:
		var p: Vector2i = s.world.shard_pos + n
		if s.world.tile_at(p) == "grass" and not s.town.building_at.has(p):
			out.append(p)
	return out


func _cost_sum(s: Sim, tech: String) -> int:
	var n := 0
	var cost: Dictionary = s.tech_tree.cost_of(tech)
	for id in cost:
		n += int(cost[id])
	return n


func test_the_cairn_lowers_research_cost_while_it_stands() -> void:
	var s := _game()
	var base: Dictionary = Data.TECHS[BIG_TECH]["cost"]
	t.check(s.tech_tree.cost_of(BIG_TECH) == base, "no cairn: the tech costs what it says")
	var spots := _spots(s)
	t.check(spots.size() >= 1 and s.place("shard_cairn", spots[0]), "a cairn goes beside the Strange Stone")
	var cut: Dictionary = s.tech_tree.cost_of(BIG_TECH)
	var share: float = 1.0 - float(Data.BUILDINGS["shard_cairn"]["research_discount"])
	t.check(is_equal_approx(share, 0.95), "the cairn takes 5% off")
	var lower := false
	for id in base:
		t.check(cut[id] == maxi(roundi(base[id] * share), 1), "%s costs 5%% less with a cairn" % id)
		t.check(cut[id] <= base[id], id + " never costs more")
		lower = lower or cut[id] < base[id]
	t.check(lower, "and at least one item is really cheaper")
	t.check(s.tech_tree.can_research("megaliths") == s.economy.can_afford(cut), "research is judged on the lower cost")
	var before: int = s.economy.inv["stone"]
	t.check(s.research(BIG_TECH), "and it is paid at the lower cost")
	t.check(before - s.economy.inv["stone"] == cut.get("stone", 0), "paying takes the cut price")
	var p: Vector2i = spots[0]
	s.demolish(p)
	t.check(
		s.tech_tree.cost_of("pottery") == Data.TECHS["pottery"]["cost"], "tear the cairn down and the boost is gone"
	)
	t.check(s.town.research_discount() == 0.0, "no discount without a cairn")


func test_only_one_cairn_counts() -> void:
	var s := _game()
	var spots := _spots(s)
	t.check(spots.size() >= 2, "set up: room for two cairns")
	t.check(s.place("shard_cairn", spots[0]), "the first cairn")
	var one := _cost_sum(s, BIG_TECH)
	t.check(s.place("shard_cairn", spots[1]), "and a second")
	t.check(_cost_sum(s, BIG_TECH) == one, "two cairns cut no more than one")
	t.check(is_equal_approx(s.town.research_discount(), 0.05), "the discount is 5% however many stand")


func test_the_cairn_stacks_with_tally_sticks() -> void:
	var s := _game()
	s.tech_tree.researched["tally_sticks"] = true
	var base: Dictionary = Data.TECHS[BIG_TECH]["cost"]
	var tally: Dictionary = s.tech_tree.cost_of(BIG_TECH)
	for id in base:
		t.check(tally[id] == maxi(roundi(base[id] * Data.TALLY_DISCOUNT), 1), "Tally Sticks alone is unchanged")
	t.check(s.place("shard_cairn", _spots(s)[0]), "a cairn beside the Strange Stone")
	var both: Dictionary = s.tech_tree.cost_of(BIG_TECH)
	var lower := false
	for id in base:
		t.check(both[id] == maxi(roundi(base[id] * Data.TALLY_DISCOUNT * 0.95), 1), id + ": both cuts, rounded once")
		lower = lower or both[id] < tally[id]
	t.check(lower, "the cairn takes a little more off a Tally Sticks price")


func test_the_flag_is_set_only_before_the_star_falls() -> void:
	var s := _game()
	t.check(not s.story.cairn_before_landing, "a new game has no cairn flag")
	t.check(not s.story.events.has("cairn_raised"), "and no cairn story moment")
	var spots := _spots(s)
	t.check(s.place("shard_cairn", spots[0]), "raise a cairn before the star falls")
	t.check(s.story.cairn_before_landing, "the flag is set")
	t.check(s.story.events.has("cairn_raised"), "and the story records cairn_raised")
	s.demolish(spots[0])
	t.check(s.place("shard_cairn", spots[0]), "rebuild it")
	t.check(
		s.story.cairn_before_landing and s.story.events.count("cairn_raised") == 1,
		"the flag stays and the moment is once"
	)
	var late := _game()
	late.story.record("star_falling")
	t.check(late.place("shard_cairn", _spots(late)[0]), "a cairn after the star has fallen")
	t.check(not late.story.cairn_before_landing, "does not set the flag")
	t.check(late.story.events.has("cairn_raised"), "though the moment is still recorded, after the fall")
	t.check(late.story.events.find("cairn_raised") > late.story.events.find("star_falling"), "in that order")
	t.check(Data.STORY_EVENTS.has("cairn_raised"), "cairn_raised is a stable id in Data.STORY_EVENTS")


func test_the_flag_and_the_story_save() -> void:
	var s := _game()
	t.check(s.place("shard_cairn", _spots(s)[0]), "a cairn before the star")
	var d := RunSave.dump(s)
	t.check(d["story"]["cairn_before_landing"] == true, "the run save holds the flag")
	var parsed := RunSave.from_json(RunSave.to_json(d))
	var b := Sim.new()
	t.check(RunSave.restore(b, parsed), "restore from parsed JSON")
	t.check(b.story.cairn_before_landing and b.story.events.has("cairn_raised"), "the flag and the moment come back")
	t.check(RunSave.to_json(RunSave.dump(b)) == RunSave.to_json(d), "and write back the same")
	t.check(b.tech_tree.cost_of(BIG_TECH) == s.tech_tree.cost_of(BIG_TECH), "with the cairn's boost still on")
	var clean := Sim.new()
	t.check(RunSave.restore(clean, RunSave.dump(helper.game([]))), "a game without a cairn restores")
	t.check(not clean.story.cairn_before_landing, "with the flag off")
	var old: Dictionary = RunSave.dump(helper.game([]))
	old["story"].erase("cairn_before_landing")
	t.check(
		RunSave.restore(clean, old) and not clean.story.cairn_before_landing, "a save from before the flag reads as off"
	)


func test_the_cairn_text_hints_without_spoiling() -> void:
	var def: Dictionary = Data.BUILDINGS["shard_cairn"]
	t.check(def.has("status") and def["status"] != "", "the cairn has a status line")
	t.check(def["status"].contains("think") and def["status"].contains("far off"), "it hints at both payoffs")
	t.check(def["desc"].contains("5%") and def["desc"].contains("far off"), "and so does its tooltip")
	for line in [def["status"], def["desc"]]:
		for word in ["Lumen", "ship", "land", "friend", "visitor", "alien"]:
			t.check(not line.to_lower().contains(word.to_lower()), "no spoiler word '%s'" % word)
	var s := _game()
	var spots := _spots(s)
	t.check(s.place("shard_cairn", spots[0]), "raise the cairn")
	s.tick(0.1)
	t.check(s.town.buildings[s.town.building_at[spots[0]]]["status"] == def["status"], "a standing cairn shows it")
