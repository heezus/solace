extends SceneTree
## Step 7 Mac launch driver: opens the title scene and plays a step file with real mouse/key events, saving viewport PNGs.
## Run: godot --path . -s launch_data/shot_driver.gd -- --steps=FILE --out=DIR
## Steps (one per line): wait:SECONDS | shot:NAME | click:TEXT | key:NAME | dump | quit | speed:N | scene:res://path | eval:EXPR(not used)

var steps: Array = []
var idx := 0
var wait_left := 0.0
var out := ""
var log_file: FileAccess
var started := false
var elapsed := 0.0


func _initialize() -> void:
	var steps_file := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--steps="):
			steps_file = arg.trim_prefix("--steps=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	log_file = FileAccess.open(out.path_join("driver.log"), FileAccess.WRITE)
	for line in FileAccess.get_file_as_string(steps_file).split("\n"):
		line = line.strip_edges()
		if line != "" and not line.begins_with("#"):
			steps.append(line)
	change_scene_to_file("res://scenes/title.tscn")


func _log(s: String) -> void:
	log_file.store_line("[%.1f] %s" % [elapsed, s])
	log_file.flush()
	print(s)


func _walk(n: Node, acc: Array) -> void:
	acc.append(n)
	for c in n.get_children():
		_walk(c, acc)


func _all() -> Array:
	var acc: Array = []
	_walk(root, acc)
	return acc


var pending: Array = []


func _click_at(p: Vector2) -> void:
	p = root.get_final_transform() * p
	for pressed in [null, null, true, true, false]:
		var ev: InputEvent
		if pressed == null:
			ev = InputEventMouseMotion.new()
			ev.position = p
			ev.global_position = p
		else:
			ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = p
			ev.global_position = p
			ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		pending.append(ev)


func _process(delta: float) -> bool:
	elapsed += delta
	if not pending.is_empty():
		Input.parse_input_event(pending.pop_front())
		return false
	if wait_left > 0.0:
		wait_left -= delta
		return false
	if idx >= steps.size():
		quit(0)
		return false
	var step: String = steps[idx]
	idx += 1
	var kv := step.split(":", true, 1)
	var arg := kv[1] if kv.size() > 1 else ""
	match kv[0]:
		"wait":
			wait_left = float(arg)
		"shot":
			var err := root.get_texture().get_image().save_png(out.path_join(arg + ".png"))
			_log("shot %s -> %d" % [arg, err])
		"click":
			var hit: Button
			for n in _all():
				if n is Button and n.is_visible_in_tree() and not n.disabled and n.text.contains(arg):
					hit = n
			if hit == null:
				_log("click FAILED, no visible button '%s'" % arg)
			else:
				_click_at(hit.get_global_rect().get_center())
				_log("click '%s'" % hit.text)
		"clickxy":
			var xy := arg.split(",")
			_click_at(Vector2(float(xy[0]), float(xy[1])))
		"key":
			var code := OS.find_keycode_from_string(arg)
			for pr in [true, false]:
				var ev := InputEventKey.new()
				ev.keycode = code
				ev.physical_keycode = code
				ev.pressed = pr
				root.push_input(ev)
			_log("key " + arg)
		"dump":
			var lines: Array = []
			for n in _all():
				if (n is Button or n is Label or n is RichTextLabel) and n.is_visible_in_tree():
					var t: String = n.text if not n is RichTextLabel else n.get_parsed_text()
					if t.strip_edges() != "":
						lines.append("%s%s: %s" % [n.get_class(), " (disabled)" if n is Button and n.disabled else "", t.replace("\n", " / ").left(140)])
			_log("DUMP\n  " + "\n  ".join(lines))
		"speed":
			var cur := current_scene
			if cur and "speed" in cur:
				cur.speed = int(arg)
				_log("speed %s" % arg)
		"rerecord":  # the event is already in the checkpoint's story: record it again so its cutscene plays as in play
			var g := current_scene
			g.state.story.events.erase(arg)
			g.state.story.record(arg)
			_log("rerecorded " + arg)
		"quit":
			quit(0)
	return false
