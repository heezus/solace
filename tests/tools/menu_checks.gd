extends RefCounted
## The layout pass's checks of the pause menu and the Chronicle opened from it, at 1280x800, 1512x982 and 1920x1080 (kept apart so
## layout_pass.gd stays under the line limit). `layout` is the pass script (its problems, main, _resize, _shot, size_name).
## The menu fits the window without scrolling or is scrolled, never cut off; the Chronicle covers the whole window (over the goals
## panel and the bars) and none of its text runs outside its panel on any page.

const Profile = preload("res://scripts/profile.gd")

const SIZES := [Vector2i(1280, 800), Vector2i(1512, 982), Vector2i(1920, 1080)]
const PAGES := ["tellings", "lore", "people", "endings"]
const STEP := 16  # frames each size takes
const AT := 100  # frames after Bronze Dawn that the checks start

static var chronicle: Profile  # the profile the book shows: two tellings, an Exodus and a Cataclysm


static func _profile() -> Profile:
	chronicle = Profile.new()
	chronicle.tellings = [
		{
			"run": 1,
			"choices": ["cairn_raised", "hunger_shared"],
			"lean": "neighbours",
			"trust": 30.0,
			"ending": "exodus"
		},
		{"run": 2, "choices": ["hunger_held", "dark_refused"], "lean": "enemies", "trust": 30.0, "ending": "cataclysm"},
	]
	chronicle.runs = 2
	chronicle.chronicle = ["lumen_arrived", "bloom_seen", "name_read", "ship_read", "ending_exodus", "ending_cataclysm"]
	chronicle.marks = ["g_star", "g_come", "g_kin", "g_ship", "g_kin_old", "g_home_old"]
	return chronicle


## Do the step of frame `since_dawn` (since Bronze Dawn): resize the window, open the menu, then the book on each page, and check each.
static func step(layout, since_dawn: int) -> void:
	var at := since_dawn - AT
	if layout.dawn_frame < 0 or at < 0 or at > STEP * SIZES.size():
		return
	var main: Node = layout.main
	var menu = main.game_menu
	if at == 0:
		layout.frozen = true  # the bot waits while the menus are looked at
	if at == STEP * SIZES.size():
		layout._resize(Vector2i(1280, 800))  # and the rest of the pass is at the size it expects
		main.paused = false
		layout.frozen = false
		return
	var size_at := floori(at / float(STEP))
	if size_at >= SIZES.size():
		return
	match at % STEP:
		0:
			layout._resize(SIZES[size_at])
		4:
			menu.open()
		7:
			layout.hud_checks += 1
			layout.problems.append_array(pause_menu(main, layout.size_name()))
			layout._shot("pause_menu_" + layout.size_name())
			menu.book.open(_profile(), "tellings")  # as the menu's "The Chronicle" button does: the menu stays up behind it
		9, 11, 13, 15:
			var done := floori((at % STEP - 9) / 2.0)
			layout.hud_checks += 1
			layout.problems.append_array(book(main, PAGES[done], layout.size_name()))
			layout._shot("chronicle_%s_%s" % [PAGES[done], layout.size_name()])
			if at % STEP < 15:
				menu.book.show_page(PAGES[done + 1])
			else:
				menu.book.close()
				menu.close()


## The pause menu's card sits inside the window and its whole column is in view (or in the scroll that holds it).
static func pause_menu(main: Node, when: String) -> Array:
	var problems := []
	var pause = main.game_menu.menu
	var window := Rect2(Vector2.ZERO, main.get_viewport_rect().size)
	if not pause.visible:
		return ["%s: the pause menu isn't up" % when]
	var scroll: ScrollContainer = pause.scroll
	if not window.encloses(scroll.get_global_rect()):
		problems.append("%s: the pause menu runs off the window (%s in %s)" % [when, scroll.get_global_rect(), window])
	var column: Rect2 = pause.v.get_global_rect()
	if column.size.y > scroll.get_global_rect().size.y + 1.0:
		var bar := scroll.get_v_scroll_bar()
		if not bar.visible:
			problems.append("%s: the pause menu is cut off and does not scroll" % when)
	for b in pause.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.get_global_rect().size.x + 1.0 < b.get_minimum_size().x:
			problems.append("%s: the button '%s' is cut short" % [when, b.text])
	return problems


## The Chronicle covers the whole window, dimmed, over the side panel and the bars; its page stays inside its panel.
static func book(main: Node, page: String, when: String) -> Array:
	var problems := []
	var book_view = main.game_menu.book
	var window := Rect2(Vector2.ZERO, main.get_viewport_rect().size)
	if not book_view.visible or book_view.page != page:
		return ["%s: the Chronicle's %s page isn't up" % [when, page]]
	if book_view.get_global_rect() != window:
		problems.append(
			"%s: the Chronicle covers %s, not the whole window %s" % [when, book_view.get_global_rect(), window]
		)
	var scroll: ScrollContainer = book_view._pages[page]
	var panel := scroll.get_global_rect()
	if not window.encloses(panel):
		problems.append("%s: the Chronicle's %s page runs off the window (%s)" % [when, page, panel])
	for c in scroll.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or (c is Label and c.text == ""):
			continue
		var rect: Rect2 = c.get_global_rect()
		if (c is Label or c is Button or c is RichTextLabel) and not panel.grow(1.0).intersects(rect):
			continue  # scrolled out of sight inside its page, which is fine
		if c is Label and rect.end.x > panel.end.x + 1.0 and not scroll.get_h_scroll_bar().visible:
			problems.append("%s: '%s' on the %s page runs past its panel (%s)" % [when, c.text.left(30), page, rect])
			break
	var side: Control = main.side_panel
	if side.visible and not book_view.get_global_rect().encloses(side.get_global_rect()):
		problems.append("%s: the goals panel is not under the Chronicle" % when)
	return problems
