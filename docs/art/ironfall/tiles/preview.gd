extends SceneTree
## Documentation-only native Ironfall resource review; production remains Claude's hook.
const Rendered = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/ironfall/tiles/"

class Board extends Node2D:
	var rows: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,1040,660),Color("223b35"))
		label(Vector2(24,32),"Ironfall resources / 48 px cells with 45 px feature art",22)
		for row in rows.size():
			var y := 100.0+row*145.0
			label(Vector2(24,y),str(rows[row].id),18)
			for i in 3:
				var tex: Texture2D = rows[row].textures[i]
				var at := Vector2(200+i*160,y-20)
				draw_rect(Rect2(at-Vector2(1,1),Vector2(48,48)),Color("425746"))
				Rendered.fit(self,tex,Rect2(at,Vector2(45,45)))
				Rendered.fit(self,tex,Rect2(at+Vector2(52,-20),Vector2(90,90)))
			label(Vector2(710,y),"existing plain ore / copper",14)
			Rendered.fit(self,Rendered.sprite("rocks",0),Rect2(720,y+12,45,45))
			Rendered.fit(self,Rendered.sprite("rocks",3),Rect2(785,y+12,45,45))
		label(Vector2(24,590),"Top coal and bottom spent sets retain paired ridge shapes; tint is already painted.",17)
		label(Vector2(24,625),"No production renderer edits; stable type/coordinate selection and discovery stay unchanged.",16)
	func label(at: Vector2,message: String,px: int) -> void:
		draw_string(ThemeDB.fallback_font,at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color("efe8d5"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1040,660)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(HERE+"spec.json"))
	for spec in specs:
		var row := {"id":spec.id,"textures":[]}
		for r in spec.regions:
			var tex := AtlasTexture.new()
			tex.atlas = load(spec.path)
			tex.region = Rect2(r[0],r[1],r[2],r[3])
			tex.filter_clip = true
			row.textures.append(tex)
		board.rows.append(row)
	viewport.add_child(board)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(HERE+"native-review.png")
	print("IRONFALL_TILES_CAPTURE saved=",error)
	quit(0 if error==OK else 1)
