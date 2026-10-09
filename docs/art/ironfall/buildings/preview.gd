extends SceneTree
## Documentation-only native Ironfall building comparison.
const Rendered = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/ironfall/buildings/"

class Board extends Node2D:
	var textures: Array[Texture2D] = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,1000,430),Color("223b35"))
		label(Vector2(24,34),"Ironfall / 1x1 buildings / 46 px and 96 px inspection",22)
		for i in 2:
			var x := 32.0+i*475
			label(Vector2(x,90),["coal_mine","bloomery"][i],20)
			Rendered.fit(self,textures[i],Rect2(x,120,46,46))
			Rendered.fit(self,textures[i],Rect2(x+80,95,96,96))
			label(Vector2(x+220,90),"existing Mine / Smelter",16)
			Rendered.fit(self,Rendered.sprite("industry",i),Rect2(x+220,120,46,46))
			Rendered.fit(self,Rendered.sprite("industry",i),Rect2(x+290,95,96,96))
		label(Vector2(24,280),"Coal: dark entrance, black spoil, bucket/pulley. Bloomery: exposed clay stack, fire mouth.",17)
		label(Vector2(24,322),"Tint is painted; keep the existing 1x1 building box and gameplay/selection unchanged.",17)
		label(Vector2(24,365),"Static short smoke is in the source; any continuous flame/smoke animation stays engine work.",16)
	func label(at: Vector2,message: String,px: int) -> void:
		draw_string(ThemeDB.fallback_font,at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color("efe8d5"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,430)
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
	print("IRONFALL_BUILDINGS_CAPTURE saved=",error)
	quit(0 if error==OK else 1)
