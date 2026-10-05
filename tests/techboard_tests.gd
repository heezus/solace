extends RefCounted
## The research board: it fits its window whole and stays in reach while it is panned and zoomed, "What to learn next"
## shows only what can be discovered now with one tech marked Suggested (and the rule picks the right one in a known
## state), what is locked says what it waits for, and the words are plain.
## Run from tests/run_tests.gd, which owns check() and fresh(). The layout pass (tests/tools/layout_pass.gd) checks the
## same board at 1280x800 and 1100x700 in the real window.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const TechBoard = preload("res://scripts/tech_board.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const TechNext = preload("res://scripts/tech_next.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")

## The room the board gets under the panel's header and above its strip. The window's canvas is never under 1280x800
## (the stretch mode grows the longer side of a smaller or odd-shaped window), which leaves the board about 1240x485.
## ROOM_TIGHT is a tighter room than any window gives, to show the fit still holds.
const ROOM_WIDE := Vector2(1240.0, 480.0)
const ROOM_TIGHT := Vector2(1100.0, 400.0)
const READABLE_WIDE := 0.88  # the least zoom the fit may need in each, so the names stay readable
const READABLE_TIGHT := 0.7

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_board_is_fitted_whole_in_each_window()
	test_zoom_and_pan_never_lose_the_board()
	test_the_view_follows_the_window_and_the_era()
	test_the_suggested_tech_follows_its_rule()
	test_locked_techs_say_what_they_wait_for()
	test_the_panel_opens_on_what_to_learn_next()
	test_the_panel_never_asks_for_more_room_than_the_window_has()
	test_a_next_card_discovers_or_queues()
	test_the_words_are_plain()
	test_focus_and_names_stay_readable()
	test_inspector_has_a_fixed_height_with_long_details()


func _board(s: Sim, room: Vector2, era := 1) -> TechBoard:
	var board := TechBoard.new()
	board.setup(s)
	board.set_era(era)
	board.size = room
	board.fit(true)
	return board


## The board cannot be lost: along each axis it either covers the room or, when smaller, sits inside it.
func _in_reach(r: Rect2, room: Vector2) -> bool:
	for axis in 2:
		if r.size[axis] <= room[axis] + 0.5:
			if r.position[axis] < -0.5 or r.end[axis] > room[axis] + 0.5:
				return false
		elif r.position[axis] > 0.5 or r.end[axis] < room[axis] - 0.5:
			return false
	return true


func _inside(r: Rect2, room: Vector2) -> bool:
	return Rect2(Vector2(-0.5, -0.5), room + Vector2.ONE).encloses(r)


# --- Fit, zoom and pan -------------------------------------------------------


func test_the_board_is_fitted_whole_in_each_window() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	for room in [ROOM_WIDE, ROOM_TIGHT]:
		for era in [1, 2]:
			var era_board := _board(s, room, era)
			var where := "era %d in %s" % [era, room]
			t.check(era_board.fitted, "the board opens fitted: " + where)
			t.check(
				_inside(era_board.board_screen_rect(), room),
				"the fitted board is inside its room: %s (%s)" % [where, era_board.board_screen_rect()]
			)
			t.check(is_equal_approx(era_board.zoom, era_board.min_zoom()), "the fit is the smallest zoom: " + where)
			var floor_zoom := READABLE_WIDE if room == ROOM_WIDE else READABLE_TIGHT
			t.check(
				era_board.zoom >= floor_zoom,
				"the fit keeps names readable (%.2f < %.2f): %s" % [era_board.zoom, floor_zoom, where]
			)
			for tech in Rules.era_techs(era):
				t.check(_inside(era_board.card_screen_rect(tech), room), "%s's card is in view: %s" % [tech, where])
			era_board.free()
	# The fit leaves a small board alone rather than blowing it up, and never divides by an empty room.
	var tiny := TechBoard.fit_for(Vector2(100, 50), Vector2(2000, 1000))
	t.check(tiny["zoom"] <= TechBoard.MAX_FIT, "a small board is not blown up past %.1f" % TechBoard.MAX_FIT)
	t.check(TechBoard.fit_for(Vector2(1290, 522), Vector2.ZERO)["zoom"] == 1.0, "an empty room gives a plain zoom of 1")
	# A name never draws under the smallest label size.
	var board := _board(s, ROOM_TIGHT)
	t.check(board._px(TechBoard.NAME_PX) >= TechBoard.MIN_PX, "a name is never drawn under %d px" % TechBoard.MIN_PX)
	board.free()


func test_zoom_and_pan_never_lose_the_board() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	var board := _board(s, ROOM_WIDE)
	var middle := ROOM_WIDE / 2.0
	var fit_zoom := board.zoom
	# Zooming about a point keeps the board point under it.
	var at := board.to_board(middle)
	board.zoom_at(1.2, middle)
	board.settle()
	t.check(board.zoom > fit_zoom, "the wheel zooms in")
	t.check(board.to_screen(at).distance_to(middle) < 1.5, "the point under the pointer stays under it")
	t.check(not board.fitted, "a zoomed board is no longer the fit")
	for i in 30:
		board.zoom_at(1.2, Vector2(i * 37 % 1240, i * 53 % 480))
	board.settle()
	t.check(board.zoom <= TechBoard.MAX_ZOOM + 0.001, "zoom stops at %.1f (%.2f)" % [TechBoard.MAX_ZOOM, board.zoom])
	# Panned as far as it will go in any direction, the board still covers the room: it cannot be lost.
	for by in [Vector2(9000, 9000), Vector2(-9000, -9000), Vector2(9000, -9000), Vector2(-9000, 9000)]:
		board.pan_by(by)
		var r := board.board_screen_rect()
		t.check(_in_reach(r, ROOM_WIDE), "panned %s, the board is still in reach: %s" % [by, r])
	for i in 60:
		board.zoom_at(1.0 / 1.2, Vector2(i * 41 % 1240, i * 29 % 480))
	board.settle()
	t.check(is_equal_approx(board.zoom, fit_zoom) and board.fitted, "zooming out stops at the fit (%.2f)" % board.zoom)
	t.check(_inside(board.board_screen_rect(), ROOM_WIDE), "and the whole board is in the room again")
	# Fit snaps back from anywhere.
	board.zoom_at(1.5, Vector2(100, 100))
	board.pan_by(Vector2(-300, -80))
	board.fit(true)
	t.check(is_equal_approx(board.zoom, fit_zoom) and board.fitted, "Fit puts the whole board back in view")
	t.check(board.origin == TechBoard.fit_for(board.lay["size"], ROOM_WIDE)["origin"], "and centres it")
	board.free()


func test_the_view_follows_the_window_and_the_era() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	var board := _board(s, ROOM_WIDE)
	board.size = ROOM_TIGHT
	board._on_resized()
	t.check(board.fitted and _inside(board.board_screen_rect(), ROOM_TIGHT), "a fitted board refits a smaller window")
	board.zoom_at(1.5, ROOM_TIGHT / 2.0)
	board.settle()
	board.size = ROOM_WIDE
	board._on_resized()
	t.check(board.zoom >= board.min_zoom() - 0.001, "a zoomed board keeps its zoom in a new window")
	var r := board.board_screen_rect()
	t.check(_in_reach(r, ROOM_WIDE), "and stays in reach: %s" % r)
	board.set_era(2)
	t.check(board.fitted and board.era == 2, "a new era's board opens fitted")
	t.check(_inside(board.board_screen_rect(), ROOM_WIDE), "and whole in the room")
	board.free()


# --- What to learn next ------------------------------------------------------


func _clear_goals(s: Sim) -> void:
	for g in Data.GOALS:
		s.story.goals_done[g["id"]] = true
	for g in Data.GOALS_ERA2:
		s.story.goals_done[g["id"]] = true


## The Suggested rule in states where the answer is known. First match wins: the queued goal's route, then the Goals
## list's tech's route, then the cheapest the stockpile can pay for, then the one with the least left to gather.
func test_the_suggested_tech_follows_its_rule() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0
	var roots := TechNext.ready_now(s, 1)
	t.check(
		roots.size() == 5 and "knapping" in roots and "foraging" in roots,
		"a new game can discover the five first techs: %s" % [roots]
	)
	# 1. A queued goal wins over everything: Masonry needs Knapping and Fire, and Knapping comes first on the way.
	s.tech_tree.set_goal("masonry")
	var pick := TechNext.suggested(s, roots)
	t.check(pick["tech"] == "knapping", "queued Masonry: its first step is Knapping (%s)" % [pick])
	t.check(pick["why"] == Data.NEXT_WHY_QUEUED_ROUTE % "Masonry", "and it says why: %s" % pick["why"])
	s.tech_tree.set_goal("fire")
	pick = TechNext.suggested(s, roots)
	t.check(
		pick["tech"] == "fire" and pick["why"] == Data.NEXT_WHY_QUEUED, "a queued tech that can be discovered is itself"
	)
	s.tech_tree.clear()
	# 2. With nothing queued, the Goals list: its first tech goal is Knapping, then Gatherer's Hut.
	t.check(
		TechNext.goals_tech(s) == "knapping", "the Goals list first asks for Knapping (%s)" % TechNext.goals_tech(s)
	)
	pick = TechNext.suggested(s, roots)
	t.check(pick["tech"] == "knapping" and pick["why"] == Data.NEXT_WHY_LIST, "so Knapping is suggested: %s" % [pick])
	s.story.goals_done["knapping"] = true
	s.tech_tree.researched["knapping"] = true
	roots = TechNext.ready_now(s, 1)
	t.check(TechNext.goals_tech(s) == "gatherers_hut", "then Gatherer's Hut")
	pick = TechNext.suggested(s, roots)
	t.check(pick["tech"] == "foraging", "which needs Knapping (known) and Foraging: Foraging is next (%s)" % [pick])
	t.check(
		pick["why"] == Data.NEXT_WHY_LIST_ROUTE % "Gatherer's Hut",
		"and says what it is on the way to: %s" % pick["why"]
	)
	s.tech_tree.researched.erase("knapping")
	roots = TechNext.ready_now(s, 1)
	# 3. With no goals left, the cheapest the stockpile can pay for now (fewest items; Fire and Cordage cost 15 and 15...).
	_clear_goals(s)
	t.check(TechNext.goals_tech(s) == "", "a finished Goals list asks for nothing")
	s.economy.inv["fiber"] = 15
	pick = TechNext.suggested(s, roots)
	t.check(
		pick["tech"] == "cordage" and pick["why"] == Data.NEXT_WHY_CHEAP,
		"only Cordage can be paid for, so it is the pick: %s" % [pick]
	)
	t.give(s, 99)
	pick = TechNext.suggested(s, roots)
	var cheapest := ""
	var least := 99999
	for tech in roots:
		var total := 0
		for id in s.tech_tree.cost_of(tech):
			total += int(s.tech_tree.cost_of(tech)[id])
		if total < least or (total == least and Data.TECH_ORDER.find(tech) < Data.TECH_ORDER.find(cheapest)):
			least = total
			cheapest = tech
	t.check(
		pick["tech"] == cheapest, "with everything paid for the cheapest wins: %s, not %s" % [pick["tech"], cheapest]
	)
	t.check(
		pick["tech"] in ["foraging", "knapping", "cordage", "fire"],
		"and it is one of the 15-item techs (%s)" % pick["tech"]
	)
	# 4. Nothing can be paid for: the one with the least still to gather.
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0
	s.economy.inv["berries"] = 5
	s.economy.inv["fiber"] = 5
	pick = TechNext.suggested(s, roots)
	t.check(
		pick["tech"] == "foraging" and pick["why"] == Data.NEXT_WHY_CLOSE,
		"Foraging needs only 5 more Fiber: %s" % [pick]
	)
	t.check(TechNext.suggested(s, []).is_empty(), "nothing to suggest when nothing can be discovered")
	# A route tech that is not ready is passed over: the pick is always one that can be discovered now.
	s.tech_tree.set_goal("water_wheel")
	pick = TechNext.suggested(s, roots)
	t.check(pick["tech"] in roots, "the pick is always among the techs that can be discovered now: %s" % [pick])


func test_locked_techs_say_what_they_wait_for() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	var ready := TechNext.ready_now(s, 1)
	var behind := TechNext.locked_behind(s, 1, ready)
	t.check(
		"masonry" in behind and "gatherers_hut" in behind and "stone_axe" in behind,
		"the techs just behind: %s" % [behind]
	)
	t.check(not "water_wheel" in behind and not "storehouse" in behind, "a tech two steps behind is not listed")
	t.check(not "star_lore" in behind, "a hidden tech is not listed before the Strange Stone is seen")
	for tech in behind:
		t.check(not tech in ready and not s.tech_tree.requirements_met(tech), "%s is locked" % tech)
		t.check(TechNext.needs_text(s, tech) != "", "%s says what it waits for" % tech)
	t.check(
		TechNext.needs_text(s, "masonry") == "Knapping and Fire",
		"Masonry waits for Knapping and Fire: %s" % TechNext.needs_text(s, "masonry")
	)
	s.tech_tree.researched["knapping"] = true
	t.check(TechNext.needs_text(s, "masonry") == "Fire", "and only Fire once Knapping is known")
	# An either-or reads as one of two, and a parent that is done ends it.
	t.check(
		TechNext.needs_text(s, "calendar") == "Farming and one of Megaliths or Storytelling",
		"Calendar: %s" % TechNext.needs_text(s, "calendar")
	)
	s.tech_tree.researched["storytelling"] = true
	t.check(
		TechNext.needs_text(s, "calendar") == "Farming",
		"Storytelling ends the either-or: %s" % TechNext.needs_text(s, "calendar")
	)
	t.check(
		TechNext.short_text(s, "knapping") != "" and TechNext.short_text(s, "knapping").begins_with("need") == false,
		"what is short is said without 'need'"
	)


func _labels(node: Node) -> Array:
	var out: Array = []
	if node is Label or node is Button:
		out.append(node)
	for c in node.get_children():
		out += _labels(c)
	return out


func _texts(node: Node) -> Array:
	return _labels(node).map(func(l): return l.text)


func test_the_panel_opens_on_what_to_learn_next() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0
	s.economy.inv["wood"] = 12
	s.economy.inv["stone"] = 10
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel._on_open()
	var next_view = panel.next_view
	t.check(panel.view == "next" and next_view.visible and not panel.board.visible, "it opens on What to learn next")
	t.check(
		panel.view_buttons["next"].text == "What to learn next" and panel.view_buttons["next"].button_pressed,
		"the toggle says so"
	)
	t.check(
		panel.view_buttons["all"].text == "Whole board" and not panel.view_buttons["all"].button_pressed,
		"and offers the whole board"
	)
	t.check(panel.explain.text == Data.EXPLAIN_NEXT and panel.explain.text != "", "with a line explaining the view")
	t.check(not panel.detail.visible, "the hover strip is only for the whole board")
	var ready := TechNext.ready_now(s, 1)
	t.check(
		next_view.cards.keys().size() == ready.size(),
		"one card per tech that can be discovered now (%d)" % next_view.cards.size()
	)
	for tech in ready:
		t.check(next_view.cards.has(tech), "%s has a card" % tech)
	for tech in next_view.cards:
		t.check(s.tech_tree.requirements_met(tech), "%s only shows if everything it needs is known" % tech)
	t.check(not next_view.cards.has("masonry"), "a locked tech has no card")
	# Exactly one card is Suggested, and it is the rule's pick.
	var badges := _texts(next_view).filter(func(x): return x == Data.NEXT_SUGGESTED)
	t.check(badges.size() == 1, "one Suggested badge (%d)" % badges.size())
	var pick := TechNext.suggested(s, ready)
	t.check(
		next_view.suggested == pick["tech"] and pick["tech"] == "knapping",
		"and it is Knapping, the Goals list's first tech (%s)" % next_view.suggested
	)
	t.check(_texts(next_view.cards["knapping"]).has(pick["why"]), "the Suggested card says why")
	# A card: the sentence about what it unlocks, the price in words with have of need, and what is short.
	var knapping := _texts(next_view.cards["knapping"])
	t.check(
		knapping.has(Data.NEXT_UNLOCKS % Data.TECH_BLURBS["knapping"]), "a card says what it unlocks: %s" % [knapping]
	)
	t.check(
		knapping.has(Data.NEXT_COST_ITEM % ["Flint", 0, 5]) and knapping.has(Data.NEXT_COST_ITEM % ["Stone", 10, 10]),
		"and what you have of what it costs: %s" % [knapping]
	)
	t.check(knapping.has(Data.NEXT_SHORT % "5 Flint"), "and what is still short: %s" % [knapping])
	t.check(
		(
			_texts(next_view.cards["fire"]).has(Data.NEXT_SHORT % "10 Wood")
			or _texts(next_view.cards["fire"]).has(Data.NEXT_ENOUGH)
		),
		"another card says its own: %s" % [_texts(next_view.cards["fire"])]
	)
	# Under the cards, what is locked behind them, each with a "needs X first" line.
	var masonry := _texts(next_view.rows["masonry"])
	t.check(masonry.has(Data.LOCKED_NEEDS % "Knapping and Fire"), "Masonry says what it needs first: %s" % [masonry])
	t.check(_texts(next_view).has(Data.LOCKED_HEADING), "the locked ones have their own heading")
	t.check(next_view.rows.size() <= TechNext.MAX_LOCKED, "at most %d locked ones are listed" % TechNext.MAX_LOCKED)
	# Everything on the next view is at least 14 px.
	for l in _labels(next_view):
		t.check(
			l.get_theme_font_size("font_size") >= Ui.MIN_TEXT,
			"'%s' is %d px" % [l.text, l.get_theme_font_size("font_size")]
		)
	# The toggle swaps the views, and the whole board has its own line and its zoom buttons.
	panel._pick_view("all")
	t.check(panel.board.visible and not next_view.visible and panel.view == "all", "the toggle opens the whole board")
	t.check(panel.explain.text.contains("Brass") and panel.detail.visible, "with its own line and strip")
	t.check(panel.board_buttons.all(func(b): return b.visible), "and its Fit and zoom buttons")
	panel._pick_view("next")
	t.check(next_view.visible and not panel.board.visible and not panel.board_buttons[0].visible, "and back")
	# Closing and opening again keeps the view the player chose.
	panel._pick_view("all")
	panel._on_open()
	t.check(panel.view == "all", "the panel keeps the view the player picked")
	panel.free()


## The layout pass found the panel 1548 px wide in a 1280 window: with every good seen and a long queue, the stock
## line asked for more room than the window has. The panel's smallest size, in both views and eras, must fit the
## smallest canvas (1280x800 less the panel's 8 px insets). The layout pass checks the real laid-out board.
func test_the_panel_never_asks_for_more_room_than_the_window_has() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	t.give(s, 500)
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	s.tech_tree.researched["bronze_dawn"] = true
	s.shard_seen = true
	var window := Vector2(1264.0, 784.0)
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel._on_open()
	for goal in ["", "bronze_dawn", "falling_star"]:
		for era in [1, 2]:
			s.tech_tree.clear()
			if goal != "":
				s.tech_tree.researched.erase(goal)
				s.tech_tree.set_goal(goal)
			panel._pick_era(era)
			for view in ["next", "all"]:
				panel._pick_view(view)
				var where := "goal %s, era %d, %s view" % [goal, era, view]
				var least := panel.get_combined_minimum_size()
				t.check(
					least.x <= window.x,
					"the panel asks for %.0f px of width, the window has %.0f: %s" % [least.x, window.x, where]
				)
				t.check(
					least.y <= window.y,
					"the panel asks for %.0f px of height, the window has %.0f: %s" % [least.y, window.y, where]
				)
				t.check(panel.board.get_combined_minimum_size().x == 0.0, "the board imposes no width: " + where)
	panel.free()


func test_a_next_card_discovers_or_queues() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0
	s.economy.inv["fiber"] = 15
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel._on_open()
	var buttons: Array = panel.next_view.cards["cordage"].find_children("*", "Button", true, false)
	t.check(
		buttons.size() == 1 and buttons[0].text == Data.DISCOVER_BUTTON % "Cordage",
		"a card you can pay for offers Discover"
	)
	var other: Array = panel.next_view.cards["fire"].find_children("*", "Button", true, false)
	t.check(other.size() == 1 and other[0].text == Data.NEXT_QUEUE, "one you cannot pay for offers Queue it")
	other[0].pressed.emit()
	t.check(s.tech_tree.goal == "fire", "Queue it makes it the goal")
	t.check(
		panel.next_view.cards["fire"].find_children("*", "Button", true, false)[0].text == Data.QUEUED,
		"and the card says it is queued"
	)
	panel.next_view.cards["cordage"].find_children("*", "Button", true, false)[0].pressed.emit()
	t.check(s.tech_tree.researched.has("cordage"), "Discover discovers it")
	t.check(not panel.next_view.cards.has("cordage"), "and it leaves the list")
	t.check(
		panel.next_view.cards.has("stone_axe") == false and panel.next_view.rows.has("stone_axe"),
		"Stone Axe still waits for Knapping"
	)
	panel.free()


func test_the_words_are_plain() -> void:
	var words: Array = [
		Data.VIEW_NEXT,
		Data.VIEW_ALL,
		Data.VIEW_NEXT_TIP,
		Data.VIEW_ALL_TIP,
		Data.EXPLAIN_NEXT,
		Data.EXPLAIN_ALL,
		Data.NEXT_NONE,
		Data.NEXT_ALL_DONE,
		Data.NEXT_RULE,
		Data.NEXT_WHY_QUEUED,
		Data.NEXT_WHY_LIST,
		Data.NEXT_WHY_CHEAP,
		Data.NEXT_WHY_CLOSE,
		Data.NEXT_COST_HEAD,
		Data.NEXT_ENOUGH,
		Data.LOCKED_HEADING,
		Data.LOCKED_NOTE,
		Data.FIT_TIP,
	]
	words.append_array(Data.TECH_BLURBS.values())
	for w in words:
		t.check(not String(w).to_lower().contains("rank"), "no jargon: " + w)
		t.check(not String(w).to_lower().contains("research"), "one verb, Discover: " + w)
	t.check(Data.VIEW_NEXT == "What to learn next", "the view is titled What to learn next")
	t.check(
		Data.EXPLAIN_NEXT.length() <= 160 and Data.EXPLAIN_ALL.length() <= 160,
		"the explanation lines are one line long"
	)


## Selection stays after hover ends; inspecting never reveals hidden cards or mutates progression.
func test_focus_and_names_stay_readable() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:  # these tests are about the rules for the cards: every item has been found
		s.economy.seen[id] = true
	var board := _board(s, ROOM_TIGHT)
	board.set_selected("masonry")
	t.check(
		board.focus_tech() == "masonry" and board.chain.has("knapping"), "selected discovery keeps its dependency focus"
	)
	board._set_hover("cordage")
	t.check(board.focus_tech() == "cordage", "hover previews another branch")
	board._set_hover("")
	t.check(board.focus_tech() == "masonry" and board.chain.has("fire"), "leaving hover restores the selected branch")
	board.set_era(2)
	t.check(board.focus_tech() == "" and board.chain.is_empty(), "switching era clears persistent branch focus")
	board.set_era(1)
	board.set_selected("star_lore")
	t.check(board.selected == "" and board.chain.is_empty(), "hidden discovery cannot become presentation focus")
	for name in ["The Falling Star", "Bronze Dawn"]:
		var lines := board.title_lines(name, 85, 14)
		t.check(" ".join(lines) == name, "gate title preserves every word")
		for line in lines:
			t.check(
				board.bold.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 85, "wrapped gate title fits"
			)
	board.fit(true)
	var r := board.card_screen_rect("gatherers_hut")
	var fits := board.card_icon_fits("gatherers_hut", r)
	t.check(not fits, "a long fitted name gets the icon's room")
	board.free()
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel._pick_view("all")
	var known := s.tech_tree.researched.duplicate(true)
	var inv := s.economy.inv.duplicate(true)
	panel.board._set_hover("masonry")
	panel.board._set_hover("")
	t.check(panel.shown == "masonry", "inspector stays available while moving to its action")
	t.check(panel.strip["title"].text == "Masonry", "full name has its own inspector heading")
	t.check(
		panel.strip["state"].text != "" and panel.strip["icon"].texture != null,
		"inspector separates state and illustration"
	)
	t.check(
		s.tech_tree.researched == known and s.economy.inv == inv and s.tech_tree.queue.is_empty(),
		"inspection changes no purchases or queue"
	)
	var prices: HFlowContainer = panel.strip["prices"]
	t.check(prices.get_child_count() == s.tech_tree.cost_of("masonry").size(), "research displays each cost symbol")
	for price in prices.get_children():
		var icon: Control = price.get_child(0).get_child(0)
		t.check(
			"have" in icon.tooltip_text and "need" in icon.tooltip_text, "price symbols identify stock and requirement"
		)
	panel.free()


## Expanded explanations must scroll inside the inspector rather than refitting the board.
func test_inspector_has_a_fixed_height_with_long_details() -> void:
	var s: Sim = t.fresh()
	t.give(s, 500)
	s.shard_seen = true
	s.tech_tree.researched["bronze_dawn"] = true
	var panel := TechPanel.new()
	panel.setup(s)
	panel.visible = true
	panel._pick_view("all")
	for tech in Data.TECH_ORDER:
		for parent in Data.TECHS[tech]["requires"]:
			s.tech_tree.researched[parent] = true
		panel._pick_era(Data.TECHS[tech].get("era", 1))
		panel.board._set_hover(tech)
		panel.refresh()
		t.check(
			panel.detail.get_combined_minimum_size().y == TechPanel.STRIP_H,
			"inspector retains its fixed minimum: " + tech
		)
	panel.free()
