extends Node2D
## Sight on the map: a child of the map view, so it draws over it in the same pixels. It watches the Alt key (held) and the top
## bar's Sight button (latched), reads the sim into a Sight once a second while on, and draws it every frame. With Sight off it
## does one key check a frame and nothing else (scripts/sight.gd).

const Art = preload("res://scripts/art.gd")
const Data = preload("res://scripts/data.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Sight = preload("res://scripts/sight.gd")
const Ui = preload("res://scripts/ui.gd")

var state
var sight := Sight.new()
var latched := false
var key_line: Label
var band: ColorRect  # the key line's own strip under the top bar, so map labels never run into it
var top_bar: Control
var _on := false
var _gathered := -1.0e9
var _time := 0.0


## Add a layer to the map view `map`; the key line goes on the UI layer `ui`, under `bar`.
static func attach(map: Node2D, ui: CanvasLayer, bar: Control, s) -> void:
	var layer: Node2D = (load("res://scripts/sight_layer.gd") as GDScript).new()
	layer.state = s
	layer.top_bar = bar
	layer.band = ColorRect.new()
	layer.band.color = Ui.PANEL
	layer.band.visible = false
	layer.band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer.band)
	layer.key_line = Ui.label(Data.SIGHT_KEY, Ui.LABEL_TEXT)
	layer.key_line.add_theme_color_override("font_color", Ui.ACTION)
	layer.key_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.band.add_child(layer.key_line)
	map.add_child(layer)
	bar.sight_toggled.connect(func(on): layer.latched = on)


func _exit_tree() -> void:
	Overlays.badges_hidden = false


func is_on() -> bool:
	return latched or Input.is_key_pressed(KEY_ALT)


func _process(delta: float) -> void:
	var on := is_on()
	if on != _on:
		_on = on
		band.visible = on
		Overlays.badges_hidden = on
		queue_redraw()
	if not on:
		return
	_time += delta
	if _time - _gathered >= 1.0:
		_gathered = _time
		sight.gather(state)
		key_line.text = Data.SIGHT_KEY if sight.idle_note == "" else "%s   ·   %s" % [Data.SIGHT_KEY, sight.idle_note]
	band.position = Vector2(0, top_bar.size.y)
	band.size = Vector2(top_bar.size.x, key_line.size.y + 8)
	key_line.position = Vector2(12, 4)
	queue_redraw()


func _draw() -> void:
	if _on:
		sight.draw(
			self, get_local_mouse_position(), _time, get_canvas_transform().affine_inverse() * get_viewport_rect()
		)
