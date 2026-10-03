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


## The second era's row of chips is the same widget as the stone age's rows (a chip is a chip in every era): the same
## size, sprite size, count and rate font sizes, padding, gap and tooltip with the rate in it, each under the column of
## the chip above it, and none touches the bar's edge or is cut off.
static func third_row(main: Node, when: String) -> Array:
	var problems: Array = []
	var tb = main.top_bar
	var ref: Dictionary = tb.chips["wood"]
	var seen := 0
	var col := 0
	for id in tb.chips:
		if int(Data.ITEMS[id].get("era", 1)) != 2:
			continue
		var c: Dictionary = tb.chips[id]
		if not c["box"].is_visible_in_tree():
			problems.append("%s: the %s chip isn't showing in the third row" % [when, id])
			continue
		seen += 1
		problems.append_array(_same_chip(ref, c, id, when))
		var above: Control = tb.chips[Data.ITEM_ORDER[col]]["box"]  # the same column of the first row
		var lined_up := absf(c["box"].get_global_rect().position.x - above.get_global_rect().position.x) <= 0.5
		if above.is_visible_in_tree() and not lined_up:
			problems.append("%s: the %s chip isn't under the first row's column %d" % [when, id, col])
		col += 1
	if seen != 5:
		problems.append("%s: %d chips in the third row, not 5" % [when, seen])
	var rows: Array = []
	for id in ["wood", "rope", "copper_ore"]:
		rows.append(tb.chips[id]["box"].get_global_rect())
	if absf(rows[1].position.y - rows[0].position.y - (rows[2].position.y - rows[1].position.y)) > 0.5:
		problems.append("%s: the three rows of chips aren't evenly spaced (%s)" % [when, rows])
	return problems + chip_fit(main, when)


## Chip `c` against the reference chip `ref`: every measured property of the widget is the same.
static func _same_chip(ref: Dictionary, c: Dictionary, id: String, when: String) -> Array:
	var problems: Array = []
	var a: Control = ref["box"]
	var b: Control = c["box"]
	if a.size != b.size:
		problems.append("%s: the %s chip is %s, the first row's are %s" % [when, id, b.size, a.size])
	if c["icon"].size != ICON_SIZE or c["icon"].size != ref["icon"].size:
		problems.append("%s: the %s sprite is %s, not %s like the first row" % [when, id, c["icon"].size, ICON_SIZE])
	for part in ["count", "rate"]:
		if c[part] == null:
			problems.append("%s: the %s chip has no %s line like the first row's" % [when, id, part])
		elif c[part].get_theme_font_size("font_size") != ref[part].get_theme_font_size("font_size"):
			problems.append("%s: the %s chip's %s is a different size from the first row's" % [when, id, part])
	if c["rate"] != null and c["rate"].get_theme_font_size("font_size") < Ui.MIN_TEXT:
		problems.append("%s: the %s chip's rate is under %d px" % [when, id, Ui.MIN_TEXT])
	var pa: StyleBox = a.get_theme_stylebox("panel")
	var pb: StyleBox = b.get_theme_stylebox("panel")
	for side in 4:
		if pa.get_margin(side) != pb.get_margin(side):
			problems.append("%s: the %s chip's padding differs from the first row's (side %d)" % [when, id, side])
	if _all(a).size() != _all(b).size():
		problems.append("%s: the %s chip is built differently from the first row's" % [when, id])
	if not String(b.tooltip_text).contains("per second"):
		problems.append("%s: the %s chip's tooltip lost the rate" % [when, id])
	return problems


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


static func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out += _all(c)
	return out
