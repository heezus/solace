extends RefCounted
## Unit testbench for the Buildings block (scripts/buildings.gd): the placement rules, placing and tearing
## down, the refund, pausing, power and aura range, housing and the work rules that live in the block.
## Buildings is built alone, on a hand-made World, an Economy with a hand-set stockpile and a hand-set set
## of researched techs; no Kith, no fog block and no GameState. The last tests check GameState's
## pass-throughs and the effects it runs around a placement or a demolition (fog, walking grid, workers).
## Run from tests/run_tests.gd, which owns check() and the helpers.

const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Fog = preload("res://scripts/fog.gd")
const GameState = preload("res://scripts/game_state.gd")
const Research = preload("res://scripts/research.gd")
const Rules = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world.gd")

var t  # the runner, tests/run_tests.gd
var _techs: Dictionary = {}  # the researched techs
var _eco: Economy
var _world: World
var _unseen: Dictionary = {}  # tiles the fog still covers (everything else is seen)
var _camp := Vector2i(1, 4)


func run(runner) -> void:
	t = runner
	test_unlocked_follows_the_tech()
	test_errors_in_order()
	test_unexplored_tiles_refuse()
	test_wrong_terrain()
	test_cost_is_checked_last()
	test_roads_bridges_and_fields()
	test_a_pass_costs_stone()
	test_needs_river_and_shard()
	test_near_hearth_edge()
	test_place_pays_and_books_a_building()
	test_a_refused_place_changes_nothing()
	test_place_clears_rocks_and_trees()
	test_place_a_bridge_and_a_field()
	test_built_type()
	test_demolish_a_building()
	test_demolish_a_road_and_a_field()
	test_demolish_refuses_nothing_and_the_hearth()
	test_remove_at_reindexes()
	test_road_rev_bumps()
	test_pause_and_status()
	test_timers_count_down()
	test_power_range()
	test_aura_range()
	test_housing()
	test_hut_radius_and_gathering()
	test_wants_to_work()
	test_static_helpers()
	test_buildings_stand_alone()
	test_game_state_passes_through()
	test_game_state_place_runs_the_effects()
	test_game_state_demolish_frees_the_worker()
	test_game_state_pause_frees_the_worker()


func _seen(p: Vector2i) -> bool:
	return not _unseen.has(p)


func _shard_seen() -> bool:
	return false


## A Buildings block on a 12 by 8 map of grass with the Hearth at (1, 4), an Economy that holds exactly
## `stock` (every other count zero) and the techs in `done` researched. The pieces are left in _world, _eco
## and _techs for a test to look at.
func _block(stock: Dictionary = {}, done: Array = []) -> Buildings:
	_techs = {}
	for id in done:
		_techs[id] = true
	_unseen = {}
	_eco = Economy.new(_techs)
	for id in _eco.inv:
		_eco.inv[id] = 0
	for id in stock:
		_eco.inv[id] = stock[id]
	_world = World.new(12, 8)
	_world.camp_pos = _camp
	var b := Buildings.new(_world, _eco, Research.new(_eco, _techs, _shard_seen), _seen)
	b.add_building("camp", _camp)
	return b


func _rich() -> Dictionary:
	return {"wood": 100, "stone": 100, "fiber": 100, "rope": 100, "grain": 100, "clay": 100, "brick": 100}


func test_unlocked_follows_the_tech() -> void:
	var b := _block()
	t.check(b.unlocked("camp") and b.unlocked("dwelling"), "buildings with no tech are always unlocked")
	t.check(not b.unlocked("charcoal_pit"), "a workshop waits for its tech")
	_techs["fire"] = true
	t.check(b.unlocked("charcoal_pit"), "and opens once it is researched")


func test_errors_in_order() -> void:
	var b := _block()
	t.check(
		b.placement_error("charcoal_pit", Vector2i(-3, 0)) == "Not discovered yet", "a locked building says so first"
	)
	t.check(b.placement_error("dwelling", Vector2i(-1, 0)) == "Off the map", "off the left edge")
	t.check(b.placement_error("dwelling", Vector2i(12, 0)) == "Off the map", "off the right edge")
	t.check(b.placement_error("dwelling", Vector2i(3, 8)) == "Off the map", "off the bottom")
	t.check(b.placement_error("dwelling", _camp) == "Something is already there", "the Hearth's tile is taken")
	_world.add_road(Vector2i(3, 3))
	t.check(b.placement_error("dwelling", Vector2i(3, 3)) == "Something is already there", "so is a road")
	t.check(b.placement_error("dwelling", Vector2i(3, 4)) == "Not enough materials", "an empty stockpile can't pay")


func test_unexplored_tiles_refuse() -> void:
	var b := _block(_rich())
	_unseen[Vector2i(4, 4)] = true
	t.check(b.placement_error("dwelling", Vector2i(4, 4)).begins_with("Unexplored"), "fog blocks building")
	t.check(b.placement_error("dwelling", Vector2i(4, 3)) == "", "seen ground is fine")
	_unseen[_camp] = true
	t.check(b.placement_error("dwelling", _camp).begins_with("Unexplored"), "fog is asked before what stands there")


func test_wrong_terrain() -> void:
	var b := _block(_rich(), ["fire", "gatherers_hut"])
	_world.set_tile(Vector2i(3, 3), "tree")
	_world.set_tile(Vector2i(4, 3), "river")
	_world.set_tile(Vector2i(5, 3), "berry")
	for p in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]:
		t.check(b.placement_error("dwelling", p) == "Build on open grassland", "no Dwelling on %s" % _world.tile_at(p))
		t.check(b.placement_error("charcoal_pit", p) == "Build on open grassland", "nor a Charcoal Pit on it")
	t.check(b.placement_error("charcoal_pit", Vector2i(3, 5)) == "", "grass takes a Charcoal Pit")


func test_cost_is_checked_last() -> void:
	var b := _block({"wood": 12, "fiber": 5})
	t.check(b.placement_error("dwelling", Vector2i(3, 4)) == "Not enough materials", "one item short")
	_eco.inv["fiber"] = 6
	t.check(b.placement_error("dwelling", Vector2i(3, 4)) == "", "the exact cost is enough")
	t.check(
		b.placement_error("dwelling", Vector2i(9, 4)) == "Must be within 6 tiles of the Hearth", "but range comes first"
	)


func test_roads_bridges_and_fields() -> void:
	var b := _block(_rich(), ["haulers", "farming"])
	_world.set_tile(Vector2i(4, 2), "river")
	_world.set_tile(Vector2i(5, 2), "flax")
	_world.set_tile(Vector2i(6, 2), "tree")
	_world.set_tile(Vector2i(7, 2), "rock")
	t.check(b.placement_error("road", Vector2i(4, 2)).begins_with("Roads can't cross the river"), "no road on water")
	t.check(b.placement_error("road", Vector2i(5, 2)).begins_with("Roads go on grassland"), "no road on flax")
	t.check(b.placement_error("road", Vector2i(3, 2)) == "", "a road on grass")
	t.check(b.placement_error("road", Vector2i(6, 2)) == "", "a road through Forest")
	t.check(b.placement_error("road", Vector2i(7, 2)) == "", "a road cutting Rocks")
	t.check(b.placement_error("bridge", Vector2i(3, 2)) == "Bridges go on river tiles", "a bridge needs water")
	t.check(b.placement_error("bridge", Vector2i(4, 2)) == "", "a bridge on the river")
	t.check(b.placement_error("field", Vector2i(5, 2)) == "Fields go on open grassland", "no field on flax")
	t.check(b.placement_error("field", Vector2i(3, 2)) == "", "a field on grass")
	_eco.inv["wood"] = 1
	t.check(b.placement_error("road", Vector2i(3, 2)) == "Not enough materials", "a road costs 2 wood")
	_eco.inv["rope"] = 0
	_eco.inv["wood"] = 100
	t.check(b.placement_error("bridge", Vector2i(4, 2)) == "Not enough materials", "a bridge needs rope")
	_eco.inv["grain"] = 0
	t.check(b.placement_error("field", Vector2i(3, 2)) == "Not enough materials", "a field needs grain to sow")


func test_a_pass_costs_stone() -> void:
	var b := _block({"stone": 2}, ["haulers"])
	_world.set_tile(Vector2i(4, 2), "rock")
	t.check(Rules.cost_at("road", "rock") == Data.PASS_COST, "the pass has its own cost")
	t.check(b.placement_error("road", Vector2i(4, 2)) == "Not enough materials", "wood doesn't cut a pass")
	_eco.inv["stone"] = 3
	t.check(b.placement_error("road", Vector2i(4, 2)) == "", "3 Stone is enough, and no wood is needed")


func test_needs_river_and_shard() -> void:
	var b := _block(_rich(), ["water_wheel", "star_lore"])
	_world.set_tile(Vector2i(6, 2), "river")
	_world.set_tile(Vector2i(9, 6), "shard")
	t.check(b.placement_error("water_wheel", Vector2i(3, 4)) == "Must touch the river", "a wheel away from the water")
	t.check(b.placement_error("water_wheel", Vector2i(6, 3)) == "", "a wheel beside it")
	t.check(b.placement_error("water_wheel", Vector2i(5, 3)) == "Must touch the river", "a diagonal doesn't touch")
	t.check(b.placement_error("shard_cairn", Vector2i(3, 4)) == "Must go next to the Strange Stone", "a cairn far away")
	t.check(b.placement_error("shard_cairn", Vector2i(9, 5)) == "", "a cairn beside the shard")


func test_near_hearth_edge() -> void:
	var b := _block(_rich())
	t.check(b.near_hearth(Vector2i(7, 4)), "exactly 6 tiles out is near")
	t.check(not b.near_hearth(Vector2i(8, 4)), "7 tiles is not")
	t.check(b.placement_error("dwelling", Vector2i(7, 4)) == "", "a Dwelling at the edge")
	t.check(b.placement_error("dwelling", Vector2i(8, 4)) == "Must be within 6 tiles of the Hearth", "and just past it")
	t.check(b.placement_error("storehouse", Vector2i(8, 4)) == "Not discovered yet", "other buildings aren't limited")
	_techs["storehouse"] = true
	t.check(b.placement_error("storehouse", Vector2i(10, 4)) == "", "a Storehouse can go far away")


func test_place_pays_and_books_a_building() -> void:
	var b := _block({"wood": 20, "fiber": 7})
	var at := Vector2i(3, 4)
	var rev := b.road_rev
	var done := b.place("dwelling", at)
	t.check(done == {"kind": "house", "cleared": ""}, "place reports what it built")
	t.check(_eco.inv["wood"] == 8 and _eco.inv["fiber"] == 1, "it pays the cost")
	t.check(b.buildings.size() == 2 and b.buildings[1]["pos"] == at, "the Dwelling is added after the Hearth")
	t.check(b.building_at[at] == 1 and b.building_at[_camp] == 0, "building_at points at both")
	t.check(b.buildings[1]["worker"] == -1 and not b.buildings[1]["paused"], "it starts idle")
	t.check(b.road_rev == rev + 1, "and the road networks are marked stale")
	t.check(b.placement_error("dwelling", at) == "Something is already there", "the tile is taken now")


func test_a_refused_place_changes_nothing() -> void:
	var b := _block({"wood": 5})
	var rev := b.road_rev
	t.check(b.place("dwelling", Vector2i(3, 4)).is_empty(), "no materials, no building")
	t.check(b.place("dwelling", Vector2i(-1, 4)).is_empty(), "off the map, no building")
	t.check(_eco.inv["wood"] == 5 and b.buildings.size() == 1, "nothing was paid or added")
	t.check(b.road_rev == rev and not b.building_at.has(Vector2i(3, 4)), "and nothing is marked")


func test_place_clears_rocks_and_trees() -> void:
	var b := _block(_rich(), ["haulers"])
	_world.set_tile(Vector2i(4, 2), "rock")
	_world.set_tile(Vector2i(5, 2), "tree")
	var stone: int = _eco.inv["stone"]
	var wood: int = _eco.inv["wood"]
	var pass_road := b.place("road", Vector2i(4, 2))
	t.check(pass_road == {"kind": "road", "cleared": "rock"}, "a road through Rocks reports the pass")
	t.check(_world.tile_at(Vector2i(4, 2)) == "grass" and _world.roads.has(Vector2i(4, 2)), "the rock is cut away")
	t.check(_eco.inv["stone"] == stone - 3 and _eco.inv["wood"] == wood, "and a pass costs stone, not wood")
	var felled := b.place("road", Vector2i(5, 2))
	t.check(felled == {"kind": "road", "cleared": "tree"}, "a road through Forest reports the felling")
	t.check(_world.tile_at(Vector2i(5, 2)) == "grass" and _eco.inv["wood"] == wood - 2, "the trees are felled")
	t.check(b.buildings.size() == 1, "roads are not buildings")


func test_place_a_bridge_and_a_field() -> void:
	var b := _block(_rich(), ["haulers", "farming"])
	_world.set_tile(Vector2i(4, 2), "river")
	var bridge := b.place("bridge", Vector2i(4, 2))
	t.check(bridge == {"kind": "bridge", "cleared": ""}, "a bridge clears nothing")
	t.check(_world.tile_at(Vector2i(4, 2)) == "river" and _world.roads.has(Vector2i(4, 2)), "the river stays under it")
	var field := b.place("field", Vector2i(3, 2))
	t.check(field == {"kind": "field", "cleared": ""}, "a field")
	t.check(_world.fields.has(Vector2i(3, 2)) and _world.tile_at(Vector2i(3, 2)) == "grain", "it is sown")
	t.check(b.buildings.size() == 1 and b.building_at.size() == 1, "neither is a building")


func test_built_type() -> void:
	var b := _block(_rich(), ["haulers", "farming"])
	_world.set_tile(Vector2i(4, 2), "river")
	b.place("dwelling", Vector2i(3, 4))
	b.place("road", Vector2i(3, 2))
	b.place("bridge", Vector2i(4, 2))
	b.place("field", Vector2i(5, 2))
	t.check(b.built_type(_camp) == "camp", "the Hearth")
	t.check(b.built_type(Vector2i(3, 4)) == "dwelling", "a building")
	t.check(b.built_type(Vector2i(3, 2)) == "road", "a road")
	t.check(b.built_type(Vector2i(4, 2)) == "bridge", "a road over the river is a bridge")
	t.check(b.built_type(Vector2i(5, 2)) == "field", "a field")
	t.check(b.built_type(Vector2i(9, 9)) == "", "nothing")


func test_demolish_a_building() -> void:
	var b := _block({"wood": 12, "fiber": 6})
	var at := Vector2i(3, 4)
	b.place("dwelling", at)
	t.check(_eco.inv["wood"] == 0 and _eco.inv["fiber"] == 0, "paid in full")
	var done := b.demolish(at)
	t.check(done["type"] == "dwelling" and done["index"] == 1, "it says what and where")
	t.check(done["refund"] == {"wood": 6, "fiber": 3}, "half the cost comes back")
	t.check(_eco.inv["wood"] == 6 and _eco.inv["fiber"] == 3, "into the stockpile")
	t.check(b.buildings.size() == 2, "the building stays on the list until the owner has freed its worker")
	b.remove_at(done["index"])
	t.check(b.buildings.size() == 1 and not b.building_at.has(at), "then remove_at takes it off")


func test_demolish_a_road_and_a_field() -> void:
	var b := _block(_rich(), ["haulers", "farming"])
	b.place("road", Vector2i(3, 2))
	b.place("field", Vector2i(4, 2))
	var wood: int = _eco.inv["wood"]
	var road := b.demolish(Vector2i(3, 2))
	t.check(road["type"] == "road" and road["index"] == -1, "a road needs no follow-up")
	t.check(not _world.roads.has(Vector2i(3, 2)), "it is off the World")
	t.check(road["refund"] == {"wood": 1} and _eco.inv["wood"] == wood + 1, "and half its wood is back")
	var field := b.demolish(Vector2i(4, 2))
	t.check(field["type"] == "field" and field["index"] == -1, "so is a field")
	t.check(not _world.fields.has(Vector2i(4, 2)) and _world.tile_at(Vector2i(4, 2)) == "grass", "the grass comes back")
	t.check(field["refund"] == {"fiber": 1}, "a field's half of 3 fiber and 1 grain rounds down")


func test_demolish_refuses_nothing_and_the_hearth() -> void:
	var b := _block(_rich())
	var wood: int = _eco.inv["wood"]
	var rev := b.road_rev
	t.check(b.demolish(Vector2i(6, 6)).is_empty(), "empty ground")
	t.check(b.demolish(_camp).is_empty(), "the Hearth stays")
	t.check(b.demolish(Vector2i(-2, 0)).is_empty(), "off the map")
	t.check(b.buildings.size() == 1 and _eco.inv["wood"] == wood and b.road_rev == rev, "and nothing changed")


func test_remove_at_reindexes() -> void:
	var b := _block(_rich())
	var spots := [Vector2i(3, 4), Vector2i(5, 4), Vector2i(3, 6), Vector2i(5, 6)]
	for p in spots:
		b.place("dwelling", p)
	t.check(b.buildings.size() == 5, "the Hearth and four Dwellings")
	b.remove_at(2)  # the Dwelling at (5, 4)
	t.check(b.buildings.size() == 4 and not b.building_at.has(spots[1]), "the middle one is gone")
	t.check(b.buildings.map(func(x): return x["pos"]) == [_camp, spots[0], spots[2], spots[3]], "the order is kept")
	var consistent := b.building_at.size() == b.buildings.size()
	for i in b.buildings.size():
		consistent = consistent and b.building_at.get(b.buildings[i]["pos"], -1) == i
	t.check(consistent, "building_at agrees with the list after the shuffle")
	b.remove_at(3)  # the last one
	t.check(b.building_at.size() == 3 and not b.building_at.has(spots[3]), "the last can go too")
	t.check(b.place("dwelling", spots[1]) == {"kind": "house", "cleared": ""}, "a freed tile can be built on again")
	t.check(b.building_at[spots[1]] == 3, "at the end of the list")


func test_road_rev_bumps() -> void:
	var b := _block(_rich(), ["haulers"])
	var rev := b.road_rev
	b.place("road", Vector2i(3, 2))
	t.check(b.road_rev == rev + 1, "a road bumps it")
	b.place("dwelling", Vector2i(3, 4))
	t.check(b.road_rev == rev + 2, "so does a building")
	b.demolish(Vector2i(3, 2))
	t.check(b.road_rev == rev + 3, "and a demolition")
	b.road_net = {"rev": rev}
	t.check(b.road_net.get("rev") == rev, "road_net is the caller's cache, kept as it is given")


func test_pause_and_status() -> void:
	var b := _block(_rich())
	b.place("dwelling", Vector2i(3, 4))
	b.set_paused(1, true)
	t.check(b.buildings[1]["paused"] and not b.buildings[0]["paused"], "only that building pauses")
	b.set_paused(1, false)
	t.check(not b.buildings[1]["paused"], "and resumes")
	b.set_status(b.buildings[1], "Working", "Warning")
	t.check(
		b.buildings[1]["status"] == "Working" and b.buildings[1]["alert"] == "Warning",
		"status and alert are set together"
	)


func test_timers_count_down() -> void:
	var b := _block()
	var camp: Dictionary = b.buildings[0]
	camp["unreachable"] = 1.0
	camp["rush_cd"] = 0.25
	b.tick_timers(camp, 0.5)
	t.check(
		is_equal_approx(camp["unreachable"], 0.5) and is_equal_approx(camp["rush_cd"], 0.0),
		"both count down, none below 0"
	)
	b.tick_timers(camp, 2.0)
	t.check(camp["unreachable"] == 0.0 and camp["rush_cd"] == 0.0, "and stay at 0")


func test_power_range() -> void:
	var b := _block(_rich(), ["water_wheel"])
	_world.set_tile(Vector2i(6, 2), "river")
	t.check(not b.is_powered(Vector2i(6, 4)), "no wheel, no power")
	t.check(b.place("water_wheel", Vector2i(6, 3)).has("kind"), "a Water Wheel beside the river")
	t.check(b.is_powered(Vector2i(6, 3)) and b.is_powered(Vector2i(6, 6)), "the wheel and 3 tiles away are powered")
	t.check(b.is_powered(Vector2i(8, 5)), "a diagonal within the radius (2.8 tiles)")
	t.check(not b.is_powered(Vector2i(6, 7)), "4 tiles away is not")
	t.check(not b.in_range_of("aura", Vector2i(6, 4)), "power is not an aura")


func test_aura_range() -> void:
	var b := _block(_rich(), ["megaliths"])
	b.place("standing_stone", Vector2i(5, 4))
	t.check(b.in_range_of("aura", Vector2i(6, 5)), "a diagonal is next door")
	t.check(b.in_range_of("aura", Vector2i(4, 4)), "so is the side")
	t.check(not b.in_range_of("aura", Vector2i(7, 4)), "two tiles away is not")


func test_housing() -> void:
	var b := _block(_rich())
	t.check(b.housing() == 4, "the Hearth houses 4")
	b.place("dwelling", Vector2i(3, 4))
	t.check(b.housing() == 7, "a Dwelling adds 3")
	_techs["shelter"] = true
	t.check(b.housing() == 9, "Shelter adds 2 to each Dwelling, and not to the Hearth")


func test_hut_radius_and_gathering() -> void:
	var b := _block(_rich(), ["gatherers_hut"])
	_world.set_tile(Vector2i(6, 4), "tree")  # 2 tiles from the hut at (4, 4)
	_world.set_tile(Vector2i(7, 4), "rock")  # 3 tiles
	_world.set_tile(Vector2i(4, 2), "berry")
	t.check(b.hut_radius() == 2, "a hut reaches 2 tiles")
	t.check(
		b.gather_tiles(Vector2i(4, 4)) == [Vector2i(4, 2), Vector2i(6, 4)], "and finds the resource tiles in row order"
	)
	b.place("gatherers_hut", Vector2i(4, 4))
	t.check(b.buildings[1]["gather_items"] == ["berries", "wood"], "the hut remembers what it can gather")
	_techs["scouting"] = true
	t.check(b.hut_radius() == 3, "Scouting adds a tile")
	t.check(b.gather_tiles(Vector2i(4, 4)).size() == 3, "and a third resource comes into reach")
	b.place("gatherers_hut", Vector2i(2, 7))
	t.check(b.buildings[2]["gather_items"].is_empty(), "a hut with nothing near gathers nothing")


func test_wants_to_work() -> void:
	var b := _block(_rich(), ["gatherers_hut", "fire", "water_wheel", "grindstone"])
	_world.set_tile(Vector2i(6, 2), "river")
	b.place("gatherers_hut", Vector2i(3, 4))
	b.place("charcoal_pit", Vector2i(3, 6))
	b.place("grindstone", Vector2i(6, 5))
	var hut: Dictionary = b.buildings[1]
	var pit: Dictionary = b.buildings[2]
	var mill: Dictionary = b.buildings[3]
	t.check(b.wants_to_work(hut), "an empty hut has room")
	hut["out"] = {"wood": Data.BUFFER_CAP}
	t.check(not b.wants_to_work(hut), "a full hut waits for a hauler")
	hut["out"] = {"wood": 4, "stone": 5}
	t.check(b.wants_to_work(hut), "the whole buffer counts, not one item")
	hut["out"] = {"wood": 5, "stone": 5}
	t.check(not b.wants_to_work(hut), "so 5 and 5 is full")
	t.check(not b.wants_to_work(pit), "a workshop with no input has nothing to do")
	pit["inbuf"] = {"wood": 1}
	t.check(not b.wants_to_work(pit), "one wood is short of 2")
	pit["inbuf"] = {"wood": 2}
	t.check(b.wants_to_work(pit), "enough wood")
	pit["out"] = {"charcoal": Data.BUFFER_CAP}
	t.check(not b.wants_to_work(pit), "but not with a full output")
	mill["inbuf"] = {"grain": 2}
	t.check(not b.wants_to_work(mill), "a Grindstone needs power")
	b.place("water_wheel", Vector2i(6, 3))
	t.check(b.wants_to_work(mill), "and works beside a wheel")
	t.check(not b.wants_to_work(b.buildings[0]), "the Hearth has no work")


func test_static_helpers() -> void:
	t.check(Buildings.buffered({}) == 0 and Buildings.buffered({"wood": 3, "stone": 4}) == 7, "buffered adds it all up")
	var hut := {"type": "gatherers_hut"}
	t.check(
		Buildings.needs_worker(hut) and Buildings.needs_worker({"type": "kiln"}), "huts and workshops take a worker"
	)
	t.check(
		not Buildings.needs_worker({"type": "camp"}) and not Buildings.needs_worker({"type": "water_wheel"}),
		"others don't"
	)


func test_buildings_stand_alone() -> void:
	var b := _block(_rich(), ["haulers"])
	var before := _world.tiles.duplicate()
	b.placement_error("road", Vector2i(3, 2))
	b.built_type(Vector2i(3, 2))
	b.wants_to_work(b.buildings[0])
	t.check(_world.tiles == before and _world.roads.is_empty(), "asking questions never changes the map")
	t.check(_eco.inv["wood"] == 100 and _techs.size() == 1, "or the stockpile or the techs")
	b.place("road", Vector2i(3, 2))
	t.check(_techs.size() == 1, "placing never writes the techs")


func test_game_state_passes_through() -> void:
	var s: GameState = t.fresh()
	t.check(is_same(s.buildings, s.town.buildings), "buildings is the block's list")
	t.check(is_same(s.building_at, s.town.building_at), "so is building_at")
	s.road_rev += 1
	t.check(s.road_rev == s.town.road_rev, "road_rev is the block's")
	s.road_net = {"rev": 7}
	t.check(s.town.road_net["rev"] == 7, "and so is road_net")
	t.check(
		s.building_at.has(s.camp_pos) and s.buildings[s.building_at[s.camp_pos]]["type"] == "camp",
		"the Hearth is booked"
	)
	t.check(s.built_type(s.camp_pos) == "camp" and s.building_unlocked("dwelling"), "queries ask the block")
	t.check(not s.building_unlocked("charcoal_pit"), "locked buildings are locked")
	t.check(s.hut_radius() == 2 and s.housing() == 4, "so do hut_radius and housing")
	t.check(s.is_powered(s.camp_pos) == s.town.is_powered(s.camp_pos), "and is_powered")
	t.check(s.buffered({"a": 2}) == 2 and s.needs_worker({"type": "kiln"}), "and the small helpers")
	t.check(s.placement_error("dwelling", s.camp_pos) == "Something is already there", "placement_error too")


func test_game_state_place_runs_the_effects() -> void:
	var s: GameState = t.fresh()
	t.give(s, 100)
	s.researched["haulers"] = true
	s.researched["scouting"] = true
	s.researched["farming"] = true
	var events_before := s.events.size()
	var river: Vector2i = t.find_tile(s, "river")
	t.check(s.place("bridge", river), "a bridge goes down")
	t.check(not s.astar.is_point_solid(river), "the walking grid is refreshed")
	t.check(is_equal_approx(s.walk_cost(river), Data.WALK_COST["road"]), "the bridge is a road for walking")
	var grass: Vector2i = s.camp_pos + Vector2i(0, 2)
	s.world.set_tile(grass, "grass")
	s.fog.cells.fill(0)
	s.fog.reveal(grass, 0)
	t.check(s.place("dwelling", grass), "a Dwelling")
	var want := Fog.new()
	want.setup(GameState.WIDTH, GameState.HEIGHT)
	want.reveal(grass, Data.SIGHT_BUILDING + Data.SCOUTING_SIGHT)
	t.check(
		s.fog.count() == want.count() and s.fog.is_revealed(grass), "the fog lifts around it, by its sight and Scouting"
	)
	s.fog.reveal_all()
	var wood: Vector2i = s.camp_pos + Vector2i(2, -3)
	s.world.set_tile(wood, "tree")
	t.check(s.place("road", wood) and s.tile_at(wood) == "grass", "a road through Forest")
	t.check(
		s.events.size() == events_before + 1 and s.events[-1] == "Felled the trees for a road", "the player is told"
	)
	var rock: Vector2i = s.camp_pos + Vector2i(3, -3)
	s.world.set_tile(rock, "rock")
	t.check(s.place("road", rock), "a road through Rocks")
	t.check(s.events[-1] == "Cut a pass through the rocks", "the player is told")
	var side: Array = [s.camp_pos + Vector2i(-1, 2), s.camp_pos + Vector2i(-2, 2), grass]
	t.check(s.place_line("road", side) == 2, "place_line counts the ones that went (the Dwelling blocks one)")
	var field: Vector2i = s.camp_pos + Vector2i(-3, 3)
	s.world.set_tile(field, "grass")
	t.check(s.place("field", field) and s.fields.has(field), "and a field")
	t.check(is_equal_approx(s.walk_cost(field), 1.0) and not s.astar.is_point_solid(field), "the grid takes the field")
	var n := s.events.size()
	s.inv["wood"] = 0
	t.check(not s.place("road", s.camp_pos + Vector2i(-4, 2)) and s.events.size() == n, "a refused place says nothing")


func test_game_state_demolish_frees_the_worker() -> void:
	var s: GameState = t.fresh()
	t.give(s, 100)
	s.researched["gatherers_hut"] = true
	var first := s.camp_pos + Vector2i(0, 2)
	var second := s.camp_pos + Vector2i(2, 2)
	s.world.set_tile(first, "grass")
	s.world.set_tile(second, "grass")
	t.check(s.place("gatherers_hut", first) and s.place("gatherers_hut", second), "two huts")
	s.tick(0.1)
	var w2: int = s.buildings[s.building_at[second]]["worker"]
	t.check(s.buildings[s.building_at[first]]["worker"] >= 0 and w2 >= 0, "both are staffed")
	var refund := s.demolish(first)
	t.check(refund == Rules.refund_of("gatherers_hut"), "the refund comes back")
	t.check(not s.building_at.has(first) and s.building_at[second] == 1, "the other hut moves up the list")
	t.check(s.kith[w2]["building"] == 1 and s.buildings[1]["worker"] == w2, "and its worker follows it")
	t.check(s.events[-1] == "Tore down the Gatherer's Hut", "the player is told")
	t.check(
		s.demolish(first).is_empty() and s.demolish(s.camp_pos).is_empty(),
		"nothing to tear down twice, and the Hearth stays"
	)


func test_game_state_pause_frees_the_worker() -> void:
	var s: GameState = t.fresh()
	t.give(s, 100)
	s.researched["gatherers_hut"] = true
	var p := s.camp_pos + Vector2i(0, 2)
	s.world.set_tile(p, "grass")
	s.place("gatherers_hut", p)
	s.tick(0.1)
	var i: int = s.building_at[p]
	var w: int = s.buildings[i]["worker"]
	t.check(w >= 0, "staffed")
	s.set_paused(i, true)
	t.check(
		s.buildings[i]["paused"] and s.buildings[i]["worker"] < 0 and s.kith[w]["job"] == "", "pausing frees the worker"
	)
	s.set_paused(i, false)
	t.check(not s.buildings[i]["paused"] and s.buildings[i]["worker"] < 0, "resuming leaves it to the next assignment")
