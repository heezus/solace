extends PanelContainer
## The tech panel: a header with the counter, the two views and the legend, the stock strip (what you have, so
## nothing needs closing to check), the queue and the techs ready now, the scrolling board, and a strip about
## the tech under the mouse. Click a ready card to discover it. Click any other card to make it the goal: the
## techs it still needs are queued and discovered as soon as each is affordable.
## It opens on "Next steps", a short grid of what is next, until the player picks the whole board.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const TechBoard = preload("res://scripts/tech_board.gd")
const Ranks = preload("res://scripts/ranks.gd")

const BG := Ui.PANEL
const WHOLE_BOARD_FROM := 8  # techs discovered before the board opens on the whole board by default

var state: Sim
var board: TechBoard
var scroll: ScrollContainer
var counter: Label
var title: Label
var era_buttons := {}  # era -> its tab
var era_chosen := false  # the player picked an era tab: the panel keeps it from then on
var queue_row: HBoxContainer
var ready_row: HBoxContainer
var stock_row: HBoxContainer
var stock_chips := {}  # item -> {"box", "count"}
var view_buttons := {}
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
		var which: String = part[0]
		b.pressed.connect(func(): _pick_view(which))
		head.add_child(b)
		view_buttons[which] = b
	for part in [
		[Data.LEGEND_DONE, TechBoard.MET],
		[Data.LEGEND_NEEDED, TechBoard.NEEDED],
		[Data.LEGEND_HOVER, TechBoard.GOLD],
	]:
		var l := Ui.label("— " + part[0], Ui.MIN_TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_color_override("font_color", part[1])
		head.add_child(l)
	var or_note := Ui.label("or = either parent", Ui.MIN_TEXT)
	or_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(or_note)
	var close := Ui.button("Close (T)")
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)

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
	var cost_note := Ui.label(Data.LEGEND_COST, Ui.MIN_TEXT)
	cost_note.add_theme_color_override("font_color", Ui.TEXT_DIM)
	cost_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stock_row.add_child(cost_note)
	v.add_child(stock_row)

	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	queue_row = HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 6)
	rows.add_child(queue_row)
	ready_row = HBoxContainer.new()
	ready_row.add_theme_constant_override("separation", 6)
	rows.add_child(ready_row)
	v.add_child(rows)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	board = TechBoard.new()
	scroll.add_child(board)
	board.setup(state)
	board.card_clicked.connect(_on_card)
	board.hover_changed.connect(func(_t): refresh())

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BAR, 10))
	detail.custom_minimum_size = Vector2(0, 118)
	v.add_child(detail)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	detail.add_child(dh)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 3)
	dh.add_child(dv)
	strip["title"] = Ui.label("", 16)
	dv.add_child(strip["title"])
	for key in ["desc", "cost", "warn", "links", "route"]:
		var l := Ui.label("", Ui.MIN_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		dv.add_child(l)
		strip[key] = l
	var act := Ui.button("")
	act.custom_minimum_size = Vector2(200, 44)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.pressed.connect(_on_action)
	dh.add_child(act)
	strip["button"] = act
	visibility_changed.connect(_on_open)


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
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	rows_key = ""
	refresh()


## Era 2's tab opens when Bronze Dawn is discovered.
func _era_open(e: int) -> bool:
	return e == 1 or state.tech_tree.researched.has("bronze_dawn")


## The player picked a view: from then on the panel keeps it.
func _pick_view(which: String) -> void:
	view_chosen = true
	board.set_view(which)
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	refresh()


## Open on Next steps (early on) or the whole board scrolled to the frontier: the middle of the techs ready now.
func _on_open() -> void:
	if not visible:
		return
	if not era_chosen:
		board.set_era(2 if _era_open(2) else 1)
	if not view_chosen:
		board.set_view("next" if state.tech_tree.researched.size() < WHOLE_BOARD_FROM else "all")
	refresh()
	if board.view == "next":
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0
		return
	var ready_now := state.tech_tree.ready_list()
	if ready_now.is_empty():
		return
	var c := Vector2.ZERO
	for tech in ready_now:
		c += board.card_rect(tech).get_center()
	c /= ready_now.size()
	await get_tree().process_frame
	scroll.scroll_horizontal = int(c.x - scroll.size.x / 2.0)
	scroll.scroll_vertical = int(c.y - scroll.size.y / 2.0)


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
		view_buttons[which].button_pressed = which == board.view
	for id in stock_chips:
		var c: Dictionary = stock_chips[id]
		c["box"].visible = state.economy.seen.has(id)
		c["count"].text = str(state.economy.inv.get(id, 0))
	board.update_view()
	var key := "%s|%s|%s" % [state.tech_tree.queue, ready_now, state.tech_tree.goal]
	if key != rows_key:
		rows_key = key
		_fill_row(queue_row, Data.QUEUE_CAPTION, state.tech_tree.queue, Data.QUEUE_EMPTY)
		_fill_row(ready_row, Data.READY_CAPTION, ready_now, Data.READY_EMPTY)
	shown = board.hovered if board.hovered != "" else selected
	if shown != "" and (not state.tech_tree.tech_visible(shown) or not board.shows(shown)):
		shown = ""
	if shown == "":
		_show_frontier(ready_now)
	else:
		_show_tech(shown)
	board.queue_redraw()


## A caption and a chip per tech (or a hint when there are none).
func _fill_row(row: HBoxContainer, caption: String, techs: Array, empty: String) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var cap := Ui.label(caption, Ui.MIN_TEXT)
	cap.add_theme_color_override("font_color", Ui.TEXT_DIM)
	row.add_child(cap)
	if techs.is_empty():
		var hint := Ui.label(empty, Ui.MIN_TEXT)
		hint.add_theme_color_override("font_color", Ui.TEXT_DIM)
		row.add_child(hint)
		return
	for tech in techs:
		var b := Ui.button(Data.TECHS[tech]["name"])
		b.custom_minimum_size = Vector2(0, 24)
		var style := Ui.panel_style(Ui.CARD, 4)
		style.border_color = TechBoard.GOLD if state.tech_tree.can_research(tech) else Ui.OUTLINE
		style.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", style)
		b.pressed.connect(_on_card.bind(tech))
		b.tooltip_text = _chip_tip(tech)
		row.add_child(b)
	if caption == Data.QUEUE_CAPTION and state.tech_tree.goal != "":
		var clear := Ui.button("Clear")
		clear.pressed.connect(
			func():
				state.tech_tree.clear()
				refresh()
		)
		row.add_child(clear)


## A queue or ready chip's tooltip: the cost, what the building will cost after, and a heads-up when paying leaves too little.
func _chip_tip(tech: String) -> String:
	var lines: Array = ["Cost: " + Ui.cost_text(state.tech_tree.cost_of(tech))]
	if Ui.then_builds_text(tech) != "":
		lines.append(Ui.then_builds_text(tech))
		var warning := Ui.build_warning(state.economy.inv, tech, state.tech_tree.cost_of(tech))
		if state.tech_tree.can_research(tech) and warning != "":
			lines.append(warning)
	return "\n".join(lines)


func _show_frontier(ready_now: Array) -> void:
	var names: Array = ready_now.map(func(t): return Data.TECHS[t]["name"])
	strip["title"].text = Data.STRIP_READY % ", ".join(names) if not names.is_empty() else Data.STRIP_NONE
	strip["title"].add_theme_color_override("font_color", TechBoard.GOLD if not names.is_empty() else Ui.TEXT)
	strip["desc"].text = Data.STRIP_HELP
	strip["cost"].text = Data.RANK_HELP
	strip["warn"].visible = false
	strip["links"].text = ""
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
	strip["links"].text = "NEEDS: %s     LEADS TO: %s" % [_needs_text(tech), _leads_text(tech)]
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
