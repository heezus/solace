extends VBoxContainer
## The sky window in the side panel, from Sky Watch on: a small night sky with the Wanderer in it, and under it a line
## that says how near it is. Before Star Charts the light only hangs there, growing; once the Kith have charted it a
## dotted path is drawn across the sky and the Wanderer rides along it. Static helpers place the light and pick its size,
## so a test can check them without a window. What it says is in Data (WANDERER_*), what it shows is Sim.sky.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")

const SKY_H := 64.0
const NIGHT := Color("141a33")  # the Wanderer's sprite is on this dark starfield
const STAR_COUNT := 16
const PATH_DOTS := 14

var state: Sim
var _sky: Control
var _line: Label


func setup(game: Sim, width: float) -> void:
	state = game
	visible = false
	add_theme_constant_override("separation", 4)
	_sky = Control.new()
	_sky.custom_minimum_size = Vector2(width, SKY_H)
	_sky.tooltip_text = Data.WANDERER_TIP
	_sky.draw.connect(_paint)
	add_child(_sky)
	_line = Ui.label("", Ui.MIN_TEXT)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_line.custom_minimum_size = Vector2(width, 0)
	add_child(_line)


## Show or hide the window with Sky Watch, and keep its line and picture up to date.
func refresh() -> void:
	visible = state.sky.named()
	if not visible:
		return
	_line.text = line_text(state.sky.mood(), state.sky.approach(), state.sky.charted())
	_sky.queue_redraw()


## "The Wanderer: a bright light  ·  40% of the way". Without Star Charts the Kith cannot say how far it has come.
static func line_text(mood: int, approach: float, charted: bool) -> String:
	var state_text: String = Data.WANDERER_STATES[mood]
	if not charted:
		return "%s: %s" % [Data.WANDERER_NAME, state_text]
	return "%s: %s" % [Data.WANDERER_NAME, Data.WANDERER_PATH % [state_text, roundi(approach * 100.0)]]


## Where the Wanderer is in a sky of `box` when it has come `approach` (0 to 1) of the way: a low arc from the left
## horizon, up over the middle and down to the right.
static func light_at(approach: float, box: Vector2) -> Vector2:
	var t := clampf(approach, 0.0, 1.0)
	var a := Vector2(box.x * 0.08, box.y * 0.55)
	var b := Vector2(box.x * 0.5, -box.y * 0.35)
	var c := Vector2(box.x * 0.92, box.y * 0.82)
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## The Wanderer's radius: a pinprick far away, big and bright when it is close.
static func light_radius(approach: float) -> float:
	return 2.0 + 5.0 * clampf(approach, 0.0, 1.0)


func _paint() -> void:
	var box := _sky.size
	_sky.draw_rect(Rect2(Vector2.ZERO, box), NIGHT)
	for i in STAR_COUNT:
		var star := Vector2(fposmod(i * 47.0 + 11.0, box.x), fposmod(i * 29.0 + 5.0, box.y - 8.0))
		_sky.draw_circle(star, 1.0, Color(Ui.TEXT, 0.3 + 0.1 * (i % 4)))
	var approach: float = state.sky.approach()
	if state.sky.charted():
		for i in PATH_DOTS + 1:
			var dot := light_at(float(i) / float(PATH_DOTS), box)
			_sky.draw_circle(dot, 1.4, Color(Art.STONE_GLOW, 0.35 if float(i) / float(PATH_DOTS) > approach else 0.15))
	var at := light_at(approach if state.sky.charted() else 0.0, box)
	var radius := light_radius(approach)
	_sky.draw_circle(at, radius * 2.2, Color(Art.STONE_GLOW, 0.18))
	_sky.draw_circle(at, radius, Color("bdf4ff"))
	_sky.draw_rect(Rect2(Vector2.ZERO, box), Ui.LINE, false, 2.0)
