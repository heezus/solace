extends SceneTree
## Documentation-only captures of the production cutscene player; no save/profile writes.
const Player = preload("res://scripts/cutscene_player.gd")
const Sim = preload("res://scripts/sim.gd")
const Data = preload("res://scripts/data.gd")
const HERE := "res://docs/art/ironfall/phase-b/"

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var p := Player.new()
	viewport.add_child(p)
	p.setup(Sim.new(),null,[])
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	p.set_process(false)
	p.queue.clear()
	for frame in 4:
		await process_frame
	p.size = Vector2(1280,800)
	for seq in ["ironfall","bloom_sign"]:
		p._start(seq)
		for i in p.stills.size():
			p.index = i
			p.still_time = 5.0
			p.total_time = 5.0
			p._show_line()
			p._layout()
			p.queue_redraw()
			for frame in 8:
				await process_frame
			p._layout()
			for frame in 2:
				await process_frame
			await RenderingServer.frame_post_draw
			var id: String = p.stills[i].art
			var error := viewport.get_texture().get_image().save_png(HERE+id+"-player.png")
			if error != OK or p.texture(id) == null:
				quit(1)
				return
	viewport.size = Vector2i(1600,900)
	p.size = Vector2(1600,900)
	p._layout()
	p.queue_redraw()
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(HERE+"bloom_sign_2-wide-player.png")
	print("PHASE_B_PLAYER_CAPTURE saved=",error)
	quit(0 if error==OK else 1)
