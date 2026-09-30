extends PanelContainer
## The research panel: a header with the counter and legend, the research queue and the techs ready now,
## the scrolling research board, and a strip about the tech under the mouse (or the frontier).
## Click a ready card to research it. Click any other card to make it the goal: the techs it still needs
## are queued and researched as soon as each is affordable.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const TechBoard = preload("res://scripts/tech_board.gd")
const Ranks = preload("res://scripts/ranks.gd")

const BG := Color("172c4a")

var state: GameState
var board: TechBoard
var scroll: ScrollContainer
var counter: Label
var queue_row: HBoxContainer
var ready_row: HBoxContainer
var strip := {}
var shown := ""  # the tech in the strip, "" for the frontier
var rows_key := ""  # what the queue and ready rows show, so they're only rebuilt when it changes
var selected := ""


func setup(game: GameState) -> void:
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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(Ui.label("Research  ·  Stone Age", 22))
	counter = Ui.label("", 13)
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counter.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	head.add_child(counter)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	for part in [
		["researched", TechBoard.MET],
		["still needed", TechBoard.NEEDED],
		["hover: its whole chain", TechBoard.GOLD],
	]:
		var l := Ui.label("— " + part[0], 12)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_color_override("font_color", part[1])
		head.add_child(l)
	var or_note := Ui.label("or = either parent", 12)
	or_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(or_note)
	var close := Ui.button("Close (T)")
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)

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
	for key in ["desc", "cost", "links", "route"]:
		var l := Ui.label("", 12)
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
	if state.can_research(tech):
		state.research(tech)
		state.tech_tree.refill()
	elif state.researched.has(tech):
		Ranks.buy(state, tech)  # a researched card with ranks buys the next one, when affordable
	else:
		state.tech_tree.set_goal(tech)
	refresh()


func _on_action() -> void:
	if shown == "":
		return
	_on_card(shown)


## Open scrolled to the frontier: the middle of the techs that are ready now.
func _on_open() -> void:
	if not visible:
		return
	refresh()
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
	var done := state.researched.size()
	var ready_now := state.tech_tree.ready_list()
	var hidden_n := Data.TECHS.size() - Rules.visible_techs(state.shard_seen).size()
	counter.text = (
		"%d of %d researched  ·  %d ready%s"
		% [done, Data.TECHS.size(), ready_now.size(), ("  ·  %d hidden" % hidden_n) if hidden_n > 0 else ""]
	)
	var key := "%s|%s|%s" % [state.research_queue, ready_now, state.research_goal]
	if key != rows_key:
		rows_key = key
		_fill_row(queue_row, "QUEUE", state.research_queue, "Click a far tech to queue its chain")
		_fill_row(ready_row, "READY TO RESEARCH", ready_now, "Nothing yet: gather more")
	shown = board.hovered if board.hovered != "" else selected
	if shown != "" and not state.tech_visible(shown):
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
	var cap := Ui.label(caption, 11)
	cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	row.add_child(cap)
	if techs.is_empty():
		var hint := Ui.label(empty, 12)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		row.add_child(hint)
		return
	for tech in techs:
		var b := Ui.button(Data.TECHS[tech]["name"])
		b.custom_minimum_size = Vector2(0, 24)
		var style := Ui.panel_style(Ui.CARD, 4)
		style.border_color = TechBoard.GOLD if state.can_research(tech) else Ui.OUTLINE
		style.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", style)
		b.pressed.connect(_on_card.bind(tech))
		row.add_child(b)
	if caption == "QUEUE" and state.research_goal != "":
		var clear := Ui.button("Clear")
		clear.pressed.connect(
			func():
				state.tech_tree.clear()
				refresh()
		)
		row.add_child(clear)


func _show_frontier(ready_now: Array) -> void:
	strip["title"].text = "Frontier"
	strip["title"].add_theme_color_override("font_color", TechBoard.GOLD)
	var names: Array = ready_now.map(func(t): return Data.TECHS[t]["name"])
	strip["desc"].text = "Ready now: " + (", ".join(names) if not names.is_empty() else "nothing yet")
	strip["cost"].text = "Hover a card to see its whole chain in gold. Click one to research it, or to queue the way there."
	strip["links"].text = ""
	strip["route"].text = ""
	strip["button"].visible = false


func _show_tech(tech: String) -> void:
	var t: Dictionary = Data.TECHS[tech]
	var lane: String = Data.LANES[t["lane"]]["name"] if Data.LANES.has(t["lane"]) else "Gate"
	var state_text := "researched"
	if not state.researched.has(tech):
		if state.can_research(tech):
			state_text = "ready"
		elif state.requirements_met(tech):
			state_text = "gather more"
		else:
			state_text = "locked"
	var side := "  ·  side branch" if t.get("side", false) else ""
	strip["title"].text = "%s  ·  %s  ·  %s%s" % [t["name"], lane, state_text, side]
	strip["title"].add_theme_color_override("font_color", Color.WHITE)
	strip["desc"].text = t["desc"]
	strip["cost"].text = "Cost: " + Ui.progress_text(state.inv, t["cost"], 99)
	if Ranks.has_ranks(tech):
		var r := Ranks.rank(state, tech)
		strip["cost"].text += (
			"     RANK %s of III · ranks II and III: %s each, optional"
			% [Data.RANK_NAMES[maxi(r, 1)] if r > 0 else "-", Ranks.effect_text(tech)]
		)
		if not Ranks.next_cost(state, tech).is_empty():
			strip["cost"].text += (" · next: " + Ui.progress_text(state.inv, Ranks.next_cost(state, tech), 99))
	strip["links"].text = "NEEDS: %s     LEADS TO: %s" % [_needs_text(tech), _leads_text(tech)]
	var route := Rules.route_to(tech, state.researched, Rules.visible_techs(state.shard_seen))
	if route.is_empty():
		strip["route"].text = ""
	else:
		var names: Array = route.map(func(r): return Data.TECHS[r]["name"])
		var now: Array = route.filter(func(r): return state.can_research(r)).map(func(r): return Data.TECHS[r]["name"])
		strip["route"].text = (
			"YOUR ROUTE: " + " › ".join(names) + ("     Ready now: " + ", ".join(now) if not now.is_empty() else "")
		)
	var b: Button = strip["button"]
	b.visible = not state.researched.has(tech) or not Ranks.next_cost(state, tech).is_empty()
	b.disabled = false
	b.text = "Research " + t["name"] if state.can_research(tech) else "Queue the way there"
	if state.research_goal == tech:
		b.text = "Queued"
	if state.researched.has(tech) and b.visible:
		b.text = "Buy rank %s" % Data.RANK_NAMES[Ranks.rank(state, tech) + 1]
		b.disabled = not Ranks.can_buy(state, tech)


func _needs_text(tech: String) -> String:
	var parts: Array = Data.TECHS[tech]["requires"].map(_need_name)
	var any: Array = (
		Data.TECHS[tech].get("requires_any", []).filter(func(r): return state.tech_visible(r)).map(_need_name)
	)
	if any.size() == 1:
		parts.append(any[0])
	elif any.size() > 1:
		parts.append("one of " + " or ".join(any))
	return ", ".join(parts) if not parts.is_empty() else "nothing, start here"


func _need_name(r: String) -> String:
	return Data.TECHS[r]["name"] + (" (done)" if state.researched.has(r) else "")


func _leads_text(tech: String) -> String:
	var next: Array = []
	for t in Data.TECH_ORDER:
		var d: Dictionary = Data.TECHS[t]
		if state.tech_visible(t) and (tech in d["requires"] or tech in d.get("requires_any", [])):
			next.append(d["name"])
	return ", ".join(next) if not next.is_empty() else "the next era"
