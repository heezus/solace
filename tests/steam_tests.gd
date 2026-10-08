extends RefCounted
## Ironfall stage 3 (design-system/19-ironfall.md): steam and the end. The Boiler and the Shard Boiler, the Shard Lamp, Rail and
## the Steam Cart, the Beast Pen and its beast cart, Steel and Steel Tools, the Iron Plough, Taught Hands II, the Shard chipped
## from the Strange Stone, Bloom Sampling, the gifts and Lessons some techs wait for, Lantern Parties and the Livewire gate with
## its end card. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const World = preload("res://scripts/world.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Land = preload("res://scripts/land.gd")
const Rules = preload("res://scripts/rules.gd")
const Roads = preload("res://scripts/roads.gd")
const Steam = preload("res://scripts/steam.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Hands = preload("res://scripts/hands.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Patch = preload("res://scripts/patch.gd")
const Kith = preload("res://scripts/kith.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Finds = preload("res://scripts/teardown_finds.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ExpeditionPicker = preload("res://scripts/expedition_picker.gd")
const EraCard = preload("res://scripts/era_card.gd")
const CardText = preload("res://scripts/card_text.gd")
const Work = preload("res://scripts/work.gd")

## Every tech of the stage, the ones a town needs to have for the buildings to be on offer.
const STAGE_TECHS := [
	"boiler",
	"beast_pen",
	"rails",
	"shard_lamps",
	"taught_hands_ii",
	"blast_furnace",
	"iron_plough",
	"shard_boiler",
	"steel",
	"bloom_sampling",
	"livewire"
]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_stage_three_data_is_whole()
	test_rail_is_eight_times_open_ground()
	test_a_stone_bridge_stays_paved()
	test_the_boiler_burns_for_a_machine_that_wants_power()
	test_a_cold_boiler_leaves_the_forge_without_power()
	test_the_forge_makes_steel()
	test_the_shard_boiler_and_the_shard_lamp()
	test_a_steam_cart_runs_on_rail_and_burns_coal()
	test_a_steam_cart_hauls_coal_to_a_boiler()
	test_a_beast_pen_tames_a_beast()
	test_steel_and_steel_tools()
	test_the_blast_furnace_doubles_the_bloomery()
	test_the_iron_plough()
	test_taught_hands_two()
	test_the_strange_stone_gives_shards()
	test_bloom_sampling_gates_the_samples()
	test_gifts_and_lessons_gate_techs()
	test_the_lantern_party()
	test_livewire_ends_the_age()
	test_stage_three_saves_and_loads()


# --- Helpers ------------------------------------------------------------------


## A town in Ironfall: the map grown east and south, the stage's techs open (the buildings' own are researched by the tests), the
## fog lifted and a stocked stockpile.
func town(map_seed := 2) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	for tech in ["bronze_dawn", "haulers", "coal_seams", "ironstone", "teardown", "bloomery", "iron_tools", "boiler"]:
		s.tech_tree.researched[tech] = true
	Land.grow_if_due(s)
	s.fog.reveal_all()
	t.give(s, 400)
	s.story.record(Data.IRONFALL_EVENT)
	return s


## An open tile (of a kind that takes `_type`) between `lo` and `hi` tiles from `around` ((-1, -1) when none).
func spot(s: Sim, _type: String, around: Vector2i, lo := 2, hi := 6) -> Vector2i:
	for r in range(lo, hi + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p := around + Vector2i(dx, dy)
				if (
					maxi(absi(dx), absi(dy)) == r
					and Data.TILES[s.world.tile_at(p)]["buildable"]
					and not s.town.building_at.has(p)
				):
					return p
	return Vector2i(-1, -1)


## Lay `tier` road on every tile from a to b (a straight run), clearing the trees on the way. False when a river is in the way.
func lay(s: Sim, a: Vector2i, b: Vector2i, tier: int) -> bool:
	var tiles := Rules.line_tiles(a, b)
	if tiles.any(func(p): return s.world.tile_at(p) == "river" or s.town.building_at.has(p)):
		return false
	for p in tiles:
		if s.world.tile_at(p) in ["tree", "rock"]:
			s.world.set_tile(p, "grass")
		s.world.add_road(p, tier)
		s.pathing.update_cell(p)
	s.town.road_rev += 1
	return true


## A straight run of `n` tiles east of the Hearth that can take a road, as [first, last]; fills the row with grass first.
func run_east(s: Sim, n: int) -> Array:
	var c: Vector2i = s.world.camp_pos
	for dy in range(0, 12):
		for flip in [1, -1]:
			var y: int = c.y + dy * flip
			var a := Vector2i(c.x + 1, y)
			var b := Vector2i(c.x + n, y)
			if Rules.line_tiles(a, b).all(
				func(p): return s.world.in_bounds(p) and s.world.tile_at(p) != "river" and not s.town.building_at.has(p)
			):
				return [a, b]
	return []


func feed(s: Sim, seconds: float, step := 0.5) -> void:
	for i in int(seconds / step):
		s.economy.inv["berries"] = 999
		s.tick(step)


## A Boiler, and a Forge within its reach with inputs on its shelf. Returns [boiler, forge] (the building dictionaries).
func forge_by_boiler(s: Sim, fuel_type := "boiler") -> Array:
	var around: Vector2i = s.world.camp_pos + Vector2i(0, 3)
	var bp := spot(s, fuel_type, around, 1, 5)
	s.town.add_building(fuel_type, bp)
	var fp := spot(s, "forge", bp, 1, 3)
	s.town.add_building("forge", fp)
	var boiler: Dictionary = s.town.buildings[s.town.building_at[bp]]
	var forge: Dictionary = s.town.buildings[s.town.building_at[fp]]
	forge["inbuf"] = {"iron": 6, "coal": 3}
	return [boiler, forge]


# --- The data -----------------------------------------------------------------


func test_stage_three_data_is_whole() -> void:
	t.check(Data.BUILT_STAGE == 3, "the game is built to stage 3")
	for id in STAGE_TECHS:
		t.check(Data.TECHS.has(id) and Rules.tech_enabled(id), "%s is on the board and can be bought" % id)
		t.check(Data.TECHS[id]["era"] == 4 and int(Data.TECHS[id]["stage"]) == 3, "%s belongs to stage 3" % id)
	t.check(Data.TECHS["livewire"]["lane"] == "gate", "Livewire is the gate")
	t.check(
		Data.TECHS["livewire"]["cost"] == {"steel": 100, "iron": 100, "brick": 60, "rope": 40},
		"and costs steel, iron, brick and rope"
	)
	t.check(Data.TECHS["livewire"]["lessons"] == ["spore", "root", "sap"], "and wants the three Bloom Lessons")
	for type in ["boiler", "shard_boiler", "forge", "steam_shed", "beast_pen", "shard_lamp", "rail"]:
		t.check(Data.BUILDINGS.has(type) and Data.BUILD_ORDER.has(type), "%s is a building on the bar" % type)
		var in_tab := false
		for tab in Data.BUILD_TABS:
			in_tab = in_tab or type in Data.BUILD_TABS[tab]
		t.check(in_tab, "%s has a tab" % type)
	for type in ["boiler", "shard_boiler", "shard_lamp", "beast_pen"]:
		t.check(
			Data.BUILDINGS[type].get("fed", false) and not Data.BUILDINGS[type]["in"].is_empty(),
			"%s is fed by haulers" % type
		)
		t.check(not Buildings.needs_worker(_fake(type)), "%s needs no worker" % type)
		t.check(Buildings.served(_fake(type)), "but haulers serve it")
	t.check(
		Data.BUILDINGS["boiler"]["radius"] == 5 and Data.BUILDINGS["shard_boiler"]["radius"] == 5,
		"boilers reach 5 tiles"
	)
	t.check(Data.BUILDINGS["shard_lamp"]["light"] == Data.LAMP_LIGHT, "a lamp lights its tiles")
	t.check(Data.BUILDINGS["forge"].get("needs_power", false), "the Forge needs power")
	t.check(Data.BUILDINGS["forge"]["out"] == {"steel": 1}, "and makes Steel")
	for item in ["steel", "steel_tools", "shard"]:
		t.check(Data.ITEMS.has(item) and Data.ITEM_ORDER.has(item), "%s is a top-bar good" % item)
	t.check(Data.RECIPES["steel_tools"]["tech"] == "steel", "Steel Tools wait for Steel")
	t.check(Data.STEEL_TOOL_JOBS == 600 and Kith.tool_jobs("steel_tools") == 600, "a Steel Tool lasts 600 jobs")
	t.check(Data.STEEL_TOOL_JOBS > Data.IRON_TOOL_JOBS, "longer than iron")
	t.check(Data.TOOL_ITEMS[0] == "steel_tools", "a worker takes Steel first")
	t.check(
		Data.LIVEWIRE_EVENT in Data.STORY_EVENTS and Data.STORY_TECHS["livewire"] == Data.LIVEWIRE_EVENT,
		"Livewire is a story moment"
	)
	for id in ["lamp_core", "heat_plate", "sap"]:
		t.check(Data.LESSONS[id]["live"], "the %s Lesson is live" % id)
	t.check(not Data.BLOOM_SAMPLING_PLACEHOLDER, "and Bloom Sampling is a real tech")
	var goals: Array = Data.GOALS_ERA4.map(func(g): return g["id"])
	t.check(
		goals.size() == 21 and goals.size() == goals.duplicate().filter(func(x): return goals.count(x) == 1).size(),
		"21 goals, each once"
	)
	t.check(Data.GOALS_IRONFALL_CLOSING == Data.LIVEWIRE_NOTE, "the closing line is the end card's")


func _fake(type: String) -> Dictionary:
	return {"type": type}


# --- Rail -----------------------------------------------------------------------


func test_rail_is_eight_times_open_ground() -> void:
	var s := town()
	t.check(Data.RAIL_TIER == 3 and Data.ROAD_SPEEDS.size() == 4, "Rail is the fourth road tier")
	t.check(Data.PAVED_TIER == 2 and Data.ROAD_SPEEDS[Data.PAVED_TIER] == 1.5, "after paved")
	var row := run_east(s, 4)
	t.check(not row.is_empty(), "a row to lay it on")
	t.check(lay(s, row[0], row[1], Data.RAIL_TIER), "laid")
	var open: float = Data.WALK_COST.get("grass", 1.0)
	t.check(
		is_equal_approx(s.pathing.walk_cost(row[0]), open / 8.0),
		"a Kith crosses Rail eight times as fast as open ground"
	)
	t.check(s.town.built_type(row[0]) == "rail", "the tile says it is Rail")
	t.check(Rules.road_type(Data.RAIL_TIER) == "rail" and Rules.tier_of("rail") == 3, "Rules know the tier")
	t.check(Data.ROAD_PACE.size() == Data.ROAD_SPEEDS.size(), "and the hover text has a pace for it")
	var s2 := town()
	s2.tech_tree.researched["rails"] = true
	s2.tech_tree.researched["paved_roads"] = true
	var spot_row := run_east(s2, 3)
	t.check(s2.place("paved_road", spot_row[0]), "a paved road")
	var iron: int = s2.economy.inv["iron"]
	var wood: int = s2.economy.inv["wood"]
	t.check(s2.town.upgrade_error("rail", spot_row[0]) == "", "Rail goes over it")
	t.check(s2.place("rail", spot_row[0]), "and is laid")
	t.check(s2.world.road_tier(spot_row[0]) == Data.RAIL_TIER, "the tile is Rail now")
	var paid: Dictionary = Data.BUILDINGS["paved_road"]["cost"]
	var rail_cost: Dictionary = Data.BUILDINGS["rail"]["cost"]
	t.check(s2.economy.inv["iron"] == iron - rail_cost["iron"], "it paid its iron")
	t.check(
		s2.economy.inv["wood"] == wood - maxi(rail_cost["wood"] - paid.get("wood", 0), 0),
		"and only the difference in the rest"
	)
	t.check(s2.town.upgrade_error("paved_road", spot_row[0]) != "", "a paved road does not go back over Rail")
	t.check(s2.town.upgrade_error("rail", spot_row[0]) != "", "nor Rail over Rail")
	var river: Vector2i = t.find_tile(s2, "river")
	t.check(river.x >= 0 and s2.town.placement_error("rail", river) != "", "Rail stops at the river")
	var fresh: Sim = t.fresh()
	t.check(not fresh.town.unlocked("rail"), "Rail waits for its tech")


func test_a_stone_bridge_stays_paved() -> void:
	var s := town()
	var p := Vector2i(1, 1)
	s.world.add_stone_bridge(p)
	t.check(s.world.road_tier(p) == Data.PAVED_TIER, "a Stone Bridge walks at the paved pace, not the Rail's")
	t.check(Rules.tier_of("stone_bridge") == Data.PAVED_TIER, "and counts as paved")
	var old := Sim.new()
	old.generate(42)
	old.tech_tree.researched["paved_roads"] = true
	var q: Vector2i = old.world.camp_pos + Vector2i(1, 0)
	old.world.add_road(q, 0)
	var d := RunSave.dump(old)
	d["world"].erase("road_tiers")
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, d), "a save from before road tiers loads")
	t.check(loaded.world.road_tier(q) == Data.PAVED_TIER, "and its roads are paved, not Rail")


# --- The fire ---------------------------------------------------------------------


func test_the_boiler_burns_for_a_machine_that_wants_power() -> void:
	var s := town()
	var both := forge_by_boiler(s)
	var boiler: Dictionary = both[0]
	var forge: Dictionary = both[1]
	t.check(
		Vector2(boiler["pos"]).distance_to(Vector2(forge["pos"])) <= 5.0, "the Forge stands within the Boiler's reach"
	)
	t.check(not s.town.is_powered(forge["pos"]), "a Boiler with no fire powers nothing")
	boiler["inbuf"] = {"coal": 3}
	feed(s, 2.0)
	t.check(boiler["burn"] > 0.0, "it lights when the Forge, with a worker and its inputs, wants power")
	t.check(s.town.is_powered(forge["pos"]), "and powers it")
	t.check(boiler["inbuf"]["coal"] == 2, "burning one Coal")
	t.check(boiler["status"].begins_with("Burning"), "its card says so: %s" % boiler["status"])
	var left: float = boiler["burn"]
	feed(s, 3.0)
	t.check(boiler["burn"] < left, "the fire burns down")
	var idle := town()
	var quiet := forge_by_boiler(idle)
	quiet[1]["inbuf"] = {}
	quiet[0]["inbuf"] = {"coal": 3}
	feed(idle, 30.0)
	t.check(
		quiet[0]["burn"] == 0.0 and quiet[0]["inbuf"]["coal"] == 3,
		"with no machine wanting power the Boiler stays banked"
	)
	t.check(quiet[0]["status"].begins_with("Banked"), "and says so: %s" % quiet[0]["status"])


func test_a_cold_boiler_leaves_the_forge_without_power() -> void:
	var s := town()
	var both := forge_by_boiler(s)
	both[0]["inbuf"] = {}
	feed(s, 40.0)
	t.check(both[1]["out"].get("steel", 0) == 0 and both[1]["progress"] == 0.0, "no coal, no Steel")
	t.check(
		both[1]["alert"] == "No power" and both[1]["status"].begins_with("No power"),
		"the Forge says: %s" % both[1]["status"]
	)
	t.check(both[0]["alert"] == "Needs Coal", "and the Boiler asks for Coal")
	t.check(both[0]["status"].begins_with("Cold"), "(%s)" % both[0]["status"])
	var dry := town()
	var at := spot(dry, "forge", dry.world.camp_pos)
	dry.town.add_building("forge", at)
	t.check(not dry.town.is_powered(at), "a Forge with no Boiler or Wheel is unpowered")


func test_the_forge_makes_steel() -> void:
	var s := town()
	var both := forge_by_boiler(s)
	both[0]["inbuf"] = {"coal": 4}
	feed(s, 90.0)
	var forge: Dictionary = both[1]
	t.check(forge["out"].get("steel", 0) >= 1, "a Forge by a fed Boiler makes Steel (%s)" % [forge["out"]])
	t.check(forge["inbuf"]["iron"] <= 4 and forge["inbuf"]["coal"] <= 2, "from 2 Iron and 1 Coal a firing")
	t.check(Data.BUILDINGS["forge"]["job"] == "Smith", "by a Smith")


func test_the_shard_boiler_and_the_shard_lamp() -> void:
	var s := town()
	for tech in ["shard_boiler", "shard_lamps"]:
		s.tech_tree.researched[tech] = true
	t.check(not s.town.unlocked("shard_boiler"), "a Shard Boiler waits for the Heat plate")
	t.check(not s.town.unlocked("shard_lamp"), "a Shard Lamp for the Lamp core")
	s.teardown.lessons.append("heat_plate")
	t.check(s.town.unlocked("shard_boiler") and not s.town.unlocked("shard_lamp"), "the Heat plate opens one")
	s.teardown.lessons.append("lamp_core")
	t.check(s.town.unlocked("shard_lamp"), "the Lamp core the other")
	var both := forge_by_boiler(s, "shard_boiler")
	both[0]["inbuf"] = {"shard": 2}
	feed(s, 3.0)
	t.check(
		both[0]["burn"] > Data.SHARD_BOILER_BURN - 5.0,
		"a Shard Boiler burns a Shard for %d seconds" % Data.SHARD_BOILER_BURN
	)
	t.check(both[0]["inbuf"]["shard"] == 1 and s.town.is_powered(both[1]["pos"]), "and powers the Forge on it")
	t.check(Data.SHARD_BOILER_BURN > Data.BOILER_BURN * 3.0, "one Shard burns far longer than one Coal")
	var lamp_at := spot(s, "shard_lamp", s.world.camp_pos + Vector2i(0, -3), 1, 4)
	s.town.add_building("shard_lamp", lamp_at)
	var lamp: Dictionary = s.town.buildings[s.town.building_at[lamp_at]]
	feed(s, 2.0)
	t.check(
		lamp["burn"] == 0.0 and lamp["status"].begins_with(Data.LAMP_DARK) and lamp["alert"] == "Needs Shard",
		"a lamp with no Shard is dark"
	)
	t.check(not Steam.lamp_lit(s) and not Steam.lit_at(s, lamp_at), "and lights nothing")
	lamp["inbuf"] = {"shard": 2}
	feed(s, 2.0)
	t.check(
		lamp["burn"] > Data.LAMP_BURN - 5.0 and lamp["inbuf"]["shard"] == 1,
		"a Shard lights it for %d seconds" % Data.LAMP_BURN
	)
	t.check(Steam.lamp_lit(s) and Steam.lit_at(s, lamp_at + Vector2i(Data.LAMP_LIGHT, 0)), "it lights its tiles")
	t.check(not Steam.lit_at(s, lamp_at + Vector2i(Data.LAMP_LIGHT + 2, 0)), "and no further")
	lamp["burn"] = 0.5
	lamp["inbuf"] = {}
	feed(s, 2.0)
	t.check(not Steam.lamp_lit(s), "it goes out when the last Shard is spent")


# --- Carts ------------------------------------------------------------------------


func test_a_steam_cart_runs_on_rail_and_burns_coal() -> void:
	var s := town()
	s.tech_tree.researched["rails"] = true
	s.people.found(6)
	var shed := spot(s, "steam_shed", s.world.camp_pos, 2, 6)
	s.town.add_building("steam_shed", shed)
	t.check(s.town.carts_of("steam") == 0, "a Steam Shed with no Rail laid makes no cart")
	s.people.assign_jobs()
	t.check(s.people.kith.all(func(k): return k["cart_kind"] == ""), "so nobody drives one")
	var row := run_east(s, 4)
	t.check(lay(s, row[0], row[1], Data.RAIL_TIER), "Rail is laid")
	s.people.assign_jobs()
	var carts: Array = s.people.kith.filter(func(k): return k["cart_kind"] == "steam")
	t.check(carts.size() == 1 and s.town.carts_of("steam") == 1, "now one hauler drives a Steam Cart")
	var cart: Dictionary = carts[0]
	t.check(cart["cart"] and s.people.kith[0] == cart, "the first hauler: steam goes first")
	t.check(Roads.ride(cart) == "walk" and Haulers.carry_cap(s, cart) == Data.CARRY, "cold, it is a plain hauler")
	cart["hot"] = true
	t.check(
		Roads.ride(cart) == "rail" and Haulers.carry_cap(s, cart) == Data.CARRY * Data.STEAM_LOAD,
		"with steam up it carries 40, on Rail"
	)
	s.tech_tree.researched["carrying_poles"] = true
	t.check(Haulers.carry_cap(s, cart) == Data.CARRY * 2 * Data.STEAM_LOAD, "and Carrying Poles double that")
	s.tech_tree.researched.erase("carrying_poles")
	s.economy.inv["coal"] = 5
	cart["fire"] = 0
	t.check(Steam.can_stoke(s, cart), "with coal in the stockpile it can set out")
	Steam.stoke(s, cart)
	t.check(
		s.economy.inv["coal"] == 4 and cart["fire"] == Data.STEAM_TRIPS - 1,
		"a trip burns 1 Coal and leaves %d" % (Data.STEAM_TRIPS - 1)
	)
	Steam.stoke(s, cart)
	Steam.stoke(s, cart)
	t.check(s.economy.inv["coal"] == 4 and cart["fire"] == 0, "that Coal makes %d trips" % Data.STEAM_TRIPS)
	Steam.stoke(s, cart)
	t.check(s.economy.inv["coal"] == 3, "and then it burns another")
	s.economy.inv["coal"] = 0
	cart["fire"] = 0
	t.check(not Steam.can_stoke(s, cart), "with no coal it cannot")
	var beast := {"cart": true, "cart_kind": "beast"}
	var hand := {"cart": true, "cart_kind": "hand"}
	var camp: Vector2i = s.world.camp_pos
	var far: Vector2i = row[1] + Vector2i(1, 0)
	var steam := {"cart": true, "cart_kind": "steam", "hot": true}
	t.check(Roads.can_reach(s, steam, camp, far), "a Steam Cart rolls over Rail")
	t.check(not Roads.can_reach(s, beast, camp, far), "a beast cart keeps off it")
	t.check(
		Roads.can_reach(s, hand, camp, far) and Roads.can_reach(s, {}, camp, far),
		"while a hand cart and a walker use it"
	)
	var path := Roads.walk(s, cart, far)
	t.check(path and not cart["path"].is_empty(), "a hot cart finds its way along the Rail")
	var gravel := town()
	var gr := run_east(gravel, 4)
	t.check(lay(gravel, gr[0], gr[1], 1), "a gravel road")
	t.check(
		not Roads.can_reach(gravel, steam, gravel.world.camp_pos, gr[1] + Vector2i(1, 0)),
		"a Steam Cart will not run on it"
	)


func test_a_steam_cart_hauls_coal_to_a_boiler() -> void:
	var s := town()
	s.tech_tree.researched["rails"] = true
	s.people.found(6)
	var row := run_east(s, 8)
	t.check(lay(s, row[0], row[1] - Vector2i(1, 0), Data.RAIL_TIER), "Rail runs from the Hearth to a Boiler")
	var boiler_at: Vector2i = row[1]
	s.world.set_tile(boiler_at, "grass")
	s.town.add_building("boiler", boiler_at)
	s.town.add_building("steam_shed", spot(s, "steam_shed", s.world.camp_pos, 2, 6))
	s.town.road_rev += 1
	var boiler: Dictionary = s.town.buildings[s.town.building_at[boiler_at]]
	var coal: int = s.economy.inv["coal"]
	var rode := false
	var hot := false
	for i in 400:
		s.economy.inv["berries"] = 999
		s.tick(0.25)
		for k in s.people.kith:
			if k["cart_kind"] == "steam" and k["hot"] and not k["task"].is_empty():
				hot = true
				rode = rode or Roads.ride(k) == "rail"
		if boiler["inbuf"].get("coal", 0) >= 6:
			break
	t.check(boiler["inbuf"].get("coal", 0) >= 6, "a cart brought the Boiler its coal (%s)" % [boiler["inbuf"]])
	t.check(hot and rode, "with steam up, on Rail")
	t.check(s.economy.inv["coal"] <= coal - 6 - 1, "the stockpile paid for the coal and for the steam")


func test_a_beast_pen_tames_a_beast() -> void:
	var s := town()
	s.tech_tree.researched["beast_pen"] = true
	s.people.found(6)
	var at := spot(s, "beast_pen", s.world.camp_pos, 2, 6)
	t.check(s.town.placement_error("beast_pen", at) == "", "a Pen goes on open ground")
	s.town.add_building("beast_pen", at)
	var pen: Dictionary = s.town.buildings[s.town.building_at[at]]
	t.check(not Buildings.is_tamed(pen) and s.town.carts_of("beast") == 0, "no beast yet, so no cart")
	feed(s, 3.0)
	t.check(
		pen["alert"] == "Needs Grain" and pen["status"].begins_with("Taming the beast"),
		"an empty Pen asks for Grain: %s" % pen["status"]
	)
	t.check(Haulers._stock_wanted(s, pen) == {"grain": 4}, "haulers keep it stocked with Grain")
	for i in 90:
		pen["inbuf"]["grain"] = 4
		s.economy.inv["berries"] = 999
		s.tick(1.0)
	t.check(Buildings.is_tamed(pen), "fed Grain, the beast is tame")
	t.check(pen["progress"] == Data.BEAST_TAME and pen["status"] == Data.PEN_TAMED, "(%s)" % pen["status"])
	t.check(Haulers._stock_wanted(s, pen).is_empty(), "and the Pen asks for nothing more")
	t.check(s.town.carts_of("beast") == 1, "it pulls a beast cart")
	var carts: Array = s.people.kith.filter(func(k): return k["cart_kind"] == "beast")
	t.check(carts.size() == 1, "one hauler drives it")
	t.check(Haulers.carry_cap(s, carts[0]) == Data.CARRY * Data.BEAST_LOAD, "30 a trip")
	t.check(Roads.ride(carts[0]) == "beast", "on roads, never Rail")
	var wild := town()
	wild.town.add_building("beast_pen", spot(wild, "beast_pen", wild.world.camp_pos, 2, 6))
	wild.people.assign_jobs()
	t.check(wild.people.kith.all(func(k): return k["cart_kind"] != "beast"), "an untamed Pen gives no cart")


# --- Steel, tools, fields and hands -------------------------------------------------


func test_steel_and_steel_tools() -> void:
	var s := town()
	s.tech_tree.researched["steel"] = true
	s.economy.inv["steel_tools"] = 1
	s.economy.inv["iron_tools"] = 1
	s.economy.inv["bronze_tools"] = 1
	s.economy.inv["flint_tools"] = 1
	var hut: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", hut)
	var b: Dictionary = s.town.buildings[s.town.building_at[hut]]
	s.tick(0.1)
	var k: Dictionary = s.people.kith[b["worker"]]
	t.check(
		Kith.tool_of(k) == "steel_tools" and k["tool"] == Data.STEEL_TOOL_JOBS,
		"a worker takes Steel first, and it lasts 600 jobs"
	)
	t.check(
		is_equal_approx(Bonuses.speed(s, b), 3.25), "Steel Tools give 50 points over Iron (%.2f)" % Bonuses.speed(s, b)
	)
	t.check(Bonuses.tool_bonus("steel_tools") == 2.25 and Bonuses.tool_bonus("iron_tools") == 1.75, "the shares")
	t.check("steel_tools" in Data.BUILDINGS["tool_bench"]["makes"], "the Tool Bench makes them")
	s.hand_tools = true
	t.check(Hands.hold_time(s, "wood") <= Data.HAND_TOOLS["iron_tools"]["hold"], "by hand Steel is the quickest")
	s.economy.inv["steel"] = 1
	s.economy.inv["wood"] = 2
	s.economy.inv["steel_tools"] = 0
	t.check(
		Hands.craft(s, "steel_tools") and s.economy.inv["steel_tools"] == 1, "and is made by hand from Steel and Wood"
	)
	var fresh: Sim = t.fresh()
	t.give(fresh, 99)
	t.check(not Hands.recipe_unlocked(fresh, "steel_tools"), "but only once Steel is discovered")
	t.check(Data.TOOLS_TIP.count("%") >= 6, "the Tools readout has a place for the Steel Tools")


func test_the_blast_furnace_doubles_the_bloomery() -> void:
	var s := town()
	var at := spot(s, "bloomery", s.world.camp_pos, 2, 6)
	s.town.add_building("bloomery", at)
	var b: Dictionary = s.town.buildings[s.town.building_at[at]]
	t.check(is_equal_approx(Bonuses.output(s, b), 1.0), "a Bloomery makes one Iron a firing")
	s.tech_tree.researched["blast_furnace"] = true
	t.check(is_equal_approx(Bonuses.output(s, b), 2.0), "twice the Iron after the Blast Furnace")
	var forge_at := spot(s, "forge", s.world.camp_pos, 2, 6)
	s.town.add_building("forge", forge_at)
	var forge: Dictionary = s.town.buildings[s.town.building_at[forge_at]]
	t.check(is_equal_approx(Bonuses.output(s, forge), 1.0), "but a Forge keeps its one Steel")


func test_the_iron_plough() -> void:
	var s := town()
	var tile: Vector2i = s.world.camp_pos + Vector2i(3, 3)
	s.world.set_tile(tile, "grass")
	s.world.add_field(tile)
	var base := Patch.field_share(s, tile)
	s.tech_tree.researched["iron_plough"] = true
	t.check(
		is_equal_approx(Patch.field_share(s, tile) - base, Data.IRON_PLOUGH_FIELD_BONUS),
		"the Iron Plough adds another 50% to a Field"
	)
	var wild: Vector2i = t.find_tile(s, "tree")
	t.check(Patch.field_share(s, wild) == 0.0, "and nothing to a wild tile")


func test_taught_hands_two() -> void:
	var s: Sim = t.fresh()
	t.check(Hands.learn_needed(s) == Data.LEARN_FIRST, "the first lesson takes %d harvests" % Data.LEARN_FIRST)
	s.tech_tree.researched["taught_hands_ii"] = true
	var first := Hands.learn_needed(s)
	t.check(first == ceili(Data.LEARN_FIRST * Data.TAUGHT_HANDS_II_SHARE), "Taught Hands II halves it (%d)" % first)
	s.hand_counts["stone"] = 3
	for i in first:
		Hands.teach(s, "wood")
	t.check(s.people.knows("wood"), "the Kith learn wood sooner")
	t.check(s.people.knows("stone"), "and a resource harvested often enough is learned with it")
	t.check(not s.people.knows("flint"), "though not one nobody has harvested")
	t.check(s.events.any(func(e): return e.contains("as well")), "the log says so")
	t.check(
		Hands.learn_needed(s) == ceili(Data.LEARN_CLICKS * Data.TAUGHT_HANDS_II_SHARE),
		"later lessons take half of %d" % Data.LEARN_CLICKS
	)
	var plain: Sim = t.fresh()
	plain.hand_counts["stone"] = 3
	for i in Data.LEARN_FIRST:
		Hands.teach(plain, "wood")
	t.check(plain.people.knows("wood") and not plain.people.knows("stone"), "without it nothing spreads")


func test_the_strange_stone_gives_shards() -> void:
	var s := town()
	var stone: Vector2i = s.world.shard_pos
	s.fog.reveal_all()
	t.check(Hands.item_at(s, stone) == "", "before Shard Lamps the Stone is only a thing to click")
	s.tech_tree.researched["shard_lamps"] = true
	t.check(Hands.item_at(s, stone) == "" and not Hands.chips_shard(s), "and until it has been found")
	t.check(s.gather_by_hand(stone) == Data.SHARD_TEXT and s.shard_seen, "a click finds it")
	t.check(Hands.chips_shard(s) and Hands.item_at(s, stone) == "shard", "after that a hold chips a Shard off")
	t.check(
		(
			Hands.hold_time(s, "shard") > Hands.hold_time(s, "wood")
			and Hands.hold_time(s, "shard") <= Data.HAND_HOLD["shard"]
		),
		"slowly, like ore: %.1f seconds" % Hands.hold_time(s, "shard")
	)
	var before: int = s.economy.inv.get("shard", 0)
	t.check(s.gather_by_hand(stone) == "+1 Shard", "one at a time")
	t.check(s.economy.inv["shard"] == before + 1, "into the stockpile")
	var plain := town()
	plain.shard_seen = true
	t.check(Hands.item_at(plain, plain.world.shard_pos) == "", "no chips without Shard Lamps")
	t.check(not s.people.knows("shard") and not s.hand_counts.has("shard"), "a Shard is not a craft the Kith learn")


func test_bloom_sampling_gates_the_samples() -> void:
	var s := town()
	t.check(not s.tech_tree.researched.has("bloom_sampling"), "not learned")
	t.check(not Finds.sampling_open(s), "the Kith cannot take a sample")
	t.check(Finds.bloom_problem(s) == Data.BLOOM_NO_TECH, "and the Post says why")
	s.tech_tree.researched["bloom_sampling"] = true
	t.check(Finds.sampling_open(s) and Finds.bloom_problem(s) == "", "learned, they can")
	var def: Dictionary = Data.TECHS["bloom_sampling"]
	t.check(def["requires"] == ["teardown", "shard_lamps"], "Bloom Sampling follows Teardown and Shard Lamps")


func test_gifts_and_lessons_gate_techs() -> void:
	var s := town()
	t.check(
		Data.TECHS["shard_lamps"]["gift"] == "light" and Data.TECHS["shard_boiler"]["gift"] == "craft",
		"two techs name a gift"
	)
	t.check(
		s.tech_tree.open_needs("shard_lamps") == ["the Shardlight gift"],
		"Shard Lamps waits for Shardlight: %s" % [s.tech_tree.open_needs("shard_lamps")]
	)
	t.check(s.tech_tree.missing_requirements("shard_lamps") == 1, "which counts as a requirement")
	s.tech_tree.researched["teardown"] = true
	t.check(
		s.tech_tree.missing_requirements("shard_lamps") == 1 and not s.tech_tree.requirements_met("shard_lamps"),
		"and holds it back"
	)
	s.starfall.locked["light"] = true
	t.check(
		s.tech_tree.open_needs("shard_lamps").is_empty() and s.tech_tree.requirements_met("shard_lamps"),
		"until the marks of Light are read"
	)
	var need := s.tech_tree.open_needs("livewire")
	t.check(
		need.size() == 3 and need[0].contains("Spore") and need[2].contains("Sap"),
		"Livewire waits for three Lessons: %s" % [need]
	)
	s.teardown.lessons.append_array(["spore", "root", "sap"])
	t.check(s.tech_tree.open_needs("livewire").is_empty(), "learned, nothing is left to wait for")
	t.check(s.tech_tree.open_needs("coal_seams").is_empty(), "other techs wait for neither")


func test_the_lantern_party() -> void:
	var s := town()
	t.check(is_equal_approx(Steam.daylight(s), Data.DAYLIGHT_SECONDS), "the day is %d seconds" % Data.DAYLIGHT_SECONDS)
	var at := spot(s, "shard_lamp", s.world.camp_pos, 2, 6)
	s.town.add_building("shard_lamp", at)
	var lamp: Dictionary = s.town.buildings[s.town.building_at[at]]
	lamp["burn"] = 100.0
	t.check(is_equal_approx(Steam.daylight(s), Data.DAYLIGHT_SECONDS), "a lit lamp alone does not lengthen it")
	s.teardown.lessons.append("sap")
	t.check(
		is_equal_approx(Steam.daylight(s), Data.DAYLIGHT_SECONDS * Data.LANTERN_DAYLIGHT),
		"with the Sap Lesson it is %.1f times as long" % Data.LANTERN_DAYLIGHT
	)
	lamp["burn"] = 0.0
	t.check(is_equal_approx(Steam.daylight(s), Data.DAYLIGHT_SECONDS), "and only while a lamp burns")
	lamp["burn"] = 100.0
	var late := {"seconds": 100.0, "late": false}
	t.check(
		ExpeditionPicker.trip_text(late, s).contains(str(roundi(Data.DAYLIGHT_SECONDS * Data.LANTERN_DAYLIGHT))),
		"the Post shows the longer day"
	)


func test_livewire_ends_the_age() -> void:
	var s := town()
	s.starfall.locked["light"] = true
	s.starfall.locked["craft"] = true
	for tech in ["steel", "rails", "shard_boiler", "bloom_sampling"]:
		s.tech_tree.researched[tech] = true
		s.economy.seen[tech] = true
	for item in ["steel", "iron", "brick", "rope"]:
		s.economy.seen[item] = true
	s.economy.inv["steel"] = 100
	s.economy.inv["iron"] = 100
	s.economy.inv["brick"] = 60
	s.economy.inv["rope"] = 40
	t.check(not s.research("livewire"), "the gate does not open without the Bloom Lessons")
	t.check(not s.story.has_event(Data.LIVEWIRE_EVENT), "and the age goes on")
	s.teardown.lessons.append_array(["spore", "root", "sap"])
	var told := []
	s.story.recorded.connect(func(id): told.append(id))
	t.check(s.research("livewire"), "with them, and the stores, it does")
	t.check(Data.LIVEWIRE_EVENT in told and s.story.has_event(Data.LIVEWIRE_EVENT), "the end of the age is recorded")
	t.check(s.economy.inv["steel"] == 0 and s.economy.inv["iron"] == 0, "and the stores are spent")
	s.story.update(s)
	t.check(s.story.goals_done.has("livewire"), "the last goal is done")
	var card := EraCard.new()
	card.setup()
	var closed := []
	card.closed.connect(func(): closed.append(true))
	card.open("star_falling")
	t.check(card.visible and card._words["title"].text == Data.ERA_END_TITLE, "the Falling Star's card is as it was")
	card.open(Data.LIVEWIRE_EVENT)
	t.check(
		card._words["title"].text == Data.LIVEWIRE_TITLE and card._words["text"].text == Data.LIVEWIRE_TEXT,
		"Livewire has a card of its own"
	)
	t.check(
		card._words["button"].text == Data.LIVEWIRE_BUTTON and card._words["note"].text == Data.LIVEWIRE_NOTE,
		"with its own button and note"
	)
	card.close()
	t.check(closed.size() == 1 and not card.visible, "it closes, and the game goes on")
	card.free()


# --- Saves ------------------------------------------------------------------------


func test_stage_three_saves_and_loads() -> void:
	var s := town()
	s.tech_tree.researched["rails"] = true
	var both := forge_by_boiler(s)
	both[0]["inbuf"] = {"coal": 3}
	feed(s, 2.0)
	var pen_at := spot(s, "beast_pen", s.world.camp_pos, 2, 6)
	s.town.add_building("beast_pen", pen_at)
	var pen: Dictionary = s.town.buildings[s.town.building_at[pen_at]]
	pen["progress"] = 30.0
	pen["burn"] = 2.5
	var row := run_east(s, 3)
	lay(s, row[0], row[1], Data.RAIL_TIER)
	s.people.found(4)
	s.town.add_building("steam_shed", spot(s, "steam_shed", s.world.camp_pos, 2, 6))
	s.people.assign_jobs()
	var cart: Dictionary = s.people.kith.filter(func(k): return k["cart_kind"] == "steam")[0]
	cart["fire"] = 2
	cart["hot"] = true
	var text := RunSave.to_json(RunSave.dump(s))
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, RunSave.from_json(text)), "a game with a lit Boiler, a Pen and a Steam Cart loads")
	t.check(
		loaded.town.buildings[s.town.buildings.find(both[0])]["burn"] == both[0]["burn"],
		"the Boiler's fire is as it was"
	)
	t.check(loaded.town.buildings[s.town.buildings.find(pen)]["progress"] == 30.0, "and the Pen's taming")
	t.check(loaded.town.buildings[s.town.buildings.find(pen)]["burn"] == 2.5, "(and its next Grain)")
	var back: Array = loaded.people.kith.filter(func(k): return k["cart_kind"] == "steam")
	t.check(back.size() == 1 and back[0]["fire"] == 2 and back[0]["hot"], "the Steam Cart still has steam")
	t.check(loaded.world.road_tier(row[0]) == Data.RAIL_TIER, "the Rail is still Rail")
	t.check(RunSave.to_json(RunSave.dump(loaded)) == text, "a reload saves the same text")
	var d := RunSave.dump(s)
	for b in d["buildings"]["buildings"]:
		b.erase("burn")
	for k in d["kith"]["kith"]:
		k.erase("cart_kind")
		k.erase("fire")
		k.erase("hot")
	var old := Sim.new()
	t.check(RunSave.restore(old, d), "a save from before steam loads")
	t.check(old.town.buildings.all(func(b): return b["burn"] == 0.0), "with nothing burning")
	t.check(old.people.kith.all(func(k): return k["fire"] == 0 and not k["hot"]), "and no steam up")
	var hand := Sim.new()
	hand.generate(42)
	hand.people.found(5)
	hand.tech_tree.researched["haulers"] = true
	hand.tech_tree.researched["the_wheel"] = true
	hand.town.add_building("cart_shed", hand.world.camp_pos + Vector2i(2, 2))
	hand.people.assign_jobs()
	var dd := RunSave.dump(hand)
	for k in dd["kith"]["kith"]:
		k.erase("cart_kind")
	var older := Sim.new()
	t.check(RunSave.restore(older, dd), "a save with a hand cart from before steam loads")
	t.check(older.people.kith.any(func(k): return k["cart"] and k["cart_kind"] == "hand"), "its cart is a hand cart")
