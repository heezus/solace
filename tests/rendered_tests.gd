extends RefCounted
## Visual variation and terrain caching must preserve gameplay state, RNG and hidden terrain.

const Rendered = preload("res://scripts/rendered_art.gd")
const Ground = preload("res://scripts/world_ground.gd")
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")
const Bridge = preload("res://scripts/bridge_art.gd")
const Data = preload("res://scripts/data.gd")
const IconRow = preload("res://scripts/icon_row.gd")


func run(t) -> void:
	test_starfall_icons(t)
	test_grounding_masks(t)
	test_roads_join_across_cells(t)
	var choices := {}
	for y in 12:
		for x in 18:
			var p := Vector2i(x, y)
			var choice := Rendered.variant(p, 4, 17, 7)
			choices[choice] = true
			t.check(choice == Rendered.variant(p, 4, 17, 7), "a tile keeps its appearance on redraw")
			t.check(choice >= 0 and choice < 4, "a variant stays inside the atlas family")
	t.check(choices.size() == 4, "map variation uses every tree rather than the default")
	for family in Rendered.REGIONS:
		for i in Rendered.REGIONS[family].size():
			var tex := Rendered.sprite(family, i)
			t.check(tex.atlas != null and tex.filter_clip, "atlas exists and prevents neighboring sprite bleed")
			t.check(
				Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "atlas region stays inside its source"
			)
	var world := World.new(6, 5)
	var fog := Fog.new()
	fog.setup(6, 5)
	var s := {"world": world, "fog": fog, "town": {"building_at": {}}, "tech_tree": {"researched": {}}}
	var ground := Ground.new()
	ground._rebuild(s)
	var before := world.to_dict()
	var first := ground._image.get_data()
	var count := ground.builds
	ground._rebuild(s)
	t.check(ground.builds == count, "unchanged terrain is reused rather than rebuilt")
	world.set_tile(Vector2i(2, 2), "river")
	ground._rebuild(s)
	t.check(ground._image.get_data() == first, "hidden rivers do not leak through neighboring ground")
	world.roads[Vector2i(1, 1)] = true
	ground._rebuild(s)
	t.check(ground._image.get_data() == first, "hidden roads do not leak into known terrain")
	world.roads.clear()
	fog.reveal_all()
	ground._rebuild(s)
	t.check(ground._image.get_data() != first, "revealing a river refreshes its connected banks")
	world.roads[Vector2i(1, 1)] = true
	count = ground.builds
	ground._rebuild(s)
	t.check(ground.builds == count + 1, "a placed road refreshes terrain")
	world.set_tile(Vector2i(2, 2), "grass")
	world.roads.clear()
	t.check(world.to_dict() == before, "rendering does not mutate world state")
	seed(713)
	var expected := randi()
	seed(713)
	Rendered.variant(Vector2i(4, 6), 3, 81, 7)
	ground._rebuild(s)
	t.check(randi() == expected, "art variation and terrain generation leave simulation RNG untouched")

	var bridge_world := World.new(6, 5)
	var bridge_state := {"world": bridge_world}
	for x in range(1, 4):
		bridge_world.set_tile(Vector2i(x, 2), "river")
		bridge_world.roads[Vector2i(x, 2)] = true
	for x in range(1, 4):
		var crossing := Bridge.span(bridge_state, Vector2i(x, 2))
		t.check(crossing["anchor"] == Vector2i(1, 2), "bridge pieces share a bank anchor")
		t.check(crossing["length"] == 3 and crossing["part"] == x - 1, "bridge middle does not repeat bank caps")
	bridge_world = World.new(6, 5)
	bridge_state["world"] = bridge_world
	for y in range(1, 4):
		bridge_world.set_tile(Vector2i(2, y), "river")
		bridge_world.roads[Vector2i(2, y)] = true
	var vertical := Bridge.span(bridge_state, Vector2i(2, 2))
	t.check(vertical["axis"] == Vector2i.DOWN and vertical["length"] == 3, "vertical crossings use vertical modules")
	bridge_world.roads.clear()
	bridge_world.roads[Vector2i(2, 2)] = true
	bridge_world.roads[Vector2i(1, 2)] = true
	bridge_world.roads[Vector2i(3, 2)] = true
	var short := Bridge.span(bridge_state, Vector2i(2, 2))
	t.check(short["length"] == 1 and short["axis"] == Vector2i.RIGHT, "single-cell bridge follows its bank roads")


## Visual meanders must remain joined at cell boundaries in either axis.
func test_roads_join_across_cells(t) -> void:
	var world := World.new(6, 5)
	var fog := Fog.new()
	fog.setup(6, 5)
	fog.reveal_all()
	var s := {"world": world, "fog": fog, "town": {"building_at": {}}}
	var ground := Ground.new()
	for map_seed in 20:
		world.map_seed = map_seed
		for side in [Vector2i.RIGHT, Vector2i.DOWN]:
			var start := Vector2i(1, 1)
			world.roads = {start: true, start + side: true}
			var a := ground._road_center(start, map_seed)
			var b := ground._road_center(start + side, map_seed)
			var axis := 0 if side == Vector2i.RIGHT else 1
			var f := (2.0 - a[axis]) / (b[axis] - a[axis])
			var seam := a.lerp(b, f)
			for offset in [-0.001, 0.001]:
				t.check(ground._road(s, seam + Vector2(side) * offset) > 0.99, "meandering road joins both cell edges")


## Ground regions and foundation wear must be private, removable and independent of gameplay.
func test_grounding_masks(t) -> void:
	var world := World.new(6, 5)
	var fog := Fog.new()
	fog.setup(6, 5)
	var town := {"building_at": {}, "buildings": []}
	var s := {"world": world, "fog": fog, "town": town, "tech_tree": {"researched": {}}}
	var ground := Ground.new()
	ground._rebuild(s)
	var hidden := ground._image.get_data()
	for y in range(1, 4):
		for x in range(1, 4):
			world.set_tile(Vector2i(x, y), "tree")
	town.buildings.append({"type": "camp"})
	town.building_at[Vector2i(2, 2)] = 0
	ground._rebuild(s)
	t.check(ground._image.get_data() == hidden, "hidden woods and foundations do not leak through ground")
	fog.reveal_all()
	ground._rebuild(s)
	var pixel := Vector2i(2, 2) * Ground.SAMPLES + Vector2i(8, 18)
	var center := ground._image.get_pixelv(pixel)
	t.check(center.b > 0.5 and center.a > 0.8, "visible woods blend beneath a worn foundation")
	var outer := Vector2i(3, 2) * Ground.SAMPLES + Vector2i(0, 12)
	var hearth_wear := ground._image.get_pixelv(outer).a
	town.buildings[0]["type"] = "gatherers_hut"
	ground._rebuild(s)
	t.check(ground._image.get_pixelv(outer).a < hearth_wear, "apron follows visual building footprint changes")
	town.building_at.clear()
	ground._rebuild(s)
	t.check(ground._image.get_pixelv(pixel).a == 0.0, "demolition removes foundation wear")
	for y in range(1, 4):
		for x in range(1, 4):
			world.set_tile(Vector2i(x, y), "grass")
	ground._rebuild(s)
	t.check(ground._image.get_pixelv(pixel).b == 0.0, "clearing trees refreshes woodland ground")


## Every pack, gift and glyph-set heading has its picture, and the row helper gives it a hover name.
func test_starfall_icons(t) -> void:
	var ids: Array = []
	for pack in Data.PACKS:
		ids.append("pack_" + pack)
	for gift in Data.LUMEN_GIFTS:
		ids.append("gift_" + gift)
	for n in Data.GLYPH_SETS:
		ids.append("set_" + Data.GLYPH_SETS[n]["id"])
	for id in ids:
		t.check(Rendered.icon(id) != null, "%s has an icon" % id)
	t.check(Rendered.icon("shard") != null, "the shard has an icon")
	t.check(Rendered.icon("nothing") == null, "an unknown icon is null, not an error")
	t.check(Rendered.STARFALL_ICONS.size() == Rendered.REGIONS["starfall-icons"].size(), "one region per icon id")
	var label := Label.new()
	var row: Control = IconRow.wrap("pack_light", label, "Light pack")
	t.check(row != label and row.get_child(0).tooltip_text == "Light pack", "an icon row names its picture on hover")
	t.check(IconRow.wrap("nothing", label, "x") == label, "a line without an icon is left as it was")
	row.free()
	label = Label.new()
	label.free()
