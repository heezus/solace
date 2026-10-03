extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")
const BuildBar = preload("res://scripts/build_bar.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Rules = preload("res://scripts/rules.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")
const Hands = preload("res://scripts/hands.gd")
const World = preload("res://scripts/world.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")
const KithArt = preload("res://scripts/kith_art.gd")
const SidePanel = preload("res://scripts/side_panel.gd")
const HoverText = preload("res://scripts/hover_text.gd")
const Messages = preload("res://scripts/messages.gd")
const ToastStack = preload("res://scripts/toast_stack.gd")
const EastPointer = preload("res://scripts/east_pointer.gd")
const Land = preload("res://scripts/land.gd")
const MessageLog = preload("res://scripts/message_log.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")
const EraCard = preload("res://scripts/era_card.gd")
const Profile = preload("res://scripts/profile.gd")

const TILE: float = Overlays.TILE
const MAP_ORIGIN := Vector2.ZERO  # the node's transform pans and zooms the map
const ZOOM_PX := [32.0, 48.0, 64.0]  # a tile's size on screen at each zoom step (scroll or pinch)
const DEFAULT_ZOOM := 1
const PAN_SPEED := 720.0  # screen px a second while an arrow key or WASD is held
const FRAME_W := 4.0  # the cocoa frame round the map view
const BANNER_SECONDS := 14.0  # how long the Bronze Dawn banner stays up
const FIT_SETTLE_FRAMES := 3  # frames after a window resize while the bars settle to their new size
const OUTLINE: Color = Art.OUTLINE
const OUTLINE_W := 2.5
const KITH: Color = Ui.KITH
const SIDE_W := 264.0
const BAD: Color = Ui.BAD
const GOAL_COLOR: Color = Ui.HIGHLIGHT
const LINE_TYPES := ["road", "bridge", "stone_bridge", "field"]  # laid by dragging
const AURA_FILL := Color(0.55, 0.45, 0.6, 0.2)
const NUDGE_TIME := 2.0  # seconds the "hold it down" hint stays after a click that let go too soon

var fit_vp := Vector2.ZERO  # the window size the map was last fit to
var fit_bars := Vector2.ZERO  # the top and bottom bar heights the fit uses
var fit_settle := 0
var zoom_step := DEFAULT_ZOOM
var cam := Vector2.ZERO  # the map point (in map px at TILE) at the middle of the map view
var view := Rect2()  # the map view on screen: between the bars, left of the side panel, edge to edge
var panning := false  # the middle button is down: dragging pans
var zoom_wait := 0.0  # seconds before a pinch may step the zoom again
var frame: Panel
var state: Sim
var placing := ""  # building type being placed, "" when not placing
var hover := Vector2i(-1, -1)
var drag_from := Vector2i(-1, -1)  # where a road, bridge or field drag started
var time := 0.0
var popups: Array = []  # {pos: Vector2, text: String, t: float}
var rubble: Array = []  # {pos: Vector2i, t: float}, torn-down buildings fading out

var messages := Messages.new()
var toasts: ToastStack
var east_pointer: EastPointer  # the lasting pointer to the new land (after Bronze Dawn)
var msg_log: MessageLog
var told := {}  # warm lines already said (see _watch_flavor)
var was_starving := false
var top_bar: TopBar
var bottom_bar: BuildBar
var side_panel: SidePanel
var info_label: Label  # the side panel's hover text
var tech_panel: TechPanel
var era_card: EraCard  # the Falling Star's card, put up once
var building_panel: BuildingPanel  # the selected building's card, docked in the side panel
var banner_shown := false  # the Bronze Dawn banner has been shown
var ui_refresh := 0.0
var paused := false
var speed := 1  # simulation steps per frame: 1x, 2x or 3x
var holding := false  # the left button is down on a resource tile: hold to harvest
var press_tile := Vector2i(-1, -1)  # the resource tile the current hold started on
var press_harvested := false  # a harvest completed during this press
## A click that let go before the ring filled: {tile, frac (how far it got), t}. Shown for NUDGE_TIME.
var nudge := {}


func _ready() -> void:
	Ui.apply_theme()
	state = Sim.new()
	state.generate(randi())
	cam = Overlays.center(state.world.camp_pos)  # start looking at the Hearth
	_build_ui()
	state.tech_tree.tech_researched.connect(_on_tech_researched)
	state.story.recorded.connect(_on_story)
	_toast(Data.CAMP_TOAST % Data.PEOPLE["many"] + "\n" + Data.CAMERA_HINT, 9.0)  # one toast, low on the map


func _process(delta: float) -> void:
	time += delta
	if not paused:
		for i in speed:
			state.tick(delta)
	for e in state.events:
		if e == Data.BORN_EVENT % Data.PEOPLE["one"]:
			var at := Overlays.center(state.world.camp_pos) - Vector2(0, 12)
			popups.append(
				{"pos": at, "text": Data.BORN_POPUP % Data.PEOPLE["one"], "t": 0.0, "col": KITH.lightened(0.3)}
			)
			_toast(Data.BORN_TOAST % Data.PEOPLE["many"], 3.0)
		elif e == Data.LAND_GREW_EVENT or e == Data.DISCOVERED_EVENT % Data.TECHS["bronze_dawn"]["name"]:
			continue  # the dawn says all of this once, in its banner
		else:
			var style := Messages.style_of(e)
			messages.push(e, style["seconds"], style["sticky"], style["key"])
	state.events.clear()
	if state.won and not banner_shown:
		banner_shown = true  # the stone age ends with a banner, and the game goes on
		messages.push(Data.ERA_BANNER_TITLE + "  ·  " + Data.ERA_BANNER_TEXT, BANNER_SECONDS)
	messages.keep_counts = state.tech_tree.researched.has("tally_sticks")
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.2)
	if not nudge.is_empty():
		nudge["t"] += delta
		if nudge["t"] >= NUDGE_TIME:
			nudge = {}
	for r in rubble:
		r["t"] += delta
	rubble = rubble.filter(func(r): return r["t"] < Overlays.RUBBLE_TIME)
	_watch_food()
	_watch_flavor()
	messages.advance(delta)
	zoom_wait -= delta
	if not tech_panel.visible:  # the research board takes the arrows and WASD while it is open
		_pan_with_keys(delta)
	_layout()
	hover = _tile_under()
	_hold(delta)
	ui_refresh -= delta
	if ui_refresh <= 0.0:
		ui_refresh = 0.2
		_refresh_ui()
	queue_redraw()


## Lay the map out in its view: edge to edge between the bars and left of the side panel, at the current zoom,
## looking at `cam` (kept so the map always covers the view, or centred where it is smaller). The bars keep
## steady heights (see TopBar._fix_width), and at one window size the view uses the tallest each bar has been once
## the window settled, so a bar can never make the map jump back and forth.
func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp != fit_vp:
		fit_vp = vp
		fit_settle = FIT_SETTLE_FRAMES
	if fit_settle > 0:
		fit_settle -= 1
		fit_bars = Vector2(top_bar.size.y, bottom_bar.size.y)
	else:
		fit_bars = fit_bars.max(Vector2(top_bar.size.y, bottom_bar.size.y))
	var top := fit_bars.x
	var bottom := fit_bars.y
	view = Rect2(0, top, maxf(vp.x - SIDE_W, 100.0), maxf(vp.y - top - bottom, 100.0))
	frame.position = view.position
	frame.size = view.size
	toasts.size = Vector2(maxf(view.size.x - 32.0, 100.0), maxf(view.size.y - 28.0, 100.0))
	toasts.position = Vector2(16, top + 14)  # stacked from the bottom edge up, so the lit area stays in view
	msg_log.position = Vector2(16, vp.y - bottom - msg_log.size.y - 16)
	era_card.place(view)
	side_panel.position = Vector2(view.end.x, top)
	side_panel.size = Vector2(SIDE_W, view.size.y)
	var k: float = ZOOM_PX[zoom_step] / TILE
	scale = Vector2(k, k)
	var map_size := Vector2(state.world.width, state.world.height) * TILE
	var half := view.size / (2.0 * k)
	for axis in 2:
		cam[axis] = (
			map_size[axis] / 2.0
			if half[axis] * 2.0 >= map_size[axis]
			else clampf(cam[axis], half[axis], map_size[axis] - half[axis])
		)
	position = (view.get_center() - cam * k).round()
	Art.ui_k = 1.0 / k
	if not east_pointer.target.is_empty():
		east_pointer.place(view, screen_of(east_pointer.target["tile"]))
	else:
		east_pointer.visible = false
	var rid := get_canvas_item()  # nothing is drawn outside the view
	RenderingServer.canvas_item_set_clip(rid, true)
	RenderingServer.canvas_item_set_custom_rect(rid, true, Rect2((view.position - position) / k, view.size / k))


## The east pointer was pressed: put the way to the ore in view (the Home key's camera, aimed east).
func _look_east(tile: Vector2i) -> void:
	center_on(Land.look_east_at(state, tile))


## Put tile p in the middle of the view.
func center_on(p: Vector2i) -> void:
	cam = Overlays.center(p)
	_layout()


## Where tile p's middle is on screen (canvas coordinates).
func screen_of(p: Vector2i) -> Vector2:
	return position + Overlays.center(p) * scale.x


## Arrow keys or WASD move the view while held.
func _pan_with_keys(delta: float) -> void:
	var dir := Vector2(
		(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
			- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		),
		(
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
			- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		)
	)
	if dir != Vector2.ZERO:
		cam += dir.normalized() * PAN_SPEED * delta / scale.x


## One zoom step in (+1) or out (-1), about the mouse when it is over the map, else about the middle of the view.
func _zoom(dir: int) -> void:
	var step := clampi(zoom_step + dir, 0, ZOOM_PX.size() - 1)
	if step == zoom_step:
		return
	var at := get_global_mouse_position()
	if not view.has_point(at):
		at = view.get_center()
	var anchor := (at - position) / scale.x  # the map point under `at`, which stays under it
	zoom_step = step
	cam = anchor - (at - view.get_center()) / (ZOOM_PX[step] / TILE)
	_layout()


# --- Input -------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			_zoom(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed and view.has_point(get_global_mouse_position())
	elif event is InputEventMouseMotion and panning:
		cam -= event.relative / scale.x
	elif event is InputEventMagnifyGesture and zoom_wait <= 0.0 and absf(event.factor - 1.0) > 0.04:
		zoom_wait = 0.25
		_zoom(1 if event.factor > 1.0 else -1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_holding()
		if drag_from.x >= 0:
			_lay_line()
	elif event is InputEventMouseButton and event.pressed:
		var p := _tile_under()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			placing = ""
			drag_from = Vector2i(-1, -1)
			building_panel.select(Vector2i(-1, -1))
		elif event.button_index == MOUSE_BUTTON_LEFT and state.world.in_bounds(p):
			if placing in LINE_TYPES:
				drag_from = p  # laid on release, with a preview while dragging
			else:
				_click_tile(p)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				tech_panel.visible = not tech_panel.visible
			KEY_SPACE:
				_set_speed(0)
			KEY_1, KEY_2, KEY_3:
				_set_speed(event.keycode - KEY_0)
			KEY_X:
				placing = "" if placing == "demolish" else "demolish"
			KEY_HOME:
				center_on(state.world.camp_pos)
			KEY_ESCAPE:
				placing = ""
				tech_panel.visible = false
				building_panel.select(Vector2i(-1, -1))


## 0 toggles pause; 1, 2 or 3 sets the speed and unpauses. The game waits while the end card is up.
func _set_speed(v: int) -> void:
	if era_card.visible:
		return
	if v == 0:
		paused = not paused
	else:
		speed = v
		paused = false
	_refresh_ui()


## The tiles the current drag covers, ending under the mouse (kept on the map).
func _drag_line() -> Array:
	var end := _tile_under().clamp(Vector2i.ZERO, Vector2i(state.world.width - 1, state.world.height - 1))
	return Rules.line_tiles(drag_from, end)


## Release: lay the dragged road, bridge or fields on every tile that takes it.
func _lay_line() -> void:
	var line := _drag_line()
	drag_from = Vector2i(-1, -1)
	if placing not in LINE_TYPES:
		return
	var err := state.town.placement_error(placing, line[0])
	if state.place_line(placing, line) == 0 and err != "":
		_toast(err, 2.0)


func _tile_under() -> Vector2i:
	if not view.has_point(get_global_mouse_position()):
		return Vector2i(-1, -1)  # over a bar or the side panel
	if placing == "" and _over_hearth():
		return state.world.camp_pos  # the whole drawing is the Hearth, to point at and click
	var local := (get_local_mouse_position() - MAP_ORIGIN) / TILE
	return Vector2i(floori(local.x), floori(local.y))


func _click_tile(p: Vector2i) -> void:
	if placing == "demolish":
		_demolish(p)
		return
	if placing != "":
		var err := state.town.placement_error(placing, p)
		if err == "":
			state.place(placing, p)
			if not state.economy.can_afford(Data.BUILDINGS[placing]["cost"]):
				placing = ""
		else:
			_toast(err, 2.0)
		return
	if state.town.building_at.has(p):
		var note := Workers.click(state, state.town.building_at[p])
		if note != "":
			popups.append({"pos": _tile_center(p), "text": note, "t": 0.0})
		building_panel.select(p)
		return
	if Hands.item_at(state, p) == "" and state.world.tile_at(p) != "shard":
		building_panel.select(Vector2i(-1, -1))  # clicking bare ground puts the card away; holding a resource keeps it
	if state.world.tile_at(p) == "shard" and state.fog.is_revealed(p):
		var first_look := not state.shard_seen
		_toast(state.gather_by_hand(p) + ("\nA new idea stirs in the tech tree: Star Lore." if first_look else ""), 8.0)
		return
	# Everything else is gathered by holding: _process fills the ring while the button stays down.
	state.release_harvest()
	holding = true
	press_tile = p
	press_harvested = false


## Hold to harvest, each frame the button is down: over a Control (a bar, a panel) it doesn't count.
func _hold(delta: float) -> void:
	if not holding:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or placing != "":
		_stop_holding()
		return
	if get_viewport().gui_get_hovered_control() != null or not state.world.in_bounds(hover):
		state.release_harvest()
		return
	var msg := state.hold_harvest(hover, delta)
	if msg != "":
		press_harvested = true
		popups.append({"pos": _tile_center(hover), "text": msg, "t": 0.0})


## Let go. A press on a resource that ended before its ring filled shows the hold hint (see _draw_nudge).
func _stop_holding() -> void:
	if holding and not press_harvested and Hands.item_at(state, press_tile) != "":
		var frac := state.harvest_frac if state.harvest_tile == press_tile else 0.0
		nudge = {"tile": press_tile, "frac": frac, "t": 0.0}
	holding = false
	press_harvested = false
	state.release_harvest()


## Tear down what's at p for half its cost back.
func _demolish(p: Vector2i) -> void:
	var type := state.town.built_type(p)
	if type == "":
		return
	if Data.BUILDINGS[type]["kind"] == "camp":
		_toast("The Hearth stays: it's the heart of the settlement.", 2.0)
		return
	var refund := state.demolish(p)
	rubble.append({"pos": p, "t": 0.0})
	if building_panel.pos == p:
		building_panel.select(Vector2i(-1, -1))
	popups.append(
		{"pos": _tile_center(p), "text": "+" + Ui.cost_text(refund) if not refund.is_empty() else "Cleared", "t": 0.0}
	)


# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# The cocoa frame round the map view, under everything else.
	frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = Ui.LINE
	rim.set_border_width_all(int(FRAME_W))
	frame.add_theme_stylebox_override("panel", rim)
	layer.add_child(frame)

	# Top bar: Kith, food, and every good with its rate.
	top_bar = TopBar.new()
	layer.add_child(top_bar)
	top_bar.setup(state)
	top_bar.speed_picked.connect(_set_speed)
	top_bar.log_pressed.connect(func(): msg_log.toggle())

	# Bottom bar: tabs of fixed-size build buttons, Demolish and Craft.
	bottom_bar = BuildBar.new()
	layer.add_child(bottom_bar)
	bottom_bar.setup(state)
	bottom_bar.build_picked.connect(_pick_building)
	bottom_bar.craft_picked.connect(func(r): Hands.craft(state, r))
	bottom_bar.tech_pressed.connect(func(): tech_panel.visible = not tech_panel.visible)
	bottom_bar.demolish_pressed.connect(func(): placing = "" if placing == "demolish" else "demolish")

	# The side panel: Goals, and the Info section that also holds the selected building's card.
	side_panel = SidePanel.new()
	layer.add_child(side_panel)
	side_panel.setup(state, SIDE_W)
	info_label = side_panel.info_label
	building_panel = side_panel.building_panel
	building_panel.closed.connect(func(): building_panel.select(Vector2i(-1, -1)))

	# Toasts stack up from the bottom of the map (placed in _layout, so they never cover the bars); the log opens over the map.
	toasts = ToastStack.new()
	layer.add_child(toasts)
	toasts.setup(messages)
	east_pointer = EastPointer.new()
	layer.add_child(east_pointer)
	east_pointer.setup()
	east_pointer.look.connect(_look_east)
	msg_log = MessageLog.new()
	layer.add_child(msg_log)
	msg_log.setup(messages)

	tech_panel = TechPanel.new()
	layer.add_child(tech_panel)
	tech_panel.setup(state)
	era_card = EraCard.new()
	layer.add_child(era_card)
	era_card.setup()
	era_card.closed.connect(func(): paused = false)


func _refresh_ui() -> void:
	top_bar.refresh(paused, speed)
	bottom_bar.refresh(placing, state.tech_tree.ready_list().size())
	tech_panel.refresh()
	building_panel.refresh()
	east_pointer.refresh(state)
	side_panel.refresh_goals(state)
	side_panel.sky_view.refresh()
	side_panel.show_info("" if get_viewport().gui_get_hovered_control() != null else HoverText.text(self))


## A toast that stays `seconds` (see Messages.push), stacked under any others and kept in the log.
func _toast(text: String, seconds: float) -> void:
	messages.push(text, seconds)


## Picking a card on the build bar: it starts (or stops) placing, and puts the selected building's card away.
func _pick_building(type: String) -> void:
	placing = "" if placing == type else type
	if placing != "":
		building_panel.select(Vector2i(-1, -1))


## Trouble with the food stays on screen until it's over: a sticky toast while starving, gone once fed again.
func _watch_food() -> void:
	var eco = state.economy
	if eco.starving and not was_starving:
		messages.push(Data.STARVING_TEXT % Data.PEOPLE["many"], 0.0, true, "food")
	was_starving = eco.starving
	if not eco.low and not eco.starving:
		messages.resolve("food")


## Say each warm line once, when its first moment comes (the story ids it waits for are in Data.FLAVOR_STORY).
func _watch_flavor() -> void:
	for id in Data.FLAVOR_STORY:
		if state.story.events.has(id) and not told.has(id):
			told[id] = true
			_toast(Data.FLAVOR_STORY[id], 5.0)
	if not told.has("stock") and state.economy.inv.get(Data.FLAVOR_STOCK_ITEM, 0) >= Data.FLAVOR_STOCK_AMOUNT:
		told["stock"] = true
		_toast(Data.FLAVOR_STOCK, 5.0)


## The story moments that do something on screen: the Falling Star ends the era with a card (the game waits behind it)
## and goes into the profile, the save that outlives a run.
func _on_story(id: String) -> void:
	if id == "star_falling":
		paused = true
		era_card.open()
		if not Profile.note_run(state):
			_toast(Data.PROFILE_UNSAVED, 6.0)


## A discovery that unlocks buildings: their cards and tab glow, and a toast says where to find them.
func _on_tech_researched(tech: String) -> void:
	var types := Rules.buildings_of(tech)
	if types.is_empty():
		return
	bottom_bar.pulse_unlock(types)
	var by_tab := {}
	for type in types:
		var names: Array = by_tab.get(BuildBar.tab_of(type), [])
		names.append(Data.BUILDINGS[type]["name"])
		by_tab[BuildBar.tab_of(type)] = names
	var parts: Array = []
	for tab_name in by_tab:
		parts.append(Data.UNLOCKED_TOAST % [" and ".join(by_tab[tab_name]), tab_name])
	_toast("; ".join(parts), 5.0)


# --- Drawing -----------------------------------------------------------------


## What a tile is drawn as: ore not yet named by its tech shows as plain ground.
func _feature_name(tile: String) -> String:
	var tech: String = Data.TILES[tile].get("tech", "")
	return "plain_ore" if tech != "" and not state.tech_tree.researched.has(tech) else tile


func _tile_rect(p: Vector2i) -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(p) * TILE, Vector2(TILE, TILE))


func _tile_center(p: Vector2i) -> Vector2:
	return MAP_ORIGIN + (Vector2(p) + Vector2(0.5, 0.5)) * TILE


## The tiles the view can see (a tile's margin included), kept on the map.
func _visible_tiles() -> Rect2i:
	var from := (view.position - position) / scale.x / TILE
	var to := (view.end - position) / scale.x / TILE
	var lo := Vector2i(
		clampi(floori(from.x) - 1, 0, state.world.width - 1), clampi(floori(from.y) - 1, 0, state.world.height - 1)
	)
	var hi := Vector2i(
		clampi(ceili(to.x) + 1, 0, state.world.width - 1), clampi(ceili(to.y) + 1, 0, state.world.height - 1)
	)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _draw() -> void:
	var seen := _visible_tiles()
	# Ground.
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if not state.fog.is_revealed(p):
				# Unexplored land is one flat color with a faint hatch: no terrain, no icons, nothing to give away.
				draw_rect(_tile_rect(p), Data.FOG)
				draw_texture_rect(Art.fog_hatch(int(TILE)), _tile_rect(p), false)
				continue
			var t := state.world.tile_at(p)
			var base: Color = (
				Data.TILES["grass"]["color"]
				if t in ["tree", "rock", "berry", "grain", "flax", "shard"]
				else Data.TILES[t]["color"]
			)
			if t == "grass" and (x + y) % 2 == 0:
				base = Data.GRASS_ALT  # the checker: two grass shades, 4% apart
			draw_rect(_tile_rect(p), base)
	_draw_roads()

	# Features.
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if not state.fog.is_revealed(p):
				continue
			Art.map_feature(self, _feature_name(state.world.tile_at(p)), _tile_center(p), p, time, TILE / Art.DESIGN)

	# Ranges: a hut's gathering tiles, power range for wheels, Standing Stone reach.
	var hovered_type := ""
	if state.town.building_at.has(hover):
		hovered_type = state.town.buildings[state.town.building_at[hover]]["type"]
	if (
		state.world.in_bounds(hover)
		and (placing == "gatherers_hut" or (placing == "" and hovered_type == "gatherers_hut"))
	):
		_draw_gather_range(hover)
	if placing == "water_wheel" and state.world.in_bounds(hover):
		draw_circle(_tile_center(hover), Data.BUILDINGS["water_wheel"]["radius"] * TILE, Color(0.16, 0.62, 0.56, 0.18))
	if placing == "grindstone" or hovered_type in ["water_wheel", "grindstone"]:
		for b in state.town.buildings:
			if b["type"] == "water_wheel":
				draw_circle(
					_tile_center(b["pos"]),
					Data.BUILDINGS["water_wheel"]["radius"] * TILE,
					Color(0.16, 0.62, 0.56, 0.18)
				)
	_draw_aura_ranges(hovered_type)
	Overlays.settlement_ring(self, state, placing == "dwelling", placing == "" and _over_hearth())
	for b in state.town.buildings:
		_draw_building(b)
	Overlays.rubble(self, rubble)
	var sel := building_panel.selected()
	if not sel.is_empty():
		draw_rect(Overlays.footprint(state, sel["pos"]).grow(1), GOAL_COLOR, false, 3.0)
		if sel["type"] == "gatherers_hut" and placing == "":
			_draw_gather_range(sel["pos"])
		Overlays.flow_arrows(self, state, sel, time)
	KithArt.draw_all(self, state, time)
	Overlays.fog_edges(self, state, seen)
	Overlays.alert_badges(self, state)

	# Placement ghost.
	if placing == "demolish" and state.world.in_bounds(hover):
		Overlays.demolish_hover(self, state, hover)
	elif placing in LINE_TYPES and drag_from.x >= 0:
		Overlays.line_ghost(self, state, placing, _drag_line())
	elif placing != "" and state.world.in_bounds(hover):
		var note := ""
		if Data.BUILDINGS[placing]["kind"] in ["gatherer", "processor"]:
			note = BuildingPanel.trip_text(state, hover)
		elif placing == "road" and state.world.tile_at(hover) == "rock":
			note = "Cut a pass · %s" % Ui.cost_text(Data.PASS_COST)
		elif placing == "road" and state.world.tile_at(hover) == "tree":
			note = (
				"Fell the trees · %s"
				% Ui.cost_text(Rules.cost_at("road", "tree", state.tech_tree.researched.has("causeways")))
			)
		Overlays.placement_ghost(self, state, placing, hover, note)
	elif state.world.in_bounds(hover) and not state.fog.is_revealed(hover):
		var fr := _tile_rect(hover)
		Art.dashed_rect(self, fr.grow(-1), Color(1, 1, 1, 0.6), 2.0, 5.0, 4.0)
		Art.pill(self, Vector2(fr.get_center().x, fr.end.y + 4), "Unexplored", Ui.TEXT, OUTLINE, 14)
	elif state.world.in_bounds(hover) and state.fog.is_revealed(hover) and Overlays.blocked_hint(state, hover) != "":
		draw_rect(_tile_rect(hover).grow(-1), Color(1, 1, 1, 0.8), false, 2.0)
		var r := _tile_rect(hover)
		Art.pill(
			self, Vector2(r.get_center().x, r.end.y + 4), Overlays.blocked_hint(state, hover), Ui.TEXT, OUTLINE, 14
		)
	elif state.world.in_bounds(hover):
		draw_rect(_tile_rect(hover).grow(-1), Color(1, 1, 1, 0.8), false, 2.0)  # the Info panel says what it is

	_draw_hold_ring()
	_draw_nudge()
	if paused:
		var top_mid := (Vector2(view.get_center().x, view.position.y + 12.0) - position) / scale.x
		Art.pill(self, top_mid, "Paused · Space to resume", GOAL_COLOR, OUTLINE, 16)

	var font := ThemeDB.fallback_font
	for pop in popups:
		var pos: Vector2 = pop["pos"] + Vector2(-20, -10 - pop["t"] * 30) * Art.ui_k
		var a: float = 1.0 - pop["t"] / 1.2
		var px := roundi(16.0 * Art.ui_k)
		draw_string_outline(
			font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(5.0 * Art.ui_k), Color(OUTLINE, a)
		)
		var col: Color = pop.get("col", Ui.TEXT)
		draw_string(font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))


## A Standing Stone's reach: under the cursor while placing one, around each one while hovering one.
func _draw_aura_ranges(hovered_type: String) -> void:
	var radius: float = Data.BUILDINGS["standing_stone"]["radius"] * TILE
	if placing == "standing_stone" and state.world.in_bounds(hover):
		draw_circle(_tile_center(hover), radius, AURA_FILL)
	if hovered_type == "standing_stone":
		for b in state.town.buildings:
			if b["type"] == "standing_stone":
				draw_circle(_tile_center(b["pos"]), radius, AURA_FILL)


## Whether the mouse is over the Hearth's 2x2 drawing.
func _over_hearth() -> bool:
	return (
		view.has_point(get_global_mouse_position())
		and Overlays.footprint(state, state.world.camp_pos).has_point(get_local_mouse_position())
	)


## Outline the hut's reach and light up the tiles of the one resource it works (or would start on).
func _draw_gather_range(p: Vector2i) -> void:
	var r := state.town.hut_radius()
	var reach := Rect2(MAP_ORIGIN + Vector2(p - Vector2i(r, r)) * TILE, Vector2.ONE * (2 * r + 1) * TILE)
	draw_rect(reach, Color(GOAL_COLOR, 0.18))
	Art.dashed_rect(self, reach, GOAL_COLOR, 2.0 * Art.ui_k, 10.0 * Art.ui_k, 6.0 * Art.ui_k)
	for t in state.town.tiles_of(p, state.town.focus_at(p)):  # only what the hut works
		draw_rect(_tile_rect(t).grow(-3), Color(1, 0.82, 0.4, 0.35))
		draw_rect(_tile_rect(t).grow(-3), GOAL_COLOR, false, 2.0)


func _draw_building(b: Dictionary) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var p: Vector2i = b["pos"]
	var k := TILE / Art.DESIGN
	var r := Overlays.footprint(state, p)  # a tile, or the Hearth's 2x2
	var working: bool = b["status"] == "Working"
	Art.map_building(self, b["type"], r, working, time)
	if b["type"] == "shard_cairn":
		Art.cairn_glow(self, r, state.sky.approach(), time)
	var tile := _tile_rect(p).grow(-2.0 * k)
	if def["kind"] == "gatherer":
		HutFocus.draw_marker(self, tile, b["focus"])
		if HutFocus.wants_click(state, b):
			HutFocus.draw_click_badge(self, tile, time)

	# Progress bar and held output.
	if def.has("time") and working:
		var frac := Work.progress_frac(state, b)
		draw_rect(Rect2(tile.position + Vector2(3, tile.size.y - 8), Vector2((tile.size.x - 6) * frac, 5)), GOAL_COLOR)
	var held := Buildings.buffered(b["out"])
	if held > 0:
		var badge := tile.position + Vector2(tile.size.x - 3, 3)
		var radius := 10.0 * Art.ui_k
		Art.outlined_circle(self, badge, radius, GOAL_COLOR if held < Data.BUFFER_CAP else BAD)
		var digits := str(held)
		var px := roundi(14.0 * Art.ui_k)
		var wide := ThemeDB.fallback_font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := badge + Vector2(-wide / 2.0, px * 0.36)
		draw_string(ThemeDB.fallback_font, at, digits, HORIZONTAL_ALIGNMENT_LEFT, -1, px, OUTLINE)
	_draw_trips(b, tile)
	_draw_rush(b, tile)


## Hold to harvest: an outline ring over the held tile, with a highlight arc filling clockwise from the top.
func _draw_hold_ring() -> void:
	if not holding or not state.world.in_bounds(state.harvest_tile) or Hands.item_at(state, state.harvest_tile) == "":
		return
	var c := _tile_center(state.harvest_tile)
	var radius := TILE * 0.42
	draw_arc(c, radius, 0.0, TAU, 40, OUTLINE, 7.0, true)
	draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 3.0, true)
	if state.harvest_frac > 0.0:
		var to := -PI / 2.0 + TAU * state.harvest_frac
		draw_arc(c, radius, -PI / 2.0, to, maxi(4, int(40 * state.harvest_frac)), GOAL_COLOR, 4.0, true)


## A quick click on a resource: the ring shows how far the hold got and fades, with a hint to keep the button down.
func _draw_nudge() -> void:
	if nudge.is_empty():
		return
	var p: Vector2i = nudge["tile"]
	var fade: float = clampf(2.0 * (1.0 - nudge["t"] / NUDGE_TIME), 0.0, 1.0)
	var c := _tile_center(p)
	var radius := TILE * 0.42
	draw_arc(c, radius, 0.0, TAU, 40, Color(OUTLINE, fade), 7.0, true)
	draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.3 * fade), 3.0, true)
	var to := -PI / 2.0 + TAU * maxf(nudge["frac"], 0.12)  # always a little arc, so the ring reads as unfinished
	draw_arc(c, radius, -PI / 2.0, to, 12, Color(GOAL_COLOR, fade), 4.0, true)
	var item := Hands.item_at(state, p)
	if item != "":
		var secs := str(snappedf(Hands.hold_time(state, item), 0.1))
		Art.pill(
			self, c + Vector2(0, TILE * 0.7), "Hold the mouse down for %ss to gather" % secs, GOAL_COLOR, OUTLINE, 12
		)


## A hut that hauls by clicks (before Paths & Haulers, or with no road link) shows its trip queue as
## pips along the top: gold for each queued trip.
func _draw_trips(b: Dictionary, r: Rect2) -> void:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or Roads.automated(state, b):
		return
	for n in Data.TRIP_QUEUE:
		var c := r.position + Vector2(r.size.x / 2.0 + (n - (Data.TRIP_QUEUE - 1) / 2.0) * 12.0, -4.0)
		draw_circle(c, 5.4, OUTLINE)
		draw_circle(c, 3.6, GOAL_COLOR if n < b["trips"] else Color(Ui.TEXT, 0.4))


## A rushed building shows its cooldown as a shrinking wedge in its top-left corner.
func _draw_rush(b: Dictionary, r: Rect2) -> void:
	if b["rush_cd"] <= 0.0:
		return
	var c := r.position + Vector2(8, 8)
	var frac: float = b["rush_cd"] / Data.RUSH_COOLDOWN
	draw_circle(c, 8.0, OUTLINE)
	draw_circle(c, 6.0, Color(Ui.TEXT, 0.3))
	var pts := PackedVector2Array([c])
	for n in 13:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * frac * n / 12.0) * 6.0)
	if frac > 0.02:
		draw_colored_polygon(pts, GOAL_COLOR)


func _draw_roads() -> void:
	var dirt: Color = Data.BUILDINGS["road"]["color"]
	if state.tech_tree.researched.has("causeways"):
		dirt = dirt.lerp(Data.BUILDINGS["stone_bridge"]["color"], 0.7)  # the roads are laid in stone now
	var k := TILE / Art.DESIGN
	var seen := _visible_tiles()
	for p in state.world.roads:
		if not seen.has_point(p) or not state.fog.is_revealed(p):
			continue
		var c := _tile_center(p)
		if state.world.tile_at(p) == "river":
			var bridge := Art.sprite("stone_bridge" if state.world.stone_bridges.has(p) else "tile_bridge_wood")
			if bridge != null:
				draw_texture_rect(bridge, _tile_rect(p), false)
				continue
			draw_rect(_tile_rect(p).grow_individual(0, -5 * k, 0, -5 * k), Color("8d6e63"))
			continue
		draw_circle(c, 8.0 * k, dirt)
		for n in World.NEIGHBORS:
			if state.world.roads.has(p + n) or state.town.building_at.has(p + n):
				var half := Vector2(n) * TILE * 0.5
				var w := Vector2(absf(n.y), absf(n.x)) * 8.0 * k
				draw_colored_polygon(PackedVector2Array([c - w, c + w, c + half + w, c + half - w]), dirt)
