extends ScrollContainer
## "What to learn next": a card for each tech that can be discovered right now, with what it costs (what you have of
## what it needs, in words), one plain sentence about what it unlocks and a button; one of them is marked Suggested
## (the rule is TechNext.suggested). Under them, the techs just behind, each saying what it waits for first.
## Emits `chosen(tech)`: the panel discovers the tech if it can be paid for, or queues it.

signal chosen(tech: String)

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const TechNext = preload("res://scripts/tech_next.gd")

const CARD_W := 396.0
const GOLD := Color("ffd166")

var state: Sim
var era := 1
var cards := {}  # tech -> its card, for the techs that can be discovered now
var rows := {}  # tech -> its row, for the techs just behind
var suggested := ""  # the tech marked Suggested
var key := ""  # what the cards were built from: they are rebuilt only when it changes
var box: VBoxContainer


func setup(game: Sim) -> void:
	state = game
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


## Rebuild the cards when what they show has changed (the stockpile counts, what is ready, the queue, the era).
func refresh(for_era: int) -> void:
	era = for_era
	var techs := TechNext.ready_now(state, era)
	var pick := TechNext.suggested(state, techs)
	if pick.has("tech"):  # the suggested one leads
		techs.erase(pick["tech"])
		techs.push_front(pick["tech"])
	var behind := TechNext.locked_behind(state, era, techs)
	var parts: Array = [era, pick.get("tech", ""), pick.get("why", ""), state.tech_tree.goal]
	for t in techs:
		parts.append([t, state.tech_tree.cost_of(t), _have(t), state.tech_tree.can_research(t)])
	for t in behind:
		parts.append([t, TechNext.needs_text(state, t)])
	var now := str(parts)
	if now == key:
		return
	key = now
	_build(techs, pick, behind)


func _choose(tech: String) -> void:
	chosen.emit(tech)


func _have(tech: String) -> Array:
	return state.tech_tree.cost_of(tech).keys().map(func(id): return state.economy.inv.get(id, 0))


func _build(techs: Array, pick: Dictionary, behind: Array) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	cards = {}
	rows = {}
	suggested = pick.get("tech", "")
	var head := Ui.label(Data.VIEW_NEXT, 22)
	box.add_child(head)
	if techs.is_empty():
		var done := Rules.era_techs(era).all(func(t): return state.tech_tree.researched.has(t))
		var none := Ui.label(Data.NEXT_ALL_DONE if done else Data.NEXT_NONE, Ui.MIN_TEXT)
		none.add_theme_color_override("font_color", Ui.TEXT_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(none)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	box.add_child(flow)
	for t in techs:
		var card := _card(t, t == suggested, pick.get("why", ""))
		flow.add_child(card)
		cards[t] = card
	if behind.is_empty():
		return
	box.add_child(Ui.label(Data.LOCKED_HEADING, 20))
	var note := Ui.label(Data.LOCKED_NOTE, Ui.MIN_TEXT)
	note.add_theme_color_override("font_color", Ui.TEXT_DIM)
	box.add_child(note)
	for i in mini(behind.size(), TechNext.MAX_LOCKED):
		var row := _locked_row(behind[i])
		box.add_child(row)
		rows[behind[i]] = row
	if behind.size() > TechNext.MAX_LOCKED:
		var more := Ui.label(Data.LOCKED_MORE % (behind.size() - TechNext.MAX_LOCKED), Ui.MIN_TEXT)
		more.add_theme_color_override("font_color", Ui.TEXT_DIM)
		box.add_child(more)


## One tech that can be discovered now.
func _card(tech: String, is_pick: bool, why: String) -> PanelContainer:
	var def: Dictionary = Data.TECHS[tech]
	var paid := state.tech_tree.can_research(tech)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var style := Ui.panel_style(Ui.CARD, 12)
	style.border_color = GOLD if is_pick else Art.OUTLINE
	style.set_border_width_all(4 if is_pick else 2)
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("tech", tech)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	top.add_child(_icon(def["icon"]))
	var name_label := Ui.label(def["name"], 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	if is_pick:
		top.add_child(_badge())
		var reason := _wrapped(why, GOLD)
		v.add_child(reason)
	v.add_child(_wrapped(Data.NEXT_UNLOCKS % Data.TECH_BLURBS.get(tech, def["unlock"]), Ui.TEXT))
	v.add_child(_cost_row(state.tech_tree.cost_of(tech)))
	var short := TechNext.short_text(state, tech)
	var status := _wrapped(Data.NEXT_ENOUGH if paid else Data.NEXT_SHORT % short, Ui.GOOD if paid else Ui.SHORT)
	v.add_child(status)
	if paid and Ui.build_warning(state.economy.inv, tech, state.tech_tree.cost_of(tech)) != "":
		v.add_child(_wrapped(Ui.build_warning(state.economy.inv, tech, state.tech_tree.cost_of(tech)), Ui.SHORT))
	var button := Ui.button(Data.DISCOVER_BUTTON % def["name"] if paid else Data.NEXT_QUEUE)
	button.custom_minimum_size = Vector2(0, 36)
	button.tooltip_text = "" if paid else Data.NEXT_QUEUE_TIP
	if not paid and state.tech_tree.goal == tech:
		button.text = Data.QUEUED
		button.disabled = true
	button.pressed.connect(_choose.bind(tech))
	v.add_child(button)
	return card


## One tech just behind: its name, what it waits for and a button to queue the way there.
func _locked_row(tech: String) -> PanelContainer:
	var def: Dictionary = Data.TECHS[tech]
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Ui.panel_style(Ui.CARD_LOCKED, 8))
	row.set_meta("tech", tech)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	h.add_child(_icon(def["icon"], 28.0))
	var name_label := Ui.label(def["name"], 16)
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_label)
	var needs := _wrapped(Data.LOCKED_NEEDS % TechNext.needs_text(state, tech), Ui.TEXT_DIM)
	needs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(needs)
	var queue := Ui.button(Data.QUEUED if state.tech_tree.goal == tech else Data.NEXT_QUEUE)
	queue.tooltip_text = Data.NEXT_QUEUE_TIP
	queue.disabled = state.tech_tree.goal == tech
	queue.pressed.connect(_choose.bind(tech))
	h.add_child(queue)
	return row


func _wrapped(text: String, col: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	return l


## The Suggested badge: gold, with the rule in its tooltip.
func _badge() -> PanelContainer:
	var badge := PanelContainer.new()
	var style := Ui.panel_style(GOLD, 4)
	style.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.tooltip_text = Data.NEXT_RULE
	var l := Ui.label(Data.NEXT_SUGGESTED, Ui.MIN_TEXT)
	l.add_theme_color_override("font_color", Art.OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.add_child(l)
	return badge


## A tech's picture, drawn by the same code as on the board.
func _icon(icon: String, side := 40.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_icon.bind(c, icon))
	return c


func _draw_icon(c: Control, icon: String) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.13, 0.08, 0.06))
	Art.tech_icon(c, icon, r, 0.0)
	c.draw_rect(r, Art.OUTLINE, false, 2.0)


## The price, one chip per item: its picture and "Wood 12 of 20", green when you have enough of it, red when short.
func _cost_row(cost: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 4)
	var head := Ui.label(Data.NEXT_COST_HEAD, Ui.MIN_TEXT)
	head.add_theme_color_override("font_color", Ui.TEXT_DIM)
	flow.add_child(head)
	for id in cost:
		var have: int = state.economy.inv.get(id, 0)
		var need: int = cost[id]
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(Ui.item_icon(id, 20))
		var l := Ui.label(Data.NEXT_COST_ITEM % [Data.ITEMS[id]["name"], mini(have, need), need], Ui.MIN_TEXT)
		l.add_theme_color_override("font_color", Ui.GOOD if have >= need else Ui.SHORT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(l)
		flow.add_child(chip)
	return flow
