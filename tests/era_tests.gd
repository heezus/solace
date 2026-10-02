extends RefCounted
## Era 2, Bronze Dawn, stage 1 (design-system/10-bronze-dawn.md): the second tech tree and what of it is built, the land
## that grows east, ore and hand mining, Mines (two Kith), the Smelter and the Crucible, the era's tech effects, and
## the save of a grown game. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const MapEast = preload("res://scripts/map_east.gd")
const Hands = preload("res://scripts/hands.gd")
const Work = preload("res://scripts/work.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Roads = preload("res://scripts/roads.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Messages = preload("res://scripts/messages.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const TechBoard = preload("res://scripts/tech_board.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")

## The era's techs whose effects are built (stage 1); the rest are the next update's.
const BUILT := ["prospecting", "tally_sticks", "plough", "mining", "smelting", "kilns_ii", "alloying"]
## What each era-2 tech needs (design-system/10-bronze-dawn.md); Granaries also needs Markets or Kilns II.
const PARENTS := {
	"prospecting": ["bronze_dawn"],
	"tally_sticks": ["bronze_dawn"],
	"plough": ["bronze_dawn"],
	"mining": ["prospecting", "tally_sticks"],
	"smelting": ["prospecting", "plough"],
	"kilns_ii": ["smelting", "tally_sticks"],
	"the_wheel": ["tally_sticks", "plough"],
	"alloying": ["smelting", "mining"],
	"causeways": ["the_wheel", "mining"],
	"markets": ["the_wheel", "tally_sticks"],
	"sky_watch": ["tally_sticks", "mining"],
	"bronze_tools": ["alloying", "causeways"],
	"granaries": ["plough"],
	"bronze_ploughshare": ["bronze_tools", "plough"],
	"star_charts": ["sky_watch", "alloying"],
	"falling_star": ["bronze_tools", "star_charts", "granaries"],
}
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 42, 99, 123, 2024]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_era_two_tree_is_defined()
	test_era_two_board_lays_out()
	test_unbuilt_techs_cannot_be_bought()
	test_the_land_grows_east_and_the_stone_half_stays()
	test_the_new_land_is_fair()
	test_ore_is_dug_by_hand_after_prospecting()
	test_a_mine_needs_two_kith()
	test_a_mine_is_served_by_roads_and_haulers()
	test_smelting_recipes()
	test_era_two_tech_effects()
	test_a_grown_game_saves_and_loads()
	test_the_tech_panel_has_a_tab_per_era()


## A game that has just researched Bronze Dawn the proper way: it has won, and the land has not grown yet.
func dawn(map_seed: int) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	t.give(s, 99999)
	for tech in Rules.route_to("bronze_dawn", {}, Rules.visible_techs(true)):
		s.research(tech)
	return s


## The same, one tick later: the land has grown, and the whole map is in sight.
func grown(map_seed: int) -> Sim:
	var s := dawn(map_seed)
	s.tick(0.1)
	s.fog.reveal_all()
	return s


## The ore tile of kind `tile` nearest the Hearth, or (-1, -1).
func hills(s: Sim, tile := "copper_hills") -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if s.world.tile_at(p) == tile and d < best_d:
				best = p
				best_d = d
	return best


func mine_of(s: Sim) -> Dictionary:
	for b in s.town.buildings:
		if b["type"] == "mine":
			return b
	return {}


# --- The tree ----------------------------------------------------------------


func test_era_two_tree_is_defined() -> void:
	var mine := Rules.era_techs(2)
	t.check(Data.ERAS.size() == 2 and mine.size() == 16, "the second era has 16 techs (%d)" % mine.size())
	t.check(Data.ERA_TIER_NAMES.has(1) and Data.ERA_TIER_NAMES.has(2), "every era has its column captions")
	for tech in PARENTS:
		t.check(Data.TECHS.has(tech) and tech in mine, tech + " is an era-2 tech")
		var d: Dictionary = Data.TECHS[tech]
		var want: Array = PARENTS[tech].duplicate()
		var have: Array = d["requires"].duplicate()
		want.sort()
		have.sort()
		t.check(have == want, "%s needs %s (has %s)" % [tech, want, have])
		for p in d["requires"] + d.get("requires_any", []):
			var parent: Dictionary = Data.TECHS[p]
			if int(parent.get("era", 1)) == 2:
				t.check(d["tier"] > parent["tier"], "%s sits right of %s" % [tech, p])
			else:
				t.check(p == "bronze_dawn", "the only way in from the stone age is Bronze Dawn")
		t.check(
			d["slot"] <= 1 and (Data.LANES.has(d["lane"]) or d["lane"] == "gate"), tech + " has a place on the board"
		)
		t.check(d.has("icon") and d.has("unlock") and d.has("desc") and not d["cost"].is_empty(), tech + " has a card")
	t.check(Data.TECHS["granaries"]["requires_any"] == ["markets", "kilns_ii"], "Granaries need Markets or Kilns II")
	t.check(Data.TECHS["falling_star"]["lane"] == "gate", "The Falling Star is the era's gate")
	var roots := mine.filter(func(x): return Data.TECHS[x]["requires"] == ["bronze_dawn"])
	t.check(roots.size() == 3, "three techs open the era: %s" % [roots])
	var colors := {}
	for tech in mine:
		colors[Data.TECHS[tech]["color"].to_html()] = true
	t.check(colors.size() == mine.size(), "every era-2 tech has its own color")
	var built := mine.filter(Rules.tech_enabled)
	built.sort()
	var expect := BUILT.duplicate()
	expect.sort()
	t.check(built == expect, "exactly the seven stage-1 techs are built: %s" % [built])
	for tech in mine:
		if tech not in BUILT:
			t.check(int(Data.TECHS[tech]["stage"]) == 2, tech + " waits for stage 2")
	t.check(Rules.era_techs(1).size() == 29, "the stone age is untouched")


func test_era_two_board_lays_out() -> void:
	var lay := TechLayout.build(2)
	t.check(lay["overflow"] == 0, "every era-2 line found a free track (%d did not)" % lay["overflow"])
	t.check(lay["rects"].size() == 16, "the era-2 board shows its 16 cards")
	t.check(lay["edges"].size() == TechLayout.links(2).size(), "one line per era-2 requirement")
	t.check(TechLayout.links(2).size() == 28, "era 2 has 28 links (%d)" % TechLayout.links(2).size())
	for a in lay["rects"]:
		for b in lay["rects"]:
			if a < b:
				t.check(not lay["rects"][a].intersects(lay["rects"][b]), "%s and %s cards don't overlap" % [a, b])
	for e in lay["edges"]:
		var pts: PackedVector2Array = e["pts"]
		t.check(pts[0].x == lay["rects"][e["from"]].end.x, e["from"] + " leaves from the card's right edge")
		t.check(pts[pts.size() - 1].x == lay["rects"][e["to"]].position.x, e["to"] + " enters on the left edge")
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			t.check(a.x == b.x or a.y == b.y, "lines are orthogonal")
			var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))
			for tech in lay["rects"]:
				var card: Rect2 = lay["rects"][tech].grow(-1.0)
				var hit := box.end.x >= card.position.x and box.position.x <= card.end.x
				hit = hit and box.end.y >= card.position.y and box.position.y <= card.end.y
				t.check(not hit, "%s > %s passes under %s" % [e["from"], e["to"], tech])


## A tech whose effect is not built yet is on the board but locked: it can't be bought, queued or aimed at.
func test_unbuilt_techs_cannot_be_bought() -> void:
	var s: Sim = t.fresh()
	t.give(s, 99999)
	for tech in Data.TECH_ORDER:
		if Rules.tech_enabled(tech):
			s.tech_tree.researched[tech] = true
	var board := TechBoard.new()
	board.setup(s)
	board.set_era(2)
	var panel := TechPanel.new()
	panel.setup(s)
	var locked := 0
	for tech in Rules.era_techs(2):
		if Rules.tech_enabled(tech):
			continue
		locked += 1
		t.check(not s.tech_tree.can_research(tech), tech + " isn't researchable")
		t.check(not s.research(tech), tech + " can't be paid for")
		t.check(not s.tech_tree.researched.has(tech), tech + " stays unresearched")
		s.tech_tree.set_goal(tech)
		t.check(s.tech_tree.goal == "" and s.tech_tree.queue.is_empty(), tech + " can't be a goal")
		panel._on_card(tech)
		t.check(not s.tech_tree.researched.has(tech) and s.tech_tree.goal == "", tech + " ignores a click")
		t.check(tech not in s.tech_tree.ready_list(), tech + " is never ready")
		t.check(tech not in board.next_techs(), tech + " is never a next step")
		t.check(board.shows(tech), tech + " is on the board")
	t.check(locked == 9, "nine era-2 techs wait for the next update (%d)" % locked)
	t.check(Data.TECH_UNBUILT == "Needs the next update", "locked cards say what is true")
	t.check(not Data.TECH_UNBUILT.to_lower().contains("soon"), "and never 'coming soon'")
	board.free()
	panel.free()


# --- The land ----------------------------------------------------------------


func test_the_land_grows_east_and_the_stone_half_stays() -> void:
	for map_seed in [1, 2, 3, 42]:
		var s := dawn(map_seed)
		var w: int = s.world.width
		var h: int = s.world.height
		t.check(
			s.won and not s.world.is_grown() and w == s.world.stone_width, "Bronze Dawn is won on the stone-age map"
		)
		var stone: Array = s.world.tiles.duplicate()
		var seen_before := {}
		for y in h:
			for x in w:
				seen_before[Vector2i(x, y)] = s.fog.is_revealed(Vector2i(x, y))
		s.tick(0.1)
		t.check(s.world.is_grown() and s.world.width == w * 2 and s.world.height == h, "the map doubles east")
		t.check(s.world.stone_width == w, "and remembers where the stone age ends")
		var same := true
		var kept := true
		for y in h:
			for x in w:
				same = same and s.world.tiles[y * s.world.width + x] == stone[y * w + x]
				kept = kept and (s.fog.is_revealed(Vector2i(x, y)) or not seen_before[Vector2i(x, y)])
		t.check(same, "the stone-age half is exactly as it was (map %d)" % map_seed)
		t.check(kept, "and what was seen is still seen")
		var fresh_stone := Sim.new()
		fresh_stone.generate(map_seed)
		t.check(fresh_stone.world.tiles == stone, "and is what the seed makes")
		t.check(Data.LAND_GREW_EVENT in s.events, "the player is told")
		var hidden := 0
		for y in h:
			for x in range(w + 8, s.world.width):
				hidden += 0 if s.fog.is_revealed(Vector2i(x, y)) else 1
		t.check(hidden > 0, "the new land starts under fog")
		var width_after: int = s.world.width
		s.tick(1.0)
		t.check(s.world.width == width_after and s.won, "it grows once, and the game goes on")
		var again := dawn(map_seed)
		again.tick(0.1)
		t.check(again.world.tiles == s.world.tiles, "the same seed grows the same land (map %d)" % map_seed)
		var other := dawn(map_seed + 1000)
		other.tick(0.1)
		t.check(other.world.tiles != s.world.tiles, "another seed grows another")
		t.check(hills(s).x >= 0 and hills(s, "tin_stream").x >= 0, "there is copper and tin in the new land")


func test_the_new_land_is_fair() -> void:
	var worst := 0
	for map_seed in SEEDS:
		var s := Sim.new()
		s.generate(map_seed)
		var report := {}
		var strip: Array = MapEast.make(s.world, report)
		var w: int = s.world.stone_width
		var h: int = s.world.height
		t.check(strip.size() == w * h, "the new land is as big as the old (%d)" % strip.size())
		t.check(report["faults"].is_empty(), "map %d: the new land is fair (%s)" % [map_seed, report["faults"]])
		t.check(report["attempts"] <= MapEast.ATTEMPTS, "map %d: at most %d tries" % [map_seed, MapEast.ATTEMPTS])
		worst = maxi(worst, report["crossings"])
		t.check(
			report["crossings"] <= MapEast.MAX_CROSSINGS,
			"map %d: the tin is %d river tiles away" % [map_seed, report["crossings"]]
		)
		var copper := 0
		var near := 0
		var tin: Array = []
		for i in strip.size():
			if strip[i] == "copper_hills":
				copper += 1
				near += 1 if i % w < MapEast.WEST_ZONE else 0
			elif strip[i] == "tin_stream":
				tin.append(Vector2i(i % w, floori(float(i) / w)))
		t.check(
			copper >= MapEast.COPPER_MIN and near >= MapEast.COPPER_NEAR_MIN,
			"map %d: copper is common and near" % map_seed
		)
		t.check(tin.size() == MapEast.TIN_TILES, "map %d: tin is %d tiles" % [map_seed, tin.size()])
		for p in tin:
			t.check(p.x * 3 >= w * 2 and p.y * 3 <= h, "map %d: tin lies far to the north-east %s" % [map_seed, p])
		var again := {}
		t.check(MapEast.make(s.world, again) == strip, "map %d: the same land every time" % map_seed)
		# Tin and copper can be reached from the Hearth: walking, with at most MAX_CROSSINGS river tiles bridged.
		s.world.grow_east()
		t.check(
			_crossings_to(s, hills(s, "tin_stream")) <= MapEast.MAX_CROSSINGS,
			"map %d: the Hearth reaches the tin" % map_seed
		)
		t.check(_crossings_to(s, hills(s)) <= MapEast.MAX_CROSSINGS, "map %d: and the copper" % map_seed)
	var s0 := Sim.new()
	s0.generate(1)
	var blank: Array = []
	blank.resize(s0.world.width * s0.world.height)
	blank.fill("grass")
	t.check(not MapEast.faults_of(s0.world, blank).is_empty(), "a land with no ore is refused, and made again")
	print("East land: the worst river crossing to the tin is %d tile(s) across %d maps" % [worst, SEEDS.size()])


## The fewest river tiles between the Hearth and `goal` on the grown map (a 0-1 search over every tile).
func _crossings_to(s: Sim, goal: Vector2i) -> int:
	var dist := {s.world.camp_pos: 0}
	var open: Array = [s.world.camp_pos]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var p: Vector2i = open.pop_at(best)
		if p == goal:
			return dist[p]
		for n in MapEast.NEIGHBORS:
			var q: Vector2i = p + n
			if not s.world.in_bounds(q):
				continue
			var d: int = dist[p] + (1 if s.world.tile_at(q) == "river" else 0)
			if not dist.has(q) or d < dist[q]:
				dist[q] = d
				open.append(q)
	return 1000


# --- Ore, mines and smelting ---------------------------------------------------


func test_ore_is_dug_by_hand_after_prospecting() -> void:
	var s := grown(42)
	var p := hills(s)
	var tin := hills(s, "tin_stream")
	t.check(p.x >= s.world.stone_width and tin.x >= s.world.stone_width, "ore is in the new land")
	t.check(Data.TILES["copper_hills"]["mine_only"] and Data.TILES["tin_stream"]["mine_only"], "huts never gather ore")
	t.check(Hands.item_at(s, p) == "" and Hands.item_at(s, tin) == "", "before Prospecting the ground yields nothing")
	s.economy.inv["copper_ore"] = 0
	s.economy.inv["tin"] = 0
	t.check(s.gather_by_hand(p) != "ore" and s.economy.inv["copper_ore"] == 0, "and a click digs nothing")
	s.tech_tree.researched["prospecting"] = true
	t.check(Hands.item_at(s, p) == "copper_ore" and Hands.item_at(s, tin) == "tin", "Prospecting names the ore")
	t.check(
		Hands.hold_time(s, "copper_ore") == Data.HAND_HOLD["copper_ore"],
		"copper ore is held for %.0f s" % Data.HAND_HOLD["copper_ore"]
	)
	t.check(Hands.hold_time(s, "tin") > Hands.hold_time(s, "wood") * 2.0, "hand mining is slow")
	var got := ""
	for i in 60:
		got = s.hold_harvest(p, 0.1)
		if got != "":
			break
	t.check(s.economy.inv["copper_ore"] == 1, "holding digs a piece of ore (%d)" % s.economy.inv["copper_ore"])
	t.check(not s.people.knows("copper_ore"), "ore is not a skill a Kith learns by watching")
	t.check(
		Data.ITEMS["copper_ore"]["era"] == 2 and Data.ITEMS["bronze"]["era"] == 2, "the ores and metals are era-2 goods"
	)
	for hut_tile in s.town.gather_tiles(s.world.camp_pos):
		t.check(s.world.tile_at(hut_tile) not in ["copper_hills", "tin_stream"], "a hut never reaches ore")


func test_a_mine_needs_two_kith() -> void:
	t.check(Data.BUILDINGS["mine"]["crew"] == 2 and Buildings.crew_size({"type": "mine"}) == 2, "a Mine takes two Kith")
	t.check(Buildings.crew_size({"type": "kiln"}) == 1, "a Kiln takes one")
	var s := grown(42)
	var p := hills(s)
	t.check(s.town.placement_error("mine", s.world.camp_pos + Vector2i(0, 3)) != "", "a Mine stands only on ore")
	t.check(t.place_free(s, "mine", p) and s.town.building_at.has(p), "a Mine goes on Copper Hills")
	var b: Dictionary = mine_of(s)
	t.check(b["ore"] == "copper_ore", "it digs what its tile yields")
	for i in 400:
		s.economy.inv["berries"] = 999
		s.tick(0.1)
	t.check(
		b["worker"] >= 0 and b["mate"] >= 0 and Buildings.is_staffed(b), "with Kith to spare, both places are filled"
	)
	var dug: int = b["out"].get("copper_ore", 0) + s.economy.inv.get("copper_ore", 0)
	t.check(dug >= Data.BUILDINGS["mine"]["dig"], "a staffed Mine digs (%d)" % dug)
	# With one Kith it stays idle.
	var s2 := grown(42)
	while s2.people.kith.size() > 1:
		s2.people._remove_kith()
	t.place_free(s2, "mine", hills(s2))
	s2.economy.inv["copper_ore"] = 0
	for i in 400:
		s2.economy.inv["berries"] = 999
		s2.tick(0.1)
	var b2: Dictionary = mine_of(s2)
	t.check(not Buildings.is_staffed(b2), "one Kith can't work a Mine")
	t.check(b2["out"].get("copper_ore", 0) == 0 and s2.economy.inv["copper_ore"] == 0, "and it digs nothing")
	t.check(b2["status"] != "Working", "its card doesn't say it works (%s)" % b2["status"])


func test_a_mine_is_served_by_roads_and_haulers() -> void:
	var s := grown(4)  # a map with no river between the Hearth and the copper
	s.tech_tree.researched["haulers"] = true
	var p := hills(s)
	t.place_free(s, "mine", p)
	t.road_link(s, p)
	var b: Dictionary = mine_of(s)
	t.check(Roads.linked(s, b), "a road links the Mine to the Hearth")
	s.economy.inv["copper_ore"] = 0
	for i in 3000:
		s.economy.inv["berries"] = 9999
		s.tick(0.1)
	t.check(s.economy.inv["copper_ore"] > 0, "haulers carry its ore home (%d)" % s.economy.inv["copper_ore"])


func test_smelting_recipes() -> void:
	var smelter: Dictionary = Data.BUILDINGS["smelter"]
	var crucible: Dictionary = Data.BUILDINGS["crucible"]
	t.check(
		smelter["in"] == {"copper_ore": 2, "charcoal": 1} and smelter["out"] == {"copper": 1},
		"2 Copper Ore + 1 Charcoal make Copper"
	)
	t.check(
		crucible["in"] == {"copper": 3, "tin": 1} and crucible["out"] == {"bronze": 1}, "3 Copper + 1 Tin make Bronze"
	)
	t.check(smelter["tech"] == "smelting" and crucible["tech"] == "alloying", "they come with Smelting and Alloying")
	for type in ["smelter", "crucible"]:
		var s := grown(42)
		var at: Vector2i = s.world.camp_pos + Vector2i(-3, 2)
		t.check(t.place_free(s, type, at), "a %s goes up by the Hearth" % type)
		var b: Dictionary = s.town.buildings[s.town.building_at[at]]
		var made: String = Data.BUILDINGS[type]["out"].keys()[0]
		for id in Data.BUILDINGS[type]["in"]:
			b["inbuf"][id] = Data.BUILDINGS[type]["in"][id]
		for i in 600:
			s.economy.inv["berries"] = 999
			s.tick(0.1)
		var held: int = b["out"].get(made, 0)
		t.check(held == 1, "the %s makes one %s (%d)" % [type, made, held])
		for id in Data.BUILDINGS[type]["in"]:
			t.check(b["inbuf"].get(id, 0) == 0, "and uses its %s" % id)


# --- Tech effects ------------------------------------------------------------


func test_era_two_tech_effects() -> void:
	var s: Sim = t.fresh()
	t.give(s, 0)
	var base: Dictionary = Data.TECHS["prospecting"]["cost"]
	t.check(s.tech_tree.cost_of("prospecting") == base, "no discount before Tally Sticks")
	s.tech_tree.researched["tally_sticks"] = true
	var cheap: Dictionary = s.tech_tree.cost_of("prospecting")
	for id in base:
		t.check(cheap[id] == maxi(roundi(base[id] * Data.TALLY_DISCOUNT), 1), "Tally Sticks: %s costs 10%% less" % id)
		t.check(cheap[id] < base[id], "%s is cheaper" % id)
	for id in cheap:
		s.economy.inv[id] = cheap[id]
	t.check(not s.research("prospecting"), "its parent comes first")
	s.tech_tree.researched["bronze_dawn"] = true
	t.check(s.research("prospecting"), "the discounted price is enough")
	for id in cheap:
		t.check(s.economy.inv[id] == 0, "%s was paid in full, no more" % id)
	# The log keeps counts once Tally Sticks is known.
	var plain := Messages.new()
	plain.push("A Kith was born", 3.0)
	plain.push("A Kith was born", 3.0)
	t.check(plain.history.size() == 2, "without Tally Sticks every message is a line")
	var counted := Messages.new()
	counted.keep_counts = true
	counted.push("A Kith was born", 3.0)
	counted.push("A Kith was born", 3.0)
	counted.push("Food is low", 3.0)
	counted.push("A Kith was born", 3.0)
	t.check(counted.history.size() == 3, "with it a repeat is one line (%d)" % counted.history.size())
	t.check(Messages.entry_text(counted.history[0]) == Data.LOG_COUNT % ["A Kith was born", 2], "that says how many")
	t.check(Messages.entry_text(counted.history[1]) == "Food is low", "a single message is just its text")
	# The Plough: Fields yield half as much again.
	var f: Sim = t.fresh()
	t.give(f, 999)
	var grass: Vector2i = t.find_grass(f, false)
	t.place_free(f, "gatherers_hut", f.world.camp_pos + Vector2i(-2, 0))
	var hut: Dictionary = f.town.buildings[f.town.buildings.size() - 1]
	f.world.fields[grass] = true
	var n: int = Work.bundle_size(f, hut, "grain")
	var total := 0
	for i in 20:
		total += Work.harvest_amount(f, hut, grass, "grain")
	t.check(total == 20 * n, "a Field gives its bundle (%d)" % total)
	hut["field_extra"] = 0.0
	f.tech_tree.researched["plough"] = true
	total = 0
	for i in 20:
		total += Work.harvest_amount(f, hut, grass, "grain")
	var want := roundi(20.0 * n * (1.0 + Data.PLOUGH_FIELD_BONUS))
	t.check(absi(total - want) <= 1, "the Plough adds half again (%d, want %d)" % [total, want])
	f.tech_tree.researched["calendar"] = true
	hut["field_extra"] = 0.0
	total = 0
	for i in 20:
		total += Work.harvest_amount(f, hut, grass, "grain")
	want = roundi(20.0 * n * (1.0 + Data.PLOUGH_FIELD_BONUS + Data.CALENDAR_FIELD_BONUS))
	t.check(absi(total - want) <= 1, "with the Calendar the shares add up (%d, want %d)" % [total, want])
	# Kilns II: a Kiln makes twice the Brick.
	var k: Sim = t.fresh()
	t.give(k, 999)
	t.place_free(k, "kiln", k.world.camp_pos + Vector2i(-2, 2))
	var kiln: Dictionary = k.town.buildings[k.town.buildings.size() - 1]
	t.check(Bonuses.output(k, kiln) == 1.0, "a Kiln makes its two Brick")
	k.tech_tree.researched["kilns_ii"] = true
	t.check(Bonuses.output(k, kiln) == 2.0, "Kilns II doubles it")
	var grind := {"type": "grindstone", "pos": k.world.camp_pos, "worker": -1}
	t.check(Bonuses.output(k, grind) == 1.0, "and only the Kiln")
	kiln["inbuf"] = {"clay": 1, "charcoal": 1}
	kiln["out"] = {}
	Work.finish_cycle(k, kiln)
	t.check(kiln["out"].get("brick", 0) == 4, "a firing gives four Brick (%d)" % kiln["out"].get("brick", 0))


# --- Saves -------------------------------------------------------------------


func test_a_grown_game_saves_and_loads() -> void:
	var a := grown(42)
	for type in ["mine", "smelter", "crucible"]:
		var at: Vector2i = (
			hills(a) if type == "mine" else a.world.camp_pos + Vector2i(-3, 2 if type == "smelter" else 4)
		)
		t.place_free(a, type, at)
	for i in 300:
		a.economy.inv["berries"] = 999
		a.tick(0.1)
	var d := RunSave.dump(a)
	var text := RunSave.to_json(d)
	var b := Sim.new()
	t.check(RunSave.restore(b, d), "a grown game loads into a fresh Sim")
	t.check(b.world.width == a.world.width and b.world.stone_width == a.world.stone_width, "the grown size is kept")
	t.check(b.world.tiles == a.world.tiles and b.world.is_grown(), "and the grown tiles")
	t.check(RunSave.to_json(RunSave.dump(b)) == text, "it writes back the same save")
	var c := Sim.new()
	t.check(RunSave.restore(c, RunSave.from_json(text)), "and so does the JSON text of it")
	t.check(c.world.tiles == a.world.tiles and c.world.width == a.world.width, "with the grown map in it")
	var kinds: Array = []
	for bb in c.town.buildings:
		kinds.append(bb["type"])
	t.check("mine" in kinds and "smelter" in kinds and "crucible" in kinds, "the new buildings are back: %s" % [kinds])
	for i in a.town.buildings.size():
		var x: Dictionary = a.town.buildings[i]
		var y: Dictionary = c.town.buildings[i]
		t.check(
			x["mate"] == y["mate"] and x["ore"] == y["ore"] and x["worker"] == y["worker"],
			"%s keeps its crew and ore" % x["type"]
		)
	for i in 200:
		a.tick(0.1)
		b.tick(0.1)
	t.check(RunSave.to_json(RunSave.dump(b)) == RunSave.to_json(RunSave.dump(a)), "and goes on like the original")
	t.check(not b.world.grow_east(), "a loaded game doesn't grow twice")
	# A save made at the moment of Bronze Dawn grows the land when it is loaded and played on.
	var moment := dawn(7)
	var e := Sim.new()
	t.check(RunSave.restore(e, RunSave.dump(moment)), "a save from the moment of Bronze Dawn loads")
	t.check(not e.world.is_grown() and e.won, "it is still the stone age's last moment")
	e.tick(0.1)
	moment.tick(0.1)
	t.check(
		e.world.is_grown() and e.world.tiles == moment.world.tiles, "the land grows on the next tick, the same land"
	)
	# A stone-age save has no growth in it.
	var old: Sim = t.fresh()
	var f := Sim.new()
	t.check(RunSave.restore(f, RunSave.from_json(RunSave.to_json(RunSave.dump(old)))), "a stone-age save loads")
	t.check(not f.world.is_grown() and f.world.width == old.world.width, "and stays the stone age")


# --- The tech panel ----------------------------------------------------------


func test_the_tech_panel_has_a_tab_per_era() -> void:
	var s: Sim = t.fresh()
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel.refresh()
	t.check(panel.era_buttons.size() == Data.ERAS.size(), "one tab per era")
	t.check(
		panel.era_buttons[1].button_pressed and not panel.era_buttons[2].button_pressed, "the stone age tab is open"
	)
	t.check(panel.era_buttons[2].disabled, "the next era's tab is locked")
	t.check(panel.era_buttons[2].tooltip_text == Data.ERA_TAB_LOCKED, "and says when it opens")
	t.check(panel.board.era == 1 and panel.title.text == Data.BOARD_TITLE % "Stone Age", "the board is the stone age's")
	panel._pick_era(2)
	t.check(panel.board.era == 1, "a locked tab does nothing")
	t.check(panel.counter.text.contains("of 28"), "the counter counts the era's techs (%s)" % panel.counter.text)
	s.tech_tree.researched["bronze_dawn"] = true
	panel.refresh()
	t.check(not panel.era_buttons[2].disabled, "Bronze Dawn opens the second tab")
	panel._pick_era(2)
	t.check(panel.board.era == 2 and panel.era_buttons[2].button_pressed, "and it shows the second tree")
	t.check(
		panel.title.text == Data.BOARD_TITLE % "Bronze Dawn" and panel.counter.text.contains("of 16"),
		"with its own title and count"
	)
	panel._pick_view("all")
	for tech in Rules.era_techs(2):
		t.check(
			panel.board.shows(tech) and panel.board.card_rect(tech).size.x > 0.0,
			tech + " has a card on the second board"
		)
	for tech in Rules.era_techs(1):
		t.check(not panel.board.shows(tech), tech + " is not on it")
	panel.free()
