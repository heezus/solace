extends SceneTree
## Plays one era's start like a person, with the real UI live and real mouse and key events, so runtime errors in any era show up in
## the log (tests/tools/play_pass.gd does the same for the stone age and Bronze Dawn). Give it a start id from DevStarts after `--`
## (default bronze_first); the earned starts (earned_ironfall_steam, earned_livewire) are the end of a real run through the era before.
## It opens every build tab and clicks every card on show, places a few buildings with the mouse, clicks buildings and their panel
## (pause, collect, trade lines, glyph rows), presses every tab key and the tech board, opens the menu, answers any card the game puts up,
## and lets the town run at triple speed for a while.
## Run: godot --headless --fixed-fps 60 --path . -s tests/tools/era_pass.gd -- <start id>
## Manual only (the "Era click pass" workflow), never part of CI. Fails on any ERROR, WARNING or PROBLEM line, like the other passes.

const Data = preload("res://scripts/data.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const Hotkeys = preload("res://scripts/hotkeys.gd")
const Launch = preload("res://scripts/launch.gd")
const RunSave = preload("res://scripts/run_save.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")

const PLACEMENTS := 10  # buildings put down with the mouse
const CARDS_PER_TAB := 8  # cards clicked on each tab
const RUN_FRAMES := 1500  # frames the town runs at triple speed at the end (25 s of frames, 75 s of game)
const TOP_UP := 250  # units of every good the pass gives itself, so a card is never refused for want of a few

var main: Node
var start_id := "bronze_first"
var frame := 0
var steps: Array = []
var problems: Array = []
var clicks := 0
var placed := 0
var _run_from := -1


func _init() -> void:
	Engine.max_fps = 60  # a headless run has no vsync (CI passes --fixed-fps 60)
	seed(7)
	CutscenePlayer.suppress = true
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		start_id = args[0]
	var s = DevStarts.build(start_id)
	if s == null:
		printerr("ERA PASS PROBLEM: no start called %s" % start_id)
		quit(1)
		return
	Launch.ask_stage(RunSave.dump(s))
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	if main == null:
		return false
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 800)
	frame += 1
	if frame == 3:
		_script()
	if frame > 3 and not steps.is_empty():
		var next: Callable = steps.pop_front()
		next.call()
	elif frame > 3 and steps.is_empty():
		if _run_from < 0:
			_run_from = frame
			main.speed = 3
			main.paused = false
		_answer_cards()
		if frame - _run_from > RUN_FRAMES:
			_finish()
	return false


func _finish() -> void:
	for p in problems:
		printerr("ERA PASS PROBLEM (%s): %s" % [start_id, p])
	var s = main.state
	print(
		(
			"Era pass %s done at frame %d: %d clicks, %d buildings placed, %d buildings stand, %.1f game minutes in"
			% [start_id, frame, clicks, placed, s.town.buildings.size(), s.seasons.time / 60.0]
		)
	)
	quit(1 if not problems.is_empty() else 0)


# --- Input helpers -------------------------------------------------------------


func _win(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _screen_of(p: Vector2i) -> Vector2:
	if not main.view.grow(-main.TILE).has_point(main.screen_of(p)):
		main.center_on(p)
	return main.screen_of(p)


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
	clicks += 1
	_move(at)
	_button(at, index, true)
	_button(at, index, false)


## Click a control if it is on show (a tab or card the era has not earned is hidden, which is right).
func _click_if_shown(c: Control) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	_click(c.get_global_rect().get_center())
	return true


func _key(code: Key) -> void:
	clicks += 1
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()


## Queue `f` to run on a frame of its own, `wait` frames later.
func _then(f: Callable, wait := 1) -> void:
	for i in wait - 1:
		steps.append(func(): pass)
	steps.append(f)


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		problems.append(problem)


## A free, buildable, seen tile for `type` near the Hearth, or (-1, -1).
func _spot(type: String) -> Vector2i:
	var s = main.state
	var c: Vector2i = s.world.camp_pos
	for r in range(3, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var p := c + Vector2i(dx, dy)
				if s.world.in_bounds(p) and s.fog.is_revealed(p) and s.town.placement_error(type, p) == "":
					return p
	return Vector2i(-1, -1)


func _top_up() -> void:
	var s = main.state
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = maxi(s.economy.inv.get(id, 0), TOP_UP)


# --- The script --------------------------------------------------------------


func _script() -> void:
	var s = main.state
	_then(func(): _top_up(), 30)
	_then(func(): _move(_screen_of(s.world.camp_pos)), 2)
	# Every tab, every card on show: click it, put it down with the mouse where it fits, or cancel it.
	for tab in main.bottom_bar.tab_buttons.keys():
		_then(func(): _click_if_shown(main.bottom_bar.tab_buttons[tab]), 2)
		for i in CARDS_PER_TAB:
			_then(func(): _try_card(tab, i), 3)
	_then(func(): _cancel(), 2)
	_then(func(): _expect(main.placing == "", "Esc did not cancel placing"), 2)
	# Click a building of every type, and what its panel offers.
	_then(func(): _click_buildings(), 2)
	# Every tab key, the tech board, the menu.
	for tab in Hotkeys.TAB_KEYS:
		_then(func(): _key(Hotkeys.TAB_KEYS[tab]), 3)
	_then(func(): _key(KEY_T), 3)
	_then(func(): _tech_board(), 3)
	_then(func(): _key(KEY_T), 3)
	_then(func(): _key(KEY_L), 3)
	_then(func(): _key(KEY_L), 3)
	for i in 4:  # Esc puts away the drawer, the selection and the board first, then opens the menu
		_then(func(): _open_menu_key(), 3)
	_then(func(): _menu(), 3)
	_then(func(): _key(KEY_P), 3)
	_then(func(): _key(KEY_P), 3)
	_then(func(): _round_trip(), 3)


## The `i`th card of `tab` that is on show: click it and, if it started a placement, click a tile that takes it.
func _try_card(tab: String, i: int) -> void:
	var types: Array = Data.BUILD_TABS.get(tab, []).filter(
		func(t):
			return (
				main.bottom_bar.build_buttons.has(t) and main.bottom_bar.build_buttons[t]["button"].is_visible_in_tree()
			)
	)
	if i >= types.size():
		return
	var type: String = types[i]
	_top_up()
	if not _click_if_shown(main.bottom_bar.build_buttons[type]["button"]):
		return
	if main.placing != type:
		return  # a card the era shows but cannot yet place (locked): the click said so in a toast
	var p := _spot(type)
	if p.x < 0 or placed >= PLACEMENTS:
		_cancel()
		return
	var before: int = main.state.town.buildings.size()
	_click(_screen_of(p))
	if main.state.town.buildings.size() > before:
		placed += 1
	_cancel()


## Esc while something is being placed puts it away (Esc with nothing to cancel opens the menu: that has its own step).
func _cancel() -> void:
	if main.placing != "":
		_key(KEY_ESCAPE)


## One building of each type that stands: click it, then click what its panel shows.
func _click_buildings() -> void:
	var s = main.state
	var seen := {}
	for b in s.town.buildings.duplicate():
		if seen.has(b["type"]) or Data.BUILDINGS[b["type"]]["kind"] in ["road", "bridge"]:
			continue
		seen[b["type"]] = true
		var at := b["pos"] as Vector2i
		_then(func(): _click(_screen_of(at)), 2)
		_then(func(): _panel_clicks(), 2)


## Click the panel's pause, collect, trade lines and glyph rows when the selected building has them.
func _panel_clicks() -> void:
	var panel = main.building_panel
	if not panel.visible:
		return
	for key in ["collect", "focus"]:
		if panel.parts.has(key) and panel.parts[key] is Button:
			_click_if_shown(panel.parts[key])
	if panel.parts.has("pause"):  # pause and resume again: a click each
		_click_if_shown(panel.parts["pause"])
		_click_if_shown(panel.parts["pause"])
	if panel.parts.has("trade"):
		for which in panel.parts["trade"]._lines:
			_click_if_shown(panel.parts["trade"]._lines[which])
	if panel.parts.has("glyphs") and panel.parts["glyphs"].visible:
		var n := 0
		for row in panel.parts["glyphs"].get_children():
			for c in row.find_children("*", "Button", true, false):
				if n < 4:
					n += int(_click_if_shown(c))


## Click the first few cards the research board shows.
func _tech_board() -> void:
	var panel = main.tech_panel
	_expect(panel.visible, "T did not open the research board")
	if not panel.visible:
		return
	var n := 0
	for c in panel.find_children("*", "Button", true, false):
		if n < 10 and c.is_visible_in_tree():
			_click(c.get_global_rect().get_center())
			n += 1


func _open_menu_key() -> void:
	_answer_cards()  # a card on show keeps Esc from opening the menu, so answer it first
	if not main.game_menu.is_open():
		_key(KEY_ESCAPE)


func _menu() -> void:
	_expect(main.game_menu.is_open() or main._modal_up(), "Esc did not open the menu")
	if main.game_menu.is_open():
		_key(KEY_ESCAPE)
		_then(func(): main.game_menu.close(), 2)  # shut whatever the key left open: the run below clicks the map


## Save the run and load it back: the state must survive a round trip while the UI is live.
func _round_trip() -> void:
	var dump := RunSave.dump(main.state)
	var copy = DevStarts.build("stone_age")
	_expect(
		RunSave.restore(copy, RunSave.from_json(RunSave.to_json(dump))), "the live run did not survive a save and load"
	)
	_expect(copy.town.buildings.size() == main.state.town.buildings.size(), "a save and load lost buildings")


## While the town runs: answer any card the game puts up with its first button, so the game never waits behind one.
func _answer_cards() -> void:
	if main.game_menu.is_open():
		return
	for card in [main.notice_card, main.moment_card, main.era_card]:
		if card != null and card.visible:
			for c in card.find_children("*", "Button", true, false):
				if _click_if_shown(c):
					break
	if main.paused and not main.game_menu.is_open():
		main.paused = false
