extends RefCounted
## The Gatherer's Hut picker, checked for the layout pass (tests/tools/layout_pass.gd): the picker beside the ghost while
## a hut is placed, and the row of buttons on the hut card, with three or more resources in reach, at whatever the window is.
## A hut is held over a spot, placed with Clay picked, and its card opened; each step returns its problems as a list.

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")
const PatchText = preload("res://scripts/patch_text.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Art = preload("res://scripts/art.gd")

var spot := Vector2i(-1, -1)  # where the hut stands for the check
var tiles := {}  # the tiles turned into resources, to put back
var count := 3  # how many resources are in reach of the spot (three made up, others the map has)


## Hold a hut over a spot with Wood, Clay and Berries in reach, with the Hearth's neighbourhood stocked to pay for it.
func hold_a_hut(main: Node) -> Array:
	var s = main.state
	s.research("gatherers_hut")
	for id in s.economy.inv:
		if not Data.FOOD_VALUE.has(id) and int(Data.ITEMS[id].get("era", 1)) == 1:
			s.economy.inv[id] = maxi(s.economy.inv[id], 40)
	spot = Vector2i(-1, -1)
	for r in range(2, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if spot.x < 0 and s.town.placement_error("gatherers_hut", p) == "":
					spot = p
	if spot.x < 0:
		return ["no room for a hut to check the picker on"]
	tiles.clear()
	var want := {Vector2i(1, 0): "tree", Vector2i(-2, 0): "clay", Vector2i(0, 2): "berry"}
	for off in want:
		tiles[spot + off] = s.world.tile_at(spot + off)
		s.world.set_tile(spot + off, want[off])
	count = s.town.focus_options(spot).size()
	if count < 3:
		return ["only %d resources in reach of the picker check's spot (want 3)" % count]
	main.building_panel.select(Vector2i(-1, -1))
	main.placing = "gatherers_hut"
	main.pick_focus = ""
	main.get_viewport().warp_mouse(main.screen_of(spot))
	return []


## The placement picker: one row per resource, each tall enough to click, none over another, all inside the panel and
## the visible map.
func check_placing(main: Node, when: String) -> Array:
	if spot.x < 0:
		return []
	var problems: Array = []
	var bounds: Rect2 = main._view_local()
	var rects: Dictionary = HutFocus.pick_rects(main.state, spot, bounds)
	if rects.is_empty() or rects["rows"].size() != count:
		return ["the placement picker at %s isn't offering all %d resources" % [when, count]]
	var panel: Rect2 = rects["panel"]
	if not bounds.encloses(panel):
		problems.append("the placement picker at %s: %s runs out of the map view %s" % [when, panel, bounds])
	var seen: Array = []
	for item in rects["rows"]:
		var r: Rect2 = rects["rows"][item]
		if not panel.encloses(r):
			problems.append("the placement picker at %s: the %s row %s is outside %s" % [when, item, r, panel])
		if r.size.y * main.scale.x < 24.0:
			problems.append("the placement picker at %s: the %s row is under 24 px tall" % [when, item])
		for other in seen:
			if r.intersects(other):
				problems.append("the placement picker at %s: two rows overlap" % when)
		seen.append(r)
	return problems + check_pill(main, panel, when)


## The ghost's note pill (trip, then the patch's "Clay x4 · +30% speed") sits under the ghost and never touches the
## picker's panel, and it fits the map view.
func check_pill(main: Node, panel: Rect2, when: String) -> Array:
	var s = main.state
	var item: String = HutFocus.pick_chosen(s, spot, main.pick_focus)
	var note: String = PatchText.with_pill(s, "gatherers_hut", spot, item, BuildingPanel.trip_text(s, spot))
	if note == "":
		return []
	var k := Art.ui_k
	var px := maxi(roundi(14.0 * k), 1)
	var w: float = ThemeDB.fallback_font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 14.0 * k
	var tile: Rect2 = Overlays.rect(spot)
	var pill := Rect2(Vector2(tile.get_center().x - w / 2.0, tile.end.y + 4.0), Vector2(w, px + 8.0 * k))
	var problems: Array = []
	if pill.intersects(panel):
		problems.append("the placement pill at %s (%s) overlaps the picker (%s): %s" % [when, pill, panel, note])
	if pill.intersects(tile):
		problems.append("the placement pill at %s covers the ghost" % when)
	return problems


## Put the hut down with Clay picked (it must work Clay, with no extra click) and open its card.
func place_picked(main: Node) -> Array:
	if spot.x < 0:
		return []
	main.pick_focus = "clay"
	main._place_at(spot)
	main.placing = ""
	main.building_panel.select(spot)
	main.ui_refresh = 999.0
	var b: Dictionary = main.state.town.buildings[main.state.town.building_at[spot]]
	return [] if b["focus"] == "clay" else ["a hut placed with Clay picked works %s" % b["focus"]]


## The hut card's picker: a button for each resource (icon, plain name, tooltip, 14 px text), one pressed, all inside the
## card and the side panel (they wrap rather than widen it), none over another.
func check_card(main: Node, when: String) -> Array:
	if spot.x < 0:
		return []
	var problems: Array = []
	var focus = main.building_panel.parts["focus"]
	var card: Rect2 = main.building_panel.get_global_rect()
	var side: Rect2 = main.side_panel.get_global_rect()
	if not focus.is_visible_in_tree() or not focus.row.visible or focus.row.get_child_count() != count:
		return ["the hut card at %s isn't showing a button for each of %d resources" % [when, count]]
	var pressed := 0
	var seen: Array = []
	for b in focus.row.get_children():
		var r: Rect2 = b.get_global_rect()
		pressed += int(b.button_pressed)
		if not (card.encloses(r) and side.encloses(r)):
			problems.append("the hut card at %s: the %s button %s runs out of %s / %s" % [when, b.text, r, card, side])
		if r.size.y < 28.0 or r.size.x < 40.0:
			problems.append("the hut card at %s: the %s button is only %s" % [when, b.text, r.size])
		if b.get_theme_font_size("font_size") < Ui.MIN_TEXT:
			problems.append("the hut card at %s: the %s button's text is under %d px" % [when, b.text, Ui.MIN_TEXT])
		if b.icon == null or b.tooltip_text == "":
			problems.append("the hut card at %s: the %s button has no icon or tooltip" % [when, b.text])
		for other in seen:
			if r.intersects(other):
				problems.append("the hut card at %s: two resource buttons overlap" % when)
		seen.append(r)
	if pressed != 1:
		problems.append("the hut card at %s: %d resource buttons are pressed (want 1)" % [when, pressed])
	return problems


## Take the hut and the made-up resources away again, so the bot plays on as before.
func cleanup(main: Node) -> void:
	if spot.x >= 0:
		main.building_panel.select(Vector2i(-1, -1))
		main.state.demolish(spot)
		for t in tiles:
			main.state.world.set_tile(t, tiles[t])
	spot = Vector2i(-1, -1)
	main.placing = ""
	main.ui_refresh = 0.0
