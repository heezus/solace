extends RefCounted
## Livewire stage 2, the tide (design-system/23-livewire.md): the Bloom's creep out of the south patches, the buildings it eats,
## Arc Lamps, Firebreaks, the Scorcher, Tide Watch, Living Ground, Powered Mines, the saves, and the edge cases a review found in
## stage 1's power and orders. Run from tests/livewire_tests.gd, which owns the helpers (town, meadow, put...).

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Power = preload("res://scripts/power.gd")
const Work = preload("res://scripts/work.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Lessons = preload("res://scripts/lessons.gd")
const Tide = preload("res://scripts/tide.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")

var t  # the runner, tests/run_tests.gd
var base  # the Livewire tests, for their helpers


func run(runner, helpers) -> void:
	t = runner
	base = helpers
	test_the_data_is_whole()
	test_the_tide_begins_with_livewire()
	test_it_spreads_at_the_set_pace()
	test_what_slows_it()
	test_the_hearth_is_never_taken()
	test_the_ground_changes_under_the_bloom()
	test_buildings_are_overgrown_then_lost()
	test_an_arc_lamp_holds_it_off()
	test_a_scorcher_burns_it_clear()
	test_tide_watch_says_when()
	test_living_ground_and_powered_mines()
	test_the_tide_saves_and_loads()
	test_edge_cases_from_the_review()


# --- Helpers -------------------------------------------------------------------


func town() -> Sim:
	var s: Sim = base.town()
	s.story.record(Data.LIVEWIRE_BEGUN)
	return s


## A town with the tide begun and no front yet, on a meadow (so tests place the front where they want it).
func quiet() -> Sim:
	var s := town()
	s.tide.begin(s)
	s.tide.front.clear()
	return s


func tick_for(s: Sim, seconds: float, step := 0.5) -> void:
	base.tick_for(s, seconds, step)


func put(s: Sim, type: String, p: Vector2i) -> Dictionary:
	return base.put(s, type, p)


## Join the front now: the tile is taken on the next tick.
func take(s: Sim, p: Vector2i) -> void:
	s.tide.front[p] = s.tide.time


## A pole with a lit Generator beside it, and the net worked out: returns the Generator.
func powered(s: Sim, c: Vector2i) -> Dictionary:
	put(s, "power_pole", c)
	var gen := put(s, "generator", c + Vector2i(0, 2))
	gen["burn"] = 9999.0
	gen["inbuf"] = {"coal": 5}
	s.livewire.tick(s, 0.0)
	return gen


# --- The data ------------------------------------------------------------------


func test_the_data_is_whole() -> void:
	for id in ["arc_lamp", "scorcher", "firebreak"]:
		t.check(Data.BUILDINGS.has(id) and id in Data.BUILD_ORDER, "%s is a building" % id)
	t.check("arc_lamp" in Data.BUILD_TABS["Lore"] and "scorcher" in Data.BUILD_TABS["Workshops"], "in their tabs")
	t.check("firebreak" in Data.BUILD_TABS["Logistics"], "a Firebreak is in Logistics")
	t.check(
		Data.BUILDINGS["scorcher"]["fed"] and Data.BUILDINGS["scorcher"]["in"] == {"coal": 1}, "a Scorcher burns Coal"
	)
	t.check(
		Data.BUILDINGS["arc_lamp"]["light"] == 5 and Data.BUILDINGS["scorcher"]["reach"] == 4,
		"5 tiles of light, 4 of fire"
	)
	t.check(Data.TILES.has(Data.TILE_BLOOM_TIDE) and not Data.TILES[Data.TILE_BLOOM_TIDE]["buildable"], "tide ground")
	t.check(Data.TIDE_STEP_SECONDS == 35.0 and Data.OVERGROWN_LOST_SECONDS == 180.0, "35 s a tile, 3 minutes to lose")
	for id in ["tide_watch", "arc_lamps", "scorcher", "firebreaks", "living_ground", "foremen", "powered_mines"]:
		t.check(Data.TECHS[id]["stage"] == 2, "%s is a stage 2 tech" % id)
	t.check("firebreak" in Data.BUILD_ORDER and "firebreak" in ["road", "firebreak"], "a Firebreak is laid by dragging")
	for id in Data.TIDE_KEEPS:
		t.check(Data.TILES.has(id), "%s is a tile" % id)


# --- The creep -----------------------------------------------------------------


func test_the_tide_begins_with_livewire() -> void:
	var early := Sim.new()
	early.generate(2)
	early.tick(1.0)
	t.check(not early.tide.begun and early.tide.grown.is_empty(), "before Livewire the tide does nothing")
	var s := town()
	t.check(not s.tide.begun, "it waits for a tick")
	s.tick(0.5)
	t.check(s.tide.begun and not s.tide.front.is_empty(), "it begins the tick after Livewire does")
	t.check(Data.TIDE_BEGAN_LINE in s.events, "and the feed says so")
	var patches := 0
	for p in s.tide.front:
		t.check(s.world.tile_at(p) not in s.tide.PATCH_TILES, "the front is beside a patch, not on it")
		patches += 1
	t.check(patches > 0 and s.tide.grown.is_empty(), "nothing is taken yet")
	t.check(s.tide.front_distance(s) == -1, "so no Bloom is near the Hearth")
	var late := town()
	late.tick(0.5)
	var n: int = late.tide.front.size()
	late.tide.begin(late)
	t.check(late.tide.begun and late.tide.front.size() == n, "beginning twice changes nothing")


func test_it_spreads_at_the_set_pace() -> void:
	var s := town()
	tick_for(s, 30.0)
	t.check(s.tide.grown.is_empty(), "no tile joins before a tile's time (30 s)")
	tick_for(s, 10.0)
	t.check(not s.tide.grown.is_empty(), "the first tiles join at about 35 s")
	for p in s.tide.grown:
		var next_to := false
		for d in Tide.SIDES:
			if s.tide.is_bloom(s, p + d) and (p + d) != p:
				next_to = true
		t.check(next_to, "every taken tile touches the Bloom")
	var count: int = s.tide.grown.size()
	tick_for(s, 70.0)
	t.check(s.tide.grown.size() > count, "and it keeps coming")
	var twin := town()
	tick_for(twin, 110.0)
	t.check(twin.tide.grown.keys() == s.tide.grown.keys(), "the same ground floods the same way (no chance in it)")


func test_what_slows_it() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	var open := c + Vector2i(5, 5)
	t.check(is_equal_approx(s.tide.cost(s, open), 35.0), "open ground: 35 s")
	var road := c + Vector2i(5, 6)
	s.world.add_road(road, 0)
	t.check(is_equal_approx(s.tide.cost(s, road), 105.0), "a road: 3 times as long")
	var rail := c + Vector2i(5, 7)
	s.world.add_road(rail, 3)
	t.check(is_equal_approx(s.tide.cost(s, rail), 210.0), "a rail: 6 times as long")
	var river := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if river.x < 0 and s.world.tile_at(Vector2i(x, y)) == "river":
				river = Vector2i(x, y)
	t.check(river.x >= 0 and is_equal_approx(s.tide.cost(s, river), 105.0), "a river tile: 3 times as long")
	var strip := put(s, "firebreak", c + Vector2i(5, 8))
	t.check(
		strip["type"] == "firebreak" and is_equal_approx(s.tide.cost(s, strip["pos"]), 350.0), "a Firebreak: 10 times"
	)
	var lamp := put(s, "shard_lamp", c + Vector2i(-5, -5))
	lamp["burn"] = 100.0
	t.check(is_equal_approx(s.tide.cost(s, c + Vector2i(-5, -4)), 70.0), "a burning Shard Lamp's light: twice as long")
	lamp["burn"] = 0.0
	t.check(is_equal_approx(s.tide.cost(s, c + Vector2i(-5, -4)), 35.0), "a cold one does nothing")


func test_the_hearth_is_never_taken() -> void:
	var s := quiet()
	var near: Vector2i = s.world.camp_pos + Vector2i(3, 0)
	take(s, near)
	var edge: Vector2i = s.world.camp_pos + Vector2i(6, 0)
	take(s, edge)
	var out: Vector2i = s.world.camp_pos + Vector2i(7, 0)
	take(s, out)
	s.tick(0.5)
	t.check(not s.tide.grown.has(near) and not s.tide.grown.has(edge), "no Bloom within 6 tiles of the Hearth")
	t.check(s.tide.grown.has(out), "7 tiles out it may")
	t.check(not s.tide.front.has(near) and not s.tide.front.has(edge), "and those tiles are not asked again")


func test_the_ground_changes_under_the_bloom() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	var tree := c + Vector2i(1, 1)
	s.world.set_tile(tree, "tree")
	var field := c + Vector2i(2, 1)
	s.world.add_field(field)
	var grass := c + Vector2i(3, 1)
	var road := c + Vector2i(4, 1)
	s.world.add_road(road, 0)
	var seam := c + Vector2i(5, 1)
	s.world.set_tile(seam, "coal_seam")
	for p in [tree, field, grass, road, seam]:
		take(s, p)
	s.tick(0.1)
	for p in [tree, field, grass]:
		t.check(s.world.tile_at(p) == Data.TILE_BLOOM_TIDE, "%s is Bloom ground now" % p)
	t.check(not s.world.fields.has(field), "a Field under it is gone")
	t.check(s.world.tile_at(road) == "grass" and s.world.roads.has(road), "a road stays a road")
	t.check(s.world.tile_at(seam) == "coal_seam", "ore stays ore")
	t.check(s.tide.grown.has(road) and s.tide.grown.has(seam), "though the Bloom has them")
	t.check(s.town.placement_error("forge", grass) == Data.TIDE_BUILD_ERROR, "nothing is built on it")
	t.check(s.town.placement_error("forge", c + Vector2i(-3, -3)) != Data.TIDE_BUILD_ERROR, "but beside it you can")


# --- What it eats --------------------------------------------------------------


func test_buildings_are_overgrown_then_lost() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	var forge := put(s, "forge", c)
	forge["inbuf"] = {"iron_ore": 5}
	var iron: int = s.economy.inv["iron_ore"]
	take(s, c)
	s.tick(0.5)
	t.check(s.tide.is_overgrown(forge), "a building the Bloom reaches is overgrown")
	s.tick(0.5)
	t.check(forge["status"].begins_with("Overgrown") and forge["alert"] == Data.OVERGROWN_ALERT, "and says so")
	var panel := BuildingPanel.recipe_text(s, forge)
	t.check(panel != "" and s.tide.note(s, forge).begins_with("Overgrown"), "its card too: %s" % s.tide.note(s, forge))
	t.check(not Power.asking(s, forge), "it asks nothing of a net")
	tick_for(s, 160.0)
	t.check(s.town.building_at.has(c) and s.tide.hit.has(c), "it stands for about 3 minutes")
	tick_for(s, 25.0)
	t.check(not s.town.building_at.has(c), "and is then lost")
	t.check(s.tide.lost == 1 and (Data.OVERGROWN_LOST_LINE % "Forge") in s.events, "with a line in the feed")
	t.check(s.economy.inv["iron_ore"] == iron, "what it held is lost with it")
	t.check(s.world.tile_at(c) == Data.TILE_BLOOM_TIDE, "and its ground is Bloom now")
	var hearth := s.world.camp_pos
	t.check(s.town.built_type(hearth) == "camp", "the Hearth stands")


func test_an_arc_lamp_holds_it_off() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	var gen := powered(s, c)
	var lamp := put(s, "arc_lamp", c + Vector2i(1, 0))
	s.tick(0.5)
	t.check(s.town.is_powered(lamp["pos"]) and lamp["status"] == Data.ARC_LIT % 5, "a powered Arc Lamp is lit")
	var lit := c + Vector2i(3, 1)
	take(s, lit)
	var far := c + Vector2i(1, 7)
	take(s, far)
	s.tick(0.5)
	t.check(not s.tide.grown.has(lit) and s.tide.front.has(lit), "the Bloom waits at its light")
	t.check(s.tide.grown.has(far), "and takes the dark beyond it")
	tick_for(s, 20.0)
	t.check(not s.tide.grown.has(lit), "as long as it stays lit")
	gen["burn"] = 0.0
	gen["inbuf"] = {}
	s.tick(0.5)
	t.check(not s.town.is_powered(lamp["pos"]) and lamp["status"] == Data.ARC_DARK, "a dark lamp says so")
	tick_for(s, 12.0)
	t.check(s.tide.grown.has(lit), "and the Bloom walks in")
	# an overgrown building in the light is not lost, and in the dark it is
	var held := quiet()
	var hc: Vector2i = base.meadow(held)
	var hgen := powered(held, hc)
	put(held, "arc_lamp", hc + Vector2i(1, 0))
	var mill := put(held, "grindstone", hc + Vector2i(-1, -1))
	held.tide.grown[mill["pos"]] = true
	held.tide.hit[mill["pos"]] = 170.0
	tick_for(held, 40.0)
	t.check(held.town.building_at.has(mill["pos"]) and held.tide.hit[mill["pos"]] == 170.0, "in the light it is held")
	t.check(held.tide.note(held, mill) == Data.OVERGROWN_HELD, "and its card says so")
	hgen["burn"] = 0.0
	hgen["inbuf"] = {}
	tick_for(held, 15.0)
	t.check(not held.town.building_at.has(mill["pos"]), "with the light out it is lost")


func test_a_scorcher_burns_it_clear() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	powered(s, c)
	var scorcher := put(s, "scorcher", c + Vector2i(1, 0))
	scorcher["inbuf"] = {"coal": 3}
	t.check(not s.tide.draws(scorcher), "with no Bloom in reach it draws nothing")
	var q := c + Vector2i(3, 1)
	s.tide.grown[q] = true
	s.world.set_tile(q, Data.TILE_BLOOM_TIDE)
	s.tide.rev += 1
	var far := c + Vector2i(1, 7)
	s.tide.grown[far] = true
	t.check(s.tide.scorch_target(scorcher) == q and s.tide.draws(scorcher), "it picks the nearest tile in reach")
	tick_for(s, 20.0)
	t.check(
		q in s.tide.grown and scorcher["status"].begins_with("Burning"), "a tile takes 30 s: %s" % scorcher["status"]
	)
	tick_for(s, 12.0)
	t.check(s.tide.burnt.has(q) and not s.tide.grown.has(q), "then it is burnt ground")
	t.check(
		s.world.tile_at(q) == "grass" and s.town.placement_error("forge", q) != Data.TIDE_BUILD_ERROR, "built on again"
	)
	t.check(s.tide.grown.has(far), "the tile out of reach stays")
	t.check(scorcher["inbuf"]["coal"] == 2, "for 1 Coal")
	t.check(
		s.tide.scorch_target(scorcher).x < 0 and scorcher["status"] == Data.SCORCHER_NOTHING, "and then nothing to burn"
	)
	# the tide never takes burnt ground back
	s.tide.front[q] = s.tide.time
	s.tick(0.5)
	t.check(not s.tide.grown.has(q), "burnt ground is never taken again")
	# no power, nothing
	var dark := quiet()
	var dc: Vector2i = base.meadow(dark)
	put(dark, "power_pole", dc)
	var cold := put(dark, "scorcher", dc + Vector2i(1, 0))
	cold["inbuf"] = {"coal": 3}
	dark.tide.grown[dc + Vector2i(3, 0)] = true
	tick_for(dark, 40.0)
	t.check(
		dark.tide.burnt.is_empty() and cold["status"].begins_with(Data.SCORCHER_NO_POWER),
		"with no power it burns nothing: %s" % cold["status"]
	)
	# a building on burnt ground works again
	var mill := put(s, "grindstone", c + Vector2i(-1, -1))
	s.tide.grown[mill["pos"]] = true
	s.tide.hit[mill["pos"]] = 50.0
	s.tide.clear(s, mill["pos"])
	t.check(not s.tide.is_overgrown(mill), "burnt clear, an overgrown building works again")


# --- Tide Watch ----------------------------------------------------------------


func test_tide_watch_says_when() -> void:
	var s := town()
	s.tick(0.5)
	var patch := Vector2i(-1, -1)
	for i in range(s.world.base_height * s.world.width, s.world.tiles.size()):
		if patch.x < 0 and s.world.tiles[i] in Tide.PATCH_TILES:
			patch = Vector2i(i % s.world.width, floori(float(i) / s.world.width))
	var spot := patch + Vector2i(0, -8)
	s.world.set_tile(spot, "grass")
	var forge := put(s, "forge", spot)
	tick_for(s, 20.0)
	t.check(s.tide.eta.is_empty(), "without Tide Watch nothing is worked out")
	t.check(s.tide.note(s, forge) == "", "and the card says nothing")
	s.tech_tree.researched["tide_watch"] = true
	tick_for(s, 5.0)
	t.check(s.tide.eta.has(spot), "with it, the Kith work out when the front arrives")
	var left: float = s.tide.eta[spot] - s.tide.time
	t.check(left > 120.0 and left < 400.0, "about 8 tiles on: %.0f s" % left)
	t.check(s.tide.note(s, forge).begins_with("Tide Watch: the Bloom reaches this in about"), s.tide.note(s, forge))
	var said := false
	tick_for(s, 150.0)
	for e in s.events:
		if str(e).begins_with("The Bloom reaches the Forge in about"):
			said = true
	t.check(said, "and once it is close the feed says so")
	var times := s.events.filter(func(e): return str(e).begins_with("The Bloom reaches the Forge")).size()
	tick_for(s, 20.0)
	t.check(
		s.events.filter(func(e): return str(e).begins_with("The Bloom reaches the Forge")).size() == times, "only once"
	)
	t.check(Tide.duration(45.0) == "45 s" and Tide.duration(240.0) == "4 min", "durations read in words")


func test_living_ground_and_powered_mines() -> void:
	var s := quiet()
	var c: Vector2i = base.meadow(s)
	t.check(s.tide.ash_share(s, c) == 0.0, "no bonus on plain ground")
	s.tide.burnt[c] = true
	t.check(s.tide.ash_share(s, c) == 0.0, "nor on burnt ground before Living Ground")
	s.tech_tree.researched["living_ground"] = true
	t.check(s.tide.ash_share(s, c) == Data.ASH_FIELD_BONUS, "a Field on burnt ground yields half as much again")
	t.check(s.tide.ash_share(s, c + Vector2i(1, 0)) == 0.0, "only on burnt ground")
	# Powered Mines: a Mine on a net that gives power digs twice as fast
	var m := quiet()
	var mc: Vector2i = base.meadow(m)
	var mine := put(m, "mine", mc + Vector2i(1, 0))
	var alone: float = Work.time(m, mine)
	powered(m, mc)
	m.livewire.tick(m, 0.0)
	t.check(is_equal_approx(Work.time(m, mine), alone), "without Powered Mines a Mine is as it was")
	m.tech_tree.researched["powered_mines"] = true
	m.livewire.tick(m, 0.0)
	t.check(m.livewire.net_at(mine["pos"]).size() > 0, "with it a Mine joins the net")
	t.check(is_equal_approx(Work.time(m, mine), alone / 2.0), "and digs twice as fast")
	var far := put(m, "mine", mc + Vector2i(7, 7))
	m.livewire.tick(m, 0.0)
	t.check(is_equal_approx(Work.time(m, far), alone), "a Mine off the net does not")
	t.check(Power.note(m, mine) != "", "its card talks of the net: %s" % Power.note(m, mine))


# --- Saves ---------------------------------------------------------------------


func test_the_tide_saves_and_loads() -> void:
	var s := town()
	tick_for(s, 100.0)
	var c: Vector2i = base.meadow(s)
	var forge := put(s, "forge", c)
	s.tide.grown[c] = true
	s.tide.hit[c] = 42.0
	s.tide.burnt[c + Vector2i(1, 0)] = true
	var text := RunSave.to_json(RunSave.dump(s))
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, RunSave.from_json(text)), "a town mid-tide loads")
	t.check(loaded.tide.begun and is_equal_approx(loaded.tide.time, s.tide.time), "the tide is where it was")
	t.check(loaded.tide.grown.keys() == s.tide.grown.keys(), "the Bloom's ground is the same")
	t.check(
		loaded.tide.front.size() == s.tide.front.size() and loaded.tide.burnt.has(c + Vector2i(1, 0)),
		"front and ash too"
	)
	t.check(
		is_equal_approx(loaded.tide.hit[c], 42.0) and forge["type"] == "forge", "an overgrown building keeps its count"
	)
	loaded.tick(0.5)
	s.tick(0.5)
	t.check(loaded.tide.grown.size() == s.tide.grown.size(), "and goes on the same way")
	var again := Sim.new()
	t.check(RunSave.restore(again, RunSave.from_json(RunSave.to_json(RunSave.dump(loaded)))), "round trip")
	t.check(RunSave.VERSION == 1, "the save version is unchanged")
	# an old Livewire save has no tide: it starts when the game is loaded
	var d := RunSave.dump(s)
	d["game"].erase("tide")
	var old := Sim.new()
	t.check(RunSave.restore(old, d), "a save from stage 1 loads")
	t.check(not old.tide.begun, "with no tide in it")
	old.tick(0.5)
	t.check(old.tide.begun, "it begins on the first tick, as Livewire has begun")


# --- What the stage 1 review found ---------------------------------------------


func test_edge_cases_from_the_review() -> void:
	# A machine held by a standing order that is mid-job finishes it with its power.
	var s := town()
	var c: Vector2i = base.meadow(s)
	var gen := powered(s, c)
	var forge := put(s, "forge", c + Vector2i(1, 0))
	forge["worker"] = 0
	forge["inbuf"] = {"iron_ore": 4, "coal": 4}
	s.livewire._held = {"forge": true}
	forge["progress"] = 0.0
	t.check(not Power.asking(s, forge), "a held machine with no job in hand asks for nothing")
	forge["progress"] = 1.0
	t.check(
		Power.asking(s, forge) or not s.town.wants_power(forge), "but mid-job it still asks, so the job is finished"
	)
	gen["burn"] = 0.0
	# A machine in a lit engine's own reach runs full speed whatever the net does.
	var w := town()
	var wc: Vector2i = base.meadow(w)
	put(w, "power_pole", wc)
	var boiler := put(w, "boiler", wc + Vector2i(0, 2))
	boiler["burn"] = 999.0
	var machines: Array = []
	for p in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)]:
		var mill := put(w, "grindstone", wc + p)
		mill["worker"] = machines.size()
		machines.append(mill)
		var recipe: Dictionary = Buildings.recipe_in(mill)
		mill["inbuf"] = {}
		for id in recipe:
			mill["inbuf"][id] = recipe[id] * 4
	var net: Dictionary = base.net_of(w, wc)
	t.check(net["asks"] == 5 and net["given"] == 3, "five ask a net that gives 3")
	t.check(w.livewire.speed_of(machines[0]) == 1.0, "yet the Boiler powers them itself, so they run full speed")
