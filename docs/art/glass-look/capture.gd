extends SceneTree
## Native paired review fixture; run with a display, -- <output directory>.
const DevStarts = preload("res://scripts/dev_starts.gd")
const Launch = preload("res://scripts/launch.gd")
const RunSave = preload("res://scripts/run_save.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
var main: Node
var frames := 0
var out := ""


func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	CutscenePlayer.suppress = true
	var s
	if FileAccess.file_exists("/tmp/solace-glass-fixture.run"):
		s = load("res://scripts/sim.gd").new()
		RunSave.restore(s, RunSave.from_json(FileAccess.get_file_as_string("/tmp/solace-glass-fixture.run")))
	else:
		s = DevStarts.build("livewire_tide")
		for i in 900:
			s.tick(0.1)
		FileAccess.open("/tmp/solace-glass-fixture.run", FileAccess.WRITE).store_string(
			RunSave.to_json(RunSave.dump(s))
		)
	Launch.ask_stage(RunSave.dump(s))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1500, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_process(false)


func _process(_delta: float) -> bool:
	frames += 1
	if frames > 3:
		main._layout()
		main.queue_redraw()
	if frames == 3:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1500, 900)
		root.content_scale_size = root.size
		# Delivery history is transient and is rebuilt by playing the loaded town.
		for i in 900:
			main.state.tick(0.1)
		main._refresh_ui()
		main.side_panel.show_info("")  # keep the review independent of the desktop cursor
		main.paused = true
		main.set_process(false)
		main.zoom_step = 3
		main.cam = (Vector2(main.state.world.camp_pos) + Vector2(0.5, 0.5)) * 48.0
		main.building_panel.select(main.state.world.camp_pos)
	if frames == 30:
		_shot("building")
		main.tech_panel.visible = true
		main.tech_panel._apply_view("all")
		main.tech_panel.refresh()
	if frames == 60:
		_shot("tech")
		main.tech_panel.visible = false
		main.messages.push("The town is ready. Goods are moving between workshops.", 0.0, true, "glass-review")
		main.msg_log.visible = true
	if frames == 90:
		_shot("messages")
		main.msg_log.visible = false
		main.messages.dismiss(main.messages.active[-1]["id"])
		for c in main.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("sight_layer.gd"):
				c.latched = true
	if frames == 120:
		_shot("sight")
		quit()
	return false


func _shot(id: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(id + ".png"))
	var geometry := {}
	for c in main.find_children("*", "Control", true, false):
		if c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			geometry[str(main.get_path_to(c))] = [r.position.x, r.position.y, r.size.x, r.size.y]
	FileAccess.open(out.path_join(id + "-geometry.json"), FileAccess.WRITE).store_string(JSON.stringify(geometry))
	print("Captured ", id)
