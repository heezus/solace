extends SceneTree
## The map's fit scale over a long run: the bot plays to Bronze Dawn with the UI refreshing every frame,
## and the map's scale may change only when the window size does (the bars must keep steady heights).
## It also checks the HUD's fit, at 1280x800 and after two resizes: the Info panel stays above the bottom bar
## even with a wall of text, a building's details are docked in the Info panel (nothing floats over the map),
## the top bar never runs past the window and none of its text is cut short (also with the food warning and
## starvation showing), toasts stack without overlapping each other or a chip, every chip has a tooltip that names it
## and a sprite, a Hearth's blurb shows once, every build card's text fits it, and the message log opens.
## Run: godot --headless --path . -s tests/tools/layout_pass.gd   (exits 1 on a problem)

const Data = preload("res://scripts/data.gd")
const World = preload("res://scripts/world.gd")
const HoverText = preload("res://scripts/hover_text.gd")
const Autoplay = preload("res://tests/autoplay.gd")

const BOT_STEPS_PER_FRAME := 20
const MAX_FRAMES := 9000
const RESIZE_AT := 400  # frame: the window is resized once, and the map must refit
const SHRINK_AT := 450  # frame: and made smaller than the design size
const WALL := "A long line of text that has to wrap onto several lines inside the Info panel. "

var main: Node
var bot: Autoplay
var frame := 0
var last_vp := Vector2.ZERO
var last_scale := Vector2.ZERO
var last_pos := Vector2.ZERO
var last_bars := Vector2.ZERO
var problems: Array = []
var changes := 0
var refit_due := 0  # the frame by which the map must have refit after a resize
var hud_checks := 0  # how many HUD checks ran
var base := {}  # the top bar's height and the map's place before the stress cases
var saved := {}  # the stockpile as it was, put back after them
var frozen := false  # the bot's ticking is paused while a check sets the state by hand


func _init() -> void:
	seed(7)
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.paused = true
		bot = Autoplay.new()
		bot.attach(main.state)
	if frame > 3 and not frozen:
		for i in BOT_STEPS_PER_FRAME:
			if main.state.won:
				break
			main.state.tick(Autoplay.DT)
			bot.step(false)
		main.ui_refresh = 0.0  # refresh the bars every frame, so any wobble shows
	if frame == RESIZE_AT:
		root.size = Vector2i(1600, 800)  # wider: the map must refit (re-centre; the bars keep their heights)
	if frame == SHRINK_AT:
		root.size = Vector2i(1100, 700)  # then a window of another shape: everything must still fit
	if frame > 5:
		_check()
	_hud_checks()
	if main.state.won or frame > MAX_FRAMES:
		_finish()
	return false


func _check() -> void:
	var vp: Vector2 = main.get_viewport_rect().size
	var bars := Vector2(main.top_bar.size.y, main.bottom_bar.size.y)
	if last_scale != Vector2.ZERO and main.scale != last_scale:
		changes += 1
		if vp == last_vp and refit_due == 0:
			problems.append(
				(
					"frame %d: the map scale went %.4f -> %.4f with the window unchanged (bars %s -> %s)"
					% [frame, last_scale.x, main.scale.x, last_bars, bars]
				)
			)
	if last_vp != Vector2.ZERO and vp != last_vp:
		refit_due = frame + 2
	if refit_due > 0 and (main.scale != last_scale or main.position != last_pos):
		refit_due = 0
	elif refit_due > 0 and frame > refit_due:
		problems.append("frame %d: the window went to %s but the map didn't refit" % [frame, vp])
		refit_due = 0
	last_vp = vp
	last_scale = main.scale
	last_pos = main.position
	last_bars = bars


## The HUD checks, on fixed frames. Those that set the state by hand freeze the bot for a frame or two.
func _hud_checks() -> void:
	match frame:
		8:
			frozen = true
			_show_hearth_panel()
		10:
			_check_hearth_blurb_once()
			_check_card_is_docked("the Hearth's card")
			main.building_panel.select(Vector2i(-1, -1))
			main._toast("A toast that must not cover the chips", 30.0)
			main._toast("A second toast, stacked under the first, not over it", 30.0)
			main.messages.push("A third that stays until it is clicked", 0.0, true)
			main.messages.push("A fourth: " + WALL, 30.0)
		12:
			_check_toast_and_chips()
			main.messages.active.clear()
			main.messages.changed.emit()
			main.state.economy.low = true
		14:
			_check_top_bar_text("with the food warning up")
			main.state.economy.starving = true
		16:
			_check_top_bar_text("while starving")
			main.state.economy.starving = false
			main.state.economy.low = false
			frozen = false
		28:
			frozen = true
			base = {
				"bar": main.top_bar.size.y,
				"pos": main.position,
				"scale": main.scale,
				"chip_x": main.top_bar.chips["wood"]["box"].get_global_rect().position.x,
			}
			var eco = main.state.economy
			saved = {"inv": eco.inv.duplicate(), "seen": eco.seen.duplicate(), "flows": eco.flows.to_dict()}
		30, 33, 36, 39, 42:
			_stress_case(floori((frame - 30) / 3.0))
		32, 35, 38, 41:
			_check_stable("stress case %d" % floori((frame - 32) / 3.0))
			main.ui_refresh = 0.0
		44:
			_check_stable("stress case 4")
			var eco = main.state.economy
			eco.inv.clear()
			eco.inv.merge(saved["inv"])
			eco.seen.clear()
			eco.seen.merge(saved["seen"])
			eco.flows.from_dict(saved["flows"])
			eco.low = false
			eco.starving = false
			main.ui_refresh = 0.0
			frozen = false
		50:
			frozen = true
			main.ui_refresh = 999.0
			main.info_label.text = WALL.repeat(40)  # far more than fits
		52:
			_check_fit("with a wall of text in the Info panel")
			main.ui_refresh = 0.0
			frozen = false
		54:
			frozen = true
			_show_hut_panel_with_a_wall_of_text()
		55:
			_check_card_buttons("a hut's card with a wall of text")
			main.building_panel.select(Vector2i(-1, -1))
			main.ui_refresh = 0.0
			frozen = false
		56:
			frozen = true
			main.msg_log.visible = false
			main.messages.push("Discovered a thing", 30.0)
			main.msg_log.toggle()
		58:
			_check_log_opens()
			main.msg_log.visible = false
			main.tech_panel.view_chosen = false
			main.tech_panel.visible = true
		60:
			_check_board_open()
			main.tech_panel._pick_view("all")
		62:
			_check_board_hover()
			main.tech_panel.visible = false
			frozen = false
	if frame > 5 and frame % 5 == 0:
		_check_fit("at frame %d" % frame)
	if frame > 5 and frame % 20 == 0:
		_check_build_cards("at frame %d" % frame)
	if frame > 5 and frame % 25 == 0:
		_check_top_bar_text("at frame %d" % frame)


## Long top-bar text, one case at a time: the food warning, starving, needs-room text, the longest hold hint,
## and every chip showing with big numbers. Each is applied here and checked two frames on (_check_stable).
func _stress_case(n: int) -> void:
	var eco = main.state.economy
	eco.low = n in [0, 2]
	eco.starving = n == 1
	match n:
		0, 1, 2:
			eco.inv["berries"] = 0 if n != 0 else 3
		3:
			main.msg_log.visible = true  # the log is open over the map: the top bar must not care
		4:
			for id in Data.ITEM_ORDER:
				eco.inv[id] = 9999
				eco.seen[id] = true
				eco.flows.add(id, 12.5, "hand")
			eco.flows.advance(1.0)


## The top bar is as tall as it was, the map hasn't moved or changed scale, and no text is cut short.
func _check_stable(what: String) -> void:
	hud_checks += 1
	if main.top_bar.size.y != base["bar"]:
		problems.append("%s: the top bar went from %.0f to %.0f tall" % [what, base["bar"], main.top_bar.size.y])
	if main.position != base["pos"] or main.scale != base["scale"]:
		problems.append(
			"%s: the map moved (%s, x%s -> %s, x%s)" % [what, base["pos"], base["scale"], main.position, main.scale]
		)
	var chip_x: float = main.top_bar.chips["wood"]["box"].get_global_rect().position.x
	if not is_equal_approx(chip_x, base["chip_x"]):
		problems.append("%s: the chips moved sideways (%.0f -> %.0f)" % [what, base["chip_x"], chip_x])
	_check_top_bar_text(what)


## A hut (placed by hand) selected, with far more text in its card than the panel has room for.
func _show_hut_panel_with_a_wall_of_text() -> void:
	var s = main.state
	for id in s.economy.inv:
		if not Data.FOOD_VALUE.has(id):  # food stays as it is: a big pantry with no income would stop the bot growing
			s.economy.inv[id] = maxi(s.economy.inv[id], 40)
	s.research("gatherers_hut")
	var at := Vector2i(-1, -1)
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if at.x < 0 and s.town.placement_error("gatherers_hut", p) == "":
					at = p
	if at.x < 0 or not s.place("gatherers_hut", at):
		problems.append("couldn't place a hut for the card check")
		return
	main.building_panel.select(at)
	main.ui_refresh = 999.0
	main.building_panel.parts["desc"].text = WALL.repeat(4)


## Collect, Pause and Demolish stay on the side panel and above the bottom bar, however tall the card is.
func _check_card_buttons(what: String) -> void:
	hud_checks += 1
	var side: Rect2 = main.side_panel.get_global_rect()
	var bottom: Rect2 = main.bottom_bar.get_global_rect()
	var seen := 0
	for key in ["collect", "pause", "demolish"]:
		var b: Button = main.building_panel.parts[key]
		if not b.is_visible_in_tree():
			continue
		seen += 1
		var r: Rect2 = b.get_global_rect()
		if r.size.x < 20.0 or r.size.y < 20.0 or not side.encloses(r) or r.end.y > bottom.position.y + 1.0:
			problems.append(
				"%s: the %s button (%s) isn't reachable (side panel %s, bottom bar %s)" % [what, key, r, side, bottom]
			)
	if seen < 2:
		problems.append("%s: only %d card buttons showed (want Pause and Demolish)" % [what, seen])


func _show_hearth_panel() -> void:
	main.building_panel.select(main.state.world.camp_pos)
	main.ui_refresh = 0.0


## Clicking the Hearth: its blurb is on screen once, across its card and the Info panel.
func _check_hearth_blurb_once() -> void:
	hud_checks += 1
	var blurb: String = Data.BUILDINGS["camp"]["desc"]
	main.hover = main.state.world.camp_pos
	var texts: Array = [HoverText.text(main)]
	for key in ["status", "desc"]:
		if main.building_panel.parts[key].visible:
			texts.append(main.building_panel.parts[key].text)
	var n := 0
	for text in texts:
		n += String(text).count(blurb)
	if n != 1:
		problems.append("the Hearth's blurb shows %d times across its card and the Info panel (want 1)" % n)


## Toasts sit below the top bar, clear of every chip and of each other; every chip has a tooltip that names it
## and a sprite behind nothing.
func _check_toast_and_chips() -> void:
	hud_checks += 1
	_check_toast_stack()
	var bar: Rect2 = main.top_bar.get_global_rect()
	for id in main.top_bar.chips:
		var c: Dictionary = main.top_bar.chips[id]
		for tid in main.toasts.panels:
			if main.toasts.panels[tid].get_global_rect().intersects(c["box"].get_global_rect()):
				problems.append("a toast covers the %s chip" % id)
		if c["box"].tooltip_text == "":
			problems.append("the %s chip has no tooltip" % id)
		elif not String(c["box"].tooltip_text).begins_with(Data.ITEMS[id]["name"]):
			problems.append("the %s chip's tooltip doesn't start with its name (the icon carries it)" % id)
		var icon: Control = c["icon"]
		if not icon is TextureRect or icon.texture == null:
			problems.append("the %s chip has no sprite" % id)
		elif icon.size.x < 24.0 or icon.get_global_rect().end.y > bar.end.y:
			problems.append("the %s chip's sprite is %s (want 24 px, inside the bar)" % [id, icon.size])


## The Info panel stays above the bottom bar, and the top bar stays inside the window.
func _check_fit(when: String) -> void:
	hud_checks += 1
	var vp: Vector2 = main.get_viewport_rect().size
	var side: Rect2 = main.side_panel.get_global_rect()
	var bottom: Rect2 = main.bottom_bar.get_global_rect()
	if side.end.y > bottom.position.y + 1.0:
		problems.append(
			"%s: the side panel runs past the bottom bar (%.0f > %.0f)" % [when, side.end.y, bottom.position.y]
		)
	var bar: Rect2 = main.top_bar.get_global_rect()
	if bar.end.x > vp.x + 1.0:
		problems.append("%s: the top bar (%.0f wide) is wider than the window (%.0f)" % [when, bar.end.x, vp.x])
	if main.building_panel.visible:
		_check_card_is_docked("the building card " + when)


## No text in the top bar is cut short: a line either fits its width or wraps and fits its height.
func _check_top_bar_text(when: String) -> void:
	hud_checks += 1
	var bar: Rect2 = main.top_bar.get_global_rect()
	for l in _labels(main.top_bar):
		if not l.is_visible_in_tree() or l.text == "":
			continue
		var font: Font = l.get_theme_font("font")
		var fs: int = l.get_theme_font_size("font_size")
		var r: Rect2 = l.get_global_rect()
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > r.size.x + 1.0:
				problems.append('%s: "%s" is cut short in the top bar (%.0f > %.0f px)' % [when, l.text, w, r.size.x])
		elif l.get_line_count() > l.get_visible_line_count() or r.end.y > bar.end.y + 1.0:
			problems.append('%s: "%s" is cut short in the top bar' % [when, l.text])


## The map's rectangle on screen.
func _map_rect() -> Rect2:
	return Rect2(main.position, Vector2(World.WIDTH, World.HEIGHT) * main.TILE * main.scale.x)


## The selected building's card is docked in the side panel: not floating, inside its width, off the map.
func _check_card_is_docked(what: String) -> void:
	hud_checks += 1
	var card: Control = main.building_panel
	if card.top_level or not main.side_panel.is_ancestor_of(card):
		problems.append("%s isn't docked in the side panel (a popup?)" % what)
	var rect: Rect2 = card.get_global_rect()
	var side: Rect2 = main.side_panel.get_global_rect()
	if not card.visible or rect.position.x < side.position.x or rect.end.x > side.end.x + 1.0:
		problems.append("%s (%s) isn't inside the side panel (%s)" % [what, rect, side])
	if rect.intersects(_map_rect()):
		problems.append("%s (%s) covers the map (%s)" % [what, rect, _map_rect()])
	var close: Control = card.get_child(0).get_child(0).get_child(2)
	if not close is Button or close.text != "x" or close.size.x < 24.0:
		problems.append("%s has no visible close x" % what)


## Toasts stack: no two overlap, none covers a chip or starts inside the top bar; a sticky one says so.
func _check_toast_stack() -> void:
	var rects: Array = []
	for id in main.toasts.panels:
		var p: Control = main.toasts.panels[id]
		rects.append(p.get_global_rect())
	if rects.size() < 4:
		problems.append("only %d toasts stacked (want 4)" % rects.size())
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				problems.append("toasts %d and %d overlap (%s, %s)" % [i, j, rects[i], rects[j]])
		if rects[i].position.y < main.top_bar.get_global_rect().end.y - 0.5:
			problems.append("toast %d starts inside the top bar" % i)
		if rects[i].end.x > main.get_viewport_rect().size.x - main.SIDE_W:
			problems.append("toast %d runs into the side panel (%s)" % [i, rects[i]])


## Every build card's words fit it: no cut-off, at most two lines under a locked card, nothing with dots.
func _check_build_cards(when: String) -> void:
	hud_checks += 1
	for type in main.bottom_bar.build_buttons:
		var parts: Dictionary = main.bottom_bar.build_buttons[type]
		var card: Control = parts["button"]
		if not card.is_visible_in_tree():
			continue
		for key in ["title", "sub", "why"]:
			var l: Label = parts[key]
			if l.text == "":
				continue
			var font: Font = l.get_theme_font("font")
			var fs: int = l.get_theme_font_size("font_size")
			if l.text.contains("..."):
				problems.append('%s: the %s card says "%s"' % [when, type, l.text])
			var lines := 1
			var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				if w > l.size.x + 0.5:
					problems.append(
						'%s: "%s" is cut off on the %s card (%.0f > %.0f px)' % [when, l.text, type, w, l.size.x]
					)
			else:
				lines = l.get_line_count()
				w = l.size.x
				if lines > 2:
					problems.append('%s: "%s" takes %d lines on the %s card' % [when, l.text, lines, type])
			var end := Vector2(l.position.x + w, l.position.y + lines * font.get_height(fs))
			if end.x > card.size.x or end.y > card.size.y:
				problems.append(
					(
						"%s: the %s text of the %s card runs past the card (to %s of %s)"
						% [when, key, type, end, card.size]
					)
				)
		if (
			parts["pips"].visible
			and not Rect2(Vector2.ZERO, card.size).encloses(Rect2(parts["pips"].position, parts["pips"].size))
		):
			problems.append("%s: the price of the %s card runs past the card" % [when, type])
	for type in ["shard_cairn", "standing_stone"]:
		if (
			main.bottom_bar.build_buttons[type]["button"].is_visible_in_tree()
			and not (
				main.state.town.unlocked(type) or main.state.tech_tree.requirements_met(Data.BUILDINGS[type]["tech"])
			)
		):
			problems.append("%s: the story card %s shows before it is revealed" % [when, type])


func _check_log_opens() -> void:
	hud_checks += 1
	if not main.msg_log.visible:
		problems.append("the message log didn't open")
		return
	if main.msg_log.list.get_child_count() < 1:
		problems.append("the message log is empty")
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(main.msg_log.get_global_rect()):
		problems.append("the message log runs off the window (%s)" % main.msg_log.get_global_rect())
	var found := false
	for l in _labels(main.msg_log):
		found = found or l.text == "Discovered a thing"
	if not found:
		problems.append("the newest message isn't in the log")


## The research board on first open: the Next steps view, the stock strip showing, all inside the window.
func _check_board_open() -> void:
	hud_checks += 1
	var panel = main.tech_panel
	if panel.board.view != "next" and panel.state.tech_tree.researched.size() < panel.WHOLE_BOARD_FROM:
		problems.append("the board didn't open on Next steps")
	if not panel.stock_row.visible or panel.stock_row.get_global_rect().size.y < 8.0:
		problems.append("the stock strip isn't visible while the board is open")
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(panel.get_global_rect()):
		problems.append("the research board runs off the window (%s)" % panel.get_global_rect())
	for l in _labels(panel.stock_row):
		if l.get_global_rect().size.x + 1.0 < l.get_minimum_size().x:
			problems.append("stock strip text is cut off: %s" % l.text)


## Hovering a tech lights it and its direct neighbours only, never the chain beyond.
func _check_board_hover() -> void:
	hud_checks += 1
	var board = main.tech_panel.board
	var probe_tech := "knapping"
	board._set_hover(probe_tech)
	var direct := {probe_tech: true}
	for e in board.lay["edges"]:
		if e["to"] == probe_tech:
			direct[e["from"]] = true
		elif e["from"] == probe_tech:
			direct[e["to"]] = true
	for tech in board.chain:
		if not direct.has(tech):
			problems.append("hovering %s also lit %s, which isn't one step away" % [probe_tech, tech])
	if board.chain.size() < 2:
		problems.append("hovering %s lit nothing around it" % probe_tech)
	board._set_hover("")


func _labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for c in node.get_children():
		out += _labels(c)
	return out


func _finish() -> void:
	if not main.state.won:
		problems.append("the bot didn't reach Bronze Dawn in %d frames" % MAX_FRAMES)
	for p in problems.slice(0, 20):
		printerr("LAYOUT PROBLEM: " + p)
	print(
		(
			"Layout pass: %d frames, %.1f simulated minutes, %d scale changes, %d HUD checks, %d problems"
			% [frame, bot.clock / 60.0, changes, hud_checks, problems.size()]
		)
	)
	quit(1 if not problems.is_empty() else 0)
