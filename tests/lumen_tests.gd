extends RefCounted
## Starfall part D (design-system/16-starfall.md, "Stage 5 as built"): the Lumen tab and the four buildings a glyph set opens. Each card
## opens only on its set, a Grove and a Shardwright work only in shardlight (the Cairn's or a Lantern's), a staffed Healing House helps
## the homes round it, and the road a gift is refused on never shuts the Lumen Ward out. Run from tests/run_tests.gd.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Mender = preload("res://scripts/mender.gd")
const RunSave = preload("res://scripts/run_save.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")

var t  # the runner, tests/run_tests.gd
var _h  # the stage 1 tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_each_card_opens_only_on_its_set()
	test_refusing_a_gift_leaves_its_card_shut_except_growth_and_craft()
	test_the_lantern_lights_gatherers_and_the_cairn_keeps_its_own_light()
	test_a_grove_and_a_shardwright_work_only_in_shardlight()
	test_starfruit_is_a_food_and_shardwork_a_good()
	test_a_staffed_healing_house_helps_the_homes_round_it()
	test_the_lumen_tab_shows_the_cards()
	test_an_old_save_mid_starfall_gets_the_buildings()
	test_the_ward_opens_with_craft_on_every_road()
	test_the_ward_lifts_trust_once_and_is_a_goal()
	test_every_road_reaches_the_warning()
	test_an_old_save_with_a_ward_owed_shows_the_goal()


## An arrived town with full stores, the name read and the strangers' questions answered, and a Cairn.
func _town() -> Sim:
	var s: Sim = _h._arrived()
	t.give(s, 200)
	s.starfall.locked["name"] = true
	for id in Data.MOMENT_ORDER:
		s.starfall.answered[id] = 0
	s.town.add_building("shard_cairn", _away(s, s.world.camp_pos, 3.0, 5.0))
	return s


## A free tile between `lo` and `hi` tiles from `from`.
func _away(s: Sim, from: Vector2i, lo: float, hi: float) -> Vector2i:
	for r in range(int(lo), int(hi) + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p: Vector2i = from + Vector2i(dx, dy)
				var d := Vector2(p - from).length()
				if (
					d >= lo
					and d <= hi
					and s.world.in_bounds(p)
					and Data.TILES[s.world.tile_at(p)]["buildable"]
					and not s.town.building_at.has(p)
					and not s.world.roads.has(p)
				):
					return p
	return Vector2i(-1, -1)


## The Kith read the set `id` and take its gift (the card goes up, and the first answer takes it).
func _take(s: Sim, id: String) -> void:
	for n in Data.GLYPH_SETS:
		if Data.GLYPH_SETS[n]["id"] == id:
			for g in Data.GLYPH_SETS[n]["glyphs"]:
				if not s.starfall.copied.has(g):
					s.starfall.copied.append(g)
				s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	s.starfall.check()
	s.starfall.tick(0.1)
	s.starfall.choose(0)


func _refuse(s: Sim, id: String) -> void:
	for n in Data.GLYPH_SETS:
		if Data.GLYPH_SETS[n]["id"] == id:
			for g in Data.GLYPH_SETS[n]["glyphs"]:
				if not s.starfall.copied.has(g):
					s.starfall.copied.append(g)
				s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	s.starfall.check()
	s.starfall.tick(0.1)
	s.starfall.choose(1)


func _type_of(id: String) -> String:
	return Data.LUMEN["cards"][id]["building"]


func _run(s: Sim, seconds: float) -> void:
	for i in int(seconds * 4.0):
		s.tick(0.25)


func test_each_card_opens_only_on_its_set() -> void:
	var s := _town()
	var spot: Vector2i = _h._spot(s, "dwelling")
	for id in Data.ROAD_ORDER:
		var type := _type_of(id)
		t.check(not s.starfall.opens(id) and not s.town.unlocked(type), "%s waits for the %s marks" % [type, id])
		t.check(s.town.placement_error(type, spot) == "Not discovered yet", "and can't be placed before then")
	for id in Data.ROAD_ORDER:
		for n in Data.GLYPH_SETS:
			if Data.GLYPH_SETS[n]["id"] == id:
				for g in Data.GLYPH_SETS[n]["glyphs"]:
					s.starfall.copied.append(g)
					s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
		s.starfall.check()
		t.check(
			s.starfall.locked.has(id) and not s.starfall.opens(id), "%s is read but its card waits for the road" % id
		)
		s.starfall.tick(0.1)
		s.starfall.choose(0)
		t.check(
			s.starfall.opens(id) and s.town.unlocked(_type_of(id)), "taking the %s gift opens %s" % [id, _type_of(id)]
		)
		for other in Data.ROAD_ORDER:
			if Data.ROAD_ORDER.find(other) > Data.ROAD_ORDER.find(id):
				t.check(not s.town.unlocked(_type_of(other)), "while %s stays shut" % _type_of(other))
	t.check(s.town.placement_error("starfruit_grove", spot) == "", "an open card can be placed")


func test_refusing_a_gift_leaves_its_card_shut_except_growth_and_craft() -> void:
	var s := _town()
	for id in Data.ROAD_ORDER:
		_refuse(s, id)
	t.check(s.starfall.refusals() == 4, "every gift refused")
	t.check(not s.town.unlocked("shard_lantern") and not s.town.unlocked("healing_house"), "Light and Body stay shut")
	t.check(s.town.unlocked("starfruit_grove"), "the Kith's own orchard still opens the Grove")
	t.check(s.town.unlocked("shardwright"), "and their own way to bind shard opens the Shardwright")
	t.check(s.starfall.opens("growth") and s.starfall.opens("craft"), "the cards say so")


func test_the_lantern_lights_gatherers_and_the_cairn_keeps_its_own_light() -> void:
	var s := _town()
	_take(s, "light")
	var cairn: Vector2i = s.town.buildings.filter(func(b): return b["type"] == "shard_cairn")[0]["pos"]
	var near: Vector2i = _away(s, cairn, 1.0, 2.0)
	var far: Vector2i = _away(s, cairn, 8.0, 10.0)
	s.town.add_building("gatherers_hut", near)
	s.town.add_building("gatherers_hut", far)
	var near_hut: Dictionary = s.town.buildings[s.town.building_at[near]]
	var far_hut: Dictionary = s.town.buildings[s.town.building_at[far]]
	var ids := func(b): return Bonuses.active(s, b, "").map(func(p): return p["id"])
	t.check("shardlight" in ids.call(near_hut), "a hut in the Cairn's light works faster")
	t.check("shardlight" not in ids.call(far_hut), "a hut far from any light does not")
	t.check(Bonuses.lit(s, near) and not Bonuses.lit(s, far), "lit() says where the light reaches")
	s.town.add_building("shard_lantern", _away(s, far, 1.0, 2.0))
	t.check("shardlight" in ids.call(far_hut), "a Lantern beside it brings the light")
	s.starfall.dim_left = 100.0  # the Shards: the Cairn's light is lent away
	t.check("shardlight" not in ids.call(near_hut) and "shardlight" in ids.call(far_hut), "the Lantern keeps its light")


func test_a_grove_and_a_shardwright_work_only_in_shardlight() -> void:
	var s := _town()
	_take(s, "growth")
	_take(s, "craft")
	for i in 4:
		s.people.add_kith()
	var cairn: Vector2i = s.town.buildings.filter(func(b): return b["type"] == "shard_cairn")[0]["pos"]
	var dark: Vector2i = _away(s, cairn, 7.0, 10.0)
	var lit: Vector2i = _away(s, cairn, 1.0, 3.0)
	s.town.add_building("starfruit_grove", dark)
	s.town.add_building("shardwright", lit)
	var grove: Dictionary = s.town.buildings[s.town.building_at[dark]]
	var wright: Dictionary = s.town.buildings[s.town.building_at[lit]]
	wright["inbuf"] = {"rope": 8, "bronze": 4}
	var starfruit: int = s.economy.inv["starfruit"]
	_run(s, 60.0)
	t.check(grove["alert"] == Data.LUMEN["needs_light"], "a Grove out of the light says: %s" % grove["alert"])
	t.check(grove["status"].begins_with("Needs shardlight"), "with the reason: %s" % grove["status"])
	t.check(s.economy.inv["starfruit"] == starfruit and grove["out"].get("starfruit", 0) == 0, "and grows nothing")
	t.check(
		wright["alert"] != Data.LUMEN["needs_light"] and s.economy.made_ever.has("shardwork"),
		"a Shardwright in the Cairn's light binds Shardwork"
	)
	s.town.add_building("shard_lantern", _away(s, dark, 1.0, 2.0))
	_run(s, 60.0)
	t.check(
		(
			grove["alert"] != Data.LUMEN["needs_light"]
			and (grove["out"].get("starfruit", 0) > 0 or s.economy.inv["starfruit"] > starfruit)
		),
		"a Lantern beside it wakes the Grove"
	)
	s.starfall.dim_left = 100.0
	wright["inbuf"] = {"rope": 8, "bronze": 4}
	_run(s, 10.0)
	t.check(
		wright["alert"] == Data.LUMEN["needs_light"],
		"the Shards lend the Cairn's light away, and the Shardwright stops"
	)


func test_starfruit_is_a_food_and_shardwork_a_good() -> void:
	t.check(Data.FOOD_VALUE["starfruit"] == 2.0 and "starfruit" in Data.EAT_ORDER, "Starfruit is worth two berries")
	t.check(
		Data.ITEMS.has("shardwork") and "shardwork" in Data.ITEM_ORDER and not Data.FOOD_VALUE.has("shardwork"),
		"Shardwork is a good"
	)
	var s: Sim = t.fresh()
	s.economy.inv["berries"] = 0
	s.economy.inv["starfruit"] = 10
	s.economy.food_credit = 0.0
	t.check(is_equal_approx(s.economy.food_total(), 20.0), "ten Starfruit feed twenty berries' worth")
	t.check(s.economy.eat(4.0) and s.economy.inv["starfruit"] == 8, "and the Kith eat them like any food")


func test_a_staffed_healing_house_helps_the_homes_round_it() -> void:
	var s := _town()
	_take(s, "body")
	for i in 3:
		s.people.add_kith()
	var base: float = s.people.grow_time()
	t.check(Mender.cover(s.town) == 0.0, "no Healing House, no help")
	var spot: Vector2i = _away(s, s.world.camp_pos, 2.0, 4.0)
	s.town.add_building("healing_house", spot)
	var house: Dictionary = s.town.buildings[s.town.building_at[spot]]
	house["worker"] = -1
	t.check(Mender.cover(s.town) == 0.0 and is_equal_approx(s.people.grow_time(), base), "an empty one helps no one")
	s.tick(0.1)  # a Kith is sent to work it
	t.check(house["worker"] >= 0, "a Kith is sent to be the Mender")
	t.check(Mender.cover(s.town) == 1.0, "it reaches the Hearth, the only home")
	t.check(is_equal_approx(s.people.grow_time(), base * Data.HEALER_GROW), "births come 20% sooner")
	s.town.add_building("dwelling", _away(s, spot, 9.0, 11.0))
	var cover: float = Mender.cover(s.town)
	t.check(cover > 0.0 and cover < 1.0, "a home beyond its reach is not helped (%s)" % cover)
	t.check(s.people.grow_time() < base and s.people.grow_time() > base * Data.HEALER_GROW, "so the help is partial")
	var k: Dictionary = s.people.kith[house["worker"]]
	k["tool"] = 5
	k["tool_id"] = "flint_tools"
	k["wear_acc"] = 0.0
	s.people.wear(house)  # the Mender's own tool wears as a job is done
	t.check(
		is_equal_approx(k["wear_acc"], 1.0 - (1.0 - Data.HEALER_WEAR) * cover),
		"tools wear slower in step with the cover"
	)
	house["paused"] = true
	t.check(Mender.cover(s.town) == 0.0, "a paused Healing House helps no one")


func test_the_lumen_tab_shows_the_cards() -> void:
	var early: Sim = t.fresh()
	var panel := TechPanel.new()
	panel.setup(early)
	panel.visible = true
	panel.refresh()
	t.check(
		panel.lumen_tab.disabled and panel.lumen_tab.tooltip_text == Data.LUMEN["tab_locked"],
		"the tab waits for the strangers"
	)
	panel._pick_lumen()
	t.check(not panel.lumen_on, "and does nothing before they come")
	panel.free()
	var s := _town()
	panel = TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel.refresh()
	t.check(not panel.lumen_tab.disabled, "once they have come, the tab opens")
	panel._pick_lumen()
	t.check(
		panel.lumen_on and panel.lumen.visible and not panel.next_view.visible and not panel.board.visible,
		"and shows the cards"
	)
	t.check(panel.title.text == Data.LUMEN["title"] and panel.lumen_tab.button_pressed, "with its own title")
	t.check(panel.lumen.cards.size() == 4, "four cards")
	for id in Data.ROAD_ORDER:
		t.check(
			_has_text(panel.lumen.cards[id], Data.LUMEN["closed"] % Data.LUMEN["cards"][id]["set"]),
			"%s's card is shut: read its marks" % id
		)
	_take(s, "light")
	panel.refresh()
	t.check(
		(
			_has_text(panel.lumen.cards["light"], "Shard Lantern")
			and _has_text(panel.lumen.cards["light"], "None standing yet")
		),
		"an open card names its building"
	)
	t.check(_has_text(panel.lumen.cards["body"], Data.LUMEN["closed"] % "Body"), "and the others stay shut")
	s.town.add_building("shard_lantern", _away(s, s.world.camp_pos, 3.0, 6.0))
	panel.refresh()
	t.check(_has_text(panel.lumen.cards["light"], "1 standing"), "it counts what stands")
	panel._pick_era(1)
	t.check(
		not panel.lumen_on and not panel.lumen.visible and panel.next_view.visible, "an era tab takes the panel back"
	)
	panel.free()


func _has_text(node: Node, text: String) -> bool:
	for c in node.find_children("*", "Label", true, false):
		if c.text.contains(text):
			return true
	return false


func test_an_old_save_mid_starfall_gets_the_buildings() -> void:
	var s := _town()
	s.starfall.locked["light"] = true  # a save from before the Lumen tab: the set was read and its gift taken
	s.starfall.locked["growth"] = true
	var old: Dictionary = RunSave.dump(s)
	var back := Sim.new()
	back.generate(1)
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(old))), "the old save loads")
	t.check(
		back.town.unlocked("shard_lantern") and back.town.unlocked("starfruit_grove"),
		"the sets it read open their buildings"
	)
	t.check(not back.town.unlocked("healing_house") and not back.town.unlocked("shardwright"), "and the rest wait")


func test_the_ward_opens_with_craft_on_every_road() -> void:
	var s := _town()
	var spot: Vector2i = _h._spot(s, "lumen_ward")
	t.check(
		not s.town.unlocked("lumen_ward") and s.town.placement_error("lumen_ward", spot) == "Not discovered yet",
		"no Ward before the Craft marks"
	)
	_take(s, "light")
	_take(s, "growth")
	t.check(not s.town.unlocked("lumen_ward"), "other sets do not open it")
	_take(s, "craft")
	t.check(
		s.town.unlocked("lumen_ward") and s.town.placement_error("lumen_ward", spot) == "", "reading Craft opens it"
	)
	var goods: Dictionary = Data.BUILDINGS["lumen_ward"]["cost"]
	var before: Dictionary = s.economy.inv.duplicate()
	t.check(s.place("lumen_ward", spot), "and it is built like any building")
	for id in goods:
		t.check(s.economy.inv[id] == before[id] - goods[id], "paying %d %s" % [goods[id], id])
	t.check(
		s.starfall.ward_stands() and s.town.placement_error("lumen_ward", _h._spot(s, "lumen_ward")) != "",
		"one Ward is all there is"
	)
	var refused := _town()
	for id in Data.ROAD_ORDER:
		_refuse(refused, id)
	t.check(refused.town.unlocked("lumen_ward"), "the Kith who refused every gift can still raise the Ward")
	t.check(
		refused.town.unlocked("shardwright") and refused.town.unlocked("starfruit_grove"),
		"and make what it is built of"
	)


func test_the_ward_lifts_trust_once_and_is_a_goal() -> void:
	var s := _town()
	_take(s, "craft")
	s.starfall.trust = 40.0
	s.starfall.tick(1.0)
	t.check(is_equal_approx(s.starfall.trust, 40.0), "no Ward, no change")
	s.town.add_building("lumen_ward", _h._spot(s, "lumen_ward"))
	s.starfall.tick(1.0)
	t.check(
		s.starfall.trust >= 50.0 and s.starfall.trust < 51.0,
		"a standing Ward lifts trust by 10 (%s)" % s.starfall.trust
	)
	var after: float = s.starfall.trust
	s.starfall.tick(30.0)
	t.check(is_equal_approx(s.starfall.trust, after), "once, not each minute")
	var ids: Array = Data.GOALS_ERA3.map(func(g): return g["id"])
	t.check(
		"lumen_ward" in ids and ids.find("lumen_ward") < ids.find("moments_answered"),
		"Raise the Lumen Ward is one of the era's goals"
	)
	var bare := _town()
	_take(bare, "craft")
	t.check(not bare.story.goal_met(bare, Data.GOALS_ERA3[ids.find("lumen_ward")]), "not met until it stands")
	t.check(s.story.goal_met(s, Data.GOALS_ERA3[ids.find("lumen_ward")]), "met once it does")


## The all-refused road: every gift turned down, and the Warning can still be read once the Ward stands and the questions are answered.
func test_every_road_reaches_the_warning() -> void:
	for refuse in [true, false]:
		var s := _town()
		for id in Data.ROAD_ORDER:
			if refuse:
				_refuse(s, id)
			else:
				_take(s, id)
		s.starfall.locked["name"] = true
		for g in Data.GLYPH_SETS[6]["glyphs"]:
			s.starfall.copied.append(g)
			s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
		var road := "refused" if refuse else "taken"
		t.check(
			not s.starfall.check() and not s.starfall.locked.has("warning"), "every gift %s: no Ward, no Warning" % road
		)
		t.check(
			s.town.unlocked("shardwright") and s.town.unlocked("starfruit_grove") and s.town.unlocked("lumen_ward"),
			"every gift %s: the Ward and what it needs are open" % road
		)
		s.economy.inv["shardwork"] = 0
		s.economy.inv["starfruit"] = 0
		t.check(
			not s.place("lumen_ward", _h._spot(s, "lumen_ward")), "every gift %s: the goods are made, not given" % road
		)
		s.economy.inv["shardwork"] = 30
		s.economy.inv["starfruit"] = 60
		t.check(s.place("lumen_ward", _h._spot(s, "lumen_ward")), "every gift %s: the Ward goes up" % road)
		t.check(s.starfall.check() and s.starfall.ended, "every gift %s: and the Warning reads" % road)


func test_an_old_save_with_a_ward_owed_shows_the_goal() -> void:
	var s := _town()
	_take(s, "craft")
	s.starfall.locked["warning"] = false  # the Warning is still ahead
	s.starfall.locked.erase("warning")
	var back := Sim.new()
	back.generate(1)
	t.check(
		RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))),
		"a save with the Craft marks read loads"
	)
	t.check(back.town.unlocked("lumen_ward") and not back.starfall.ward_stands(), "the Ward is open and owed")
	var ward_goal: Dictionary = Data.GOALS_ERA3.filter(func(g): return g["id"] == "lumen_ward")[0]
	t.check(
		back.story.goal_list().has(ward_goal) and not back.story.goal_met(back, ward_goal), "and the goal shows, unmet"
	)
	for g in Data.GLYPH_SETS[6]["glyphs"]:
		back.starfall.copied.append(g)
		back.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	for id in Data.MOMENT_ORDER:
		back.starfall.answered[id] = 0
	t.check(not back.starfall.may_end(), "the Warning will not read without it")
