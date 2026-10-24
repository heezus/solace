extends SceneTree
## A still of the real map view with Sight on, from a kept start: a dev start id (see scripts/dev_starts.gd) or a run-save file.
## Run with a display: xvfb-run -a godot --path . -s tests/tools/sight_shots.gd -- <dev start id or .json> <output .png> [cam x,y tiles]
## The town plays 90 game seconds first, so the last minute of hauling is there to draw.

const DevStarts = preload("res://scripts/dev_starts.gd")
const Launch = preload("res://scripts/launch.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")

var main: Node
var out := ""
var frames := 0
var look := Vector2.ZERO


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	CutscenePlayer.suppress = true
	var s: Sim
	if args[0].ends_with(".json"):
		s = Sim.new()
		var text := FileAccess.get_file_as_string(args[0])
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("run"):
			text = parsed["run"]
		RunSave.restore(s, RunSave.from_json(text))
	else:
		s = DevStarts.build(args[0])
	for i in 900:
		s.tick(0.1)
	look = Vector2(s.world.camp_pos)
	if args.size() > 2:
		var xy := args[2].split(",")
		look = Vector2(float(xy[0]), float(xy[1]))
	Launch.ask_stage(RunSave.dump(s))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1500, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		main.zoom_step = 3
		main.cam = (look + Vector2(0.5, 0.5)) * 48.0
		for c in main.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("sight_layer.gd"):
				c.latched = true
	if frames == 150:
		root.get_texture().get_image().save_png(out)
		print("Wrote ", out)
		quit(0)
	return false
