extends RefCounted
## Ironfall stage 2 (design-system/19-ironfall.md): Teardown. The parts and the eight Lessons, the Bench and its queue, haulers
## carrying parts, the Wreck's three parts, the Lumen Camp's parts by lean, the three Bloom patches and their samples, what the
## Lessons do, the Lessons list, and the save. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const World = preload("res://scripts/world.gd")
const MapSouth = preload("res://scripts/map_south.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Land = preload("res://scripts/land.gd")
const Rules = preload("res://scripts/rules.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ExpeditionPicker = preload("res://scripts/expedition_picker.gd")
const Finds = preload("res://scripts/teardown_finds.gd")
const Lessons = preload("res://scripts/lessons.gd")
const LessonsList = preload("res://scripts/lessons_list.gd")
const TeardownPanel = preload("res://scripts/teardown_panel.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const CardText = preload("res://scripts/card_text.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Hands = preload("res://scripts/hands.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Patch = preload("res://scripts/patch.gd")
const Roads = preload("res://scripts/roads.gd")
const Scouting = preload("res://scripts/scouting.gd")
const IronfallTests = preload("res://tests/ironfall_tests.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")


## A node that draws the Lessons' overlays in its own _draw, as the map does.
class OverlayCanvas:
	extends Node2D
	var sim

	func _draw() -> void:
		Lessons.draw_overlays(self, sim)


var t  # the runner, tests/run_tests.gd
var _h  # the Starfall tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_teardown_data_is_whole()
	test_the_bench_opens_a_part()
	test_a_second_copy_gives_scrap()
	test_the_queue_is_short_and_a_torn_down_bench_keeps_its_parts()
	test_haulers_carry_parts_to_the_bench()
	test_the_wreck_holds_three_parts()
	test_the_lumen_camp_hands_over_parts_by_lean()
	test_the_bloom_patches_are_fair()
	test_a_party_brings_a_sample_home()
	test_sampling_waits_for_the_placeholder_or_the_tech()
	test_iron_gears()
	test_the_rain_barrel_and_smoke_starfruit()
	test_lessons_that_wait_for_stage_three()
	test_the_bloom_overlays()
	test_the_lessons_list_and_the_bench_panel()
	test_the_goals_and_the_story()
	test_teardown_saves_and_loads()


# --- Helpers ------------------------------------------------------------------


## A town in Ironfall: the map grown east and south, the Starfall over (the Lumen lean `lean`), Teardown learned, the
## fog lifted, a stocked stockpile and an Expedition Post. Seed 2, whose Wreck can be walked to.
func town(lean := "neighbours", map_seed := 2) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	for tech in ["bronze_dawn", "haulers", "coal_seams", "teardown"]:
		s.tech_tree.researched[tech] = true
	Land.grow_if_due(s)
	s.fog.reveal_all()
	t.give(s, 400)
	s.story.record("star_falling")
	for i in int(Data.LANDING_DELAY + Data.ARRIVAL_DELAY):
		s.starfall.tick(1.0)
	s.starfall.locked["name"] = true
	s.story.record("name_read")
	s.starfall.ended = true
	s.starfall.lean = lean
	s.story.record(Data.IRONFALL_EVENT)
	s.town.add_building("expedition_post", _h._spot(s, "expedition_post"))
	return s


## A Teardown Bench right beside the Hearth (a building beside a depot is linked without a road).
func bench(s: Sim) -> Dictionary:
	var spot := Vector2i(-1, -1)
	for n in World.NEIGHBORS:
		var p: Vector2i = s.world.camp_pos + n
		if s.town.placement_error("teardown_bench", p) == "":
			spot = p
			break
	t.check(spot.x >= 0 and s.place("teardown_bench", spot), "a Bench goes up beside the Hearth")
	return s.town.buildings[s.town.building_at[spot]]


## Run the whole game `seconds` forward, keeping everyone fed, until `done` is true.
func run_until(s: Sim, seconds: float, done: Callable) -> void:
	for i in int(seconds * 2.0):
		s.economy.inv["berries"] = 999
		s.tick(0.5)
		if done.call():
			return


func back(s: Sim) -> bool:
	return Expedition.count(s) == 0


## Send one party as the Post's orders say and wait for it to come home. Returns what the log said.
func trip(s: Sim, target: String, pack := "standard") -> Array:
	s.starfall.orders = {"target": target, "pack": pack, "keep": false}
	s.events.clear()
	var plan := Expedition.plan(s)
	t.check(plan["ok"], "a party can go to %s: %s" % [target, plan["why"]])
	if not plan["ok"]:
		return []
	Expedition.send(s)
	run_until(s, 1500.0, func(): return back(s))
	t.check(back(s), "the party is home from %s" % target)
	return s.events.duplicate()


# --- The data -----------------------------------------------------------------


func test_teardown_data_is_whole() -> void:
	t.check(
		Data.PARTS.size() == 8 and Data.LESSONS.size() == 8 and Data.LESSON_ORDER.size() == 8,
		"eight parts, eight Lessons"
	)
	for id in Data.LESSON_ORDER:
		t.check(Data.PARTS.has(id) and Data.LESSONS.has(id), "%s is a part and the Lesson it holds" % id)
		for key in ["name", "teaches", "note", "live"]:
			t.check(Data.LESSONS[id].has(key), "the %s Lesson has %s" % [id, key])
		for key in ["name", "color", "from"]:
			t.check(Data.PARTS[id].has(key), "the %s part has %s" % [id, key])
	t.check(Data.LESSON_ORDER.map(func(id): return Data.LESSONS[id]["name"]).size() == 8, "in a fixed order")
	t.check(Data.BENCH_SECONDS == 40.0 and Data.BENCH_SLOTS == 3, "a part takes about 40 s, and the queue is short")
	t.check(Data.WRECK_PARTS.size() == 3, "the Wreck always holds three parts")
	t.check(
		"heat_plate" in Data.WRECK_PARTS and "lamp_core" in Data.WRECK_PARTS, "among them the Boiler's and the Lamp's"
	)
	t.check(Data.CAMP_PARTS["enemies"].is_empty(), "low: the Lumen hand over nothing")
	t.check(Data.CAMP_PARTS["neighbours"].size() == 2, "middle: two parts")
	t.check(Data.CAMP_PARTS["neighbours"] == ["lamp_core", "seed_pod"], "the Lamp core and the Seed pod")
	t.check(Data.CAMP_PARTS["allies"].size() == 4, "high: all of them")
	for id in Data.CAMP_PARTS["neighbours"]:
		t.check(id in Data.CAMP_PARTS["allies"], "%s is in the allies' offer too" % id)
	for kind in Data.BLOOM_KINDS:
		t.check(Data.PARTS.has(kind) and Data.TILES.has(Data.BLOOM_TILES[kind]), "%s is a sample and a tile" % kind)
	t.check(Data.TILES.has(Data.BLOOM_GROUND), "and the ground it grows on")
	for id in Data.LESSON_ORDER:
		var sources := 0
		sources += 1 if id in Data.WRECK_PARTS else 0
		sources += 1 if id in Data.CAMP_PARTS["allies"] else 0
		sources += 1 if id in Data.BLOOM_KINDS else 0
		t.check(sources >= 1, "%s has somewhere to be found" % id)
	for tech in Data.TECHS:
		t.check(
			not Data.TECHS[tech].has("lesson") or Data.LESSONS.has(Data.TECHS[tech]["lesson"]),
			"%s names a real Lesson" % tech
		)
	for type in Data.BUILDINGS:
		t.check(
			not Data.BUILDINGS[type].has("lesson") or Data.LESSONS.has(Data.BUILDINGS[type]["lesson"]),
			"%s names a real Lesson" % type
		)
	for id in Data.RECIPES:
		t.check(
			not Data.RECIPES[id].has("lesson") or Data.LESSONS.has(Data.RECIPES[id]["lesson"]),
			"%s names a real Lesson" % id
		)
	for id in Data.BONUSES:
		t.check(
			not Data.BONUSES[id].has("lesson") or Data.LESSONS.has(Data.BONUSES[id]["lesson"]),
			"%s names a real Lesson" % id
		)
	var waiting := Data.LESSON_ORDER.filter(func(id): return not Data.LESSONS[id]["live"])
	t.check(waiting == ["lamp_core", "heat_plate", "sap"], "three Lessons wait for stage 3: %s" % [waiting])
	t.check(Rules.tech_enabled("teardown"), "the Teardown tech is built")
	t.check("teardown_bench" in Data.BUILD_TABS["Lore"], "the Bench is on the Lore tab")
	t.check(Data.BUILDINGS["teardown_bench"]["cost"].keys() == ["iron", "brick"], "and costs iron and brick")
	t.check(Data.ITEMS.has("iron_gears") and not "iron_gears" in Data.ITEM_ORDER, "Iron Gears are no top-bar counter")
	t.check(Data.BLOOM_SAMPLING_PLACEHOLDER, "the placeholder flag for Bloom Sampling is set until stage 3")
	t.check("bloom" in Data.TARGET_ORDER and Data.TARGETS.has("bloom"), "a Bloom patch is an expedition target")


# --- The Bench ----------------------------------------------------------------


func test_the_bench_opens_a_part() -> void:
	var fresh: Sim = t.fresh()
	t.give(fresh, 400)
	t.check(
		fresh.town.placement_error("teardown_bench", fresh.world.camp_pos + Vector2i(1, 0)).begins_with("Not disc"),
		"no Bench before Teardown"
	)
	var s := town()
	var b := bench(s)
	t.check(Data.BUILDINGS[b["type"]]["kind"] == "bench" and not s.town.needs_worker(b), "a Bench needs no worker")
	t.check(
		s.town.placement_error("teardown_bench", s.world.camp_pos + Vector2i(0, -2)).contains("Only one"),
		"only one stands"
	)
	t.check(Roads.linked(s, b), "it is linked beside the Hearth, so haulers serve it")
	s.teardown.add_part("hull_gear")
	t.check(s.teardown.lesson_state("hull_gear") == "found", "a part in the pack makes its Lesson found")
	t.check(s.teardown.deliver("hull_gear") and s.teardown.pack.is_empty(), "set on the Bench, it leaves the pack")
	t.check(s.teardown.holds("hull_gear") and s.teardown.lesson_state("hull_gear") == "found", "the Bench holds it")
	t.check(not s.teardown.knows("hull_gear"), "nothing is learned yet")
	for i in 20:
		s.teardown.tick(1.0)
	t.check(not s.teardown.knows("hull_gear") and s.teardown.seconds_left() == 20.0, "20 s in, 20 s to go")
	t.check(
		b["status"].contains("Hull Gear") and b["status"].contains("20"),
		"the Bench says what it is doing: " + b["status"]
	)
	var iron: int = s.economy.inv["iron"]
	for i in 20:
		s.teardown.tick(1.0)
	t.check(
		s.teardown.knows("hull_gear") and s.teardown.lesson_state("hull_gear") == "learned",
		"40 s later the Lesson is learned"
	)
	t.check(s.teardown.bench.is_empty() and s.teardown.pack.is_empty(), "and the part is consumed")
	t.check(s.economy.inv["iron"] == iron, "a first copy gives no scrap")
	t.check(s.events.any(func(e): return e.contains("Iron Gears")), "the Kith say what they learned")
	t.check(s.story.has_event("teardown_lesson"), "the first Lesson is a story moment")
	t.check(b["status"] == Data.BENCH_WAITING, "the Bench waits again")
	t.check(s.teardown.lessons == ["hull_gear"], "one Lesson, once")


func test_a_second_copy_gives_scrap() -> void:
	var s := town()
	bench(s)
	s.teardown.add_part("lamp_core")
	s.teardown.add_part("lamp_core")
	s.teardown.deliver("lamp_core")
	s.teardown.deliver("lamp_core")
	var iron: int = s.economy.inv["iron"]
	for i in 40:
		s.teardown.tick(1.0)
	t.check(s.teardown.lessons == ["lamp_core"], "the first copy teaches")
	t.check(s.teardown.scrapping(), "the second is only scrap now")
	t.check(s.teardown.duration() == Data.SCRAP_SECONDS, "and strips quicker than it opens")
	for i in int(Data.SCRAP_SECONDS):
		s.teardown.tick(1.0)
	t.check(s.teardown.lessons == ["lamp_core"], "no second Lesson")
	t.check(s.economy.inv["iron"] == iron + Data.SCRAP_IRON, "a little Iron instead (%d)" % Data.SCRAP_IRON)
	t.check(s.events.any(func(e): return e.contains("teaches nothing new")), "the Kith say so")
	t.check(s.teardown.bench.is_empty(), "the Bench is empty")
	s.teardown.add_part("lamp_core")
	t.check(
		TeardownPanel.card_text(s, "lamp_core") == Data.PART_CARD_KNOWN % "Lamp Core",
		"the card of a known part says scrap"
	)
	s.teardown.add_part("sap")
	t.check(
		TeardownPanel.card_text(s, "sap") == Data.PART_CARD % ["Sap Sample", "Sap", "Lantern Parties"],
		"a part's card names its Lesson before it is opened"
	)


func test_the_queue_is_short_and_a_torn_down_bench_keeps_its_parts() -> void:
	var s := town()
	var b := bench(s)
	for id in ["lamp_core", "heat_plate", "hull_gear", "seed_pod"]:
		s.teardown.add_part(id)
	var put := 0
	for id in ["lamp_core", "heat_plate", "hull_gear", "seed_pod"]:
		put += 1 if s.teardown.deliver(id) else 0
	t.check(put == Data.BENCH_SLOTS and s.teardown.pack == ["seed_pod"], "only %d fit on the Bench" % Data.BENCH_SLOTS)
	t.check(s.teardown.next_to_carry([]) == "", "and haulers carry nothing more to a full Bench")
	s.teardown.tick(10.0)
	t.check(s.teardown.bench == ["lamp_core", "heat_plate", "hull_gear"], "they open in the order they came")
	t.check(s.demolish(b["pos"]).size() > 0, "the Bench is torn down")
	s.teardown.tick(0.5)
	t.check(s.teardown.bench.is_empty() and s.teardown.pack.size() == 4, "its parts go back to the pack, none lost")
	t.check(s.teardown.progress == 0.0, "and the work starts over")
	t.check(
		s.teardown.prioritize("hull_gear") and s.teardown.pack[0] == "hull_gear", "a click moves a part to the front"
	)
	t.check(not s.teardown.prioritize("sap"), "a part that is not there cannot")
	t.check(s.teardown.next_to_carry([]) == "", "with no Bench, nothing is carried")


func test_haulers_carry_parts_to_the_bench() -> void:
	var s := town()
	var b := bench(s)
	s.people.found(5)
	for id in ["lamp_core", "heat_plate", "hull_gear", "seed_pod"]:
		s.teardown.add_part(id)
	s.teardown.prioritize("seed_pod")
	t.check(s.teardown.next_to_carry([]) == "seed_pod", "the clicked part is carried first")
	run_until(s, 30.0, func(): return s.teardown.bench.size() == Data.BENCH_SLOTS)
	t.check(s.teardown.bench.size() == Data.BENCH_SLOTS, "haulers fill the short queue (%s)" % [s.teardown.bench])
	t.check(s.teardown.bench[0] == "seed_pod", "the clicked part is first on the Bench")
	t.check(s.teardown.pack.size() == 1, "one part waits in the pack")
	run_until(s, Data.BENCH_SECONDS + 20.0, func(): return s.teardown.knows("seed_pod"))
	t.check(s.teardown.knows("seed_pod"), "the Bench opens it by itself")
	run_until(s, 60.0, func(): return s.teardown.pack.is_empty())
	t.check(s.teardown.pack.is_empty(), "and the last part is carried once there is room")
	t.check(b["status"] != "", "the Bench has a status")
	# a hauler that loses its road does not lose the part
	var lost := town()
	bench(lost)
	lost.teardown.add_part("sap")
	var k: Dictionary = lost.people.kith[0]
	k["task"] = {
		"kind": "part", "building": lost.teardown.bench_building(), "part": "sap", "depot": lost.world.camp_pos
	}
	lost.people.drop_task(k)
	t.check(lost.teardown.pack == ["sap"] and k["task"].is_empty(), "a dropped hauler task leaves the part in the pack")
	var carried := Sim.new()
	carried.generate(3)
	carried.teardown.add_part("sap")
	t.check(carried.teardown.next_to_carry([]) == "", "no Bench, no carrying")


# --- Where parts come from ----------------------------------------------------


func test_the_wreck_holds_three_parts() -> void:
	var s := town("enemies")
	t.check(Finds.wreck_has_parts(s), "the Wreck holds parts")
	var first := trip(s, "wreck", "light")
	t.check(s.teardown.pack == ["heat_plate"], "the first trip brings the Heat plate (%s)" % [s.teardown.pack])
	t.check(first.any(func(e): return e.contains("Heat Plate")), "and the log says so")
	trip(s, "wreck", "light")
	t.check(s.teardown.pack == ["heat_plate", "lamp_core"], "then the Lamp core")
	trip(s, "wreck", "light")
	t.check(s.teardown.pack == ["heat_plate", "lamp_core", "hull_gear"], "then the Hull gear")
	t.check(s.teardown.wreck_taken.size() == 3 and not Finds.wreck_has_parts(s), "the Wreck is bare")
	trip(s, "wreck", "light")
	t.check(s.teardown.pack.size() == 3, "a fourth trip brings no part")
	t.check(s.teardown.lesson_state("heat_plate") == "found", "the Heat plate's Lesson is found")
	# the Boiler and the Lamp path: the two Lessons are reachable with no help from the Lumen
	bench(s)
	for id in s.teardown.pack.duplicate():
		s.teardown.deliver(id)
	for i in int(Data.BENCH_SECONDS * 3.0 + 5.0):
		s.teardown.tick(1.0)
	t.check(
		s.teardown.knows("heat_plate") and s.teardown.knows("lamp_core") and s.teardown.knows("hull_gear"),
		"the Wreck alone teaches three Lessons"
	)
	# marks and parts both used up: the Post says there is nothing more
	for n in [2, 3, 4, 5, 6]:
		s.starfall.locked[Data.GLYPH_SETS[n]["id"]] = true
	s.starfall.wreck_found = true
	s.starfall.orders["target"] = "wreck"
	t.check(Expedition.plan(s)["why"] == Data.POST_NO_TARGET, "nothing more to find at the Wreck")
	# it waits for Teardown
	var early := town("enemies")
	early.tech_tree.researched.erase("teardown")
	trip(early, "wreck", "light")
	t.check(
		early.teardown.pack.is_empty() and early.teardown.wreck_taken.is_empty(), "no part comes home before Teardown"
	)
	# a heavy pack brings two, a late one half
	var heavy := town("enemies")
	trip(heavy, "wreck", "heavy")
	t.check(heavy.teardown.pack.size() == 2, "a heavy pack brings two parts")
	var late := town("enemies")
	late.starfall.orders = {"target": "wreck", "pack": "heavy", "keep": false}
	Expedition.send(late)
	for k in late.people.kith:
		if Expedition.is_party(k):
			k["timer"] = Data.DAYLIGHT_SECONDS + 1.0
	run_until(late, 1500.0, func(): return back(late))
	t.check(late.teardown.pack.size() == 1, "a late party brings half")
	# a copy the Lumen already handed over comes last
	var dup := town("allies")
	dup.teardown.add_part("heat_plate")
	trip(dup, "wreck", "standard")
	t.check(
		dup.teardown.pack == ["heat_plate", "lamp_core"],
		"the Wreck gives what the town lacks first (%s)" % [dup.teardown.pack]
	)


func test_the_lumen_camp_hands_over_parts_by_lean() -> void:
	var expected := {
		"enemies": [],
		"neighbours": ["lamp_core", "seed_pod"],
		"allies": ["lamp_core", "seed_pod", "water_glass", "heat_plate"]
	}
	for lean in expected:
		var s := town(lean)
		s.town.add_building("lumen_camp", _h._spot(s, "lumen_camp"))
		for i in 300:
			Finds.camp_tick(s, 1.0)
		t.check(
			s.teardown.pack == expected[lean],
			"%s: the Camp hands over %s (%s)" % [lean, expected[lean], s.teardown.pack]
		)
	var s := town("allies")
	t.check(Finds.camp_offer(s).size() == 4, "the offer is read off the lean")
	for i in 300:
		Finds.camp_tick(s, 1.0)
	t.check(s.teardown.pack.is_empty(), "with no Lumen Camp, nothing is handed over")
	s.town.add_building("lumen_camp", _h._spot(s, "lumen_camp"))
	for i in int(Data.CAMP_GIVE_SECONDS) - 1:
		Finds.camp_tick(s, 1.0)
	t.check(s.teardown.pack.is_empty(), "one part at a time: not yet")
	Finds.camp_tick(s, 1.0)
	t.check(s.teardown.pack == ["lamp_core"], "the first after %d s" % int(Data.CAMP_GIVE_SECONDS))
	t.check(
		s.events.any(func(e): return e.contains("Lamp Core") and e.contains(Data.LEAD_NAME)),
		"and the log says who gave it"
	)
	var early := town("allies")
	early.tech_tree.researched.erase("teardown")
	early.town.add_building("lumen_camp", _h._spot(early, "lumen_camp"))
	for i in 300:
		Finds.camp_tick(early, 1.0)
	t.check(early.teardown.pack.is_empty(), "the Lumen wait for Teardown")
	var wary := town("neighbours")
	wary.starfall.lean = ""
	wary.town.add_building("lumen_camp", _h._spot(wary, "lumen_camp"))
	for i in 300:
		Finds.camp_tick(wary, 1.0)
	t.check(wary.teardown.pack.is_empty(), "and the Starfall must have ended on a lean")


# --- The Bloom patches --------------------------------------------------------


func test_the_bloom_patches_are_fair() -> void:
	var worst_trip := 0.0
	var bad := 0
	for map_seed in IronfallTests.SEEDS:
		var s := Sim.new()
		s.generate(map_seed)
		s.tech_tree.researched["bronze_dawn"] = true
		s.tech_tree.researched["coal_seams"] = true
		Land.grow_if_due(s)
		var patches := Finds.patches(s)
		t.check(patches.size() == 3, "map %d: three Bloom patches (%d)" % [map_seed, patches.size()])
		var kinds: Array = patches.map(func(p): return p["kind"])
		t.check(kinds == Data.BLOOM_KINDS, "map %d: a sample of each kind, west to east" % map_seed)
		var xs: Array = patches.map(func(p): return p["pos"].x)
		t.check(xs[0] < xs[1] and xs[1] < xs[2], "map %d: spore, root, sap from the west" % map_seed)
		for patch in patches:
			var p: Vector2i = patch["pos"]
			t.check(
				p.y >= s.world.height - MapSouth.BLOOM_ROWS,
				"map %d: the %s patch lies at the far edge" % [map_seed, patch["kind"]]
			)
			var ground := 0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					ground += 1 if s.world.tile_at(p + Vector2i(dx, dy)) == Data.BLOOM_GROUND else 0
			t.check(
				ground + 1 >= MapSouth.BLOOM_GROUND_MIN,
				"map %d: the %s patch is a few tiles wide (%d)" % [map_seed, patch["kind"], ground + 1]
			)
			t.check(not s.fog.is_revealed(p), "map %d: the %s patch is under fog" % [map_seed, patch["kind"]])
			var goal := Scouting.goal(s, p)
			var secs: float = s.people.round_trip(s.world.camp_pos, goal)
			if secs < 0.0:
				bad += 1
			worst_trip = maxf(worst_trip, secs)
		t.check(Finds.nearest_patch(s).x >= 0, "map %d: there is a nearest patch" % map_seed)
		var fresh := World.new()
		fresh.generate(map_seed)
		fresh.grow_east()
		var report := {}
		MapSouth.make(fresh, report)
		t.check(
			report["faults"].is_empty(),
			"map %d: the south is still fair with its patches (%s)" % [map_seed, report["faults"]]
		)
	t.check(bad == 0, "every patch can be walked to (%d cannot)" % bad)
	print("Bloom patches: %d seeds, longest trip there and back %.0f s" % [IronfallTests.SEEDS.size(), worst_trip])
	var stone := World.new()
	stone.generate(7)
	t.check(stone.tiles.all(func(tile): return not tile.begins_with("bloom")), "the stone age map has no Bloom")
	stone.grow_east()
	t.check(stone.tiles.all(func(tile): return not tile.begins_with("bloom")), "nor has Bronze Dawn's")


func test_a_party_brings_a_sample_home() -> void:
	var s := town("enemies")
	var before := Finds.patches(s)
	t.check(Finds.bloom_problem(s) == "", "a party may go to a Bloom patch")
	var plan_target := Finds.nearest_patch(s)
	var told := trip(s, "bloom")
	var kind: String = before[0]["kind"]
	for patch in before:
		if patch["pos"] == plan_target:
			kind = patch["kind"]
	t.check(s.teardown.pack == [kind], "the sample is in the pack (%s)" % [s.teardown.pack])
	t.check(s.teardown.sampled == [kind], "and noted")
	t.check(s.world.tile_at(plan_target) == Data.BLOOM_GROUND, "the sample tile is plain Bloom ground now")
	t.check(Finds.patches(s).size() == 2, "two samples are left")
	t.check(told.any(func(e): return e.contains("Bloom patch")), "the log says what came home")
	t.check(s.fog.is_revealed(plan_target), "the party saw the patch")
	trip(s, "bloom")
	trip(s, "bloom")
	t.check(s.teardown.pack.size() == 3 and s.teardown.sampled.size() == 3, "all three samples come home")
	var got: Array = s.teardown.pack.duplicate()
	got.sort()
	t.check(got == ["root", "sap", "spore"], "one of each kind")
	s.starfall.orders["target"] = "bloom"
	t.check(Expedition.plan(s)["why"] == Data.BLOOM_NONE_LEFT, "and no patch is left to sample")
	t.check(not Finds.patches(s).any(func(p): return true), "the patches list is empty")
	t.check(s.fog.is_revealed(plan_target), "still seen")
	for id in got:
		t.check(Data.LESSONS[id]["live"] or id == "sap", "%s is a Lesson" % id)


func test_sampling_waits_for_the_placeholder_or_the_tech() -> void:
	var s := town("enemies")
	t.check(Finds.sampling_open(s), "the placeholder flag opens sampling in stage 2")
	t.check(not Finds.sampling_open(s, false), "without it, the tech decides: closed")
	s.tech_tree.researched["bloom_sampling"] = true
	t.check(Finds.sampling_open(s, false), "and open once Bloom Sampling is learned")
	var raw := Sim.new()
	raw.generate(4)
	t.check(Finds.bloom_problem(raw) == Data.BLOOM_NO_TEARDOWN, "the Kith will not touch it without Teardown")
	raw.tech_tree.researched["teardown"] = true
	raw.story.record(Data.IRONFALL_EVENT)
	t.check(Finds.bloom_problem(raw) == Data.BLOOM_NO_LAND, "nor can they reach a land that is closed")
	var pick := ExpeditionPicker.new()
	pick.setup(raw)
	raw.story.events.erase(Data.IRONFALL_EVENT)
	pick._next_target()
	pick._next_target()
	t.check(raw.starfall.orders["target"] == "wreck", "the picker offers two targets before Ironfall (wreck, fog)")
	raw.story.record(Data.IRONFALL_EVENT)
	raw.starfall.orders["target"] = "fog"
	pick._next_target()
	t.check(raw.starfall.orders["target"] == "bloom", "and a Bloom patch once the Kith can open what they find")
	pick.free()
	var take := town("enemies")
	take.tech_tree.researched.erase("bloom_sampling")
	t.check(Finds.take_sample(take, Vector2i(0, 0)) == "", "no sample lies by the Hearth")


# --- What the Lessons do ------------------------------------------------------


func test_iron_gears() -> void:
	var s := town()
	t.check(not Hands.recipe_unlocked(s, "iron_gears"), "no Iron Gears before the Hull gear Lesson")
	t.check(not Hands.craft(s, "iron_gears"), "and none can be made")
	s.teardown.lessons.append("hull_gear")
	t.check(Hands.recipe_unlocked(s, "iron_gears"), "the Lesson opens the recipe")
	var iron: int = s.economy.inv["iron"]
	t.check(Hands.craft(s, "iron_gears") and s.economy.inv["iron_gears"] == 1, "two Iron make a gear by hand")
	t.check(s.economy.inv["iron"] == iron - 2, "it costs two Iron")
	var post: Vector2i = _h._spot(s, "twine_post")
	t.check(t.place_free(s, "twine_post", post), "a workshop")
	var w: Dictionary = s.town.buildings[s.town.building_at[post]]
	var plain := Bonuses.speed(s, w)
	w["inbuf"]["iron_gears"] = 1
	t.check(
		is_equal_approx(Bonuses.speed(s, w), plain + 0.25),
		"a fitted gear speeds it up 25%% (%.2f to %.2f)" % [plain, Bonuses.speed(s, w)]
	)
	w["inbuf"]["iron_gears"] = 0
	t.check(is_equal_approx(Bonuses.speed(s, w), plain), "none, no bonus")
	t.check(Haulers._stock_wanted(s, w).get("iron_gears", 0) == 1, "haulers fit one gear to a workshop")
	s.teardown.lessons.erase("hull_gear")
	t.check(not Haulers._stock_wanted(s, w).has("iron_gears"), "but only once the Lesson is learned")
	w["inbuf"]["iron_gears"] = 1
	t.check(is_equal_approx(Bonuses.speed(s, w), plain), "and a gear does nothing before it")
	t.check(gears_are_described(), "the speed-up is in the workshop card")


func gears_are_described() -> bool:
	return Data.BONUSES["iron_gears"]["name"] == "Iron Gears" and Data.ITEMS["iron_gears"]["desc"].contains("25%")


func test_the_rain_barrel_and_smoke_starfruit() -> void:
	var s := town()
	var spot: Vector2i = _h._spot(s, "rain_barrel")
	t.check(not CardText.shown(s, "rain_barrel"), "no Rain Barrel card before the Water glass Lesson")
	t.check(s.town.placement_error("rain_barrel", spot) == "Not discovered yet", "and it cannot be placed")
	s.teardown.lessons.append("water_glass")
	t.check(
		CardText.shown(s, "rain_barrel") and s.town.placement_error("rain_barrel", spot) == "", "the Lesson opens it"
	)
	var field := spot + Vector2i(0, 4)
	for dx in range(-3, 4):
		s.world.set_tile(field + Vector2i(dx, 0), "grass")
	s.world.add_field(field)
	var plain := Patch.field_share(s, field)
	t.check(t.place_free(s, "rain_barrel", spot), "a Rain Barrel goes up")
	t.check(
		(
			is_equal_approx(Patch.field_share(s, field), plain + Data.RAIN_BARREL_FIELD)
			or Vector2(spot).distance_to(Vector2(field)) > Data.RAIN_BARREL_RADIUS
		),
		"Fields in reach pay 20% more"
	)
	var near := spot + Vector2i(2, 1)
	s.world.add_field(near)
	t.check(
		is_equal_approx(Patch.field_share(s, near), plain + 0.2),
		"a Field within %d tiles pays 20%% more" % int(Data.RAIN_BARREL_RADIUS)
	)
	var far := spot + Vector2i(0, 8)
	s.world.set_tile(far, "grass")
	s.world.add_field(far)
	t.check(is_equal_approx(Patch.field_share(s, far), plain), "a Field further off does not")
	s.teardown.lessons.erase("water_glass")
	t.check(is_equal_approx(Patch.field_share(s, near), plain), "and without the Lesson none does")
	# Starfruit ripens in coal smoke too
	var hut: Vector2i = _h._spot(s, "gatherers_hut")
	s.town.add_building("gatherers_hut", hut)
	var h: Dictionary = s.town.buildings[s.town.building_at[hut]]
	var base := Bonuses.building_yield(s, h, "berries")
	s.starfall.locked["growth"] = true
	s.teardown.lessons.append("seed_pod")
	t.check(is_equal_approx(Bonuses.building_yield(s, h, "berries"), base), "no smoke, no extra yield")
	var smoke := hut + Vector2i(2, 0)
	if s.town.building_at.has(smoke):
		smoke = hut + Vector2i(-2, 0)
	s.town.add_building("bloomery", smoke)
	t.check(
		is_equal_approx(Bonuses.building_yield(s, h, "berries"), base + 0.5), "berries near a Bloomery yield 50%% more"
	)
	s.teardown.lessons.erase("seed_pod")
	t.check(is_equal_approx(Bonuses.building_yield(s, h, "berries"), base), "but not without the Seed pod Lesson")
	s.teardown.lessons.append("seed_pod")
	s.starfall.locked.erase("growth")
	t.check(
		is_equal_approx(Bonuses.building_yield(s, h, "berries"), base), "nor before the Starfall's growth gift is read"
	)


func test_lessons_that_wait_for_stage_three() -> void:
	var s := town()
	for id in ["lamp_core", "heat_plate", "sap"]:
		s.teardown.lessons.append(id)
		t.check(s.teardown.lesson_state(id) == "learned", "%s is learned and kept" % id)
		t.check(
			LessonsList.state_text(s, id).begins_with("Learned. It will be used once"),
			"%s says its use comes later" % id
		)
	t.check(
		Data.TECHS["shard_lamps"]["lesson"] == "lamp_core" and Data.TECHS["shard_boiler"]["lesson"] == "heat_plate",
		"the techs name them"
	)
	t.check(
		not Rules.tech_enabled("shard_lamps") and not Rules.tech_enabled("shard_boiler"),
		"and stay unbuilt until stage 3"
	)
	t.check(not Data.BUILDINGS.has("shard_lamp") and not Data.BUILDINGS.has("shard_boiler"), "no building is on offer")


func test_the_bloom_overlays() -> void:
	var s := town()
	var centres := Lessons.bloom_centres(s)
	t.check(
		centres.size() == 3 or centres.size() == 4,
		"three patches, and the first sign when there is one (%d)" % centres.size()
	)
	s.starfall.bloom = Vector2i(5, 5)
	t.check(
		Lessons.bloom_centres(s).size() == 4 and Lessons.bloom_centres(s)[0] == Vector2i(5, 5), "the first sign leads"
	)
	var rock := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if s.world.tile_at(Vector2i(x, y)) == "rock" and rock.x < 0:
				rock = Vector2i(x, y)
	t.check(Lessons.is_slow_ground(s, rock), "rock is slow ground for the Bloom")
	var road := s.world.camp_pos + Vector2i(1, 1)
	s.world.add_road(road)
	t.check(Lessons.is_slow_ground(s, road), "so is road")
	t.check(
		not Lessons.is_slow_ground(s, Vector2i(0, 0)) or s.world.tile_at(Vector2i(0, 0)) in Data.ROOT_LIT,
		"and open ground is not"
	)
	s.teardown.lessons.append("spore")
	s.teardown.lessons.append("root")
	var canvas := OverlayCanvas.new()
	canvas.sim = s
	t.root.add_child(canvas)
	canvas.notification(CanvasItem.NOTIFICATION_DRAW)  # as the engine would on a redraw
	canvas.free()
	t.check(s.teardown.knows("spore") and s.teardown.knows("root"), "the two Bloom Lessons draw without trouble")


# --- The Lessons list and the Bench's panel -------------------------------------


func test_the_lessons_list_and_the_bench_panel() -> void:
	var s := town()
	var b := bench(s)
	var list := LessonsList.new()
	list.setup(s)
	list.show_for(b)
	t.check(list.visible, "the Lessons list shows at the Bench")
	t.check(list.get_child_count() == 10, "a heading, eight Lessons and a hint (%d)" % list.get_child_count())
	t.check(
		LessonsList.state_text(s, "seed_pod") == Data.LESSON_LOCKED % Data.PARTS["seed_pod"]["from"],
		"a Lesson with no part is locked, and says where its part is"
	)
	s.teardown.add_part("seed_pod")
	t.check(
		LessonsList.state_text(s, "seed_pod") == Data.LESSON_FOUND % "Seed Pod", "with a part in the pack it is found"
	)
	s.teardown.lessons.append("seed_pod")
	t.check(
		LessonsList.state_text(s, "seed_pod") == Data.LESSONS["seed_pod"]["note"], "and learned, it says what it gave"
	)
	t.check(LessonsList.state_color(s, "seed_pod") != LessonsList.state_color(s, "sap"), "in a colour of its own")
	list.show_for(b)
	t.check(list.get_child_count() == 10, "it is built again when a Lesson changes")
	var wall: Vector2i = _h._spot(s, "glyph_wall")
	s.town.add_building("glyph_wall", wall)
	list.show_for(s.town.buildings[s.town.building_at[wall]])
	t.check(list.visible, "and beside the Glyph Wall's marks")
	list.show_for(s.town.buildings[s.town.building_at[s.world.camp_pos]])
	t.check(not list.visible, "but not at the Hearth")
	s.tech_tree.researched.erase("teardown")
	list.show_for(b)
	t.check(not list.visible, "and not before Teardown")
	s.tech_tree.researched["teardown"] = true
	var panel := TeardownPanel.new()
	panel.setup(s)
	panel.show_for(b)
	t.check(panel.visible, "the Bench has its panel")
	var cards := 0
	for c in panel.find_children("*", "Button", true, false):
		cards += 1 if c.text.contains("holds the") or c.text.contains("scrap") else 0
	t.check(cards >= 1, "each part in the pack is a card naming its Lesson")
	s.teardown.add_part("spore")
	s.teardown.prioritize("spore")
	panel.show_for(b)
	var first := ""
	for c in panel.find_children("*", "Button", true, false):
		if c.text.contains("holds the") and first == "":
			first = c.text
	t.check(
		first.contains("Spore Sample") and first.contains("what the Bloom eats"),
		"the first card is the clicked part: " + first
	)
	panel._carry("spore")
	t.check(s.teardown.bench == ["spore"], "the carry button sets it on the Bench by hand")
	panel.show_for(s.town.buildings[s.town.building_at[s.world.camp_pos]])
	t.check(not panel.visible, "and the panel hides elsewhere")
	var info := BuildingPanel.new()
	info.setup(s)
	info.select(b["pos"])
	t.check(
		info.visible and info.parts["bench"].visible and info.parts["lessons"].visible, "the building card shows both"
	)
	info.select(wall)
	t.check(not info.parts["bench"].visible and info.parts["lessons"].visible, "at the Wall only the list")
	for node in [list, panel, info]:
		node.free()


func test_the_goals_and_the_story() -> void:
	var s := town()
	s.tech_tree.researched.erase("teardown")
	s.story.update(s)
	t.check(s.story.goal_list() == Data.GOALS_ERA4 and Data.GOALS_ERA4.size() == 12, "the era has twelve goals")
	t.check(not s.story.goals_done.has("teardown") and not s.story.goals_done.has("bench"), "the Teardown goals wait")
	s.tech_tree.researched["teardown"] = true
	bench(s)
	s.story.update(s)
	t.check(
		s.story.goals_done.has("teardown") and s.story.goals_done.has("bench"), "Teardown and the Bench tick theirs"
	)
	t.check(not s.story.goals_done.has("first_teardown"), "no Lesson yet")
	s.teardown.add_part("hull_gear")
	s.teardown.deliver("hull_gear")
	for i in 45:
		s.teardown.tick(1.0)
	s.story.update(s)
	t.check(s.story.goals_done.has("first_teardown"), "the first Lesson ticks the last")
	t.check(Data.STORY_EVENTS.has("teardown_lesson"), "and is a story moment")


# --- The save -----------------------------------------------------------------


func test_teardown_saves_and_loads() -> void:
	var s := town("allies")
	bench(s)
	s.teardown.pack = ["sap", "root"]
	s.teardown.bench = ["lamp_core", "spore"]
	s.teardown.progress = 12.5
	s.teardown.lessons = ["hull_gear", "seed_pod"]
	s.teardown.wreck_taken = ["heat_plate"]
	s.teardown.gifts = 2
	s.teardown.gift_clock = 17.25
	s.teardown.sampled = ["spore"]
	s.world.set_tile(Finds.nearest_patch(s), Data.BLOOM_GROUND)
	var text := RunSave.to_json(RunSave.dump(s))
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, RunSave.from_json(text)), "a game with parts loads")
	for key in ["pack", "bench", "lessons", "wreck_taken", "sampled"]:
		t.check(loaded.teardown.get(key) == s.teardown.get(key), "%s is as it was" % key)
	t.check(
		loaded.teardown.progress == 12.5 and loaded.teardown.gifts == 2 and loaded.teardown.gift_clock == 17.25,
		"and the clocks"
	)
	t.check(loaded.world.tiles == s.world.tiles, "the sampled ground is as it was")
	t.check(RunSave.to_json(RunSave.dump(loaded)) == text, "a reload saves the same text")
	t.check(
		loaded.teardown.knows("hull_gear") and Hands.recipe_unlocked(loaded, "iron_gears"),
		"a Lesson still works after a load"
	)
	var d := RunSave.dump(s)
	d["game"]["teardown"] = {"pack": ["sap", "not_a_part"], "lessons": ["nonsense"], "gifts": 1}
	var odd := Sim.new()
	t.check(RunSave.restore(odd, d), "a save with a part this build does not know loads")
	t.check(odd.teardown.pack == ["sap"] and odd.teardown.lessons.is_empty(), "and drops it")
	d["game"].erase("teardown")
	var old := Sim.new()
	t.check(RunSave.restore(old, d), "a save from before Teardown loads")
	t.check(old.teardown.pack.is_empty() and old.teardown.lessons.is_empty(), "with nothing in the block")
	t.check(Data.IRONFALL_EVENT in old.story.events, "and the era it was in")
