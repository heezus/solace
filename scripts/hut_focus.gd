extends Button
## A Gatherer's Hut works one resource, its focus. This is the panel line that says which ("Gathering: Berries")
## and one click moves it on to the next resource in reach. Plain text, so it fits any panel layout. Its static
## helpers word the range summary and draw the tiny marker on the map that shows what a hut works.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")

var state: Sim
var index := -1  # the hut's place in the building list, -1 for none


func setup(game: Sim) -> void:
	state = game
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	visible = false
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Color("ffd166"))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color("ffd166"))


## Show the line for building b (hidden unless it is a hut).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "gatherer"
	if not visible:
		index = -1
		return
	index = state.town.building_at[b["pos"]]
	text = label_text(state, b)
	disabled = state.town.focus_options(b["pos"]).size() < 2
	tooltip_text = "" if disabled else "Click to work the next resource in reach."


func _pressed() -> void:
	cycle()


## Move the hut on to the next resource in reach, and say so.
func cycle() -> void:
	if index >= 0 and not state.town.cycle_focus(index).is_empty():
		changed.emit()


## "Gathering: Berries" and, when there is a choice, a hint that a click changes it.
static func label_text(s: Sim, b: Dictionary) -> String:
	var item: String = b["focus"]
	if item == "":
		return "Gathering: nothing in reach"
	var line := "Gathering: %s" % Data.ITEMS[item]["name"]
	if s.town.focus_options(b["pos"]).size() > 1:
		line += "  (click to change)"
	return line


## The little square of the item's color at a hut's lower left corner: what it works, on the map.
static func draw_marker(ci: CanvasItem, r: Rect2, item: String) -> void:
	if item == "":
		return
	var at := Rect2(r.position + Vector2(3, r.size.y - 16), Vector2(9, 9))
	ci.draw_rect(at, Data.ITEMS[item]["color"])
	ci.draw_rect(at, Color("1b2a33"), false, 1.5)
