extends SceneTree
const Rendered = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/ironfall/items/"
class Board extends Node2D:
	var textures: Array[Texture2D] = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,1000,480),Color("172c30"))
		for i in 5:
			var x := 35.0 + i*195
			draw_string(ThemeDB.fallback_font,Vector2(x,36),["coal","iron_ore","iron","steel","iron_tools"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("efe8d5"))
			for j in 3:
				var px: float = [24,32,40][j]
				Rendered.fit(self,textures[i],Rect2(x,70+j*65,px,px))
			Rendered.fit(self,textures[i],Rect2(x,290,96,96))
		draw_string(ThemeDB.fallback_font,Vector2(35,445),"24 / 32 / 40 px HUD icons; 96 px inspection below. Original alpha retained.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("efe8d5"))
func _init() -> void:
	call_deferred("capture")
func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(HERE+"spec.json"))
	for spec in specs:
		var r: Array = spec.region
		var tex := AtlasTexture.new()
		tex.atlas = load(spec.path)
		tex.region = Rect2(r[0],r[1],r[2],r[3])
		tex.filter_clip = true
		board.textures.append(tex)
	viewport.add_child(board)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(HERE+"native-review.png")
	print("IRONFALL_ITEMS_CAPTURE saved=",error)
	quit(0 if error==OK else 1)
