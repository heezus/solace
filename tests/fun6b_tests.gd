extends RefCounted
## Fun playtest 6, part B (the director's calls 3, 4, 5 and 7): the first Gatherer's Hut is free and its goal comes right after the first
## goal; roads run over Riverbed Gravel and Clay Banks, a dragged line goes round what a road can't take and says so, and every
## "Needs road" names the tiles to lay; the founding plan moves a misfit building to the nearest tile that fits, joins its roads to
## the Hearth and lists what fits nowhere; the Strange Stone and every ground a telling needs stand on every land, named by a hint.
## Run from tests/run_tests.gd.

const Blueprints = preload("res://scripts/blueprints.gd")
const CardText = preload("res://scripts/card_text.gd")
const Data = preload("res://scripts/data.gd")
const Founding = preload("res://scripts/founding.gd")
const Land = preload("res://scripts/land.gd")
const Needs = preload("res://scripts/needs.gd")
const RoadRoute = preload("res://scripts/road_route.gd")
const Roads = preload("res://scripts/roads.gd")
const Sim = preload("res://scripts/sim.gd")
const Workers = preload("res://scripts/workers.gd")

## The grounds a telling needs, by tile.
const NEEDED := [
	"shard",
	"tree",
	"rock",
	"gravel",
	"berry",
	"flax",
	"clay",
	"grain",
	"copper_hills",
	"tin_stream",
	"coal_seam",
	"iron_hills"
]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_first_hut_is_free()
	test_roads_run_over_gravel_and_clay_but_not_flax()
	test_a_dragged_road_goes_round_flax_and_says_so()
	test_needs_road_names_the_tiles_to_lay()
	test_the_founding_plan_fits_the_land()
	test_every_land_has_the_strange_stone_and_the_grounds_a_telling_needs()


## A Sim with the map in view, grass for `half` tiles around the Hearth, and Paths & Haulers known with wood and stone in the stores.
func _town(half := 12) -> Sim:
	var s := Sim.new()
	s.generate(5)
	s.fog.reveal_all()
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
			if s.world.in_bounds(p) and p != s.world.camp_pos and s.world.tile_at(p) != "river":
				s.world.set_tile(p, "grass")
	for tech in ["haulers", "gatherers_hut", "pottery", "knapping", "foraging"]:
		s.tech_tree.researched[tech] = true
	s.economy.inv["wood"] = 200
	s.economy.inv["stone"] = 200
	s.economy.inv["clay"] = 200
	s.pathing.build()
	return s


func test_the_first_hut_is_free() -> void:
	var s := _town()
	s.economy.inv["wood"] = 0
	s.economy.inv["stone"] = 0
	var at: Vector2i = s.world.camp_pos + Vector2i(5, 3)
	t.check(s.town.price("gatherers_hut").is_empty(), "the first Gatherer's Hut costs nothing")
	t.check(s.town.placement_error("gatherers_hut", at) == "", "and goes down with empty stores")
	t.check(s.place("gatherers_hut", at), "it is placed")
	t.check(s.economy.inv["wood"] == 0, "and took nothing")
	t.check(
		s.town.price("gatherers_hut") == Data.BUILDINGS["gatherers_hut"]["cost"], "the second costs the listed price"
	)
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	t.check(
		ids.slice(0, 3) == ["gather", "flax", "hut"],
		"the hut goal comes once the flax is found (Foraging shows only once Fiber is seen)"
	)
	t.check(
		Data.GOALS[ids.find("hut")]["text"].contains("first one is free"), "and its words say the first one is free"
	)


func test_roads_run_over_gravel_and_clay_but_not_flax() -> void:
	var s := _town()
	var c: Vector2i = s.world.camp_pos
	for pair in [["gravel", Vector2i(3, 0)], ["clay", Vector2i(4, 0)], ["flax", Vector2i(5, 0)]]:
		s.world.set_tile(c + pair[1], pair[0])
	t.check(s.town.placement_error("road", c + Vector2i(3, 0)) == "", "a road goes on Riverbed Gravel")
	t.check(s.town.placement_error("road", c + Vector2i(4, 0)) == "", "and on a Clay Bank")
	t.check(
		s.town.placement_error("road", c + Vector2i(5, 0)).begins_with("Roads can't go on Wild Flax"), "but not on flax"
	)
	s.place("road", c + Vector2i(3, 0))
	s.place("road", c + Vector2i(4, 0))
	t.check(
		s.world.roads.has(c + Vector2i(4, 0)) and s.world.tile_at(c + Vector2i(4, 0)) == "clay", "the bank stays a bank"
	)
	t.check(not Roads.boxed_in(s, c + Vector2i(8, 0)), "a building beside clay or gravel is not boxed in by it")


func test_a_dragged_road_goes_round_flax_and_says_so() -> void:
	var s := _town()
	var c: Vector2i = s.world.camp_pos
	var a := c + Vector2i(2, 0)
	var b := c + Vector2i(8, 0)
	for dx in range(4, 7):
		s.world.set_tile(c + Vector2i(dx, 0), "flax")  # three flax tiles across the straight way
	var straight: Array = [2, 3, 4, 5, 6, 7, 8].map(func(dx): return c + Vector2i(dx, 0))
	var line: Array = CardText.drag_line(s, "road", a, b)
	t.check(line != straight, "the line does not run straight over the flax")
	t.check(line[0] == a and line[line.size() - 1] == b, "it still runs from the start to the end")
	t.check(line.all(func(p): return s.town.placement_error("road", p) == ""), "every tile of it takes a road")
	t.check(line.size() == straight.size() + 2, "it goes round by the shortest way (%d tiles)" % line.size())
	var note := RoadRoute.note(s, "road", line)
	t.check(note == "Went around 3 Wild Flax tiles", "it says what it went around: %s" % note)
	t.check(CardText.line_report(s, "road", line).begins_with(note), "the card line says it too")
	t.check(s.place_line("road", line) == line.size(), "and every tile of it goes down")
	t.check(CardText.drag_line(s, "bridge", a, b) == straight, "a bridge keeps the straight line")
	var clear := CardText.drag_line(s, "road", c + Vector2i(2, 5), c + Vector2i(8, 5))
	t.check(clear.size() == 7 and RoadRoute.note(s, "road", clear) == "", "a clear line is straight and says nothing")


func test_needs_road_names_the_tiles_to_lay() -> void:
	var s := _town()
	var c: Vector2i = s.world.camp_pos
	for dx in range(2, 5):
		s.world.set_tile(c + Vector2i(dx, 0), "flax")
	var hut: Dictionary = (
		s.town.buildings[s.town.building_at[c + Vector2i(6, 0)]] if s.place("gatherers_hut", c + Vector2i(6, 0)) else {}
	)
	t.check(not hut.is_empty(), "a hut stands beyond the flax")
	var hint := Workers.road_hint(s, hut["pos"])
	t.check(
		hint.begins_with("Lay ") and hint.contains("road: (") and hint.contains(" to ("),
		"the hint names the tiles: %s" % hint
	)
	t.check(hint.contains("Hearth"), "and where it joins: %s" % hint)
	var lay: Array = RoadRoute.to_lay(s, hut["pos"])["tiles"]
	t.check(
		lay.size() >= 5 and not lay.any(func(p): return s.world.tile_at(p) == "flax"),
		"the way goes round the flax (%d tiles)" % lay.size()
	)
	t.check(hint.begins_with("Lay %d road" % lay.size()), "and counts them: %s" % hint)
	for p in lay:
		s.place("road", p)
	t.check(Roads.linked(s, hut), "laying exactly those tiles links the hut")
	t.check(Workers.road_hint(s, hut["pos"]) == "linked by road", "and the hint is gone")
	t.check(
		(
			RoadRoute.lay_text([Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5)])
			== "Lay 4 road: (12,5) to (15,5)"
		),
		"the words"
	)


func test_the_founding_plan_fits_the_land() -> void:
	var s := _town()
	var c: Vector2i = s.world.camp_pos
	# a plan whose corner sits at the Hearth: roads out to the east, a Kiln on flax, a Dwelling on the river, a Coal Mine nowhere
	s.world.set_tile(c + Vector2i(3, 3), "flax")
	var items := [
		{"t": "road", "x": 5, "y": 0},
		{"t": "road", "x": 6, "y": 0},
		{"t": "road", "x": 7, "y": 0},
		{"t": "kiln", "x": 3, "y": 3},
		{"t": "coal_mine", "x": 9, "y": 9},
	]
	s.carry.founding = {"name": "The founding", "w": 10, "h": 10, "items": items, "banked": true, "ax": 0, "ay": 0}
	s.tech_tree.researched["coal_seams"] = true
	var joins: Array = Founding.join_items(s, items, c)
	t.check(joins.size() == 4, "the plan's roads are joined to the Hearth by 4 roads (%d)" % joins.size())
	var xs: Array = joins.map(func(j): return j["x"])
	t.check(xs.has(1) and xs.has(4), "from beside the Hearth to the first planned road: %s" % str(xs))
	var lines := Founding.fit_lines(s)
	t.check(
		lines.size() == 2 and lines[0].contains("Kiln") and lines[1].contains("Coal Mine"),
		"the card lists what moves and what is left: %s" % str(lines)
	)
	items.pop_back()  # the Coal Mine is left to the player: the rest is laid (and Coal Seams unlearned, which would grow the land south)
	s.tech_tree.researched.erase("coal_seams")
	t.check(Founding.lay(s) == 8, "laying queues the parts and the joining roads (%d)" % s.carry.plans.size())
	s.economy.inv["brick"] = 100
	for i in 12:
		s.tick(0.5)
	t.check(
		(
			s.world.roads.has(c + Vector2i(1, 0))
			and s.world.roads.has(c + Vector2i(4, 0))
			and s.world.roads.has(c + Vector2i(5, 0))
		),
		"the roads join the Hearth"
	)
	var kiln := Vector2i(-1, -1)
	for b in s.town.buildings:
		if b["type"] == "kiln":
			kiln = b["pos"]
	t.check(kiln.x >= 0 and kiln != c + Vector2i(3, 3), "the Kiln stands on the nearest ground that fits")
	t.check(s.carry.plans.is_empty(), "and nothing is left queued: %s" % str(s.carry.plans))


func test_every_land_has_the_strange_stone_and_the_grounds_a_telling_needs() -> void:
	for seed_value in range(1, 13):
		var s := Sim.new()
		s.generate(seed_value)
		s.tech_tree.researched["bronze_dawn"] = true
		s.tech_tree.researched["coal_seams"] = true
		Land.grow_if_due(s)
		var counts := {}
		for y in s.world.height:
			for x in s.world.width:
				var tile: String = s.world.tile_at(Vector2i(x, y))
				counts[tile] = int(counts.get(tile, 0)) + 1
		for tile in NEEDED:
			t.check(counts.get(tile, 0) > 0, "map %d has %s" % [seed_value, tile])
		var stone: Vector2i = s.world.shard_pos
		t.check(
			(
				stone.x >= 0
				and s.world.tile_at(stone) == "shard"
				and Vector2(stone).distance_to(Vector2(s.world.camp_pos)) <= 30.0
			),
			"map %d: the Strange Stone stands within reach" % seed_value
		)
		# a hint names each one while it lies in the fog
		for tile in NEEDED:
			var item: String = Data.SHARD_ITEM if tile == "shard" else str(Data.TILES[tile]["yields"])
			if item == "" or _in_sight(s, tile):
				continue
			var line: String = Needs._fog_line(s, item)
			t.check(
				line.begins_with("No ") and line.contains("found yet"),
				"map %d: a hint names %s (%s)" % [seed_value, tile, line]
			)
		if _in_sight(s, "shard") == false:
			t.check(
				Needs._fog_line(s, Data.SHARD_ITEM).contains("Strange Stone"),
				"map %d: the hint says Strange Stone" % seed_value
			)


func _in_sight(s: Sim, tile: String) -> bool:
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and s.fog.is_revealed(p):
				return true
	return false
