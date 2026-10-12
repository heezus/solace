extends SceneTree
## Review-only native-size comparison; does not modify production loading.

const Rendered = preload("res://scripts/rendered_art.gd")


class Sheet:
	extends Node2D
	var bench: Texture2D

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 760, 360), Color("263c38"))
		var font := ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(24, 35),
			"Tool Bench — native size review (not integrated)",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color("efeadb")
		)
		var subjects: Array[Texture2D] = [Rendered.sprite("workshops", 2), bench, Rendered.sprite("workshops", 3)]
		var names := ["Twine Post", "Tool Bench", "Kiln"]
		for i in range(3):
			var x := 100.0 + i * 240.0
			draw_string(font, Vector2(x - 40, 78), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("efeadb"))
			Rendered.fit(self, subjects[i], Rect2(x - 24, 103, 48, 48))
			Rendered.fit(self, subjects[i], Rect2(x - 12, 190, 24, 24))
			Rendered.fit(self, subjects[i], Rect2(x - 48, 240, 96, 96))
		draw_string(font, Vector2(24, 135), "48 px", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("efeadb"))
		draw_string(font, Vector2(24, 210), "24 px", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("efeadb"))
		draw_string(font, Vector2(24, 295), "96 px", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("efeadb"))


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var source := Image.load_from_file("res://docs/art/tool-bench/tool-bench.png")
	assert(source != null and not source.is_empty())
	assert(source.get_pixel(0, 0).a == 0.0, "Sprite must have genuine transparency")
	var bounds := source.get_used_rect()
	assert(bounds.has_area())
	print("Tool Bench image dimensions: ", source.get_size(), "; alpha bounds: ", bounds)
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(source)
	atlas.region = Rect2(bounds)
	atlas.filter_clip = true
	var sheet := Sheet.new()
	sheet.bench = atlas
	root.size = Vector2i(760, 360)
	root.content_scale_size = Vector2i(760, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.add_child(sheet)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/art/tool-bench/native-preview.png")
	assert(error == OK)
	quit()
