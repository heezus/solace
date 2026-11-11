extends Node2D
## The flow view (Step 9C-1): a panel with one row per good (made and used a minute, net, stock, the buildings that make it and what the
## ones waiting wait on, the goal's goods on top), and a light on the map over the building that most limits each good the goal needs.
## Opens from the top bar's Flow button or the F key; a child of the map view, so the light is drawn in the same pixels as the map.
## Reads the sim once a second while open and does nothing while shut (scripts/flow_view.gd, scripts/goal_sums.gd).

const Data = preload("res://scripts/data.gd")
const FlowView = preload("res://scripts/flow_view.gd")
const Needs = preload("res://scripts/needs.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Ui = preload("res://scripts/ui.gd")

const PANEL_W := 640.0
const REFRESH := 1.0  # seconds between readings while open
const TITLE := "Flow"
const HEAD := ["Good", "Made / min", "Used / min", "Net / min", "In stock", "Made by"]
const NO_GOAL := "The goal in front of you needs no goods."
const HAND := "by hand %.1f"

var state
var panel: PanelContainer
var box: VBoxContainer
var top_bar: Control
var lights: Array = []  # [tile position, good id] of each building lit on the map
var _time := 0.0
var _gathered := -1.0e9


## Add the layer to the map view `map`; the panel goes on the UI layer `ui`, under `bar`, and `bar`'s Flow button opens it.
static func attach(map: Node2D, ui: CanvasLayer, bar: Control, s) -> void:
	var layer: Node2D = (load("res://scripts/flow_layer.gd") as GDScript).new()
	layer.state = s
	layer.top_bar = bar
	layer.panel = PanelContainer.new()
	layer.panel.visible = false
	layer.panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.GLASS_PANEL, 12))
	layer.box = VBoxContainer.new()
	layer.box.add_theme_constant_override("separation", 3)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_W, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(layer.box)
	layer.box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer.panel.add_child(scroll)
	ui.add_child(layer.panel)
	map.add_child(layer)
	bar.flow_pressed.connect(layer.toggle)


func toggle() -> void:
	panel.visible = not panel.visible
	_gathered = -1.0e9
	lights = []
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F and not k.ctrl_pressed and not k.alt_pressed:
		if not _typing() and not _modal():
			toggle()
			get_viewport().set_input_as_handled()


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _modal() -> bool:
	var m := get_parent()
	return m.has_method("_modal_up") and m._modal_up()


func _process(delta: float) -> void:
	if not panel.visible:
		return
	_time += delta
	if _time - _gathered >= REFRESH:
		_gathered = _time
		_rebuild()
	if not lights.is_empty():
		queue_redraw()
	panel.position = Vector2(12, top_bar.size.y + 8)
	panel.size = Vector2(PANEL_W + 24, maxf(get_viewport_rect().size.y - top_bar.size.y - 160.0, 200.0))


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
		box.remove_child(c)
	var title := Ui.label("%s   (F to close)" % TITLE, Ui.LABEL_TEXT)
	title.add_theme_color_override("font_color", Ui.ACTION)
	box.add_child(title)
	lights = []
	var goal: Dictionary = Needs.goal_goods(state)
	if goal.is_empty():
		box.add_child(_dim(NO_GOAL))
	for id in goal:
		var held := FlowView.bottleneck(state, id)
		if state.economy.inv.get(id, 0) >= Needs.goal_need(state, id) and Needs.goal_need(state, id) > 0:
			continue
		var l := _dim(held["line"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_W
		box.add_child(l)
		if held["pos"] != FlowView.NONE:
			lights.append([held["pos"], id])
	var grid := GridContainer.new()
	grid.columns = HEAD.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	for h in HEAD:
		var l := _dim(h)
		l.add_theme_color_override("font_color", Ui.ACTION)
		grid.add_child(l)
	for r in FlowView.rows(state):
		_add_row(grid, r)
	box.add_child(grid)


func _add_row(grid: GridContainer, r: Dictionary) -> void:
	var color: Color = Ui.TEXT if r["goal"] else Ui.TEXT_DIM
	var title := Ui.label(r["name"] + (" *" if r["goal"] else ""), Ui.MIN_TEXT)
	title.add_theme_color_override("font_color", color)
	grid.add_child(title)
	for v in [r["made"], r["used"]]:
		grid.add_child(_num("%.1f" % v, color))
	var net := _num("%+.1f" % r["net"], Ui.GOOD if r["net"] > 0.05 else Ui.BAD if r["net"] < -0.05 else color)
	grid.add_child(net)
	grid.add_child(_num(str(r["stock"]), color))
	var by: Array = []
	if absf(r["by_hand"]) > 0.05:
		by.append(HAND % r["by_hand"])
	for g in r["makers"]:
		by.append(FlowView.group_line(g))
	var made := _dim(", ".join(by) if not by.is_empty() else "-")
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size.x = 250.0
	grid.add_child(made)


func _dim(text: String) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.add_theme_color_override("font_color", Ui.TEXT_DIM)
	return l


func _num(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _draw() -> void:
	if not panel.visible:
		return
	var map := get_parent()
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	for light in lights:
		var c: Vector2 = map._tile_center(light[0])
		draw_arc(c, Overlays.TILE * (0.62 + 0.06 * pulse), 0.0, TAU, 40, Color(Overlays.OUTLINE, 0.9), 7.0, true)
		draw_arc(c, Overlays.TILE * (0.62 + 0.06 * pulse), 0.0, TAU, 40, Color(Ui.ACTION, 0.9), 3.5, true)
