extends VBoxContainer
## A Gatherer's Hut works one resource, its focus. In the hut panel this is the line that says which ("Gathering:
## Berries") and, when more than one resource is in reach, a row of buttons, one per resource (icon and name, the
## current one pressed): one click picks it. Tab or R (Buildings.cycle_focus) steps through them from the keyboard.
## The same choice is offered while the hut is placed: a small picker by the ghost (the pick_* helpers below), so
## the hut goes down already working the right thing. Static helpers word the range summary and draw the tiny marker
## on the map that shows what a hut works.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Overlays = preload("res://scripts/overlays.gd")

const BADGE_TEXT := "click"
const BADGE_FONT := 14
const BADGE_GAP := 12.0  # world px between the "click" pill and the hut's top: clear of its roof and the trip dots
const PICK_TITLE := "What it will work"
const PICK_KEYS := "Click one, or press Tab or R"
const PICK_ROW := 28.0  # design px: one choice in the placement picker
const PICK_ICON := 20.0
const PICK_PAD := 8.0
const BUTTON_ICON := 20
const BUTTON_TIP := "Send this hut to the %s in reach. Picking again moves it back whenever you like."

var state: Sim
var index := -1  # the hut's place in the building list, -1 for none
var line: Label  # "Gathering: Berries"
var row: HFlowContainer  # one toggle button per resource in reach, wrapping inside a narrow panel
var _shown: Array = []  # the options the buttons were built for (rebuilt only when they change)
var _buttons := {}  # item -> its Button


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	line = Ui.label("", Ui.MIN_TEXT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # wraps inside a narrow panel instead of widening it
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(60, 0)
	add_child(line)
	row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)


## Show the line and the buttons for building b (hidden unless it is a hut).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "gatherer"
	if not visible:
		index = -1
		return
	index = state.town.building_at[b["pos"]]
	line.text = label_text(state, b)
	var options := state.town.focus_options(b["pos"])
	row.visible = options.size() > 1
	if options != _shown:
		_build_buttons(options)
	for item in _buttons:
		_buttons[item].set_pressed_no_signal(item == b["focus"])


func _build_buttons(options: Array) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_shown = options.duplicate()
	for item in options:
		var b := Ui.button(Data.ITEMS[item]["name"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 32)
		b.icon = Ui.item_sprite(item)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", BUTTON_ICON)
		b.tooltip_text = BUTTON_TIP % Data.ITEMS[item]["name"]
		b.pressed.connect(choose.bind(item))
		row.add_child(b)
		_buttons[item] = b


## Set the hut to work `item` (a button was clicked), and say so.
func choose(item: String) -> void:
	if index < 0:
		return
	if state.town.set_focus(index, item):
		changed.emit()
	elif _buttons.has(item):
		_buttons[item].set_pressed_no_signal(state.town.buildings[index]["focus"] == item)


## Move the hut on to the next resource in reach (Tab or R), and say so.
func cycle() -> void:
	if index >= 0 and not state.town.cycle_focus(index).is_empty():
		changed.emit()


## "Gathering: Berries" and, when there is a choice, a pointer to the buttons under it.
static func label_text(s: Sim, b: Dictionary) -> String:
	var item: String = b["focus"]
	if item == "":
		return "Gathering: nothing in reach"
	var text := "Gathering: %s" % Data.ITEMS[item]["name"]
	if s.town.focus_options(b["pos"]).size() > 1:
		text += " (pick another below)"
	return text


## The item's icon in a cocoa disc at a hut's lower left corner: what it works, on the map.
static func draw_marker(ci: CanvasItem, r: Rect2, item: String) -> void:
	if item == "":
		return
	var c := r.position + Vector2(11, r.size.y - 11)
	ci.draw_circle(c, 12.0, Ui.LINE)
	Art.item_icon(ci, item, Rect2(c - Vector2(10, 10), Vector2(20, 20)), 1.0)


## True when a food hut's click can wait: the player has sent a first trip and the food is comfortable (no warning, no
## famine, so idle Kith are not foraging). Then the hut still works when clicked, but nothing is at stake.
static func click_can_wait(s: Sim, b: Dictionary) -> bool:
	return (
		Data.FOOD_VALUE.has(b["focus"])
		and "first_trip" in s.story.events
		and not s.economy.low
		and not s.economy.famine
	)


## True while a food hut's worker is out foraging by themselves (the famine fallback, scripts/forage.gd): somebody is
## already covering for the hut, so it has no need to ask.
static func _worker_forages(s, b: Dictionary) -> bool:
	return (
		Data.FOOD_VALUE.has(b["focus"])
		and s.economy.famine
		and String(s.people.kith[b["worker"]]["phase"]).begins_with("forage")
	)


## True for a hut that is standing idle until someone clicks it: it has a worker who can work its focus, no road
## links it to run it on its own, and no trip is waiting. (An unlinked hut only works on clicked trips.) A food hut
## stops asking while the food is comfortable (click_can_wait) and while its worker is foraging for the Hearth in a
## famine; the others always ask: their goods come only by click.
static func wants_click(s: Sim, b: Dictionary) -> bool:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or b["worker"] < 0 or b["paused"]:
		return false
	if click_can_wait(s, b) or _worker_forages(s, b):
		return false
	return (
		not Roads.automated(s, b)
		and b["trips"] == 0
		and Buildings.buffered(b["out"]) < Data.BUFFER_CAP
		and s.people.knows_focus(b)
	)


## Where the "click" badge goes over a hut's tile `r`: the box its pill covers. It floats above the tile and the
## row of trip dots (which stand up to 10 px above it), so it never hides the hut's roof or icon.
static func badge_rect(r: Rect2) -> Rect2:
	var k := Art.ui_k
	var w := ThemeDB.fallback_font.get_string_size(BADGE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(BADGE_FONT * k)).x
	w += 14.0 * k
	var h := (BADGE_FONT + 8.0) * k
	return Rect2(Vector2(r.get_center().x - w / 2.0, r.position.y - BADGE_GAP - h), Vector2(w, h))


## A small pulsing "click" pill over a hut that is waiting for a click.
static func draw_click_badge(ci: CanvasItem, r: Rect2, time: float) -> void:
	var pulse := 0.55 + 0.45 * sin(time * 5.0)
	var at := badge_rect(r)
	Art.pill(ci, Vector2(at.get_center().x, at.position.y), BADGE_TEXT, Color(Ui.HIGHLIGHT, pulse), Ui.LINE, BADGE_FONT)


# --- Choosing at placement -----------------------------------------------------------------------------------------
# While a hut is held over the map, a picker by the ghost lists what is in reach (only when there is a choice). `pick`
# below is the player's choice so far ("" for none: the hut then works its default); the owner keeps it until the hut
# goes down. Geometry is in the map's own drawing space (like Art.pill), sized by Art.ui_k so it reads at any zoom.


## The resources a hut at p could work, when there is a choice to make (two or more), else [].
static func pick_options(s: Sim, p: Vector2i) -> Array:
	var options := s.town.focus_options(p)
	return options if options.size() > 1 else []


## What a hut put at p would work given the player's `pick`: that, if it is in reach there, else the default.
static func pick_chosen(s: Sim, p: Vector2i, pick: String) -> String:
	return pick if pick in s.town.focus_options(p) else s.town.default_focus(p)


## The choice after Tab or R: the next resource in reach after the current one, around to the first. `pick` comes back
## unchanged when there is no choice at p.
static func pick_next(s: Sim, p: Vector2i, pick: String) -> String:
	var options := pick_options(s, p)
	if options.is_empty():
		return pick
	return options[(options.find(pick_chosen(s, p, pick)) + 1) % options.size()]


## The one-time toast for a hut that has just gone down at p without the player choosing: what it works, and that the
## others are in reach too ("" when the player picked, or when there was nothing else to pick).
static func pick_note(s: Sim, p: Vector2i, picked: String) -> String:
	var options := pick_options(s, p)
	if options.is_empty() or picked in options:
		return ""
	var focus: String = s.town.focus_at(p)
	var others: Array = options.filter(func(id): return id != focus).map(func(id): return Data.ITEMS[id]["name"])
	if focus == "" or others.is_empty():
		return ""
	var names: String = (
		" and ".join(others) if others.size() < 3 else ", ".join(others.slice(0, -1)) + " and " + others[-1]
	)
	var verb := "is" if others.size() == 1 else "are"
	return (
		"This hut works %s. %s %s in reach too: pick %s in the hut panel."
		% [Data.ITEMS[focus]["name"], names, verb, "it" if others.size() == 1 else "one"]
	)


## Where the picker sits for a hut at p, kept inside `bounds` (the visible map, in map space): {"panel": Rect2, "rows":
## {item: Rect2}}. Above the ghost; below its note pill when there is no room above. Empty without a choice, or
## where the hut can't go.
static func pick_rects(s: Sim, p: Vector2i, bounds: Rect2) -> Dictionary:
	var options := pick_options(s, p)
	if options.is_empty() or s.town.placement_error("gatherers_hut", p) != "":
		return {}  # no choice, or nowhere to put the hut
	var k := Art.ui_k
	var px := roundi(Ui.MIN_TEXT * k)
	var font := ThemeDB.fallback_font
	var w := 0.0
	for text in [PICK_TITLE, PICK_KEYS]:
		w = maxf(w, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	for item in options:
		var name_w := font.get_string_size(Data.ITEMS[item]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		w = maxf(w, name_w + (PICK_ICON + 20.0) * k)
	w += 2.0 * PICK_PAD * k
	var head := 2.0 * (px + 2.0 * k) + 4.0 * k
	var h := 2.0 * PICK_PAD * k + head + options.size() * PICK_ROW * k
	var tile := Overlays.rect(p)
	var y := tile.position.y - 6.0 * k - h
	if y < bounds.position.y:
		y = tile.end.y + 34.0 * k  # under the ghost's note pill
	var at := Vector2(tile.get_center().x - w / 2.0, y)
	at.x = clampf(at.x, bounds.position.x, maxf(bounds.end.x - w, bounds.position.x))
	at.y = clampf(at.y, bounds.position.y, maxf(bounds.end.y - h, bounds.position.y))
	var rows := {}
	var top := at.y + PICK_PAD * k + head
	for n in options.size():
		rows[options[n]] = Rect2(
			Vector2(at.x + PICK_PAD * k, top + n * PICK_ROW * k),
			Vector2(w - 2.0 * PICK_PAD * k, PICK_ROW * k - 2.0 * k)
		)
	return {"panel": Rect2(at, Vector2(w, h)), "rows": rows}


## The resource whose picker row is under map-space point `at` ("" for none).
static func pick_at(s: Sim, p: Vector2i, bounds: Rect2, at: Vector2) -> String:
	var rects := pick_rects(s, p, bounds)
	if rects.is_empty():
		return ""
	for item in rects["rows"]:
		if rects["rows"][item].grow(2.0 * Art.ui_k).has_point(at):
			return item
	return ""


## True when `at` is over the picker's panel (a click there is the picker's, and the ghost stays where it is).
static func pick_over(s: Sim, p: Vector2i, bounds: Rect2, at: Vector2) -> bool:
	var rects := pick_rects(s, p, bounds)
	return not rects.is_empty() and rects["panel"].has_point(at)


## Draw the picker for a hut ghost at p: a title, the keys, and one row per resource (icon and name), the one it will
## work lit gold.
static func draw_picker(ci: CanvasItem, s: Sim, p: Vector2i, pick: String, bounds: Rect2) -> void:
	var rects := pick_rects(s, p, bounds)
	if rects.is_empty():
		return
	var k := Art.ui_k
	var px := roundi(Ui.MIN_TEXT * k)
	var font := ThemeDB.fallback_font
	var panel: Rect2 = rects["panel"]
	var box := Ui.panel_style(Ui.PANEL, 0)
	box.set_border_width_all(maxi(roundi(2.0 * k), 1))
	box.set_corner_radius_all(roundi(8.0 * k))
	ci.draw_style_box(box, panel)
	var x := panel.position.x + PICK_PAD * k
	var y := panel.position.y + PICK_PAD * k + px
	ci.draw_string(font, Vector2(x, y), PICK_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT)
	ci.draw_string(font, Vector2(x, y + px + 2.0 * k), PICK_KEYS, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT_DIM)
	var chosen := pick_chosen(s, p, pick)
	for item in rects["rows"]:
		var r: Rect2 = rects["rows"][item]
		var on: bool = item == chosen
		var row_box := Ui.panel_style(Ui.HIGHLIGHT if on else Ui.CARD, 0)
		row_box.set_border_width_all(maxi(roundi(2.0 * k), 1))
		row_box.set_corner_radius_all(roundi(6.0 * k))
		ci.draw_style_box(row_box, r)
		var icon := Rect2(r.position + Vector2(6.0 * k, (r.size.y - PICK_ICON * k) / 2.0), Vector2.ONE * PICK_ICON * k)
		Art.item_icon(ci, item, icon, 1.0)
		var text_at := Vector2(icon.end.x + 8.0 * k, r.position.y + (r.size.y + px) / 2.0 - 3.0 * k)
		ci.draw_string(
			font, text_at, Data.ITEMS[item]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.LINE if on else Ui.TEXT
		)
