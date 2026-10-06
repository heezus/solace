extends SceneTree
## Actual-size asset drawing and connected road shader exercise, not a game-state integration.

const Growth = preload("res://scripts/growth_art.gd")
const Rendered = preload("res://scripts/rendered_art.gd")


class Sheet:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1080, 560), Color("263c38"))
		var font := ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(24, 32),
			"Growth assets — native drawing; gameplay hooks remain with Claude",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color("efeadb")
		)
		var names := ["Dwelling", "Homestead", "Longhouse", "Scaffold", "Hand cart", "Cargo overlay"]
		for i in range(6):
			var x := 82.0 + i * 174.0
			draw_string(font, Vector2(x - 50, 75), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("efeadb"))
			for px in [24.0, 48.0, 96.0]:
				var y := 100.0 if px == 24 else (155.0 if px == 48 else 235.0)
				var box := Rect2(x - px * 0.5, y, px, px)
				if i < 3:
					Growth.draw_house(self, i + 1, box)
				elif i == 3:
					Growth.draw_house(self, 2, box)
					Growth.draw_scaffold(self, box)
				else:
					Growth.draw_hand_cart(self, box, Rendered.named("item_wood") if i == 5 else null)
		for tier in range(3):
			draw_string(
				font,
				Vector2(24 + tier * 350, 370),
				["Path", "Gravel", "Paved"][tier],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				17,
				Color("efeadb")
			)
		draw_string(
			font,
			Vector2(24, 535),
			"Roads: actual 48 px cells, world-anchored materials, straight / corner / junction / mixed tier seams",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("efeadb")
		)


class RoadCell:
	extends Node2D

	func _draw() -> void:
		draw_texture_rect(Growth.ROADS, Rect2(0, 0, 48, 48), false)


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1080, 560)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.add_child(Sheet.new())
	for tier in range(3):
		var origin := Vector2(35 + tier * 350, 394)
		var shapes := [
			Vector4(0, 1, 0, 0),
			Vector4(1, 1, 0, 0),
			Vector4(1, 0, 0, 1),
			Vector4(0, 1, 1, 0),
			Vector4(1, 1, 1, 1),
			Vector4(1, 0, 0, 0)
		]
		for i in range(shapes.size()):
			var cell := RoadCell.new()
			cell.position = origin + Vector2(i * 48, 0)
			cell.material = Growth.road_shader_material(
				tier if i < 5 else (tier + 1) % 3, shapes[i], Vector2(i * 48, 0)
			)
			root.add_child(cell)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/art/growth-visuals/native-assets.png") == OK)
	quit()
