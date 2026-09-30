extends SceneTree
## Plays the real main scene like a person, with the UI live, so runtime errors show up in the log:
## mouse moves and clicks over the map, the build bar tabs and buttons, the building panel, the top bar
## and the research board; keys T, Space, 1, 2, 3, X and Esc; placing, clicking and demolishing
## buildings; then the pacing bot (tests/autoplay.gd) plays on to Bronze Dawn while the UI draws.
## Run under a display: xvfb-run godot --path . -s tests/tools/play_pass.gd
## CI fails the step if the output has any ERROR, SCRIPT ERROR, WARNING or Parse Error line.

const Data = preload("res://scripts/data.gd")
const Autoplay = preload("res://tests/autoplay.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Hands = preload("res://scripts/hands.gd")
const Research = preload("res://scripts/research.gd")

const BOT_STEPS_PER_FRAME := 40
const MAX_FRAMES := 4000

var main: Node
var frame := 0
var game_time := 0.0  # seconds the game has been given: the sum of the frames' deltas (see _wait_for)
var steps: Array = []  # Callables, one run per frame after the scene is up
var bot: Autoplay
var problems: Array = []
var probe := {}  # what the input checks measured, between their steps
var won_at := -1  # the frame Bronze Dawn was researched


func _init() -> void:
	seed(7)  # the same map every run
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	frame += 1
	game_time += delta
	if frame == 3:
		_script()
	if frame > 3 and not steps.is_empty():
		var next: Callable = steps.pop_front()
		next.call()
	elif frame > 3 and bot != null:
		for i in BOT_STEPS_PER_FRAME:
			if main.state.won:
				break
			main.state.tick(Autoplay.DT)
			bot.step(false)
		if main.state.won and won_at < 0:
			won_at = frame
		if won_at > 0 and frame >= won_at + 5:
			_finish()
	if frame > MAX_FRAMES:
		problems.append("the bot didn't reach Bronze Dawn in %d frames" % MAX_FRAMES)
		_finish()
	return false


func _finish() -> void:
	if not main.win_overlay.visible:
		problems.append("the win overlay isn't showing")
	for p in problems:
		printerr("PLAY PASS PROBLEM: " + p)
	if bot:
		for line in bot.lines:
			print("  ", line)
	print("Play pass done at frame %d, %.1f simulated minutes" % [frame, bot.clock / 60.0 if bot else 0.0])
	quit(1 if not problems.is_empty() else 0)


# --- Input helpers -------------------------------------------------------------


func _screen_of(p: Vector2i) -> Vector2:
	return main.position + (Vector2(p) + Vector2(0.5, 0.5)) * main.TILE * main.scale.x


## Canvas coordinates (what Controls and the map use) to window coordinates (what input events carry).
func _win(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _move(canvas_at: Vector2) -> void:
	var at := _win(canvas_at)
	Input.warp_mouse(at)  # the map reads the pointer itself, not only the events
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
		problems.append("can't click a hidden control: %s %s, frame %d" % [c, c.text if c is Button else "", frame])
		return
	_click(c.get_global_rect().get_center())


## Press the left button at `at` and keep it down.
func _hold_on(at: Vector2) -> void:
	_move(at)
	_button(at, MOUSE_BUTTON_LEFT, true)


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		problems.append(problem)


## Hold the script until `cond` is true, for up to `ms` milliseconds of game time. Holds, cooldowns and
## the rest of the game run on frame deltas, and on a slow or busy machine Godot smooths and caps
## those, so the game runs slower than the wall clock: wall-clock limits here made CI flaky.
func _wait_for(cond: Callable, problem: String, ms: int) -> void:
	var until := [-1.0]
	var poll := func(self_ref: Callable) -> void:
		if until[0] < 0.0:
			until[0] = game_time + ms / 1000.0
		if cond.call():
			return
		if game_time > until[0]:
			problems.append(problem)
			return
		steps.push_front(func(): self_ref.call(self_ref))
	steps.append(func(): poll.call(poll))


## Click every build tab three times over in one frame, with the button already down on the map:
## each click must switch the tab at once, and none may reach the map.
func _rapid_tabs() -> void:
	var s = main.state
	var names: Array = main.bottom_bar.tab_buttons.keys()
	var stone: int = s.hand_counts.get("stone", 0)
	for i in 3:
		for tab_name in names:
			_click_control(main.bottom_bar.tab_buttons[tab_name])
			_expect(main.bottom_bar.tab == tab_name, "the %s tab didn't switch at once" % tab_name)
	_expect(s.hand_counts.get("stone", 0) == stone, "a tab click harvested Stone")
	_expect(main.placing == "", "a tab click started placing something")


func _key(code: Key) -> void:
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


func _nearest(tile: String) -> Vector2i:
	var s = main.state
	var best := Vector2i(-1, -1)
	for y in s.HEIGHT:
		for x in s.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == tile and s.fog.is_revealed(p) and not s.building_at.has(p):
				if (
					best.x < 0
					or Vector2(p).distance_to(Vector2(s.camp_pos)) < Vector2(best).distance_to(Vector2(s.camp_pos))
				):
					best = p
	return best


## A free grass tile next to `near`, or (-1, -1).
func _grass_by(near: Vector2i) -> Vector2i:
	var s = main.state
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = near + Vector2i(dx, dy)
				if s.placement_error("gatherers_hut", p) == "":
					return p
	return Vector2i(-1, -1)


# --- The script --------------------------------------------------------------


func _script() -> void:
	var s = main.state
	# Look around: hover the Hearth, the fog, the river, every resource.
	_then(func(): _move(_screen_of(s.camp_pos)))
	_then(func(): _move(_screen_of(Vector2i(0, 0))))
	for tile in ["tree", "rock", "gravel", "berry", "grain", "river", "grass"]:
		var p := _nearest(tile)
		if p.x >= 0:
			_then(func(): _move(_screen_of(p)))
	# Hold on trees until a Kith learns Wood; a quick click harvests nothing.
	_then(func(): _click(_screen_of(_nearest("tree"))))
	_then(func(): _expect(s.hand_counts.is_empty(), "a quick click harvested something"), 30)
	_then(func(): _hold_on(_screen_of(_nearest("tree"))))
	_wait_for(func(): return s.knows("wood"), "holding on a tree didn't teach Wood", 20000)
	_then(func(): _button(_screen_of(_nearest("tree")), MOUSE_BUTTON_LEFT, false))
	_then(func(): _expect(not main.holding and s.harvest_frac == 0.0, "letting go didn't empty the ring"))
	# The hold ring through the real input path: timing, letting go early, moving, holding on.
	_hold_checks()
	# UI clicks are never throttled and never harvest: tabs switch on every click, even mid-hold.
	_then(func(): _hold_on(_screen_of(_nearest("rock"))))
	_then(func(): _rapid_tabs(), 20)
	_then(func(): _button(Vector2(5, 300), MOUSE_BUTTON_LEFT, false))
	_then(
		func():
			for item in ["stone", "flint", "berries", "fiber"]:
				s.learned[item] = "Tester"
	)
	# Research the first techs and try every tab and build button, and both crafts.
	_then(
		func():
			for id in s.inv:
				s.inv[id] = maxi(s.inv[id], 40)
			for tech in ["knapping", "foraging", "cordage", "fire", "gatherers_hut", "storytelling"]:
				s.research(tech)
			for id in s.inv:
				s.inv[id] = maxi(s.inv[id], 40)
	)
	for tab in main.bottom_bar.tab_buttons:
		_then(func(): _click_control(main.bottom_bar.tab_buttons[tab]))
		for type in Data.BUILD_TABS[tab]:
			_then(func(): _move(main.bottom_bar.build_buttons[type]["button"].get_global_rect().get_center()))
	for r in main.bottom_bar.craft_buttons:
		_then(func(): _click_control(main.bottom_bar.craft_buttons[r]))
	# Place a hut by the forest from the build bar, then send trips and open its panel.
	_then(func(): _click_control(main.bottom_bar.tab_buttons["Gathering"]))
	_then(func(): _click_control(main.bottom_bar.build_buttons["gatherers_hut"]["button"]))
	_then(func(): _click(_screen_of(_grass_by(_nearest("tree")))))
	_then(func(): _click(Vector2(5, 300), MOUSE_BUTTON_RIGHT))
	_then(func(): _click_building("gatherers_hut", Data.TRIP_QUEUE + 1), 5)
	for key in ["pause", "pause", "collect"]:
		_then(func(): _click_panel(key), 2)
	# Right after a harvest, the first click on the build bar and the building panel responds at once.
	_then(func(): _key(KEY_ESCAPE))
	_then(
		func():
			probe["paid"] = s.hand_counts.get("stone", 0)
			_hold_on(_screen_of(_nearest("rock")))
	)
	_wait_for(
		func(): return s.hand_counts.get("stone", 0) > probe["paid"],
		"the hold before the UI clicks never paid out",
		5000
	)
	_then(func(): _first_click_checks())
	# A workshop: place, click, pause, resume.
	_then(func(): _key(KEY_ESCAPE))
	_then(func(): _click_control(main.bottom_bar.tab_buttons["Workshops"]))
	_then(func(): _click_control(main.bottom_bar.build_buttons["charcoal_pit"]["button"]))
	_then(func(): _click(_screen_of(_grass_by(s.camp_pos + Vector2i(2, 2)))))
	_then(func(): _key(KEY_ESCAPE))
	_then(func(): _click_building("charcoal_pit", 3), 5)
	for key in ["pause", "pause", "collect"]:
		_then(func(): _click_panel(key), 2)
	# Speed keys and pause.
	for key in [KEY_SPACE, KEY_SPACE, KEY_2, KEY_3, KEY_1]:
		_then(func(): _key(key), 3)
	for v in main.top_bar.speed_buttons:
		_then(func(): _click_control(main.top_bar.speed_buttons[v]))
	# Hover the goods in the top bar.
	for id in main.top_bar.chips:
		_then(func(): _move(main.top_bar.chips[id]["box"].get_global_rect().get_center()))
	# The research board: open, hover and click cards, close.
	_then(func(): _key(KEY_T), 3)
	_then(func(): _tech_board(), 5)
	_then(
		func():
			_click_card("calendar")
			_click_control(main.tech_panel.strip["button"]),
		2
	)
	# Buy Knapping's rank II from its card, then from the strip's button once it's affordable again.
	_then(func(): _show_rank("knapping"), 2)
	_then(func(): _click_card("knapping"), 2)
	_then(func(): _expect(Ranks.rank(main.state, "knapping") == 2, "clicking Knapping didn't buy rank II"))
	_then(func(): _key(KEY_T))
	# Clicks on the research board and panels never reach the map.
	_board_click_through()
	# Demolish with X, then Esc.
	_then(func(): _key(KEY_X))
	_then(func(): _demolish_first_hut())
	_then(func(): _key(KEY_ESCAPE))
	_then(func(): _click_control(main.bottom_bar.demolish_button))
	_then(func(): _key(KEY_ESCAPE))
	# Right-click cancels placing; a dragged Road lays a line.
	_then(func(): _road_drag(), 2)
	_then(func(): _road_drag_check(), 3)
	# Then the bot plays to Bronze Dawn with the UI drawing.
	_then(func(): _start_bot(), 5)


## Click the first building of `type` n times: that selects it, so its panel opens.
func _click_building(type: String, n: int) -> void:
	for b in main.state.buildings:
		if b["type"] == type:
			for i in n:
				_click(_screen_of(b["pos"]))
			return
	problems.append("no %s was placed from the build bar" % type)


## Click a building panel button, if the panel shows it (Collect only shows with goods held).
func _click_panel(key: String) -> void:
	var panel = main.building_panel
	if not panel.visible:
		problems.append("the building panel didn't open")
	elif panel.parts[key].visible:
		_click_control(panel.parts[key])


func _tech_board() -> void:
	var panel = main.tech_panel
	if not panel.visible:
		problems.append("T didn't open the research board")
		return
	var board = panel.board
	for tech in Data.TECH_ORDER:
		var r: Rect2 = board.card_rect(tech)
		var at: Vector2 = board.get_global_transform() * r.get_center()
		_move(at)
	panel.scroll.scroll_horizontal = int(board.card_rect("calendar").position.x - 200.0)


func _show_rank(tech: String) -> void:
	var s = main.state
	for item in Ranks.next_cost(s, tech):
		s.inv[item] = s.inv.get(item, 0) + int(Ranks.next_cost(s, tech)[item])
	var board = main.tech_panel.board
	main.tech_panel.scroll.scroll_horizontal = int(board.card_rect(tech).position.x - 200.0)
	main.tech_panel.scroll.scroll_vertical = int(board.card_rect(tech).position.y - 100.0)


func _click_card(tech: String) -> void:
	var board = main.tech_panel.board
	_click(board.get_global_transform() * board.card_rect(tech).get_center())


func _demolish_first_hut() -> void:
	var s = main.state
	for b in s.buildings:
		if b["type"] == "gatherers_hut":
			_move(_screen_of(b["pos"]))
			_click(_screen_of(b["pos"]))
			return


func _start_bot() -> void:
	main.paused = true  # the bot ticks the game itself, in fixed steps
	bot = Autoplay.new()
	bot.attach(main.state)


# --- Input-path checks ---------------------------------------------------------


## Hold on a rock: the ring fills and pays out after the hold time; letting go early cancels it;
## moving to another tile starts over; holding on keeps harvesting.
func _hold_checks() -> void:
	var s = main.state
	var rock := _nearest("rock")
	var tree := _nearest("tree")
	var need: float = Hands.hold_time(s, "stone")
	# Timing: press and wait for the first Stone.
	_then(
		func():
			probe["stone"] = s.hand_counts.get("stone", 0)
			probe["t0"] = game_time
			_hold_on(_screen_of(rock))
	)
	_then(func(): _expect(main.holding, "pressing on a rock didn't start a hold"), 5)
	_then(func(): _expect(s.harvest_frac > 0.0, "the ring didn't start filling"))
	_wait_for(func(): return s.hand_counts.get("stone", 0) > probe["stone"], "holding on a rock never paid out", 5000)
	_then(
		func():
			var secs: float = game_time - probe["t0"]  # game time, like the hold itself, not the wall clock
			probe["first"] = secs
			_expect(secs >= need - 0.1 and secs <= need + 0.6, "the first Stone took %.2f s, not %.1f s" % [secs, need])
	)
	# Holding on keeps harvesting.
	_then(func(): probe["stone"] = s.hand_counts.get("stone", 0))
	_wait_for(
		func(): return s.hand_counts.get("stone", 0) >= probe["stone"] + 2, "holding on didn't keep harvesting", 6000
	)
	# Moving to another tile starts the ring over there.
	_then(func(): _move(_screen_of(tree)))
	_then(func(): _expect(s.harvest_tile == tree or s.harvest_frac < 0.5, "moving didn't reset the ring"), 2)
	_then(func(): _button(_screen_of(tree), MOUSE_BUTTON_LEFT, false))
	# Letting go early cancels: press, let go at about a third, and nothing comes.
	_then(
		func():
			probe["stone"] = s.hand_counts.get("stone", 0)
			_hold_on(_screen_of(rock))
	)
	_wait_for(func(): return s.harvest_frac > 0.2, "the ring didn't fill on the second press", 3000)
	_then(func(): _button(_screen_of(rock), MOUSE_BUTTON_LEFT, false))
	_then(func(): _expect(s.harvest_frac == 0.0 and not main.holding, "letting go early didn't empty the ring"))
	_then(func(): _expect(s.hand_counts.get("stone", 0) == probe["stone"], "letting go early still paid out"), 90)


## Just after a harvest pays out, a build button and a building panel button work on the first click.
func _first_click_checks() -> void:
	var s = main.state
	_click_control(main.bottom_bar.tab_buttons["Gathering"])
	_click_control(main.bottom_bar.build_buttons["gatherers_hut"]["button"])
	_expect(main.placing == "gatherers_hut", "the build button needed more than one click")
	_click(Vector2(5, 300), MOUSE_BUTTON_RIGHT)
	_expect(main.placing == "", "right-click didn't cancel placing")
	for b in s.buildings:
		if b["type"] == "gatherers_hut":
			_click(_screen_of(b["pos"]))
			break
	var panel = main.building_panel
	_expect(panel.visible, "clicking a hut didn't open its panel at once")
	if panel.visible and panel.parts["pause"].visible:
		var b: Dictionary = panel.selected()
		var was: bool = b["paused"]
		var counts: Dictionary = s.hand_counts.duplicate()
		_click_control(panel.parts["pause"])
		_expect(b["paused"] != was, "the panel's Pause needed more than one click")
		_click_control(panel.parts["pause"])
		_expect(s.hand_counts == counts, "a panel click harvested the tile under it")


## With the research board open over the map, a click or a held press on it harvests nothing, places
## nothing and demolishes nothing; clicking a ready card researches it at once.
func _board_click_through() -> void:
	var s = main.state
	var panel = main.tech_panel
	var over: Vector2 = _screen_of(_nearest("tree"))
	_then(
		func():
			if not panel.visible:
				_key(KEY_T)
			main.placing = ""
			probe["counts"] = s.hand_counts.duplicate()
			probe["built"] = s.buildings.size(),
		2
	)
	_then(
		func():
			_expect(panel.visible, "T didn't open the research board")
			_hold_on(over)
	)
	_then(func(): _button(over, MOUSE_BUTTON_LEFT, false), 90)
	_then(
		func():
			_expect(s.hand_counts == probe["counts"], "holding on the research board harvested the map under it")
			_expect(s.buildings.size() == probe["built"], "a board click placed or tore down a building")
			_expect(not main.holding, "the board press started a hold on the map")
			var ready: Array = Research.ready_list(s)
			if not ready.is_empty():
				var tech: String = ready[0]
				var board = panel.board
				panel.scroll.scroll_horizontal = int(board.card_rect(tech).position.x - 200.0)
				panel.scroll.scroll_vertical = int(board.card_rect(tech).position.y - 100.0)
				probe["tech"] = tech
	)
	_then(
		func():
			if probe.has("tech"):
				for item in Data.TECHS[probe["tech"]]["cost"]:
					s.inv[item] = maxi(s.inv.get(item, 0), Data.TECHS[probe["tech"]]["cost"][item])
				_click_card(probe["tech"])
				_expect(s.researched.has(probe["tech"]), "clicking a ready card didn't research it at once")
			_key(KEY_T),
		3
	)
	# The same hold with the board shut does harvest, so the check above means something.
	_then(func(): _hold_on(over), 2)
	_then(func(): _button(over, MOUSE_BUTTON_LEFT, false), 90)
	_then(func(): _expect(s.hand_counts != probe["counts"], "holding on the map with the board shut harvested nothing"))


## Place Road by dragging from one tile to another three to the side.
func _road_drag() -> void:
	var s = main.state
	s.researched["haulers"] = true
	for id in Data.BUILDINGS["road"]["cost"]:  # whatever a Road costs, enough for the drag whatever else is held
		s.inv[id] = maxi(s.inv.get(id, 0), 40)
	var start := Vector2i(-1, -1)
	for y in range(2, s.HEIGHT - 2):
		for x in range(2, s.WIDTH - 6):
			var ok := start.x < 0
			for i in 4:
				ok = ok and s.placement_error("road", Vector2i(x + i, y)) == ""
			if ok:
				start = Vector2i(x, y)
	probe["road_from"] = start
	probe["roads"] = s.roads.size()
	main.placing = "road"
	_move(_screen_of(start))
	_button(_screen_of(start), MOUSE_BUTTON_LEFT, true)


func _road_drag_check() -> void:
	var s = main.state
	var end: Vector2i = probe["road_from"] + Vector2i(3, 0)
	_move(_screen_of(end))
	_button(_screen_of(end), MOUSE_BUTTON_LEFT, false)
	_expect(
		s.roads.size() == probe["roads"] + 4, "dragging Road laid %d tiles, not 4" % (s.roads.size() - probe["roads"])
	)
	_click(_screen_of(end + Vector2i(0, 1)), MOUSE_BUTTON_RIGHT)
	_expect(main.placing == "", "right-click didn't stop laying Road")
