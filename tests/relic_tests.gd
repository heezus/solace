extends RefCounted
## Step 7E, relics (scripts/relics.gd, design-system/18-roadmap.md "Relics as built"): the three heaviest ruins of a Cataclysm run hold
## the Everburning Forge, the Old Lantern and the Founders' Cart; a crew digs one out in about a minute from a road beside the ruin;
## each relic does its one thing; and they are used up with the run. Run from tests/telling_tests.gd.

const Bonuses = preload("res://scripts/bonuses.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Carry = preload("res://scripts/carry.gd")
const Clearing = preload("res://scripts/clearing.gd")
const Data = preload("res://scripts/data.gd")
const Endings = preload("res://scripts/endings.gd")
const Fuel = preload("res://scripts/fuel.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Kith = preload("res://scripts/kith.gd")
const Relics = preload("res://scripts/relics.gd")
const Ruins = preload("res://scripts/ruins.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Scouting = preload("res://scripts/scouting.gd")
const Sim = preload("res://scripts/sim.gd")

const SEED := 5

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_heaviest_ruins_hold_the_relics()
	test_a_ruin_with_a_relic_is_not_cleared_until_it_is_dug()
	test_a_crew_needs_a_road_and_digs_for_a_minute()
	test_the_forge_burns_nothing()
	test_the_lantern_lights_twice_as_far()
	test_the_cart_lifts_the_loads_near_it()
	test_a_relic_is_used_up_with_the_run()
	test_a_first_run_has_no_relics()


## A Cataclysm run: a Sim with the whole map in view and five ruins on open grass, the heaviest first.
func _ruined() -> Sim:
	var s := Sim.new()
	s.generate(SEED)
	s.fog.reveal(s.world.camp_pos, 200)
	var spots := _spots(s, 5)
	var ruins := []
	for i in spots.size():
		ruins.append({"pos": [spots[i].x, spots[i].y], "weight": 100 - i * 10})
	s.carry.ending = "cataclysm"
	s.carry.exodus = 1
	s.carry.ruins = ruins
	Ruins.lay(s, Rect2i(0, 0, s.world.width, s.world.height))
	while s.people.kith.size() < 4:
		s.people.add_kith()
	return s


## `n` open grass tiles well away from the Hearth with grass beside them on every side, in row order.
func _spots(s: Sim, n: int) -> Array:
	var out := []
	for y in range(2, s.world.height - 2):
		for x in range(2, s.world.width - 2):
			var p := Vector2i(x, y)
			var d := (p - s.world.camp_pos).abs()
			if maxi(d.x, d.y) < 8 or maxi(d.x, d.y) > 20:
				continue
			var ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					ok = (
						ok
						and s.world.tile_at(p + Vector2i(dx, dy)) == "grass"
						and not out.any(func(q): return (q - p).abs().x < 3 and (q - p).abs().y < 3)
					)
			if ok:
				out.append(p)
				if out.size() == n:
					return out
	return out


func _pos_of(r: Dictionary) -> Vector2i:
	return Vector2i(int(r["pos"][0]), int(r["pos"][1]))


func _site(s: Sim, id: String) -> Vector2i:
	return Relics.site_of(s, id)


## Lay a road tile beside the ruin at `p` and put the crew-to-be next to it.
func _road_beside(s: Sim, p: Vector2i) -> Vector2i:
	var q := p + Vector2i(1, 0)
	s.world.add_road(q, 0)
	s.pathing.update_cell(q)
	return q


## Step the crew at relic `id` until its dig is done, returning the game seconds it took.
func _dig_through(s: Sim, id: String) -> float:
	var seconds := 0.0
	while not s.carry.dug.has(id) and seconds < 400.0:
		for k in s.people.kith:
			if k["job"] == "scout":
				Scouting.tick(s, k, 0.5)
		seconds += 0.5
	return seconds


func test_the_heaviest_ruins_hold_the_relics() -> void:
	var s := _ruined()
	var list: Array = Data.ENDINGS["relics"]
	t.check(
		list.size() == 3 and list[0]["id"] == "forge" and list[1]["id"] == "lantern" and list[2]["id"] == "cart",
		"three relics"
	)
	for i in 3:
		var p := _pos_of(s.carry.ruins[i])
		t.check(Relics.at(s, p).get("id", "") == list[i]["id"], "ruin %d holds the %s" % [i + 1, list[i]["name"]])
	t.check(Relics.at(s, _pos_of(s.carry.ruins[3])).is_empty(), "the fourth ruin holds nothing")
	t.check(Relics.waiting(s).size() == 3, "three relics lie waiting")
	t.check(Relics.tip(s, _site(s, "forge")).contains("Everburning Forge"), "the pill over a ruin names its relic")
	t.check(Relics.tip(s, _pos_of(s.carry.ruins[4])) == "", "and says nothing over a bare ruin")


func test_a_ruin_with_a_relic_is_not_cleared_until_it_is_dug() -> void:
	var s := _ruined()
	var p := _site(s, "forge")
	t.check(
		not Clearing.check(s, p)["ok"] and Clearing.check(s, p)["text"] == Data.ENDINGS["relic_ruin_kept"],
		"Demolish leaves it"
	)
	t.check(Clearing.clear(s, p) == "" and s.world.tile_at(p) == "ruins", "the ruin stands")
	var bare := _pos_of(s.carry.ruins[3])
	t.check(Clearing.check(s, bare)["ok"], "a bare ruin still clears for its Stone")


func test_a_crew_needs_a_road_and_digs_for_a_minute() -> void:
	var s := _ruined()
	var p := _site(s, "forge")
	t.check(Scouting.dig(s, p) == Data.ENDINGS["dig_no_road"], "no road beside it: no crew")
	t.check(Scouting.dig(s, _pos_of(s.carry.ruins[3])) == "", "a ruin with no relic sends nobody")
	var q := _road_beside(s, p)
	for k in s.people.kith:
		k["pos"] = Vector2(q)
	s.people.kith[2]["pos"] = Vector2(q) + Vector2(0, 1)
	var note := Scouting.click(s, p)
	t.check(
		note == Data.ENDINGS["dig_sent"] % [s.people.kith[0]["name"], "Everburning Forge"],
		"the nearest idle Kith goes: %s" % note
	)
	var crew: Dictionary = s.people.kith[0]
	t.check(crew["job"] == "scout" and crew["phase"] == "dig_out", "as a crew")
	t.check(s.people.job_of(crew) == Data.ENDINGS["job_dig"], "with the title Digger")
	t.check(Scouting.dig(s, p) == Data.ENDINGS["dig_busy"], "a second click adds no second crew")
	t.check(Relics.digging(s, "forge") == crew, "the crew is found by its relic")
	var seconds := _dig_through(s, "forge")
	t.check(
		seconds >= Data.ENDINGS["dig_seconds"] and seconds <= Data.ENDINGS["dig_seconds"] + 10.0,
		"about a minute at the ruin (%.1f s)" % seconds
	)
	t.check(s.world.tile_at(p) == "grass", "the ruin is gone")
	var i: int = s.town.building_at.get(p, -1)
	t.check(
		i >= 0 and s.town.buildings[i]["type"] == "forge" and s.town.buildings[i]["relic"] == "forge",
		"and the relic stands"
	)
	t.check(s.story.has_event("relic_forge"), "the story notes it")
	t.check(Relics.waiting(s).size() == 2, "two relics are left")
	for n in 80:
		for k in s.people.kith:
			if k["job"] == "scout":
				Scouting.tick(s, k, 0.5)
	t.check(crew["job"] == "" and Scouting.count(s) == 0, "the crew walks home and is idle again")
	t.check(Scouting.dig(s, p) == "", "nothing is left to dig there")
	# everyone busy: nobody goes
	var s2 := _ruined()
	_road_beside(s2, _site(s2, "lantern"))
	for k in s2.people.kith:
		k["job"] = "work"
	t.check(Scouting.dig(s2, _site(s2, "lantern")) == Data.ENDINGS["dig_nobody"], "nobody free: nobody goes")
	# the dug relic survives a save of the run
	var back := Sim.new()
	back.generate(SEED)
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run restores")
	var j: int = back.town.building_at.get(p, -1)
	t.check(
		back.carry.dug == ["forge"] and j >= 0 and back.town.buildings[j].get("relic", "") == "forge",
		"the dug relic is kept"
	)


func test_the_forge_burns_nothing() -> void:
	var s := _ruined()
	var p := _site(s, "forge")
	Relics.finish(s, "forge")
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(not Fuel.burns(b) and not Buildings.recipe_in(b).has("coal"), "no fuel to burn, no Coal to bring")
	t.check(Buildings.recipe_in(b) == {"iron": 2} and Buildings.recipe_out(b) == {"steel": 1}, "Iron in, Steel out")
	s.town.add_building("forge", s.world.camp_pos + Vector2i(-3, 2))
	var plain: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	t.check(Fuel.burns(plain) and Buildings.recipe_in(plain).has("coal"), "an ordinary Forge still burns Coal")


func test_the_lantern_lights_twice_as_far() -> void:
	var s := _ruined()
	var p := _site(s, "lantern")
	var home: Vector2i = s.world.camp_pos + Vector2i(2, -2)
	s.town.add_building("shard_lantern", home)
	t.check(
		Bonuses.lit(s, home + Vector2i(4, 0)) and not Bonuses.lit(s, home + Vector2i(7, 0)),
		"a Shard Lantern lights four tiles"
	)
	var far := p + Vector2i(7, 0)
	t.check(not Bonuses.lit(s, far), "dark before the Old Lantern is dug")
	Relics.finish(s, "lantern")
	t.check(Bonuses.lit(s, far), "seven tiles from it is lit")
	t.check(not Bonuses.lit(s, p + Vector2i(9, 0)), "nine is not")
	t.check(
		Relics.radius(s.town.buildings[s.town.building_at[p]]) == Data.SHARDLIGHT_RADIUS * 2.0, "its reach is double"
	)


func test_the_cart_lifts_the_loads_near_it() -> void:
	var s := _ruined()
	var p := _site(s, "cart")
	var base: int = Haulers.carry_cap(s)
	var near := {"pos": Vector2(p + Vector2i(5, 0)), "cart": false, "cart_kind": "", "hot": false}
	var far := {"pos": Vector2(p + Vector2i(12, 0)), "cart": false, "cart_kind": "", "hot": false}
	t.check(Haulers.carry_cap(s, near) == base, "before the dig a load is a load")
	Relics.finish(s, "cart")
	t.check(Haulers.carry_cap(s, near) == ceili(base * 1.5), "a hauler within eight tiles carries half as much again")
	t.check(Haulers.carry_cap(s, far) == base, "a hauler farther off does not")
	t.check(Haulers.carry_cap(s) == base, "and a load counted with no hauler named is the plain one")
	t.check(s.world.tile_at(p) == "grass" and not s.town.building_at.has(p), "the cart stands on open ground")


func test_a_relic_is_used_up_with_the_run() -> void:
	var s := _ruined()
	Relics.finish(s, "lantern")
	t.check(s.carry.dug == ["lantern"], "dug this run")
	var d := s.carry.to_dict()
	t.check(d["dug"] == ["lantern"], "the run's carry saves it")
	var again := Carry.new()
	again.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.check(again.dug == ["lantern"], "and reads it back")
	var handoff: Dictionary = Endings.handoff(s, "cataclysm")
	var next := Carry.new()
	next.set_handoff(handoff)
	t.check(next.dug.is_empty(), "the next run is handed no dug relic: it finds its own")
	t.check(not handoff.has("dug"), "the handoff does not name one")


func test_a_first_run_has_no_relics() -> void:
	var s := Sim.new()
	s.generate(SEED)
	t.check(s.carry.dug.is_empty() and Relics.waiting(s).is_empty(), "nothing to dig")
	t.check(Scouting.click(s, s.world.camp_pos) == "", "a click on the ground sends nobody")
