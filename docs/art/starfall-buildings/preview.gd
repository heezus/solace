extends SceneTree
## Native-size asset board, not a gameplay integration. No game state or save is touched.

const Rendered = preload("res://scripts/rendered_art.gd")
const SLOTS := [
	["glyph_wall", "starfall-glyph-wall", Vector2(2, 1)],
	["lumen_camp", "starfall-lumen-camp", Vector2(2, 2)],
	["expedition_post", "starfall-expedition-post", Vector2(1, 1)],
	["wreck", "starfall-wreck", Vector2(2, 1)],
]

class Board extends Node2D:
	var slots: Array = []
	var font := ThemeDB.fallback_font

	func label(at: Vector2, text: String, px := 16) -> void:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("e7e3d4"))

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 680), Color("172c30"))
		label(Vector2(24, 32), "Starfall subjects / native Godot asset board / 48 px tiles", 22)
		label(Vector2(24, 56), "48 px row uses existing footprint fit; enlarged row is only for inspection.", 16)
		for i in slots.size():
			var spec: Dictionary = slots[i]
			var x := 24.0 + i * 274.0
			label(Vector2(x, 95), spec.id, 18)
			for row in 2:
				var scale_value := 48.0 * (row + 1)
				var area := Rect2(Vector2(x + 16, 120 + row * 160), spec.footprint * scale_value)
				draw_rect(area.grow(6), Color("354e39"))
				for yy in int(spec.footprint.y):
					for xx in int(spec.footprint.x):
						draw_rect(Rect2(area.position + Vector2(xx, yy) * scale_value, Vector2.ONE * scale_value), Color("6b7d6040"), false)
				Rendered.fit(self, spec.texture, area.grow(-1))
				label(Vector2(x + 8, 244 + row * 252), "%d px tiles" % scale_value, 14)
		label(Vector2(24, 526), "Existing references at 48 px tiles: Hearth (2x2), hut (1x1), Kith (24 px)", 18)
		Rendered.building(self, "camp", Rect2(24, 546, 96, 96))
		Rendered.building(self, "gatherers_hut", Rect2(154, 546, 48, 48))
		Rendered.fit(self, Rendered.sprite("walk", 0), Rect2(250, 546, 24, 24))
		label(Vector2(320, 573), "PNG originals retained. Runtime loading is a separate Claude hook.", 16)

func _init() -> void:
	call_deferred("preview")

func preview() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1120, 680)
	root.content_scale_size = Vector2i(1120, 680)
	var board := Board.new()
	var manifest := {}
	for spec in SLOTS:
		var path := "res://art/rendered/%s.png" % spec[1]
		var image := (load(path) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		var bounds := content_bounds(image)
		if not image.detect_alpha() or bounds.size.x == 0 or bounds.size.y == 0:
			push_error("Missing transparent subject: " + path)
			quit(1)
			return
		var texture := AtlasTexture.new()
		texture.atlas = load(path)
		texture.region = bounds
		texture.filter_clip = true
		board.slots.append({"id": spec[0], "footprint": spec[2], "texture": texture})
		manifest[spec[0]] = {"path": path, "source_size": [image.get_width(), image.get_height()], "region": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "footprint": [int(spec[2].x), int(spec[2].y)]}
		print(spec[0], " alpha=", image.detect_alpha(), " region=", bounds)
	root.add_child(board)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/art/starfall-buildings/native-board.png")
	var file := FileAccess.open("res://docs/art/starfall-buildings/regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("STARFALL_NATIVE_CAPTURE saved=", error)
	quit(0 if error == OK else 1)

func content_bounds(image: Image) -> Rect2i:
	# Ignore almost invisible generator specks; preserve the original PNG and alpha.
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.05:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	return Rect2i(low, high - low + Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
