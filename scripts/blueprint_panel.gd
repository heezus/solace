extends PanelContainer
## The blueprint panel and tool (scripts/blueprints.gd): the Blueprints button on the build bar opens it over the foot of the map. It lists
## the saved blueprints (a name to rename, Lay down, Delete) and "Save a blueprint", which turns the next drag on the map into a box
## over what to keep. Laying down follows a click: the blueprint's corner goes on the tile clicked and its parts are queued as plans.
## It takes the map's mouse itself (its _unhandled_input runs before main's, so a click it uses never reaches the map) and draws its
## ghost from a Node2D it adds to the map, so main.gd only builds it (setup).

const Blueprints = preload("res://scripts/blueprints.gd")
const Art = preload("res://scripts/art.gd")
const Data = preload("res://scripts/data.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

const W := 360.0
const MARGIN := 16.0

var state: Sim
var host: Node2D  # main: the map's transform, its `view` and what is being placed
var mode := ""  # "" idle, "save" waiting for a box, "lay" waiting for a click
var index := -1  # the blueprint being laid
var from := Vector2i(-1, -1)  # where the box being dragged began
var note: Label
var list: VBoxContainer
var _ghost: Ghost
var _shown := ""  # what the list was last built from, so it is rebuilt only when it changes


## Draws the tool's ghost in the map's own space.
class Ghost:
	extends Node2D
	var panel

	func _draw() -> void:
		panel.ghost(self, panel.tile_under())


## Build the panel into the HUD `layer` for the run in `sim`, drawing its ghost on `map` (main) and answering the build bar's button.
static func attach(layer: CanvasLayer, sim: Sim, map: Node2D, bar) -> void:
	var panel := new()
	layer.add_child(panel)
	panel.setup(sim, map, bar)


func setup(sim: Sim, map: Node2D, bar) -> void:
	state = sim
	host = map
	_ghost = Ghost.new()
	_ghost.panel = self
	map.add_child(_ghost)
	bar.blueprints_pressed.connect(toggle)
	visible = false
	custom_minimum_size = Vector2(W, 0)
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	var title := Ui.label(Data.EXODUS["bp_title"], Ui.LABEL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Ui.button("x")
	close.custom_minimum_size = Vector2(28, 28)
	close.pressed.connect(close_panel)
	head.add_child(close)
	v.add_child(head)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	v.add_child(list)
	note = Ui.label("", Ui.MIN_TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(note)
	var save := Ui.button(Data.EXODUS["bp_save"])
	save.pressed.connect(_start_save)
	v.add_child(save)


func toggle() -> void:
	if visible:
		close_panel()
	else:
		visible = true
		_rebuild()


func close_panel() -> void:
	visible = false
	stop()


func stop() -> void:
	_ghost.queue_redraw()
	mode = ""
	index = -1
	from = Vector2i(-1, -1)
	note.text = ""


## Lay the panel along the foot of the map view, at its right.
func _place() -> void:
	var view: Rect2 = host.view
	size = Vector2(W, 0)
	position = Vector2(view.end.x - W - MARGIN, view.end.y - size.y - MARGIN)


func _process(_delta: float) -> void:
	if visible and _signature() != _shown:
		_rebuild()
	if visible:
		_place()
	if mode != "":
		_ghost.queue_redraw()


func _signature() -> String:
	return str(state.carry.blueprints.map(func(b): return [b["name"], b["items"].size()]))


func _rebuild() -> void:
	_shown = _signature()
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if state.carry.blueprints.is_empty():
		var none := Ui.label(Data.EXODUS["bp_empty"], Ui.MIN_TEXT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD
		none.custom_minimum_size = Vector2(W - 20.0, 0)
		list.add_child(none)
	for i in state.carry.blueprints.size():
		list.add_child(_row(i))


func _row(i: int) -> HBoxContainer:
	var bp: Dictionary = state.carry.blueprints[i]
	var h := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.text = bp["name"]
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = "%d parts" % bp["items"].size()
	name_edit.text_submitted.connect(func(text): _rename(i, text))
	name_edit.focus_exited.connect(func(): _rename(i, name_edit.text))
	h.add_child(name_edit)
	var lay := Ui.button(Data.EXODUS["bp_lay"])
	lay.pressed.connect(_start_lay.bind(i))
	h.add_child(lay)
	var drop := Ui.button("x")
	drop.tooltip_text = Data.EXODUS["bp_drop"]
	drop.pressed.connect(func(): Blueprints.drop(state, i))
	h.add_child(drop)
	return h


func _rename(i: int, text: String) -> void:
	if i < state.carry.blueprints.size() and text.strip_edges() != "":
		state.carry.blueprints[i]["name"] = text.strip_edges()


func _start_save() -> void:
	mode = "save"
	index = -1
	note.text = Data.EXODUS["bp_save_hint"]


func _start_lay(i: int) -> void:
	mode = "lay"
	index = i
	note.text = "%s: click where its corner goes. Right click to stop." % state.carry.blueprints[i]["name"]


func tile_under() -> Vector2i:
	var local: Vector2 = host.get_local_mouse_position() / Overlays.TILE
	return Vector2i(floori(local.x), floori(local.y))


func _unhandled_input(event: InputEvent) -> void:
	if mode == "" or not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		stop()  # main puts its own tools away too
	elif event.button_index == MOUSE_BUTTON_LEFT and host.view.has_point(host.get_global_mouse_position()):
		if host.placing != "":
			stop()  # picking a building ends the tool
		elif event.pressed:
			_press(tile_under())
			get_viewport().set_input_as_handled()
		elif from.x >= 0:
			_release(tile_under())
			get_viewport().set_input_as_handled()


func _press(p: Vector2i) -> void:
	if mode == "save":
		from = p
	elif mode == "lay":
		Blueprints.lay(state, index, p)


## The left button came up at tile `end`: a box being dragged is kept as a blueprint.
func _release(end: Vector2i) -> void:
	var box := _box(from, end)
	from = Vector2i(-1, -1)
	var why := Blueprints.save(state, box)
	note.text = why if why != "" else Data.EXODUS["bp_save_hint"]
	if why == "":
		mode = ""


static func _box(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := a.min(b)
	return Rect2i(lo, a.max(b) - lo + Vector2i.ONE)


## The tool's picture on the map: the box being dragged, or the blueprint where it would land with each part tinted for whether it could
## go there now.
func ghost(ci: CanvasItem, hover: Vector2i) -> void:
	if mode == "save" and from.x >= 0:
		var box := _box(from, hover)
		var r := Rect2(Vector2(box.position) * Overlays.TILE, Vector2(box.size) * Overlays.TILE)
		ci.draw_rect(r, Color(1, 1, 1, 0.12))
		Art.dashed_rect(ci, r, Color.WHITE, 2.0, 6.0, 4.0)
		var n := Blueprints.parts_in(state, box).size()
		Art.pill(ci, Vector2(r.get_center().x, r.end.y + 4), "%d parts" % n, Ui.TEXT, Art.OUTLINE, 14)
	elif mode == "lay" and index >= 0 and index < state.carry.blueprints.size() and state.world.in_bounds(hover):
		var bp: Dictionary = state.carry.blueprints[index]
		for part in bp["items"]:
			var p := hover + Vector2i(int(part["x"]), int(part["y"]))
			var err: String = (
				"Off the map" if not state.world.in_bounds(p) else state.town.placement_error(part["t"], p)
			)
			var col := Color(Overlays.ALERT, 0.45)
			if err == "":
				col = Color(1, 1, 1, 0.5)
			elif err in Blueprints.WAITS or err.begins_with(Blueprints.UNEXPLORED):
				col = Color(Ui.HIGHLIGHT, 0.4)
			ci.draw_rect(Overlays.rect(p).grow(-3), col)
		var corner := Overlays.rect(hover)
		Art.dashed_rect(
			ci, Rect2(corner.position, Vector2(bp["w"], bp["h"]) * Overlays.TILE), Color.WHITE, 2.0, 6.0, 4.0
		)
