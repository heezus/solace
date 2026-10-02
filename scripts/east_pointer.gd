extends Button
## The lasting pointer to the new land: after Bronze Dawn, a small button at the east edge of the map view says which ore
## to look for ("Look east: copper >") until its first tile is out of the fog, then the tin. One click moves the view
## toward it (the owner does that: it is the same camera as the Home key). It never moves the view by itself, and it
## goes away once it has nothing to point at or the ore is already on screen.

signal look(tile: Vector2i)

const Data = preload("res://scripts/data.gd")
const Land = preload("res://scripts/land.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

const EDGE_GAP := 10.0  # px between the button and the right edge of the view
const TOP_GAP := 24.0
const LOW_SHARE := 0.6  # the button sits no lower than this share of the view's height, clear of the toasts

var target: Dictionary = {}  # Land.ore_target: {"ore", "tile"}, {} when there is nothing to point at


func setup() -> void:
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", Ui.LABEL_TEXT)
	add_theme_color_override("font_color", Ui.HIGHLIGHT)
	add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
	pressed.connect(_on_pressed)
	visible = false


## Read what to point at (the owner calls this a few times a second).
func refresh(s: Sim) -> void:
	target = Land.ore_target(s) if s.world.is_grown() else {}
	if not target.is_empty():
		var ore: String = Data.LOOK_EAST_ORE[target["ore"]]
		text = Data.LOOK_EAST % ore
		tooltip_text = Data.LOOK_EAST_TIP % ore


## Put the button at the right edge of `view` (screen px), level with the target at `target_y` (screen px), or hide it
## when there is nothing to point at or the target tile is already inside the view (`target_screen`).
func place(view: Rect2, target_screen: Vector2) -> void:
	visible = not target.is_empty() and not view.has_point(target_screen)
	if not visible:
		return
	var y := clampf(target_screen.y, view.position.y + TOP_GAP, view.position.y + view.size.y * LOW_SHARE)
	size = get_combined_minimum_size()
	position = Vector2(view.end.x - size.x - EDGE_GAP, y - size.y / 2.0)


func _on_pressed() -> void:
	if not target.is_empty():
		look.emit(target["tile"])
