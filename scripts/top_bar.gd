extends PanelContainer
## The top bar: Kith and jobs, food with its time left, and a fixed-width chip per good showing the
## count and the net rate per second (green up, red down). Hovering a chip drops a panel explaining
## where that good comes from and where it goes.

signal speed_picked(value: int)  # 0 toggles pause

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")

const RAW := ["wood", "stone", "flint", "fiber", "clay", "berries", "grain", "fish"]
const LOSS := Color("ff9aa9")
const FLAT := Color("9fb4bf")
const MINUS := "−"

var state: GameState
var kith_label: Label
var jobs_label: Label
var food_label: Label
var food_bar: ProgressBar
var tools_label: Label
var click_label: Label
var chips := {}  # item -> {"box", "count", "rate"}
var flow_panel: PanelContainer
var flow_box: VBoxContainer
var flow_item := ""
var speed_buttons := {}


func setup(game: GameState) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.BAR, 6))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)

	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", -2)
	kith_label = Ui.label("", 15)
	jobs_label = Ui.label("", 10)
	kv.add_child(kith_label)
	kv.add_child(jobs_label)
	kv.mouse_filter = Control.MOUSE_FILTER_PASS
	kv.tooltip_text = "Kith work buildings and haul goods. Each building needs one. They grow with spare food and room."
	h.add_child(kv)
	h.add_child(VSeparator.new())

	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	food_label = Ui.label("", 14)
	fv.add_child(food_label)
	food_bar = ProgressBar.new()
	food_bar.custom_minimum_size = Vector2(110, 6)
	food_bar.show_percentage = false
	fv.add_child(food_bar)
	fv.mouse_filter = Control.MOUSE_FILTER_PASS
	fv.tooltip_text = "Every Kith eats food: Berries, then Fish, then any Flour research doesn't need."
	h.add_child(fv)
	tools_label = Ui.label("", 12)
	tools_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tools_label)
	click_label = Ui.label("", 12)
	click_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	click_label.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	click_label.custom_minimum_size = Vector2(118, 0)
	h.add_child(click_label)
	h.add_child(VSeparator.new())

	var goods := HFlowContainer.new()
	goods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods.add_theme_constant_override("h_separation", 4)
	goods.add_theme_constant_override("v_separation", 2)
	h.add_child(goods)
	for group in [["RAW", RAW], ["MADE", Data.ITEM_ORDER.filter(func(i): return i not in RAW)]]:
		var cap := Ui.label(group[0], 9)
		cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		goods.add_child(cap)
		for id in group[1]:
			goods.add_child(_chip(id, 70.0 if group[0] == "RAW" else 62.0))
	var note := Ui.label("per sec", 9)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(note)
	h.add_child(VSeparator.new())
	for part in [["Pause", 0], ["1x", 1], ["2x", 2], ["3x", 3]]:
		var b := Ui.button(part[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52 if part[1] == 0 else 32, 26)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "Pause or resume (Space)" if part[1] == 0 else "Speed x%d (key %d)" % [part[1], part[1]]
		var v: int = part[1]
		b.pressed.connect(func(): speed_picked.emit(v))
		h.add_child(b)
		speed_buttons[v] = b

	flow_panel = PanelContainer.new()
	flow_panel.top_level = true
	flow_panel.visible = false
	flow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow_panel.custom_minimum_size = Vector2(260, 0)
	flow_panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 10))
	add_child(flow_panel)
	flow_box = VBoxContainer.new()
	flow_box.add_theme_constant_override("separation", 3)
	flow_panel.add_child(flow_box)


## A fixed-width chip: the item's color square, the count and the net rate under it.
func _chip(id: String, width: float) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	box.add_child(h)
	h.add_child(Ui.item_swatch(id, 14.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	var count := Ui.label("", 14)
	var rate := Ui.label("", 10)
	rate.add_theme_font_size_override("font_size", 10)
	v.add_child(count)
	v.add_child(rate)
	h.add_child(v)
	Ui.ignore_mouse(h)
	box.tooltip_text = Data.ITEMS[id]["name"]
	box.mouse_entered.connect(_show_flow.bind(id))
	box.mouse_exited.connect(_hide_flow.bind(id))
	chips[id] = {"box": box, "count": count, "rate": rate}
	return box


## "+0.60", "−0.25" or "0" for a per-second rate.
static func rate_text(per_sec: float) -> String:
	if absf(per_sec) < 0.005:
		return "0"
	var digits := "%.2f" if absf(per_sec) < 10.0 else "%.1f"
	return ("+" if per_sec > 0.0 else MINUS) + digits % absf(per_sec)


static func rate_color(per_sec: float) -> Color:
	if absf(per_sec) < 0.005:
		return FLAT
	return Ui.GOOD if per_sec > 0.0 else LOSS


## Food value gained or lost per second, from every food's rate.
func food_rate() -> float:
	var total := 0.0
	for id in Data.FOOD_VALUE:
		total += state.flows.rate(id) * state.food_value(id)
	return total


func refresh(paused: bool, speed: int) -> void:
	var idle := Ui.idle_kith(state)
	var workers := state.kith.size() - idle
	var jobs := 0
	for b in state.buildings:
		jobs += 1 if state.needs_worker(b) and not b["paused"] else 0
	kith_label.text = "Kith %d / %d" % [state.kith.size(), state.housing()]
	var note := Ui.growth_note(state)
	kith_label.add_theme_color_override("font_color", Ui.HIGHLIGHT if note != "" else Ui.GOOD)
	jobs_label.text = "Jobs %d / %d  ·  %d %s" % [workers, jobs, idle, "hauling" if state.has_haulers() else "idle"]
	if note != "":
		jobs_label.text += "  ·  " + note
	var food := state.food_total()
	var fr := food_rate()
	var s := "Food %d  ·  %s/s" % [int(food), rate_text(fr)]
	if fr < -0.005:
		var left := food / -fr
		s += "  ·  " + (("%d min left" % int(left / 60.0)) if left >= 60.0 else ("%d s left" % int(left)))
	if state.starving:
		s = "Food: none! The Kith have stopped working"
	food_label.text = s
	food_label.add_theme_color_override("font_color", Ui.BAD if fr < -0.005 or state.starving else Color.WHITE)
	food_bar.max_value = maxf(state.kith.size() * 2.0 + Data.BIRTH_FOOD, 1.0)
	food_bar.value = minf(food, food_bar.max_value)
	food_bar.modulate = Ui.BAD if fr < -0.005 else Ui.HIGHLIGHT
	tools_label.visible = state.seen.has("flint_tools")
	var held := state.tools_held()
	tools_label.text = "Tools %d/%d Kith" % [held, state.kith.size()]
	tools_label.tooltip_text = (
		"Kith holding a Flint Tool work 50%% faster. Each tool lasts %d jobs; spares in the stockpile: %d."
		% [Data.TOOL_JOBS, state.inv.get("flint_tools", 0)]
	)
	tools_label.mouse_filter = Control.MOUSE_FILTER_STOP
	tools_label.add_theme_color_override("font_color", Ui.GOOD if held >= state.kith.size() else Color.WHITE)
	for id in chips:
		var c: Dictionary = chips[id]
		var n: int = state.inv.get(id, 0)
		var r := state.flows.rate(id)
		c["box"].visible = state.seen.has(id)
		c["count"].text = str(n)
		c["count"].modulate = Color(1, 1, 1, 0.4 if n == 0 and absf(r) < 0.005 else 1.0)
		c["rate"].text = rate_text(r)
		c["rate"].add_theme_color_override("font_color", rate_color(r))
		c["box"].tooltip_text = "" if flow_item == id else Data.ITEMS[id]["name"]
		if flow_item == id:
			c["box"].add_theme_stylebox_override("panel", _ring())
		else:
			c["box"].add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for v in speed_buttons:
		speed_buttons[v].button_pressed = paused if v == 0 else (not paused and v == speed)
	if flow_item != "":
		_fill_flow(flow_item)


## What a click on the hovered resource tile gives, e.g. "Click: +4 Wood"; "" when not over one.
func set_click_hint(text: String) -> void:
	click_label.text = text


func _ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Ui.HIGHLIGHT
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


func _show_flow(id: String) -> void:
	flow_item = id
	_fill_flow(id)
	var chip: Control = chips[id]["box"]
	flow_panel.visible = true
	flow_panel.position = chip.global_position + Vector2(0, chip.size.y + 8)
	var vp := get_viewport_rect().size
	flow_panel.position.x = minf(flow_panel.position.x, vp.x - 270.0)


func _hide_flow(id: String) -> void:
	if flow_item == id:
		flow_item = ""
		flow_panel.visible = false


## The hover panel: what makes this good, what uses it, and what happens if it runs out.
func _fill_flow(id: String) -> void:
	for c in flow_box.get_children():
		flow_box.remove_child(c)
		c.queue_free()
	var net := state.flows.rate(id)
	var head := Ui.label("%s  %d   %s/s" % [Data.ITEMS[id]["name"], state.inv.get(id, 0), rate_text(net)], 14)
	head.add_theme_color_override("font_color", rate_color(net) if absf(net) >= 0.005 else Color.WHITE)
	flow_box.add_child(head)
	var parts := state.flows.parts(id)
	var ins: Array = []
	var outs: Array = []
	for source in parts:
		if parts[source] > 0.0:
			ins.append(source)
		elif parts[source] < 0.0:
			outs.append(source)
	ins.sort_custom(func(a, b): return parts[a] > parts[b])
	outs.sort_custom(func(a, b): return parts[a] < parts[b])
	_flow_caption("COMING IN")
	if ins.is_empty():
		_flow_row("Nothing is making it right now", 0.0)
	for source in ins:
		_flow_row(_maker_name(source, id), parts[source])
	_flow_caption("GOING OUT")
	if outs.is_empty():
		_flow_row("Nothing is using it up", 0.0)
	for source in outs:
		_flow_row(_user_name(source, id), parts[source])
	if Data.FOOD_VALUE.has(id):
		_flow_note("Food worth %s each. The Kith eat it." % str(state.food_value(id)), Color(1, 1, 1, 0.7))
	if net < -0.005 and not outs.is_empty():
		var have: int = state.inv.get(id, 0)
		var left := have / -net
		var then := "the Kith go hungry" if outs[0] == "kith" else "the %s stops" % _type_name(outs[0])
		_flow_note("Runs out in %s. Then %s." % [_duration(left), then], LOSS)
		var fix := "Fix: " + _how_to_make(id)
		if outs[0] != "kith" and outs[0] != "craft":
			fix += ", or pause the " + _type_name(outs[0])
		_flow_note(fix + ".", Color(1, 1, 1, 0.8))


func _flow_caption(text: String) -> void:
	var l := Ui.label(text, 9)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	flow_box.add_child(l)


func _flow_row(text: String, per_sec: float) -> void:
	var h := HBoxContainer.new()
	var l := Ui.label(text, 12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	if per_sec != 0.0:
		var r := Ui.label(rate_text(per_sec), 12)
		r.add_theme_color_override("font_color", rate_color(per_sec))
		h.add_child(r)
	flow_box.add_child(h)


func _flow_note(text: String, col: Color) -> void:
	var l := Ui.label(text, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(240, 0)
	l.add_theme_color_override("font_color", col)
	flow_box.add_child(l)


static func _type_name(source: String) -> String:
	return Data.BUILDINGS[source]["name"] if Data.BUILDINGS.has(source) else source


## "2 Gatherer's Huts", "Gathered by hand", "Crafted by hand".
func _maker_name(source: String, id: String) -> String:
	match source:
		"hand":
			return "Gathered by hand"
		"craft":
			return "Crafted by hand"
	var n := 0
	for b in state.buildings:
		if b["type"] == source and (id in b["gather_items"] or Data.BUILDINGS[source].get("out", {}).has(id)):
			n += 1
	var title := _type_name(source)
	return "%d %ss" % [n, title] if n > 1 else title


## "Twine Post: 3 Fiber into 1 Rope", "Eaten by the Kith".
func _user_name(source: String, id: String) -> String:
	match source:
		"kith":
			return "Eaten by the Kith"
		"craft":
			return "Crafting by hand"
	var def: Dictionary = Data.BUILDINGS.get(source, {})
	if def.has("in") and def["in"].has(id):
		return "%s: %d %s into %s" % [def["name"], def["in"][id], Data.ITEMS[id]["name"], Ui.cost_text(def["out"])]
	return _type_name(source)


## Where more of a good comes from, for the fix line.
static func _how_to_make(id: String) -> String:
	if id == "fiber":
		return "a Gatherer's Hut on open grass"
	for tile in Data.TILES:
		if Data.TILES[tile]["yields"] == id:
			return "another Gatherer's Hut near %s" % Data.TILES[tile]["name"]
	for type in Data.BUILD_ORDER:
		if Data.BUILDINGS[type].get("out", {}).has(id):
			return "another " + Data.BUILDINGS[type]["name"]
	return "make more"


static func _duration(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%d s" % s
	var mins := floori(s / 60.0)
	return "%d min %d s" % [mins, s % 60] if s % 60 != 0 else "%d min" % mins
