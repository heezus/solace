extends SceneTree
## Playtest pass: plays the real main scene like a first-time player who hasn't read the docs, through real
## input events, and saves a screenshot at each step plus a text log of what the screen said (goals, info,
## toasts). Not a test: it never fails on a missed step, it reports it. Output goes to $NEWBIE_OUT.
## Run under a display: xvfb-run godot --rendering-driver opengl3 --path . -s tests/tools/newbie_pass.gd

const Data = preload("res://scripts/data.gd")

const TILE_OF := {
	"wood": "tree", "stone": "rock", "flint": "gravel", "fiber": "flax", "berries": "berry", "clay": "clay"
}

var main: Node
var game_time := 0.0
var shot_n := 0
var out_dir := "user://newbie"
var log_lines: Array = []
var capped := false
const WALL_CAP_MS := 420000


func _init() -> void:
	seed(11)
	var o := OS.get_environment("NEWBIE_OUT")
	if o != "":
		out_dir = o
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(main)
	_say("start")
	_run()


func _process(delta: float) -> bool:
	game_time += delta
	if not capped and Time.get_ticks_msec() > WALL_CAP_MS:
		capped = true
		_finish_capped()
	return false


func _finish_capped() -> void:
	_say("WALL-CLOCK CAP HIT: the pass was still running")
	await _shot("wall_cap")
	quit(0)


# --- helpers ---------------------------------------------------------------------------------------


func _say(text: String) -> void:
	var line := "[%6.1fs] %s" % [game_time, text]
	print(line)
	log_lines.append(line)
	_write_log()


func _wait(sec: float) -> void:
	var until := game_time + sec
	while game_time < until:
		await process_frame


func _screen_of(p: Vector2i) -> Vector2:
	return main.position + (Vector2(p) + Vector2(0.5, 0.5)) * main.TILE * main.scale.x


func _win(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _move(canvas_at: Vector2) -> void:
	var at := _win(canvas_at)
	Input.warp_mouse(at)
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _button(canvas_at: Vector2, index: MouseButton, pressed: bool) -> void:
	var at := _win(canvas_at)
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = index
	e.pressed = pressed
	if pressed and index == MOUSE_BUTTON_LEFT:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _click(at: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	_move(at)
	_button(at, index, true)
	_button(at, index, false)


func _click_control(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		_say("(could not click a hidden control)")
		return
	_click(c.get_global_rect().get_center())


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _screen_text() -> String:
	var goals: Array = []
	for g in main.goal_labels:
		if g.text != "":
			goals.append(g.text)
	var inv := []
	var s = main.state
	for id in s.inv:
		if s.inv[id] > 0:
			inv.append("%s %d" % [id, s.inv[id]])
	return (
		"GOALS: %s\n    INFO: %s\n    TOAST: %s\n    HAVE: %s\n    KITH: %d, learned: %s"
		% [
			" | ".join(goals),
			main.info_label.text.replace("\n", " / "),
			main.toast_label.text if main.toast_label.visible else "",
			", ".join(inv),
			s.kith.size() if "kith" in s else -1,
			", ".join(s.learned.keys()),
		]
	)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	shot_n += 1
	var img := root.get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, shot_n, name]
	img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
	_say("SHOT %02d %s\n    %s" % [shot_n, name, _screen_text()])


func _nearest(tile: String) -> Vector2i:
	var s = main.state
	var best := Vector2i(-1, -1)
	for y in s.HEIGHT:
		for x in s.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == tile and s.fog.is_revealed(p) and not s.building_at.has(p):
				if best.x < 0 or Vector2(p).distance_to(Vector2(s.camp_pos)) < Vector2(best).distance_to(Vector2(s.camp_pos)):
					best = p
	return best


## Hold on the nearest tile of `item` until `cond` holds or `limit` seconds pass.
func _gather_until(item: String, cond: Callable, limit: float) -> bool:
	var tile := _nearest(TILE_OF[item])
	if tile.x < 0:
		_say("no visible %s tile to gather" % item)
		return false
	_move(_screen_of(tile))
	_button(_screen_of(tile), MOUSE_BUTTON_LEFT, true)
	var until := game_time + limit
	var probed := false
	while game_time < until and not cond.call():
		await process_frame
		if not probed and game_time > until - limit + 6.0:
			probed = true
			var st = main.state
			_say(
				"probe %s: tile %s at %s, holding=%s, frac=%.2f, harvest_tile=%s, hand_counts=%s, hover=%s"
				% [item, st.tile_at(tile), tile, main.holding, st.harvest_frac, st.harvest_tile, st.hand_counts, main.hover]
			)
		if main.state.tile_at(tile) != TILE_OF[item] or not main.holding:
			# tile ran out: hop to the next nearest one, as a player would
			_button(_screen_of(tile), MOUSE_BUTTON_LEFT, false)
			tile = _nearest(TILE_OF[item])
			if tile.x < 0:
				return cond.call()
			_move(_screen_of(tile))
			_button(_screen_of(tile), MOUSE_BUTTON_LEFT, true)
	_button(_screen_of(tile), MOUSE_BUTTON_LEFT, false)
	return cond.call()


func _open_board_and_click(tech: String) -> void:
	_key(KEY_T)
	await _wait(0.5)
	var panel = main.tech_panel
	if not panel.visible:
		_say("T did not open the research board")
		return
	var board = panel.board
	panel.scroll.scroll_horizontal = int(board.card_rect(tech).position.x - 200.0)
	panel.scroll.scroll_vertical = int(board.card_rect(tech).position.y - 100.0)
	await _wait(0.3)
	_move(board.get_global_transform() * board.card_rect(tech).get_center())
	await _shot("board_hover_" + tech)
	_click(board.get_global_transform() * board.card_rect(tech).get_center())
	await _wait(0.3)
	await _shot("board_after_click_" + tech)
	_key(KEY_T)
	await _wait(0.3)


var _last_spot := Vector2i(-1, -1)


func _place_near(type: String, tile: String, label: String) -> void:
	var s = main.state
	_click_control(main.bottom_bar.tab_buttons["Gathering"])
	_click_control(main.bottom_bar.build_buttons[type]["button"])
	var near := _nearest(tile)
	var spot := Vector2i(-1, -1)
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = near + Vector2i(dx, dy)
				if spot.x < 0 and s.placement_error(type, p) == "":
					spot = p
	_last_spot = spot
	_move(_screen_of(spot))
	await _shot(label + "_preview")
	_click(_screen_of(spot))
	await _wait(1.0)
	_key(KEY_ESCAPE)
	await _shot(label + "_placed")
	_say("%s placed=%s" % [label, s.building_at.has(spot)])


func _write_log() -> void:
	var f := FileAccess.open(out_dir + "/log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines) + "\n")
		f.close()


# --- the newcomer's session ------------------------------------------------------------------------


func _run() -> void:
	await _wait(1.0)
	var s = main.state
	await _shot("first_look")
	await _wait(4.0)
	await _shot("after_4s_doing_nothing")

	# A newcomer clicks the thing that looks like a resource, once.
	var tree := _nearest("tree")
	_say("quick-click on the nearest tree at %s" % [tree])
	_click(_screen_of(tree))
	await _wait(1.0)
	await _shot("quick_click_tree")

	_say("click the Hearth")
	_click(_screen_of(s.camp_pos))
	await _wait(0.5)
	await _shot("click_hearth")

	# Poke the bottom bar: every tab, and a locked build button.
	for tab in main.bottom_bar.tab_buttons:
		_click_control(main.bottom_bar.tab_buttons[tab])
		await _wait(0.3)
	await _shot("last_build_tab")
	_click_control(main.bottom_bar.tab_buttons["Gathering"])
	await _wait(0.3)
	_click_control(main.bottom_bar.build_buttons["gatherers_hut"]["button"])
	await _wait(0.3)
	_say("clicked Gatherer's Hut before researching it; placing = '%s'" % main.placing)
	_move(_screen_of(s.camp_pos + Vector2i(2, 2)))
	await _shot("locked_hut_click")
	_key(KEY_ESCAPE)

	# Peek at the research board before knowing anything.
	_key(KEY_T)
	await _wait(0.8)
	await _shot("research_board_first_open")
	_key(KEY_T)
	await _wait(0.3)

	# Follow the goals the way the panel says.
	_say("hold on a tree until a Kith learns Wood")
	var t0 := game_time
	var ok := await _gather_until("wood", func(): return s.people.knows("wood"), 90.0)
	_say("wood learned=%s after %.0fs" % [ok, game_time - t0])
	await _shot("wood_learned")

	for item in ["stone", "flint"]:
		t0 = game_time
		ok = await _gather_until(item, func(): return s.people.knows(item), 120.0)
		_say("%s learned=%s after %.0fs" % [item, ok, game_time - t0])
	await _shot("stone_flint_learned")

	if _nearest("flax").x < 0:
		_say("NO FLAX VISIBLE from the start: a newcomer would have to explore")
		await _shot("no_flax_visible")
	else:
		t0 = game_time
		ok = await _gather_until("fiber", func(): return s.people.knows("fiber") or s.inv.get("fiber", 0) >= 10, 120.0)
		_say("fiber learned/have=%s after %.0fs" % [ok, game_time - t0])
		await _shot("fiber_gathered")

	# Research Knapping, craft Flint Tools.
	if not s.can_research("knapping"):
		_say("cannot afford Knapping yet: %s" % [Data.TECHS["knapping"]["cost"]])
		for item in Data.TECHS["knapping"]["cost"]:
			var need: int = Data.TECHS["knapping"]["cost"][item]
			await _gather_until(item, func(): return s.inv.get(item, 0) >= need, 120.0)
	await _open_board_and_click("knapping")
	_say("knapping researched=%s" % s.researched.has("knapping"))
	for r in main.bottom_bar.craft_buttons:
		_click_control(main.bottom_bar.craft_buttons[r])
	await _wait(0.5)
	await _shot("after_craft_click")

	# Hut needs Foraging + Knapping.
	for tech in ["foraging", "gatherers_hut"]:
		var cost: Dictionary = Data.TECHS[tech]["cost"]
		for item in cost:
			var need: int = cost[item]
			if s.inv.get(item, 0) < need and TILE_OF.has(item):
				await _gather_until(item, func(): return s.inv.get(item, 0) >= need, 150.0)
		await _open_board_and_click(tech)
		_say("%s researched=%s" % [tech, s.researched.has(tech)])

	# Place a hut beside the trees, as the goal says. Researching it ate the wood and stone, so refill first.
	if s.researched.has("gatherers_hut"):
		var hut_cost: Dictionary = Data.BUILDINGS["gatherers_hut"]["cost"]
		_say("hut costs %s, have %s" % [hut_cost, s.inv])
		for item in hut_cost:
			var need2: int = hut_cost[item]
			await _gather_until(item, func(): return s.inv.get(item, 0) >= need2, 120.0)
		await _place_near("gatherers_hut", "tree", "hut1")
		for i in 3:
			_click(_screen_of(_last_spot))
			await _wait(0.3)
		await _wait(6.0)
		await _shot("hut1_trip_running")
		# Berries: learn them by hand, then a second hut beside the bushes.
		ok = await _gather_until("berries", func(): return s.people.knows("berries"), 90.0)
		_say("berries learned=%s" % ok)
		for item in hut_cost:
			var need3: int = hut_cost[item]
			await _gather_until(item, func(): return s.inv.get(item, 0) >= need3, 120.0)
		await _place_near("gatherers_hut", "berry", "hut2_berries")
		_click(_screen_of(_last_spot))
		await _wait(0.5)
		_key(KEY_3)
		await _wait(30.0)
		await _shot("both_huts_30s_at_3x")
		await _wait(30.0)
		await _shot("both_huts_60s_at_3x")
	else:
		_say("never got the Gatherer's Hut tech")
	_say("end of newbie pass")
	_write_log()
	quit(0)
