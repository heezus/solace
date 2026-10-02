extends SceneTree
## The map view over a long run: the bot plays to Bronze Dawn with the UI refreshing every frame, and the map's
## view (its place between the bars and the zoom) may change only when the window size does (the bars must keep
## steady heights). The view runs edge to edge between the bars and up to the side panel, with the Hearth in it.
## It also checks the HUD's fit, at 1280x800 and after two resizes: the Info panel stays above the bottom bar
## even with a wall of text, a building's details are docked in the Info panel (nothing floats over the map),
## the top bar never runs past the window and none of its text is cut short (also with the food warning and
## starvation showing), toasts stack without overlapping each other or a chip, every chip has a tooltip that names it
## and a sprite, a Hearth's blurb shows once, every build card's text fits it, and the message log opens.
## Run: godot --headless --path . -s tests/tools/layout_pass.gd   (exits 1 on a problem)

const Data = preload("res://scripts/data.gd")
const World = preload("res://scripts/world.gd")
const HoverText = preload("res://scripts/hover_text.gd")
const Hands = preload("res://scripts/hands.gd")
const UiTests = preload("res://tests/ui_tests.gd")
const Ui = preload("res://scripts/ui.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const Autoplay = preload("res://tests/autoplay.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")

const BOT_STEPS_PER_FRAME := 20
const MAX_FRAMES := 9000
const ERA_FRAMES := 520  # frames played on after Bronze Dawn: the land grows, the era-2 bot digs, smelts and pours
const RESIZE_AT := 400  # frame: the window is resized once, and the map must refit
const SHRINK_AT := 450  # frame: and made smaller than the design size
const WALL := "A long line of text that has to wrap onto several lines inside the Info panel. "

var main: Node
var bot: AutoplayBronze
var dawn_frame := -1  # the frame Bronze Dawn was won; the pass plays on from there into the era it opens
var before_growth := {}  # the map view the frame before the land grew east
var grown_frame := -1
var frame := 0
var last_vp := Vector2.ZERO
var last_scale := Vector2.ZERO
var last_pos := Vector2.ZERO
var last_view := Rect2()
var last_bars := Vector2.ZERO
var problems: Array = []
var changes := 0
var first_bars := Vector2.ZERO  # the bars' heights and the map's place on frame 6: they must never change by themselves
var first_pos := Vector2.ZERO
var refit_due := 0  # the frame by which the map must have refit after a resize
var hud_checks := 0  # how many HUD checks ran
var base := {}  # the top bar's height and the map's place before the stress cases
var saved := {}  # the stockpile as it was, put back after them
var row_at: Array = []  # the buildings placed by hand for the badge check
var goals_height := 0.0  # the Goals list's height before a card opens
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
		bot = AutoplayBronze.new()
		bot.attach(main.state)
	if frame > 3 and not frozen:
		for i in BOT_STEPS_PER_FRAME:
			if main.state.won and dawn_frame < 0:
				_dawn()
			if dawn_frame > 0 and (bot.made_bronze() or frame > dawn_frame + ERA_FRAMES):
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
	if dawn_frame > 0:
		_era_two_checks()
	if (dawn_frame > 0 and (bot.made_bronze() or frame > dawn_frame + ERA_FRAMES)) or frame > MAX_FRAMES:
		_finish()
	return false


## Bronze Dawn has just been won: the era begins, and the view of the map is noted to see it stays put as the land opens.
func _dawn() -> void:
	dawn_frame = frame
	bot.begin_era_two()
	before_growth = {"pos": main.position, "scale": main.scale, "view": main.view, "bars": last_bars}


## What the first part of the next era must keep: the banner, the camera and the bars through the growth of the land
## (the map doubles under fog, the view and the HUD must not move), and the board's second tab.
func _era_two_checks() -> void:
	var world = main.state.world
	if grown_frame < 0 and world.is_grown():
		grown_frame = frame
		hud_checks += 1
		if world.width != world.stone_width * 2:
			problems.append("the land grew to %d columns, not twice %d" % [world.width, world.stone_width])
	if grown_frame > 0 and frame in [grown_frame + 2, grown_frame + 40]:
		hud_checks += 1
		var now := {"pos": main.position, "scale": main.scale, "view": main.view}
		for key in ["pos", "scale", "view"]:
			if now[key] != before_growth[key]:
				problems.append(
					"the map's %s went %s -> %s as the land opened east" % [key, before_growth[key], now[key]]
				)
		var bars := Vector2(main.top_bar.size.y, main.bottom_bar.size.y)
		if bars != before_growth["bars"]:
			problems.append("the bars went %s -> %s as the land opened" % [before_growth["bars"], bars])
	if frame == dawn_frame + 3:
		hud_checks += 1
		if (
			not main.banner_shown
			or not main.messages.history.any(func(m): return m["text"].begins_with(Data.ERA_BANNER_TITLE))
		):
			problems.append("Bronze Dawn showed no banner")
		if "win_overlay" in main:
			problems.append("a win overlay is still there: the game goes on after Bronze Dawn")
		var dawn_lines: Array = main.messages.history.filter(
			func(m): return m["text"].to_lower().contains("bronze dawn") or m["text"].contains("land opens")
		)
		if dawn_lines.size() != 1:
			problems.append("the dawn told the player %d times (want one banner): %s" % [dawn_lines.size(), dawn_lines])
	if frame == dawn_frame + 60:
		frozen = true
		main.tech_panel.era_chosen = false
		main.tech_panel.view_chosen = false
		main.tech_panel.visible = true
	if frame == dawn_frame + 62:
		_check_era_board()
		main.tech_panel.visible = false
		frozen = false
	if frame == dawn_frame + 70:
		_check_east_pointer()
	if frame > dawn_frame + 6 and frame % 25 == 0:
		_check_top_bar_text("in the second era, frame %d" % frame)
		_check_fit("in the second era, frame %d" % frame)


## The research board after Bronze Dawn opens on the second era, with its tab, its 16 cards and the locked ones saying so.
func _check_era_board() -> void:
	hud_checks += 1
	var panel = main.tech_panel
	if panel.board.era != 2 or panel.era_buttons[2].disabled or not panel.era_buttons[2].button_pressed:
		problems.append("the research board didn't open on the second era's tab after Bronze Dawn")
	if not Rect2(Vector2.ZERO, main.get_viewport_rect().size).encloses(panel.get_global_rect()):
		problems.append("the research board runs off the window (%s)" % panel.get_global_rect())
	for e in panel.era_buttons:
		var tab: Control = panel.era_buttons[e]
		if tab.get_global_rect().size.x + 1.0 < tab.get_minimum_size().x:
			problems.append("the era tab %s is cut off" % tab.text)
	_check_min_text("with the second era's board open")
	panel._pick_view("all")
	var locked := 0
	for tech in Data.TECH_ORDER:
		if Data.TECHS[tech].get("era", 1) == 2 and not panel.board.shows(tech):
			problems.append("%s has no card on the second board" % tech)
		if Data.TECHS[tech].get("stage", 1) > Data.BUILT_STAGE:
			locked += 1
	if locked != 0:
		problems.append("the second board has %d techs for the next update, not none" % locked)


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
	var view_changed: bool = main.view != last_view
	if view_changed and last_view.size != Vector2.ZERO and vp == last_vp and refit_due == 0:
		problems.append(
			"frame %d: the map view went %s -> %s with the window unchanged" % [frame, last_view, main.view]
		)
	last_view = main.view
	_check_view(frame)
	if frame == 6:
		if bars.x != main.top_bar.BAR_H:
			problems.append("the top bar is %.0f tall, not the %.0f it reserves" % [bars.x, main.top_bar.BAR_H])
		first_bars = bars
		first_pos = main.position
	elif frame < RESIZE_AT and first_bars != Vector2.ZERO and (bars != first_bars or main.position != first_pos):
		problems.append(
			(
				"frame %d: the bars went %s -> %s and the map moved %s -> %s with the window unchanged"
				% [frame, first_bars, bars, first_pos, main.position]
			)
		)
		first_bars = bars  # report each shift once
		first_pos = main.position
	if last_vp != Vector2.ZERO and vp != last_vp:
		refit_due = frame + 2
	# Refit: the map moved or rescaled, or its view took the new window's size (a map held at its left edge stays put).
	if refit_due > 0 and (main.scale != last_scale or main.position != last_pos or view_changed):
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
		7:
			goals_height = _goals_height()
		8:
			frozen = true
			_show_hearth_panel()
		10:
			if _goals_height() != goals_height:
				problems.append(
					(
						"the Goals list went %.0f -> %.0f px tall when the Info card opened"
						% [goals_height, _goals_height()]
					)
				)
			_check_hearth_blurb_once()
			_check_empty_tile_info()
			_check_card_is_docked("the Hearth's card")
			main.building_panel.select(Vector2i(-1, -1))
			main._toast("A toast that must not cover the chips", 30.0)
			main._toast("A second toast, stacked under the first, not over it", 30.0)
			main.messages.push("A third that stays until it is clicked", 0.0, true)
			main.messages.push("A fourth: " + WALL, 30.0)
		12:
			_check_min_text("with toasts up")
			_check_toast_and_chips()
			main.messages.active.clear()
			main.messages.changed.emit()
			main.state.economy.low = true
		13:
			_check_the_food_flash()
		14:
			_check_top_bar_text("with the food warning up")
			main.state.economy.starving = true
		16:
			_check_top_bar_text("while starving")
			main.state.economy.starving = false
			main.state.economy.low = false
			frozen = false
		18:
			_craft_a_tool_and_show_every_chip()
		20:
			_check_unchanged("a Flint Tool crafted and every chip showing")
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
			_check_min_text("with the research board open")
			_check_board_open()
			main.tech_panel._pick_view("all")
		62:
			_check_board_hover()
			main.tech_panel.visible = false
			frozen = false
		64:
			frozen = true
			_build_a_row_of_buildings()
		66:
			_check_pills("a row of six adjacent buildings, each blocked")
			for p in row_at:
				main.state.demolish(p)
			row_at.clear()
			frozen = false
	if frame > 5 and frame % 5 == 0:
		_check_fit("at frame %d" % frame)
	if frame > 5 and frame % 20 == 0:
		_check_build_cards("at frame %d" % frame)
	if frame > 5 and frame % 25 == 0:
		_check_top_bar_text("at frame %d" % frame)
	if frame > 5 and frame % 10 == 0 and not frozen:
		_check_pills("at frame %d" % frame)


## Playtest 4: the top bar grew 99 -> 104 px and the map shifted 2 px the first time the Tools chip showed. Craft a Flint
## Tool and show every chip: the bars' heights and the map's place must stay what they were on frame 6.
func _craft_a_tool_and_show_every_chip() -> void:
	var s = main.state
	for id in ["flint", "wood", "stone"]:
		s.economy.add(id, 20)
	if not s.tech_tree.researched.has("knapping"):
		s.research("knapping")
	if not Hands.craft(s, "flint_tools"):
		problems.append("couldn't craft a Flint Tool for the chip check")
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	main.ui_refresh = 0.0


func _check_unchanged(what: String) -> void:
	hud_checks += 1
	var bars := Vector2(main.top_bar.size.y, main.bottom_bar.size.y)
	if not main.top_bar.tools_label.visible:
		problems.append("%s: the Tools chip is not showing" % what)
	if bars != first_bars or main.position != first_pos:
		problems.append(
			(
				"%s: the bars are %s (were %s) and the map is at %s (was %s)"
				% [what, bars, first_bars, main.position, first_pos]
			)
		)


## While the food warning is up the Food block's words stay readable at every phase of the flash (4.5 to 1 on the bar),
## the block itself never fades, and its ring stays visible.
func _check_the_food_flash() -> void:
	hud_checks += 1
	var tb = main.top_bar
	var keep: float = tb.pulse
	for n in 12:
		tb.pulse = n * 0.2
		tb._process(0.0)
		var what := "the food flash at %.1f s" % tb.pulse
		if tb.food_box.modulate.a < 1.0:
			problems.append("%s: the Food block fades (alpha %.2f)" % [what, tb.food_box.modulate.a])
		for label in [tb.food_label, tb.food_sub]:
			var c: float = Ui.contrast(label.get_theme_color("font_color"), Ui.BAR)
			if c < 4.5:
				problems.append('%s: "%s" has a contrast of only %.1f' % [what, label.text, c])
		var ring: Color = tb.food_box.get_theme_stylebox("panel").border_color
		if Ui.contrast(ring, Ui.BAR) < 3.0:
			problems.append("%s: the ring has a contrast of only %.1f" % [what, Ui.contrast(ring, Ui.BAR)])
	tb.pulse = keep


## Playtest 5: "Needs Wood" and "Idle" pills stacked over each other and over the next building in a row of adjacent
## buildings. Place six side by side by hand, each with an alert, and the pills must not overlap (checked in _check_pills).
func _build_a_row_of_buildings() -> void:
	var s = main.state
	s.tech_tree.researched["cordage"] = true
	s.tech_tree.researched["fire"] = true
	for id in s.economy.inv:
		if int(Data.ITEMS[id].get("era", 1)) == 1:  # the second era's goods are the bot's to make
			s.economy.inv[id] = maxi(s.economy.inv[id], 100)
	var spot := Vector2i(-1, -1)
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
			var ok := spot.x < 0
			for k in 6:
				ok = ok and s.town.placement_error("twine_post", p + Vector2i(k, 0)) == ""
			if ok:
				spot = p
	if spot.x < 0:
		problems.append("no room for a row of buildings for the badge check")
		return
	var alerts := [
		"Needs Wood", "Idle: no free Kith", "Needs Wood", "Hungry: no food", "Needs road", "Idle: no free Kith"
	]
	for k in 6:
		var p := spot + Vector2i(k, 0)
		if s.place("twine_post" if k % 2 == 0 else "charcoal_pit", p):
			row_at.append(p)
			s.town.buildings[s.town.building_at[p]]["alert"] = alerts[k]
	main.ui_refresh = 999.0


## No alert badge leaves its tile, overlaps another badge or sits under a click badge.
func _check_pills(what: String) -> void:
	hud_checks += 1
	for line in UiTests.badge_problems(main.state).slice(0, 3):
		problems.append("%s: %s" % [what, line])


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
		# food stays as it is: a big pantry with no income would stop the bot growing
		if not Data.FOOD_VALUE.has(id) and int(Data.ITEMS[id].get("era", 1)) == 1:
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


## The lasting pointer at the east edge: shown while there is ore to look for out of view, inside the map view, in readable
## text, and one press moves the camera east (the Hearth's Home key brings it back).
func _check_east_pointer() -> void:
	hud_checks += 1
	var pointer = main.east_pointer
	if pointer.target.is_empty():
		return  # both ores are already in sight
	var tile: Vector2i = pointer.target["tile"]
	if main.view.has_point(main.screen_of(tile)):
		if pointer.visible:
			problems.append("the east pointer shows although the ore is in view")
		return
	if not pointer.visible:
		problems.append("no east pointer while the %s is out of view" % pointer.target["ore"])
		return
	if not main.view.encloses(pointer.get_global_rect()):
		problems.append("the east pointer %s runs out of the map view %s" % [pointer.get_global_rect(), main.view])
	if pointer.get_theme_font_size("font_size") < 14 or not pointer.text.begins_with("Look east"):
		problems.append(
			'the east pointer reads "%s" at %d px' % [pointer.text, pointer.get_theme_font_size("font_size")]
		)
	var before: float = main.cam.x
	pointer.pressed.emit()
	main._layout()
	if main.cam.x <= before:
		problems.append("Look east did not move the view east (%.0f -> %.0f)" % [before, main.cam.x])
	main.center_on(main.state.world.camp_pos)  # back to the Hearth, as the Home key does


## Collect and Pause stay on the side panel and above the bottom bar, however tall the card is.
func _check_card_buttons(what: String) -> void:
	hud_checks += 1
	var side: Rect2 = main.side_panel.get_global_rect()
	var bottom: Rect2 = main.bottom_bar.get_global_rect()
	var seen := 0
	for key in ["collect", "pause"]:
		var b: Button = main.building_panel.parts[key]
		if not b.is_visible_in_tree():
			continue
		seen += 1
		var r: Rect2 = b.get_global_rect()
		if r.size.x < 20.0 or r.size.y < 20.0 or not side.encloses(r) or r.end.y > bottom.position.y + 1.0:
			problems.append(
				"%s: the %s button (%s) isn't reachable (side panel %s, bottom bar %s)" % [what, key, r, side, bottom]
			)
	if seen < 1:
		problems.append("%s: no card button showed (want Pause)" % what)
	if main.building_panel.parts.has("demolish"):
		problems.append("%s: the card has a second Demolish button (the bottom bar's is the one)" % what)


## How tall the Goals list is: from the top of the side panel to the rule under the last goal line.
func _goals_height() -> float:
	var last: Label = main.side_panel.goal_labels[main.side_panel.goal_labels.size() - 1]
	return last.get_global_rect().end.y - main.side_panel.goal_header.get_global_rect().position.y


func _show_hearth_panel() -> void:
	main.building_panel.select(main.state.world.camp_pos)
	main.ui_refresh = 0.0


## An empty grass tile says more than its name: it can be built on, and what is close by to gather.
func _check_empty_tile_info() -> void:
	hud_checks += 1
	var camp: Vector2i = main.state.world.camp_pos
	var found := false
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var p := camp + Vector2i(dx, dy)
			if found or not main.state.world.in_bounds(p) or main.state.town.building_at.has(p):
				continue
			if main.state.world.tile_at(p) == "grass" and main.state.fog.is_revealed(p):
				main.hover = p
				found = true
	if not found:
		problems.append("no empty grass tile near the Hearth to check the Info text on")
		return
	var info: String = HoverText.text(main)
	if not info.contains(Data.TILES["grass"]["hint"]):
		problems.append("an empty tile's Info text says only: " + info.replace("\n", " / "))
	if info.contains("%s") or info.length() <= Data.TILES["grass"]["name"].length() + 10:
		problems.append("an empty tile's Info text is too thin: " + info)


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


## The map view's rectangle on screen.
func _map_rect() -> Rect2:
	return main.view


## The view is flush: from the left edge to the side panel, from the top bar to the bottom bar, at least 21 tiles
## wide at 1280 px; tiles are 32, 48 or 64 px; the map covers it (or is centred where smaller); the Hearth is in it
## at the start.
func _check_view(at_frame: int) -> void:
	hud_checks += 1
	var v: Rect2 = main.view
	var top: Rect2 = main.top_bar.get_global_rect()
	var bottom: Rect2 = main.bottom_bar.get_global_rect()
	var side: Rect2 = main.side_panel.get_global_rect()
	var vp: Vector2 = main.get_viewport_rect().size
	var settled: bool = at_frame > 8 and main.fit_settle == 0 and main.fit_vp == vp  # not while a resize settles
	if settled and not (is_equal_approx(v.position.x, 0.0) and absf(v.end.x - side.position.x) < 1.5):
		problems.append(
			"frame %d: the map view %s isn't flush with the window edge and the side panel %s" % [at_frame, v, side]
		)
	if settled and (absf(v.position.y - top.end.y) > 1.5 or absf(v.end.y - bottom.position.y) > 1.5):
		problems.append("frame %d: the map view %s isn't flush between the bars (%s, %s)" % [at_frame, v, top, bottom])
	var tile_px: float = main.TILE * main.scale.x
	if tile_px < 31.9 or tile_px > 64.1:
		problems.append("frame %d: tiles are %.1f px (want 32 to 64)" % [at_frame, tile_px])
	var map := Rect2(main.position, Vector2(World.WIDTH, World.HEIGHT) * main.TILE * main.scale.x)
	for axis in 2:
		if (
			map.size[axis] >= v.size[axis]
			and (map.position[axis] > v.position[axis] + 1.0 or map.end[axis] < v.end[axis] - 1.0)
		):
			problems.append("frame %d: the map %s doesn't cover its view %s" % [at_frame, map, v])
			break
	if at_frame == 8 and not v.has_point(main.screen_of(main.state.world.camp_pos)):
		problems.append("the Hearth isn't in the map view at the start")
	if (
		at_frame == 8
		and v.size.x > 1015.0
		and absf(main.get_viewport_rect().size.x - 1280.0) < 1.0
		and v.size.x != 1016.0
	):
		problems.append("the map view is %.0f px wide at 1280 (want 1016)" % v.size.x)


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


## A card's text rows never overlap each other or the sprite, and a missing-items line is plain (no "+1" codes).
func _check_card_text_clear(when: String, type: String, parts: Dictionary, card: Control) -> void:
	var boxes: Array = [Rect2(parts["icon"].position, parts["icon"].size)]
	for key in ["title", "sub", "why"]:
		var l: Label = parts[key]
		if l.text == "":
			continue
		var font: Font = l.get_theme_font("font")
		var fs: int = l.get_theme_font_size("font_size")
		var text_w := minf(font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, l.size.x)
		var lines := l.get_line_count() if l.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
		var box := Rect2(l.position, Vector2(text_w, lines * fs))  # a line is about its font size tall
		if key == "sub" and l.text.contains("+"):
			problems.append('%s: the %s card line "%s" has a "+" code in it' % [when, type, l.text])
		if not Rect2(Vector2.ZERO, card.size).grow(-2.0).encloses(box):
			problems.append("%s: the %s text of the %s card touches the border" % [when, key, type])
		for other in boxes:
			if other.intersects(box):
				problems.append("%s: the %s text of the %s card overlaps other text or the sprite" % [when, key, type])
		boxes.append(box)


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
		_check_card_text_clear(when, type, parts, card)
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


## No label or button on screen is set smaller than 14 px.
func _check_min_text(when: String) -> void:
	hud_checks += 1
	for c in _texts(main):
		var size: int = c.get_theme_font_size("font_size")
		if size < 14:
			problems.append('%s: "%s" is %d px (the minimum is 14)' % [when, c.text, size])


func _texts(node: Node) -> Array:
	var out: Array = []
	if (node is Label or node is Button) and node.is_visible_in_tree() and node.text != "":
		out.append(node)
	for c in node.get_children():
		out += _texts(c)
	return out


func _labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for c in node.get_children():
		out += _labels(c)
	return out


func _finish() -> void:
	if dawn_frame < 0:
		problems.append("the bot didn't reach Bronze Dawn in %d frames" % MAX_FRAMES)
	elif not main.state.world.is_grown():
		problems.append("the land didn't grow east after Bronze Dawn")
	elif not bot.made_bronze():
		problems.append("the era-2 bot made no Bronze in %d frames" % ERA_FRAMES)
	for p in problems.slice(0, 20):
		printerr("LAYOUT PROBLEM: " + p)
	print(
		(
			"Layout pass: %d frames, %.1f simulated minutes, %d scale changes, %d HUD checks, %d problems"
			% [frame, bot.clock / 60.0, changes, hud_checks, problems.size()]
		)
	)
	quit(1 if not problems.is_empty() else 0)
