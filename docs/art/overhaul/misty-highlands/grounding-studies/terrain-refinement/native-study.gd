extends SceneTree
const Ground = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/terrain-refinement/candidate-ground.gd")
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")
const Art = preload("res://scripts/art.gd")
const Bridge = preload("res://scripts/bridge_art.gd")
var frame := 0
var fixtures: Array = []


class Labels:
	extends Node2D

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(32, 40),
			"Terrain at 48 px per tile · exact production sprites",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			24,
			Color("eee7d6")
		)
		draw_string(
			font, Vector2(32, 83), "Previous material treatment", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eee7d6")
		)
		draw_string(
			font,
			Vector2(656, 83),
			"Refined turf, shallow banks and worn paths",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			Color("eee7d6")
		)
		draw_string(
			font,
			Vector2(32, 734),
			"Isolated renderer fixture · same layout and subject sizes · not a gameplay capture",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("bac7bd")
		)


class Fixture:
	extends Node2D
	var s: Dictionary
	var ground = Ground.new()

	func _draw() -> void:
		ground.draw(self, s, Rect2i(0, 0, 12, 12))
		for y in 12:
			for x in 12:
				var p := Vector2i(x, y)
				var type: String = s.world.tile_at(p)
				if type != "grass" and type != "river":
					Art.map_feature(self, type, (Vector2(p) + Vector2.ONE * 0.5) * 48, p, 0, 1.5)
				if type == "river" and s.world.roads.has(p):
					Bridge.draw(self, s, p)
		for b in s.town.buildings:
			var r := Rect2(Vector2(b.pos) * 48, Vector2(48, 48))
			if b.type == "camp":
				r = r.grow(24)
			Art.contact_shadow(self, Vector2(r.get_center().x, r.end.y - 2), r.size * Vector2(0.38, 0.055))
			Art.map_building(self, b.type, r, false, 0)
		Art.Rendered.fit(self, Art.Rendered.sprite("walk", 0), Rect2(195, 275, 30, 42))


func _init() -> void:
	root.add_child(Labels.new())
	for col in 2:
		var world := World.new(12, 12)
		world.map_seed = 7
		var fog := Fog.new()
		fog.setup(12, 12)
		fog.reveal_all()
		for y in 12:
			world.set_tile(Vector2i(8, y), "river")
			if y < 4 or y > 8:
				for x in [0, 1, 2, 10, 11]:
					world.set_tile(Vector2i(x, y), "tree")
		for part in [
			[Vector2i(5, 8), "rock"],
			[Vector2i(6, 8), "rock"],
			[Vector2i(5, 9), "plain_ore"],
			[Vector2i(2, 7), "berry"],
			[Vector2i(1, 6), "flax"],
			[Vector2i(6, 2), "grain"]
		]:
			world.set_tile(part[0], part[1])
		for x in range(2, 11):
			world.roads[Vector2i(x, 6)] = true
		for y in range(3, 7):
			world.roads[Vector2i(4, y)] = true
		var buildings := [
			{"pos": Vector2i(3, 4), "type": "camp"},
			{"pos": Vector2i(2, 6), "type": "gatherers_hut"},
			{"pos": Vector2i(6, 5), "type": "dwelling"}
		]
		var occupied := {}
		for i in buildings.size():
			occupied[buildings[i].pos] = i
		var fixture := Fixture.new()
		fixture.s = {
			"world": world,
			"fog": fog,
			"town": {"building_at": occupied, "buildings": buildings},
			"tech_tree": {"researched": {}}
		}
		fixture.position = Vector2(32 + col * 624, 110)
		root.add_child(fixture)
		fixtures.append(fixture)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
	if frame == 8:
		fixtures[0].ground._material.set_shader_parameter("turf_texture", Art.Rendered.sheet("meadow-ground"))
		fixtures[0].ground._shore.visible = false
		fixtures[0].ground._material.shader = load(
			"res://docs/art/overhaul/misty-highlands/grounding-studies/terrain-refinement/baseline.gdshader"
		)
		fixtures[1].ground._material.shader = load("res://docs/art/overhaul/misty-highlands/grounding-studies/terrain-refinement/candidate-terrain.gdshader")
		fixtures[1].ground._material.set_shader_parameter("turf_texture", ImageTexture.create_from_image(Image.load_from_file("res://docs/art/overhaul/misty-highlands/grounding-studies/terrain-refinement/quiet-meadow.png")))
	if frame == 20:
		capture.call_deferred()
	return false


func capture() -> void:
	var error := root.get_texture().get_image().save_png("/tmp/solace-terrain-review/native-comparison.png")
	print("Native terrain comparison: ", error)
	quit(0 if error == OK else 1)
