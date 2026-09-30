extends SceneTree
## Playtest pass: plays the real main scene like a first-time player who hasn't read the docs, through real
## input events, and saves a screenshot at each step plus a text log of what the screen said (goals, info,
## toasts). Not a test: it never fails on a missed step, it reports it. Output goes to $NEWBIE_OUT.
## Run under a display: xvfb-run godot --rendering-driver opengl3 --path . -s tests/tools/newbie_pass.gd

const Data = preload("res://scripts/data.gd")
const World = preload("res://scripts/world.gd")

const TILE_OF := {
	"wood": "tree", "stone": "rock", "flint": "gravel", "fiber": "flax", "berries": "berry", "clay": "clay"
}

var main: Node
var game_time := 0.0
var shot_n := 0
var out_dir := "user://newbie"
var log_lines: Array = []
var capped := false
const WALL_CAP_MS := 780000


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
	for g in main.side_panel.goal_labels:
		if g.text != "":
			goals.append(g.text)
	var inv := []
	var s = main.state
	for id in s.economy.inv:
		if s.economy.inv[id] > 0:
			inv.append("%s %d" % [id, s.economy.inv[id]])
	return (
		"GOALS: %s\n    INFO: %s\n    TOAST: %s\n    HAVE: %s\n    KITH: %d, learned: %s"
		% [
			" | ".join(goals),
			main.side_panel.info_label.text.replace("\n", " / "),
			_toast_text(),
			", ".join(inv),
			s.people.kith.size(),
			", ".join(s.people.learned_by.keys()),
		]
	)


func _toast_text() -> String:
	var out: Array = []
	for m in main.messages.active:
		out.append(m["text"])
	return " || ".join(out)


func _layout_text() -> String:
	return "map_pos=%s scale=%s top_bar_h=%.0f side_w=%.0f" % [main.position, main.scale, main.top_bar.size.y, main.side_panel.size.x]


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	shot_n += 1
	var img := root.get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, shot_n, name]
	img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
	_say("SHOT %02d %s\n    %s\n    LAYOUT: %s" % [shot_n, name, _screen_text(), _layout_text()])


func _nearest(tile: String) -> Vector2i:
	var s = main.state
	var best := Vector2i(-1, -1)
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and s.fog.is_revealed(p) and not s.town.building_at.has(p):
				if best.x < 0 or Vector2(p).distance_to(Vector2(s.world.camp_pos)) < Vector2(best).distance_to(Vector2(s.world.camp_pos)):
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
				% [item, st.world.tile_at(tile), tile, main.holding, st.harvest_frac, st.harvest_tile, st.hand_counts, main.hover]
			)
		if main.state.world.tile_at(tile) != TILE_OF[item] or not main.holding:
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


func _place_near(type: String, tile: String, label: String, tab := "Gathering") -> void:
	var s = main.state
	_click_control(main.bottom_bar.tab_buttons[tab])
	_click_control(main.bottom_bar.build_buttons[type]["button"])
	var near: Vector2i = s.world.camp_pos if tile == "" else _nearest(tile)
	var spot := Vector2i(-1, -1)
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = near + Vector2i(dx, dy)
				if spot.x < 0 and s.town.placement_error(type, p) == "":
					spot = p
	_last_spot = spot
	_move(_screen_of(spot))
	await _shot(label + "_preview")
	_click(_screen_of(spot))
	await _wait(1.0)
	_key(KEY_ESCAPE)
	await _shot(label + "_placed")
	_say("%s placed=%s" % [label, s.town.building_at.has(spot)])


func _afford_by_hand(cost: Dictionary, label: String) -> bool:
	var s = main.state
	for item in cost:
		var need: int = cost[item]
		if s.economy.inv.get(item, 0) < need:
			if not TILE_OF.has(item):
				_say("%s needs %d %s, which can't be hand-gathered (have %d)" % [label, need, item, s.economy.inv.get(item, 0)])
				return false
			await _gather_until(item, func(): return s.economy.inv.get(item, 0) >= need, 120.0)
	return true


func _kith_check(label: String) -> void:
	var s = main.state
	var rows: Array = []
	var on_map := 0
	for k in s.people.kith:
		var pos: Vector2 = k["pos"]
		if pos.x >= 0 and pos.y >= 0 and pos.x < World.WIDTH and pos.y < World.HEIGHT:
			on_map += 1
		rows.append("%s@(%.1f,%.1f) job=%s" % [k.get("name", "?"), pos.x, pos.y, k.get("job", "")])
	_say("KITH %s: %d on map: %s" % [label, on_map, "; ".join(rows)])


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
	_click(_screen_of(s.world.camp_pos))
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
	_move(_screen_of(s.world.camp_pos + Vector2i(2, 2)))
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
		ok = await _gather_until("fiber", func(): return s.people.knows("fiber") or s.economy.inv.get("fiber", 0) >= 10, 120.0)
		_say("fiber learned/have=%s after %.0fs" % [ok, game_time - t0])
		await _shot("fiber_gathered")

	# Research Knapping, craft Flint Tools.
	if not s.tech_tree.can_research("knapping"):
		_say("cannot afford Knapping yet: %s" % [Data.TECHS["knapping"]["cost"]])
		for item in Data.TECHS["knapping"]["cost"]:
			var need: int = Data.TECHS["knapping"]["cost"][item]
			await _gather_until(item, func(): return s.economy.inv.get(item, 0) >= need, 120.0)
	await _open_board_and_click("knapping")
	_say("knapping researched=%s" % s.tech_tree.researched.has("knapping"))
	for r in main.bottom_bar.craft_buttons:
		_click_control(main.bottom_bar.craft_buttons[r])
	await _wait(0.5)
	await _shot("after_craft_click")

	# Hut needs Foraging + Knapping.
	for tech in ["foraging", "gatherers_hut"]:
		var cost: Dictionary = Data.TECHS[tech]["cost"]
		for item in cost:
			var need: int = cost[item]
			if s.economy.inv.get(item, 0) < need and TILE_OF.has(item):
				await _gather_until(item, func(): return s.economy.inv.get(item, 0) >= need, 150.0)
		await _open_board_and_click(tech)
		_say("%s researched=%s" % [tech, s.tech_tree.researched.has(tech)])

	# Place a hut beside the trees, as the goal says. Researching it ate the wood and stone, so refill first.
	if s.tech_tree.researched.has("gatherers_hut"):
		var hut_cost: Dictionary = Data.BUILDINGS["gatherers_hut"]["cost"]
		_say("hut costs %s, have %s" % [hut_cost, s.economy.inv])
		for item in hut_cost:
			var need2: int = hut_cost[item]
			await _gather_until(item, func(): return s.economy.inv.get(item, 0) >= need2, 120.0)
		await _place_near("gatherers_hut", "tree", "hut1")
		for i in 3:
			_click(_screen_of(_last_spot))
			await _wait(0.3)
		await _wait(6.0)
		await _shot("hut1_trip_running")
		main.building_panel.select(Vector2i(-1, -1))  # close the hut popup: it covers the bushes
		# Berries: learn them by hand, then a second hut beside the bushes.
		ok = await _gather_until("berries", func(): return s.people.knows("berries"), 90.0)
		_say("berries learned=%s" % ok)
		for item in hut_cost:
			var need3: int = hut_cost[item]
			await _gather_until(item, func(): return s.economy.inv.get(item, 0) >= need3, 120.0)
		await _place_near("gatherers_hut", "berry", "hut2_berries")
		_click(_screen_of(_last_spot))
		await _wait(0.5)
		var f = main.building_panel.parts["focus"]
		_say("hut2 focus panel: visible=%s text='%s' hut focus=%s" % [f.visible, f.text, main.state.town.buildings[main.state.town.building_at[_last_spot]]["focus"]])
		await _shot("hut2_selected_focus")
		if f.visible and not f.disabled and main.state.town.buildings[main.state.town.building_at[_last_spot]]["focus"] != "berries":
			for i in 4:
				_click_control(f)
				await _wait(0.3)
				if main.state.town.buildings[main.state.town.building_at[_last_spot]]["focus"] == "berries":
					break
			_say("after clicking focus: '%s'" % f.text)
			await _shot("hut2_focus_changed")
		main.building_panel.select(Vector2i(-1, -1))
		_key(KEY_3)
		await _wait(30.0)
		await _shot("both_huts_30s_at_3x")
		await _wait(30.0)
		await _shot("both_huts_60s_at_3x")
		# Watch the Kith at normal speed: are they visible, do they move?
		_key(KEY_1)
		for i in 4:
			_kith_check("t%d" % i)
			await _shot("kith_watch_%d" % i)
			await _wait(1.5)
		_key(KEY_3)
		# A Dwelling: room for more Kith.
		var dw: Dictionary = Data.BUILDINGS["dwelling"]["cost"]
		if await _afford_by_hand(dw, "Dwelling"):
			await _place_near("dwelling", "", "dwelling", "Homes")
		await _wait(20.0)
		await _shot("after_dwelling")
		# Fire, then a Charcoal Pit; Cordage, then a Twine Post.
		for pair in [["fire", "charcoal_pit"], ["cordage", "twine_post"]]:
			var tech: String = pair[0]
			var bld: String = pair[1]
			if await _afford_by_hand(Data.TECHS[tech]["cost"], tech):
				await _open_board_and_click(tech)
				_say("%s researched=%s" % [tech, s.tech_tree.researched.has(tech)])
			if s.tech_tree.researched.has(tech) and await _afford_by_hand(Data.BUILDINGS[bld]["cost"], bld):
				await _place_near(bld, "", bld, "Workshops")
		await _wait(30.0)
		await _shot("workshops_30s_later")
		_kith_check("end")
		await _wait(60.0)
		await _shot("final_60s_more")
		_kith_check("final")
	else:
		_say("never got the Gatherer's Hut tech")
	_say("end of newbie pass")
	_write_log()
	quit(0)
