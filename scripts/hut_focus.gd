extends Button
## A Gatherer's Hut works one resource, its focus. This is the panel line that says which ("Gathering: Berries")
## and one click moves it on to the next resource in reach. Plain text, so it fits any panel layout. Its static
## helpers word the range summary and draw the tiny marker on the map that shows what a hut works.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")

const BADGE_TEXT := "click"
const BADGE_FONT := 11

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


## True when a food hut's click can wait: the player has sent a first trip and the food is comfortable (no warning, no
## famine, so idle Kith are not foraging). Then the hut still works when clicked, but nothing is at stake.
static func click_can_wait(s: Sim, b: Dictionary) -> bool:
	return (
		Data.FOOD_VALUE.has(b["focus"])
		and "first_trip" in s.story.events
		and not s.economy.low
		and not s.economy.famine
	)


## True for a hut that is standing idle until someone clicks it: it has a worker who can work its focus, no road
## links it to run it on its own, and no trip is waiting. (An unlinked hut only works on clicked trips.) A food hut
## stops asking while the food is comfortable (click_can_wait); the others always ask: their goods come only by click.
static func wants_click(s: Sim, b: Dictionary) -> bool:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or b["worker"] < 0 or b["paused"]:
		return false
	if click_can_wait(s, b):
		return false
	return (
		not Roads.automated(s, b)
		and b["trips"] == 0
		and Buildings.buffered(b["out"]) < Data.BUFFER_CAP
		and s.people.knows_focus(b)
	)


## Where the "click" badge goes over a hut's tile `r`: the box its pill covers.
static func badge_rect(r: Rect2) -> Rect2:
	var w := ThemeDB.fallback_font.get_string_size(BADGE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT).x + 12.0
	return Rect2(Vector2(r.get_center().x - w / 2.0, r.position.y - 26.0), Vector2(w, BADGE_FONT + 8.0))


## A small pulsing "click" pill over a hut that is waiting for a click.
static func draw_click_badge(ci: CanvasItem, r: Rect2, time: float) -> void:
	var pulse := 0.55 + 0.45 * sin(time * 5.0)
	var at := badge_rect(r)
	Art.pill(
		ci,
		Vector2(at.get_center().x, at.position.y),
		BADGE_TEXT,
		Color(1.0, 0.82, 0.4, pulse),
		Color("1b2a33"),
		BADGE_FONT
	)
