extends SceneTree
## Terrain scatter is presentation only, stable across redraw/camera and private behind fog.

const Ground = preload("res://scripts/world_ground.gd")
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _initialize() -> void:
	check_assets()
	for map_seed in [3, 11, 42]:
		var world := World.new(24, 24)
		world.map_seed = map_seed
		var fog := Fog.new()
		fog.setup(24, 24)
		fog.reveal_all()
		world.roads[Vector2i(10, 10)] = true
		for row in range(12, 17):
			world.set_tile(Vector2i(12, row), "river")
		var s := {
			"world": world, "fog": fog, "town": {"building_at": {Vector2i(8, 8): 0}, "buildings": [{"type": "camp"}]}
		}
		var ground := Ground.new()
		var before := world.to_dict().duplicate(true)
		seed(12345)
		var expected := randi()
		seed(12345)
		ground._rebuild(s)
		var all := ground.decal_layout(s, Rect2i(0, 0, 24, 24))
		check(not all.is_empty(), "Seed %d has ground detail" % map_seed)
		check(all == ground.decal_layout(s, Rect2i(0, 0, 24, 24)), "Stable redraw")
		var subset := ground.decal_layout(s, Rect2i(4, 4, 8, 8))
		for decal in subset:
			check(all.has(decal), "Camera position does not change scatter")
		var banks := 0
		for decal in all:
			banks += 1 if decal.z >= 24 else 0
			check(decal.z >= 0 and decal.z < 32, "Atlas cell in bounds")
			var p := Vector2(decal.x, decal.y)
			for offset in [Vector2.ZERO, Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)]:
				var mask := ground._image.get_pixelv(Vector2i((p + offset) / 48.0 * Ground.SAMPLES))
				check(
					mask.g <= 0.02 and mask.a <= 0.04 and mask.r <= (0.72 if decal.z >= 24 else 0.38),
					"Footprint clears road/apron/deep water"
				)
		check(banks > 0, "Bank details reach the shallows")
		check(randi() == expected, "Terrain rebuild and scatter preserve simulation RNG")
		check(world.to_dict() == before, "Terrain leaves world/save data unchanged")
		fog.setup(24, 24)
		ground._rebuild(s)
		check(ground.decal_layout(s, Rect2i(0, 0, 24, 24)).is_empty(), "Fog hides all decals")
		var hidden := ground._image.get_data()
		world.set_tile(Vector2i(5, 5), "tree")
		world.set_tile(Vector2i(6, 5), "river")
		ground._rebuild(s)
		check(ground._image.get_data() == hidden, "Hidden terrain does not alter visible masks")
	for message in failures:
		printerr(message)
	print("Terrain kit checks: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func check_assets() -> void:
	var ground := Ground.new()
	var names: Array[String] = ["meadow-a", "meadow-b", "meadow-c"]
	var packed := ground._material_atlas(names)
	check(packed.get_size() == Vector2(5760, 1920), "Meadow atlas dimensions")
	var packed_image := packed.get_image()
	for index in names.size():
		var source: Texture2D = load("res://art/rendered/" + names[index] + ".png")
		check(
			packed_image.get_pixel(index * 1920 + 900, 900) == source.get_image().get_pixel(900, 900),
			"Atlas preserves each painted sheet"
		)
	var shader_source := FileAccess.get_file_as_string("res://art/rendered/terrain.gdshader")
	check(shader_source.count("uniform sampler2D") <= 8, "Compatibility sampler budget")
	for slot in [
		"meadow-a",
		"meadow-b",
		"meadow-c",
		"woodland-a",
		"woodland-b",
		"water-calm",
		"water-flow",
		"earth",
		"earth-south",
		"bank"
	]:
		var texture: Texture2D = load("res://art/rendered/" + slot + ".png")
		var size := Vector2i(1920, 192) if slot == "bank" else Vector2i(1920, 1920)
		check(Vector2i(texture.get_size()) == size, slot + " imported dimensions")
		var image := texture.get_image()
		for y in size.y:
			check(image.get_pixel(0, y) == image.get_pixel(size.x - 1, y), slot + " horizontal wrap")
		if slot != "bank":
			for x in size.x:
				check(image.get_pixel(x, 0) == image.get_pixel(x, size.y - 1), slot + " vertical wrap")
	var decal_texture: Texture2D = load("res://art/rendered/decals.png")
	var atlas := decal_texture.get_image()
	check(atlas.get_size() == Vector2i(768, 384), "Decal atlas dimensions")
	for y in atlas.get_height():
		for x in atlas.get_width():
			if x % 96 < 8 or x % 96 >= 88 or y % 96 < 8 or y % 96 >= 88:
				check(atlas.get_pixel(x, y).a == 0.0, "Transparent atlas cell gutter")
