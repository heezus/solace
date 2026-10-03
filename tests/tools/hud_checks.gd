extends RefCounted
## HUD checks for the layout pass (tests/tools/layout_pass.gd), kept apart so that file stays under the line limit.
## Each takes the running main scene and returns its problems as a list of lines (empty when all is well).

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const ICON_SIZE := Vector2(24, 24)  # a good's sprite in the top bar


## The Falling Star's card sits in the middle of the dimmed map view (not the top left), clear of the top bar, the side
## panel and the bottom bar, inside the window, with the Keep building button on it, and the game waits behind it.
static func end_card(main: Node, when: String) -> Array:
	var problems: Array = []
	var card: Control = main.era_card
	var panel: Control = null
	var button: Button = null
	for c in _all(card):
		if c is PanelContainer:
			panel = c
		elif c is Button:
			button = c
	if panel == null or button == null or not card.visible:
		return ["%s: the end card isn't up with its panel and button" % when]
	var r: Rect2 = panel.get_global_rect()
	var view: Rect2 = main.view
	if r.size.x < 200.0 or r.size.y < 100.0:
		problems.append("%s: the end card is only %s" % [when, r.size])
	if r.get_center().distance_to(view.get_center()) > 2.0:
		problems.append("%s: the end card (%s) isn't centred in the map view (%s)" % [when, r, view])
	for part in ["top_bar", "bottom_bar", "side_panel"]:
		var other: Rect2 = main.get(part).get_global_rect()
		if r.intersects(other):
			problems.append("%s: the end card (%s) covers the %s (%s)" % [when, r, part, other])
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(r):
		problems.append("%s: the end card (%s) runs off the window" % [when, r])
	if not r.encloses(button.get_global_rect()) or button.text != Data.ERA_END_BUTTON:
		problems.append("%s: the Keep building button isn't on the card" % when)
	if not main.paused:
		problems.append("%s: the game isn't paused behind the end card" % when)
	var readout := Rect2(main.top_bar.kith_label.get_global_position(), main.top_bar.kith_label.size)
	if r.intersects(readout):
		problems.append("%s: the end card sits over the Kith readout" % when)
	return problems


## The second era's row of chips: each is the sprite (as big as the other rows'), the good's name in readable text and
## the count, on one line, with a tooltip that carries the rate, and none touches the bar's edge or is cut off.
static func third_row(main: Node, when: String) -> Array:
	var problems: Array = []
	var tb = main.top_bar
	var seen := 0
	for id in tb.chips:
		if int(Data.ITEMS[id].get("era", 1)) != 2:
			continue
		var c: Dictionary = tb.chips[id]
		if not c["box"].is_visible_in_tree():
			problems.append("%s: the %s chip isn't showing in the third row" % [when, id])
			continue
		seen += 1
		var item: Dictionary = Data.ITEMS[id]
		var short: String = item.get("short", item["name"])
		var names: Array = _all(c["box"]).filter(func(l): return l is Label and l.text == short)
		if names.is_empty():
			problems.append("%s: the %s chip has no name (%s) beside its count" % [when, id, short])
		for l in names:
			if l.get_theme_font_size("font_size") < Ui.MIN_TEXT:
				problems.append("%s: the %s chip's name is under %d px" % [when, id, Ui.MIN_TEXT])
		if c["icon"].size != ICON_SIZE or c["icon"].size != tb.chips["wood"]["icon"].size:
			problems.append(
				"%s: the %s sprite is %s, not %s like the first row" % [when, id, c["icon"].size, ICON_SIZE]
			)
		if not String(c["box"].tooltip_text).contains("per second"):
			problems.append("%s: the %s chip's tooltip lost the rate" % [when, id])
	if seen != 5:
		problems.append("%s: %d chips in the third row, not 5" % [when, seen])
	return problems + chip_fit(main, when)


## Every chip keeps TopBar.EDGE_PAD from the bar's top and bottom edge (the bottom rule sits inside that) and stays
## inside the bar's goods area, not clipped at its right end.
static func chip_fit(main: Node, when: String) -> Array:
	var problems: Array = []
	var tb = main.top_bar
	var bar: Rect2 = tb.get_global_rect()
	var goods: Rect2 = tb.chips["wood"]["box"].get_parent().get_parent().get_global_rect()
	var wide: bool = main.get_viewport_rect().size.x >= 1279.0
	var want: float = tb.EDGE_PAD + tb.RULE_W
	for id in tb.chips:
		var box: Control = tb.chips[id]["box"]
		if not box.is_visible_in_tree():
			continue
		var r: Rect2 = box.get_global_rect()
		var above: float = r.position.y - bar.position.y
		var below: float = bar.end.y - r.end.y
		if above < tb.EDGE_PAD - 0.5:
			problems.append(
				"%s: the %s chip is %.0f px from the bar's top edge (want %.0f)" % [when, id, above, tb.EDGE_PAD]
			)
		if below < want - 0.5:
			problems.append(
				"%s: the %s chip is %.0f px from the bar's bottom edge (want %.0f)" % [when, id, below, want]
			)
		if wide and r.end.x > goods.end.x + 0.5:
			problems.append(
				"%s: the %s chip runs out of the goods area (%.0f > %.0f)" % [when, id, r.end.x, goods.end.x]
			)
	return problems


## The Gathering tab's four cards (Gatherer's Hut, Field, Flax Field, Fishing Weir) all show, each whole inside the
## bottom bar and the window, clear of one another and of the Craft by hand buttons and the Demolish button.
static func gathering_tab(main: Node, when: String) -> Array:
	var problems: Array = []
	var bar: Control = main.bottom_bar
	if bar.tab != "Gathering":
		return ["%s: the Gathering tab isn't the one showing" % when]
	var window := Rect2(Vector2.ZERO, main.get_viewport_rect().size)
	var cards: Array = []
	for type in Data.BUILD_TABS["Gathering"]:
		var card: Control = bar.build_buttons[type]["button"]
		if not card.is_visible_in_tree():
			problems.append("%s: the %s card isn't showing on the Gathering tab" % [when, type])
			continue
		cards.append({"type": type, "rect": card.get_global_rect()})
	if cards.size() != 4:
		problems.append("%s: the Gathering tab shows %d cards (want 4)" % [when, cards.size()])
	var others: Array = [{"type": "Demolish", "rect": bar.demolish_button.get_global_rect()}]
	for r in bar.craft_buttons:
		others.append({"type": "Craft " + r, "rect": bar.craft_buttons[r].get_global_rect()})
	for a in cards:
		var r: Rect2 = a["rect"]
		if not bar.get_global_rect().encloses(r) or not window.encloses(r):
			problems.append("%s: the %s card (%s) runs out of the bottom bar or the window" % [when, a["type"], r])
		for b in cards + others:
			if a["type"] != b["type"] and r.intersects(b["rect"]) and (b in others or a["type"] < b["type"]):
				problems.append("%s: the %s card overlaps %s" % [when, a["type"], b["type"]])
	if bar.get_combined_minimum_size().x > window.size.x:
		problems.append(
			(
				"%s: the bottom bar needs %.0f px of a %.0f px window"
				% [when, bar.get_combined_minimum_size().x, window.size.x]
			)
		)
	return problems


static func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out += _all(c)
	return out
