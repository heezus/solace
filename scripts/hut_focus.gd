extends Button
## A Gatherer's Hut works one resource, its focus. This is the panel line that says which ("Gathering: Berries")
## and one click moves it on to the next resource in reach. Plain text, so it fits any panel layout. Its static
## helpers word the range summary and draw the tiny marker on the map that shows what a hut works.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")

var state: Sim
var index := -1  # the hut's place in the building list, -1 for none


func setup(game: Sim) -> void:
	state = game
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # wraps inside a narrow panel instead of widening it
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(60, 0)
	visible = false
	add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	add_theme_color_override("font_color", Ui.TEXT)
	add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
	add_theme_color_override("font_disabled_color", Ui.TEXT)


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


## The item's icon in a cocoa disc at a hut's lower left corner: what it works, on the map.
static func draw_marker(ci: CanvasItem, r: Rect2, item: String) -> void:
	if item == "":
		return
	var c := r.position + Vector2(11, r.size.y - 11)
	ci.draw_circle(c, 12.0, Ui.LINE)
	Art.item_icon(ci, item, Rect2(c - Vector2(10, 10), Vector2(20, 20)), 1.0)


## True for a hut that is standing idle until someone clicks it: it has a worker who can work its focus, no road
## links it to run it on its own, and no trip is waiting. (An unlinked hut only works on clicked trips.)
static func wants_click(s: Sim, b: Dictionary) -> bool:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or b["worker"] < 0 or b["paused"]:
		return false
	return (
		not Roads.automated(s, b)
		and b["trips"] == 0
		and Buildings.buffered(b["out"]) < Data.BUFFER_CAP
		and s.people.knows_focus(b)
	)


## A small pulsing "click" pill over a hut that is waiting for a click.
static func draw_click_badge(ci: CanvasItem, r: Rect2, time: float) -> void:
	var pulse := 0.55 + 0.45 * sin(time * 5.0)
	Art.pill(ci, Vector2(r.get_center().x, r.position.y - 30.0), "click", Color(Ui.HIGHLIGHT, pulse), Ui.LINE, 14)
