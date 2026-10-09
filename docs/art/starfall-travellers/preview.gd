extends SceneTree
## Documentation-only native artwork preview; no saves or simulation.
const Rendered = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/starfall-travellers/"

class Board extends Node2D:
	var specs: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 480), Color("172c30"))
		text(Vector2(24, 32), "Starfall travellers / native 24 px figures and 12x14 px pack / Godot art board", 21)
		for i in specs.size():
			var spec: Dictionary = specs[i]
			var x := 32.0 + i * 268.0
			text(Vector2(x, 84), spec.id, 18)
			Rendered.fit(self, spec.texture, Rect2(Vector2(x, 108), Vector2(spec.size[0], spec.size[1])))
			Rendered.fit(self, spec.texture, Rect2(Vector2(x, 180), Vector2(spec.size[0], spec.size[1]) * 4))
		text(Vector2(24, 322), "Top: native size. Middle: 4x inspection. Below: existing Kith + trial pack overlay (not wired gameplay).", 17)
		for pose in 4:
			var at := Vector2(48 + pose * 82, 390)
			Rendered.fit(self, specs[3].texture, Rect2(at + Vector2(3, -21), Vector2(12, 14)))
			Rendered.fit(self, Rendered.sprite("walk", pose), Rect2(at + Vector2(-12, -24), Vector2(24, 24)))
		text(Vector2(430, 383), "The pack is drawn behind the Kith; feet do not move.", 17)
		text(Vector2(430, 411), "Light/aura and movement stay in the existing engine layers.", 17)
	func text(at: Vector2, message: String, px: int) -> void:
		draw_string(ThemeDB.fallback_font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("e7e3d4"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1120, 480)
	root.content_scale_size = Vector2i(1120, 480)
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(HERE + "spec.json"))
	var manifest := []
	var board := Board.new()
	for spec in specs:
		var tex: Texture2D = load(spec.path)
		var image := tex.get_image()
		if image.is_compressed():
			image.decompress()
		var step := image.get_size() / Vector2i(int(spec.grid[0]), int(spec.grid[1]))
		var cell := Rect2i(Vector2i(int(spec.cell) % int(spec.grid[0]), int(spec.cell) / int(spec.grid[0])) * step, step)
		var low := cell.end
		var high := cell.position - Vector2i.ONE
		for y in range(cell.position.y, cell.end.y):
			for x in range(cell.position.x, cell.end.x):
				if image.get_pixel(x, y).a > 0.05:
					low.x = mini(low.x, x)
					low.y = mini(low.y, y)
					high.x = maxi(high.x, x)
					high.y = maxi(high.y, y)
		var bounds := Rect2i(low, high - low + Vector2i.ONE).grow(4).intersection(cell)
		if not image.detect_alpha() or bounds.size.x <= 0 or bounds.size.y <= 0:
			push_error("Missing transparent subject: " + spec.id)
			quit(1)
			return
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = bounds
		region.filter_clip = true
		board.specs.append({"id": spec.id, "size": spec.size, "texture": region})
		manifest.append({"id":spec.id,"path":spec.path,"source_size":[image.get_width(),image.get_height()],"region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"size":spec.size,"anchor":"bottom_center"})
		print(spec.id, " region=", bounds)
	root.add_child(board)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(HERE + "native-board.png")
	var file := FileAccess.open(HERE + "regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("TRAVELLERS_CAPTURE saved=", error)
	quit(0 if error == OK else 1)
