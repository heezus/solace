extends SceneTree
## Documentation-only caption and maximum-push-in review; no game/save changes.
const HERE := "res://docs/art/cutscenes/"
const GROUPS := {
	"opening": ["opening_1", "opening_2", "opening_3"],
	"bronze": ["bronze_dawn_1", "bronze_dawn_2", "bronze_dawn_3"],
	"falling": ["falling_star_1", "falling_star_2", "falling_star_3", "falling_star_4"],
	"contact": ["first_contact_1", "first_contact_1_guests", "first_contact_2", "first_contact_3"],
	"endings": ["starfall_end_1", "starfall_end_2", "starfall_end_3_neighbours", "starfall_end_3_enemies", "starfall_end_3_allies"],
	"memory": ["memory_exodus", "memory_cataclysm", "memory_loop", "memory_glyph", "memory_bloom"]
}

class Board extends Node2D:
	var ids: Array = []
	var textures: Array[Texture2D] = []
	var backdrop: Texture2D
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 1370), Color("16292d"))
		for i in ids.size():
			var at := Vector2((i % 2) * 640, int(i / 2) * 450 + 40)
			var box := Rect2(at, Vector2(640,400))
			var tex := textures[i]
			if str(ids[i]).begins_with("memory"):
				draw_texture_rect(backdrop, box, false)
				draw_texture_rect(tex, box, false, Color(1,1,1,0.12))
			else:
				var size := tex.get_size()
				var crop := size / 1.08
				draw_texture_rect_region(tex, box, Rect2((size-crop)*0.5, crop))
			for row in 100:
				draw_rect(Rect2(at+Vector2(0,267+row*1.33),Vector2(640,1.4)),Color(0.025,0.04,0.05,float(row)/100*0.75))
			draw_string(ThemeDB.fallback_font, at+Vector2(24,362), "Caption readability / 8% push-in review",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("f4edda"))
			draw_string(ThemeDB.fallback_font, at+Vector2(16,-10),str(ids[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d8e5e2"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var key := str(args[0]) if args.size() else "opening"
	var ids: Array = GROUPS[key]
	var height := int(ceil(float(ids.size())/2))*450
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.ids = ids
	for id in ids:
		var tex: Texture2D = load("res://art/rendered/cutscenes/"+str(id)+".png")
		if tex == null:
			quit(1)
			return
		board.textures.append(tex)
	if key == "memory":
		board.backdrop = load("res://art/rendered/title.png")
	viewport.add_child(board)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(HERE+key+"-review.png")
	print("CUTSCENE_REVIEW ",key," saved=",error)
	quit(0 if error == OK else 1)
