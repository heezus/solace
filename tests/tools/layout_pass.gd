extends SceneTree
## The map's fit scale over a long run: the bot plays to Bronze Dawn with the UI refreshing every frame,
## and the map's scale may change only when the window size does (the bars must keep steady heights).
## It also checks the HUD's fit, at 1280x800 and after two resizes: the Info panel stays above the bottom bar
## even with a wall of text, a building's popup stays on screen, the top bar never runs past the window and
## none of its text is cut short (also with the food warning and starvation showing), a toast never covers a
## chip, every chip has a name and a tooltip, and a Hearth's blurb shows once.
## Run: godot --headless --path . -s tests/tools/layout_pass.gd   (exits 1 on a problem)

const Data = preload("res://scripts/data.gd")
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
			main.building_panel.select(Vector2i(-1, -1))
			main._toast("A toast that must not cover the chips", 30.0)
		12:
			_check_toast_and_chips()
			main.toast_time = 0.0
			main.state.economy.low = true
		14:
			_check_top_bar_text("with the food warning up")
			main.state.economy.starving = true
		16:
			_check_top_bar_text("while starving")
			main.state.economy.starving = false
			main.state.economy.low = false
			frozen = false
		20:
			frozen = true
			main.ui_refresh = 999.0
			main.info_label.text = WALL.repeat(40)  # far more than fits
		22:
			_check_fit("with a wall of text in the Info panel")
			main.ui_refresh = 0.0
			frozen = false
	if frame > 5 and frame % 5 == 0:
		_check_fit("at frame %d" % frame)
	if frame > 5 and frame % 25 == 0:
		_check_top_bar_text("at frame %d" % frame)


func _show_hearth_panel() -> void:
	main.building_panel.select(main.state.world.camp_pos)
	main.ui_refresh = 0.0


## Clicking the Hearth: its blurb is on screen once, across its popup and the Info panel.
func _check_hearth_blurb_once() -> void:
	hud_checks += 1
	var blurb: String = Data.BUILDINGS["camp"]["desc"]
	main.hover = main.state.world.camp_pos
	var texts: Array = [main._hover_text()]
	for key in ["status", "desc"]:
		if main.building_panel.parts[key].visible:
			texts.append(main.building_panel.parts[key].text)
	var n := 0
	for text in texts:
		n += String(text).count(blurb)
	if n != 1:
		problems.append("the Hearth's blurb shows %d times across its popup and the Info panel (want 1)" % n)


## A toast sits below the top bar, clear of every chip; every chip has a name and a tooltip.
func _check_toast_and_chips() -> void:
	hud_checks += 1
	var toast: Rect2 = main.toast_label.get_global_rect()
	var bar: Rect2 = main.top_bar.get_global_rect()
	if toast.position.y < bar.end.y - 0.5:
		problems.append("the toast (%s) starts inside the top bar (%s)" % [toast, bar])
	for id in main.top_bar.chips:
		var c: Dictionary = main.top_bar.chips[id]
		if c["box"].visible and toast.intersects(c["box"].get_global_rect()):
			problems.append("the toast covers the %s chip" % id)
		if c["box"].tooltip_text == "":
			problems.append("the %s chip has no tooltip" % id)
		if c["title"].text == "":
			problems.append("the %s chip has no name" % id)


## The Info panel and the popup stay where they belong, and the top bar stays inside the window.
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
	var panel: Rect2 = main.building_panel.get_global_rect()
	if main.building_panel.visible and not Rect2(Vector2.ZERO, vp).encloses(panel):
		problems.append("%s: the building popup %s runs off the window %s" % [when, panel, vp])


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
