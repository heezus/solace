extends VBoxContainer
## The toasts: each active message (scripts/messages.gd) is a small dark panel, stacked up from the bottom of the map
## view (the lit area around the Hearth stays clear), so two never draw on top of each other. A sticky one shows a
## small "click to dismiss" note and goes when clicked; the others let the mouse through, so they never get in
## the way of holding on the map.

const Ui = preload("res://scripts/ui.gd")
const Messages = preload("res://scripts/messages.gd")

const FADE := 1.0  # seconds a toast takes to fade out
const MAX_W := 640.0

var messages: Messages
var panels := {}  # message id -> PanelContainer


func setup(queue: Messages) -> void:
	messages = queue
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	queue.changed.connect(_rebuild)


func _rebuild() -> void:
	var ids := {}
	for m in messages.active:
		ids[m["id"]] = true
	for id in panels.keys():
		if not ids.has(id):
			panels[id].queue_free()
			remove_child(panels[id])
			panels.erase(id)
	for m in messages.active:
		if not panels.has(m["id"]):
			panels[m["id"]] = _panel(m)
			add_child(panels[m["id"]])
		_fill(panels[m["id"]], m)
	# The panels sit in the order the messages came in.
	for i in messages.active.size():
		move_child(panels[messages.active[i]["id"]], i)


func _panel(m: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := Ui.panel_style(Color(Ui.BAR, 0.94), 8)
	style.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", style)
	var l := Ui.label("", Ui.LABEL_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 120.0
	p.add_child(l)
	if m["sticky"]:
		p.gui_input.connect(_on_click.bind(m["id"]))
	return p


func _fill(p: PanelContainer, m: Dictionary) -> void:
	var l: Label = p.get_child(0)
	l.text = m["text"]
	var w := minf(ThemeDB.fallback_font.get_string_size(m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 4.0, MAX_W)
	l.custom_minimum_size.x = maxf(minf(w, size.x if size.x > 0.0 else MAX_W), 120.0)
	var sticky: bool = m["sticky"]
	p.mouse_filter = Control.MOUSE_FILTER_STOP if sticky else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = "Click to dismiss" if sticky else ""
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = p.get_theme_stylebox("panel")
	style.border_color = Ui.SHORT if sticky else Ui.EDGE


func _on_click(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		messages.dismiss(id)


func _process(_delta: float) -> void:
	for m in messages.active:
		var p: PanelContainer = panels.get(m["id"])
		if p != null:
			p.modulate.a = 1.0 if m["sticky"] else clampf(m["left"] / FADE, 0.0, 1.0)
