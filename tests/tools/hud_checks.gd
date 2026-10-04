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


## The Food block's second line (rate, then where the next birth stands) fits the block: the live label shows all its
## lines at 14 px or more inside the bar, and the longest wording each state can take, measured at the block's width,
## still leaves the block (name, up to three lines, the bar) within the bar's height.
static func food_readout(main: Node, when: String) -> Array:
	var problems: Array = []
	var tb = main.top_bar
	var sub: Label = tb.food_sub
	var bar: Rect2 = tb.get_global_rect()
	if sub.is_visible_in_tree():
		if sub.get_line_count() > sub.get_visible_line_count():
			problems.append('%s: the Food readout "%s" is cut short' % [when, sub.text])
		if sub.get_theme_font_size("font_size") < Ui.MIN_TEXT:
			problems.append("%s: the Food readout is under %d px" % [when, Ui.MIN_TEXT])
		var box: Rect2 = tb.food_box.get_global_rect()
		if box.end.y > bar.end.y - tb.RULE_W + 0.5 or box.position.y < bar.position.y + tb.EDGE_PAD - 0.5:
			problems.append("%s: the Food block (%s) runs out of the bar (%s)" % [when, box, bar])
		if box.end.x > bar.end.x + 0.5:
			problems.append("%s: the Food block runs off the bar's right end" % when)
	var one: String = Data.PEOPLE["one"]
	var worst: Array = [
		Data.GROW_STEADY % [35, 35, one, "99 min"],
		Data.GROW_NEEDS_MORE % "99.9",
		Data.GROW_NEEDS_STOCK % 999,
		Data.GROW_COUNTING % [30, 30],
		Data.GROW_NEXT % [one, "99 min"],
	]
	var font := ThemeDB.fallback_font
	var width: float = tb.FOOD_W - 4.0
	var line_h := font.get_height(Ui.MIN_TEXT)
	for text in worst:
		var lines := roundi(
			font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, Ui.MIN_TEXT).y / line_h
		)
		var block: float = font.get_height(tb.COUNT_SIZE) + (1 + lines) * line_h + 6.0
		if block > tb.BAR_H - 2.0 * tb.EDGE_PAD - tb.RULE_W:
			problems.append(
				'%s: "%s" takes %d lines: the Food block would be %.0f px tall' % [when, text, lines, block]
			)
	return problems


static func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out += _all(c)
	return out
