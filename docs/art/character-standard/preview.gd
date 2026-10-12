extends SceneTree
## Documentation comparison only: production art is unchanged.
const R = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/character-standard/"
class Board extends Node2D:
	var candidate: Texture2D
	func text(at: Vector2, value: String, px := 20) -> void:
		draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color("efe8d5"))
	func figure(tex: Texture2D, x: float, feet: float, h: float) -> void:
		R.fit(self,tex,Rect2(x-h*0.5,feet-h,h,h))
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,850),Color("172c30"))
		text(Vector2(30,36),"Character scale / existing sources / no production change",25)
		text(Vector2(30,76),"CURRENT: Kith 35 px cell; Lumen / Sela 24 px fit boxes",20)
		draw_line(Vector2(30,175),Vector2(1240,175),Color("6b8580"),1)
		R.kith(self,Vector2(120,172),"scale-reference",false,0.0,false)
		R.stranger(self,Vector2(250,175),1)
		R.stranger(self,Vector2(370,175),0)
		R.building(self,"dwelling",Rect2(490,127,48,48))
		R.fit(self,R.named("hearth"),Rect2(665,79,96,96))
		text(Vector2(85,211),"Kith")
		text(Vector2(218,211),"Lumen")
		text(Vector2(341,211),"Sela")
		text(Vector2(480,211),"1x1 home")
		text(Vector2(665,211),"2x2 Hearth")
		text(Vector2(30,263),"REVIEW: ordinary Kith / Lumen 35 px; Sela 38 px candidate",20)
		draw_line(Vector2(30,355),Vector2(1240,355),Color("6b8580"),1)
		R.kith(self,Vector2(120,352),"scale-reference",false,0.0,false)
		figure(R.sprite("starfall-lumen-strangers",1),250,355,35)
		figure(R.lead_sprite(),370,355,38)
		R.building(self,"dwelling",Rect2(490,307,48,48))
		R.fit(self,R.named("hearth"),Rect2(665,259,96,96))
		figure(candidate,870,355,38)
		text(Vector2(815,387),"38 px candidate",17)
		text(Vector2(30,405),"ENLARGED SOURCE AUDIT: compare head / torso / legs, not only fitted height",20)
		figure(R.sprite("walk",1),150,740,280)
		figure(R.sprite("starfall-lumen-strangers",1),460,740,280)
		figure(R.lead_sprite(),750,740,304)
		figure(candidate,1050,740,304)
		text(Vector2(60,785),"Kith source")
		text(Vector2(380,785),"Lumen source")
		text(Vector2(670,785),"Sela identity source")
		text(Vector2(980,785),"Sela candidate")
		text(Vector2(30,827),"Candidate needs owner review: closer miniature anatomy, detail/camera still under review.",19)
func _init() -> void:
	call_deferred("capture")
func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	var source := Image.load_from_file(HERE+"sela-candidate.png")
	board.candidate = ImageTexture.create_from_image(source.get_region(Rect2i(255,159,604,1240)))
	viewport.add_child(board)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(HERE+"scale-review.png")
	print("CHARACTER_STANDARD_CAPTURE saved=",error)
	quit(0 if error==OK else 1)
