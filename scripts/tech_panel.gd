extends PanelContainer
## The tech panel: a header with the counter, the two views and the board's zoom buttons, a line saying what the view
## shows, the stock strip (what you have, so nothing needs closing to check), and then one of two views. "What to
## learn next" (the one it opens on) is a few cards, one per tech that can be discovered now, with the suggested one
## marked. "Whole board" is the fitted tech board, with the queue, the techs ready now and a strip about the tech under
## the mouse. Click a ready card to discover it. Click any other card to make it the goal: the techs it still needs
## are queued and discovered as soon as each is affordable. The panel keeps the era and view the player picks.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const TechBoard = preload("res://scripts/tech_board.gd")
const TechNextView = preload("res://scripts/tech_next_view.gd")
const Ranks = preload("res://scripts/ranks.gd")

const BG := Ui.PANEL
const STRIP_H := 170.0  # the strip about one tech: always this tall
const STRIP_SIDE_W := 330.0  # its right column: needs, leads to, route

var state: Sim
var board: TechBoard
var next_view: TechNextView
var view := "next"  # "next": What to learn next; "all": the whole board
var counter: Label
var title: Label
var era_buttons := {}  # era -> its tab
var era_chosen := false  # the player picked an era tab: the panel keeps it from then on
var queue_row: HBoxContainer
var stock_row: HBoxContainer
var stock_chips := {}  # item -> {"box", "count"}
var view_buttons := {}
var explain: Label  # one line on what the view shows
var board_buttons: Array = []  # Fit, zoom in and out: only the whole board has a view to move
var detail: PanelContainer  # the strip about one tech
var view_chosen := false  # the player picked a view: the panel keeps it from then on
var strip := {}
var shown := ""  # the tech in the strip, "" for the frontier
var rows_key := ""  # what the queue and ready rows show, so they're only rebuilt when it changes
var selected := ""


func setup(game: Sim) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.panel_style(BG, 12))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 8
	offset_top = 8
	offset_right = -8
	offset_bottom = -8
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var head := HFlowContainer.new()  # wraps onto a second line in a narrow window
	head.add_theme_constant_override("h_separation", 14)
	title = Ui.label(Data.BOARD_TITLE % Data.ERAS[1]["name"], 22)
	head.add_child(title)
	for e in Data.ERAS:  # a tab per era
		var tab := Ui.button(Data.ERAS[e]["name"])
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 26)
		var which: int = e
		tab.pressed.connect(func(): _pick_era(which))
		head.add_child(tab)
		era_buttons[e] = tab
	counter = Ui.label("", Ui.MIN_TEXT)
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counter.add_theme_color_override("font_color", Ui.TEXT_DIM)
	head.add_child(counter)
	for part in [["next", Data.VIEW_NEXT, Data.VIEW_NEXT_TIP], ["all", Data.VIEW_ALL, Data.VIEW_ALL_TIP]]:
		var b := Ui.button(part[1])
		b.toggle_mode = true
		b.tooltip_text = part[2]
		b.custom_minimum_size = Vector2(0, 26)
		b.pressed.connect(_pick_view.bind(part[0]))
		head.add_child(b)
		view_buttons[part[0]] = b
	for part in [
		[Data.FIT_BUTTON, Data.FIT_TIP, _fit], ["+", Data.ZOOM_IN_TIP, _zoom_in], ["-", Data.ZOOM_OUT_TIP, _zoom_out]
	]:
		var b := Ui.button(part[0])
		b.tooltip_text = part[1]
		b.custom_minimum_size = Vector2(0, 26)
		b.pressed.connect(part[2])
		head.add_child(b)
		board_buttons.append(b)
	var close := Ui.button("Close (T)")
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	explain = Ui.label("", Ui.MIN_TEXT)
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(explain)

	# What you have, so nothing needs closing to check what you can afford; one line says how the costs read.
	stock_row = HBoxContainer.new()
	stock_row.add_theme_constant_override("separation", 12)
	var stock_cap := Ui.label(Data.STOCK_CAPTION, Ui.MIN_TEXT)
	stock_cap.add_theme_color_override("font_color", Ui.TEXT_DIM)
	stock_row.add_child(stock_cap)
	for id in Data.ITEM_ORDER:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = Data.ITEMS[id]["name"]
		box.add_child(Ui.item_icon(id, 20))
		var count := Ui.label("", 14)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(count)
		stock_row.add_child(box)
		stock_chips[id] = {"box": box, "count": count}
	queue_row = HBoxContainer.new()  # the queue sits at the end of the same line
	queue_row.add_theme_constant_override("separation", 6)
	queue_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_row.add_child(queue_row)
	v.add_child(stock_row)

	next_view = TechNextView.new()
	v.add_child(next_view)
	next_view.setup(state)
	next_view.chosen.connect(_on_card)
	board = TechBoard.new()
	v.add_child(board)
	board.setup(state)
	board.card_clicked.connect(_on_card)
	board.hover_changed.connect(func(_t): refresh())

	_build_strip(v)
	_apply_view(view)
	visibility_changed.connect(_on_open)


## The strip about one tech, under the board: a fixed height, so hovering never resizes (and so never refits) the board.
## Left, what it is and costs; right, what it needs, leads to and the route there; far right, the one button. A line that
## runs long is trimmed, never allowed to grow the strip.
func _build_strip(parent: VBoxContainer) -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BAR, 10))
	detail.custom_minimum_size = Vector2(0, STRIP_H)
	detail.size_flags_vertical = Control.SIZE_SHRINK_END
	detail.clip_contents = true
	parent.add_child(detail)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	detail.add_child(dh)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	dh.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(STRIP_SIDE_W, 0)
	right.add_theme_constant_override("separation", 2)
	dh.add_child(right)
	strip["title"] = Ui.label("", 16)
	strip["title"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip["title"].clip_text = true
	left.add_child(strip["title"])
	for part in [
		["desc", left, 2],
		["cost", left, 3],
		["warn", left, 1],
		["needs", right, 2],
		["leads", right, 2],
		["route", right, 3]
	]:
		var l := Ui.label("", Ui.MIN_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = part[2]
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		part[1].add_child(l)
		strip[part[0]] = l
	var act := Ui.button("")
	act.custom_minimum_size = Vector2(200, 44)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.pressed.connect(_on_action)
	dh.add_child(act)
	strip["button"] = act


## Research a ready tech; any other becomes the goal, with its missing chain queued.
func _on_card(tech: String) -> void:
	selected = tech
	if state.tech_tree.can_research(tech):
		state.research(tech)
		state.tech_tree.refill()
	elif state.tech_tree.researched.has(tech):
		Ranks.buy(state, tech)  # a researched card with ranks buys the next one, when affordable
	else:
		state.tech_tree.set_goal(tech)
	refresh()


func _on_action() -> void:
	if shown == "":
		return
	_on_card(shown)


## The player picked an era's tab (one that has opened): from then on the panel keeps it.
func _pick_era(e: int) -> void:
	if not _era_open(e):
		refresh()
		return
	era_chosen = true
	board.set_era(e)
	rows_key = ""
	refresh()


## Era 2's tab opens when Bronze Dawn is discovered.
func _era_open(e: int) -> bool:
	return e == 1 or state.tech_tree.researched.has("bronze_dawn")


## The player picked a view: from then on the panel keeps it.
func _pick_view(which: String) -> void:
	view_chosen = true
	_apply_view(which)
	refresh()


## Show one of the two views: "next" (What to learn next) or "all" (the whole board, with its queue, ready row and strip).
func _apply_view(which: String) -> void:
	view = which
	var whole := view == "all"
	board.visible = whole
	next_view.visible = not whole
	detail.visible = whole
	for b in board_buttons:
		b.visible = whole
	explain.text = Data.EXPLAIN_ALL if whole else Data.EXPLAIN_NEXT
	if not whole:
		board._set_hover("")
	rows_key = ""


## Open on What to learn next, or on the view the player last picked; the board is always fitted when it opens.
func _on_open() -> void:
	if not visible:
		return
	if not era_chosen:
		board.set_era(2 if _era_open(2) else 1)
	if not view_chosen:
		_apply_view("next")
	board.fit(true)
	refresh()


func _fit() -> void:
	board.fit()


func _zoom_in() -> void:
	board.zoom_at(TechBoard.BUTTON_STEP, board.size / 2.0)


func _zoom_out() -> void:
	board.zoom_at(1.0 / TechBoard.BUTTON_STEP, board.size / 2.0)


## F fits the whole board, + and - zoom it, while the whole board is showing.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or view != "all" or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F:
			_fit()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom_in()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_out()
		_:
			return
	get_viewport().set_input_as_handled()


func refresh() -> void:
	if not visible:
		return
	var ready_now := state.tech_tree.ready_list()
	# The count is of this era's board, and leaves out a tech that is still hidden, so it doesn't give it away.
	var mine: Array = Rules.era_techs(board.era)
	var done := mine.filter(func(t): return state.tech_tree.researched.has(t)).size()
	var seen := mine.filter(func(t): return state.tech_tree.tech_visible(t)).size()
	var ready_here := ready_now.filter(func(t): return t in mine).size()
	counter.text = Data.COUNTER % [done, seen, ready_here]
	title.text = Data.BOARD_TITLE % Data.ERAS[board.era]["name"]
	for e in era_buttons:
		var tab: Button = era_buttons[e]
		tab.button_pressed = e == board.era
		tab.disabled = not _era_open(e)
		tab.tooltip_text = Data.ERA_TAB_TIP % Data.ERAS[e]["name"] if _era_open(e) else Data.ERA_TAB_LOCKED
	for which in view_buttons:
		view_buttons[which].button_pressed = which == view
	for id in stock_chips:
		var c: Dictionary = stock_chips[id]
		c["box"].visible = state.economy.seen.has(id)
		c["count"].text = str(state.economy.inv.get(id, 0))
	queue_row.visible = view == "all" or not state.tech_tree.queue.is_empty()  # over the cards, only when it holds something
	var key := "%s|%s|%s" % [state.tech_tree.queue, ready_now, state.tech_tree.goal]
	if key != rows_key:
		rows_key = key
		_fill_queue()
	if view == "next":
		next_view.refresh(board.era)
		return
	shown = board.hovered if board.hovered != "" else selected
	if shown != "" and (not state.tech_tree.tech_visible(shown) or not board.shows(shown)):
		shown = ""
	if shown == "":
		_show_frontier(ready_now)
	else:
		_show_tech(shown)
	board.queue_redraw()


## The queue, on the stock line: its caption, then the techs in order as one line that is trimmed to the room left (the
## line can never widen the panel), with the costs in its tooltip, and Clear when a goal is set.
func _fill_queue() -> void:
	var row := queue_row
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var cap := Ui.label(Data.QUEUE_CAPTION, Ui.MIN_TEXT)
	cap.add_theme_color_override("font_color", Ui.TEXT_DIM)
	row.add_child(cap)
	var techs: Array = state.tech_tree.queue
	var text := Data.QUEUE_EMPTY
	if not techs.is_empty():
		text = " › ".join(techs.map(func(t): return Data.TECHS[t]["name"]))
	var line := Ui.label(text, Ui.MIN_TEXT)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = "\n".join(
		techs.map(func(t): return "%s: %s" % [Data.TECHS[t]["name"], Ui.cost_text(state.tech_tree.cost_of(t))])
	)
	line.add_theme_color_override("font_color", Ui.TEXT_DIM if techs.is_empty() else Ui.TEXT)
	row.add_child(line)
	if state.tech_tree.goal != "":
		var clear := Ui.button("Clear")
		clear.pressed.connect(_clear_queue)
		row.add_child(clear)


func _clear_queue() -> void:
	state.tech_tree.clear()
	refresh()


func _show_frontier(ready_now: Array) -> void:
	var names: Array = ready_now.map(func(t): return Data.TECHS[t]["name"])
	strip["title"].text = Data.STRIP_READY % ", ".join(names) if not names.is_empty() else Data.STRIP_NONE
	strip["title"].add_theme_color_override("font_color", TechBoard.GOLD if not names.is_empty() else Ui.TEXT)
	strip["desc"].text = Data.STRIP_HELP
	strip["cost"].text = Data.RANK_HELP
	strip["warn"].visible = false
	strip["needs"].text = ""
	strip["leads"].text = ""
	strip["route"].text = ""
	strip["button"].visible = false


func _show_tech(tech: String) -> void:
	var t: Dictionary = Data.TECHS[tech]
	var lane: String = Data.LANES[t["lane"]]["name"] if Data.LANES.has(t["lane"]) else "Gate"
	var state_text := Data.STATE_DONE
	if not state.tech_tree.researched.has(tech):
		if not Rules.tech_enabled(tech):
			state_text = Data.TECH_UNBUILT
		elif state.tech_tree.can_research(tech):
			state_text = Data.STATE_READY
		elif state.tech_tree.requirements_met(tech):
			state_text = Data.STATE_MORE
		else:
			state_text = Data.STATE_LOCKED
	var side := "  ·  " + Data.TECH_OPTIONAL if t.get("side", false) else ""
	strip["title"].text = "%s  ·  %s  ·  %s%s" % [t["name"], lane, state_text, side]
	strip["title"].add_theme_color_override("font_color", Ui.TEXT)
	strip["desc"].text = t["desc"]
	var unbuilt := not Rules.tech_enabled(tech)
	strip["cost"].text = (
		Data.TECH_UNBUILT
		if unbuilt
		else "Cost (have/need): " + Ui.progress_text(state.economy.inv, state.tech_tree.cost_of(tech), 99)
	)
	var researched: bool = state.tech_tree.researched.has(tech)
	if not researched and not unbuilt and Ui.then_builds_text(tech) != "":
		strip["cost"].text += "     " + Ui.then_builds_text(tech)
	var warn := (
		""
		if researched or not state.tech_tree.can_research(tech)
		else Ui.build_warning(state.economy.inv, tech, state.tech_tree.cost_of(tech))
	)
	strip["warn"].text = warn
	strip["warn"].visible = warn != ""
	strip["warn"].add_theme_color_override("font_color", Ui.SHORT)
	if Ranks.has_ranks(tech):
		var r := Ranks.rank(state, tech)
		strip["cost"].text += (
			"     " + Data.RANK_LINE % [Ranks.effect_text(tech), Data.RANK_NAMES[r] if r > 0 else Data.RANK_NONE]
		)
		if not Ranks.next_cost(state, tech).is_empty():
			strip["cost"].text += (" · next: " + Ui.progress_text(state.economy.inv, Ranks.next_cost(state, tech), 99))
	strip["needs"].text = "NEEDS: " + _needs_text(tech)
	strip["leads"].text = "LEADS TO: " + _leads_text(tech)
	var route := Rules.route_to(tech, state.tech_tree.researched, Rules.visible_techs(state.shard_seen))
	if route.is_empty() or unbuilt:
		strip["route"].text = ""
	else:
		var names: Array = route.map(func(r): return Data.TECHS[r]["name"])
		var now: Array = (
			route.filter(func(r): return state.tech_tree.can_research(r)).map(func(r): return Data.TECHS[r]["name"])
		)
		strip["route"].text = (
			"YOUR ROUTE: " + " › ".join(names) + ("     Ready now: " + ", ".join(now) if not now.is_empty() else "")
		)
	var b: Button = strip["button"]
	b.visible = not unbuilt and (not researched or not Ranks.next_cost(state, tech).is_empty())
	b.disabled = false
	b.text = Data.DISCOVER_BUTTON % t["name"] if state.tech_tree.can_research(tech) else Data.QUEUE_BUTTON
	if state.tech_tree.goal == tech:
		b.text = Data.QUEUED
	if state.tech_tree.researched.has(tech) and b.visible:
		b.text = "Buy rank %s" % Data.RANK_NAMES[Ranks.rank(state, tech) + 1]
		b.disabled = not Ranks.can_buy(state, tech)


func _needs_text(tech: String) -> String:
	var parts: Array = Data.TECHS[tech]["requires"].map(_need_name)
	var any: Array = (
		Data.TECHS[tech].get("requires_any", []).filter(func(r): return state.tech_tree.tech_visible(r)).map(_need_name)
	)
	if any.size() == 1:
		parts.append(any[0])
	elif any.size() > 1:
		parts.append("one of " + " or ".join(any))
	return ", ".join(parts) if not parts.is_empty() else "nothing, start here"


func _need_name(r: String) -> String:
	return Data.TECHS[r]["name"] + (" (done)" if state.tech_tree.researched.has(r) else "")


func _leads_text(tech: String) -> String:
	var next: Array = []
	for t in Data.TECH_ORDER:
		var d: Dictionary = Data.TECHS[t]
		if state.tech_tree.tech_visible(t) and (tech in d["requires"] or tech in d.get("requires_any", [])):
			next.append(d["name"])
	return ", ".join(next) if not next.is_empty() else "the next era"
