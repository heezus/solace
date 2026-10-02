extends PanelContainer
## The top bar: Kith and jobs, food with its time left (flashing red when it is about to run out), and a
## fixed-width chip per good in two rows, each a sprite that carries the good's color, its count in cream and its
## net rate per second under it (moss up, alert red down; the name is in the tooltip). Hovering a chip drops a
## panel explaining where that good comes from and where it goes. No line in the bar is ever cut short: long
## ones wrap onto a second line.

signal speed_picked(value: int)  # 0 toggles pause
signal log_pressed  # the Messages button

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")
const Hands = preload("res://scripts/hands.gd")
const Buildings = preload("res://scripts/buildings.gd")

const RAW := ["wood", "stone", "flint", "fiber", "clay", "berries", "grain", "fish", "copper_ore", "tin"]
const FIRST_ROW := 7  # goods in the first row; the rest are in the second
const LOSS := Ui.SHORT  # `alert`, lifted to read on cocoa
## The Food readout's text while the warning is up: light enough to read on the bar (over 4.5 to 1) at every moment.
const ALARM_TEXT := Ui.SHORT
## The ring around it flashes between these two; it is the only thing that flashes, so the words never dim.
const FLASH_FROM := Ui.SHORT
const FLASH_TO := Ui.TEXT
const FLASH_SPEED := 7.0
const FLAT := Ui.TEXT_DIM
const MINUS := "−"
const CHIP_W := 80.0
const ICON := 24.0  # a good's sprite, with nothing behind it
const ROW_H := 42.0  # a row of chips keeps this height whether or not its goods have appeared yet
## The bar is never shorter than its tallest block, the Kith block with its name, jobs line and three lines of note,
## plus the panel's margins: it is reserved from the first frame, so a chip, a note or a long line appearing later can
## never make it (or the map under it) grow.
const BAR_H := 113.0
const FOOD_W := 190.0
const COUNT_SIZE := 18  # numbers are 18
const KITH_W := 216.0  # the Kith block, wide enough for "Jobs filled 19 of 19  ·  25 hauling"

var state: Sim
var kith_label: Label
var jobs_label: Label
var note_label: Label  # why the Kith aren't growing: wraps, never cut short
var food_box: PanelContainer  # rings red and flashes while the food is about to run out
var food_label: Label
var food_sub: Label
var food_bar: ProgressBar
var tools_label: Label
var log_button: Button
var pulse := 0.0
var chips := {}  # item -> {"box", "title", "count", "rate"}
var flow_panel: PanelContainer
var flow_box: VBoxContainer
var flow_item := ""
var speed_buttons := {}


func setup(game: Sim) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.bar_style(Ui.BAR, true))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = BAR_H
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	add_child(h)

	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", -2)
	kith_label = Ui.label("", Ui.LABEL_TEXT)
	jobs_label = Ui.label("", Ui.MIN_TEXT)
	note_label = Ui.label("", Ui.MIN_TEXT)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.max_lines_visible = 3  # the bar keeps its reserved height (BAR_H): three lines at most
	kv.add_child(kith_label)
	kv.add_child(jobs_label)
	kv.add_child(note_label)
	kv.mouse_filter = Control.MOUSE_FILTER_PASS
	_fix_width(kv, [kith_label, jobs_label], KITH_W)
	note_label.custom_minimum_size.x = KITH_W
	kv.tooltip_text = ""  # filled in refresh() with the job counts
	h.add_child(kv)
	h.add_child(VSeparator.new())

	food_box = PanelContainer.new()
	food_box.add_theme_stylebox_override("panel", _outline(Color(0, 0, 0, 0)))
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 0)
	food_label = Ui.label("", Ui.LABEL_TEXT)
	fv.add_child(food_label)
	food_sub = Ui.label("", Ui.MIN_TEXT)
	food_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fv.add_child(food_sub)
	food_bar = ProgressBar.new()
	food_bar.custom_minimum_size = Vector2(110, 6)
	food_bar.show_percentage = false
	fv.add_child(food_bar)
	food_box.add_child(fv)
	food_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_fix_width(food_box, [food_label], FOOD_W)
	food_sub.custom_minimum_size.x = FOOD_W - 4.0
	food_box.tooltip_text = Data.FOOD_TIP % Data.PEOPLE["one"]
	h.add_child(food_box)
	h.add_child(VSeparator.new())

	# The goods, in two rows that never wrap: RAW, and MADE with the tool count at its end.
	var goods := VBoxContainer.new()
	goods.add_theme_constant_override("separation", 2)
	goods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods.clip_contents = true  # a narrow window clips the end of a row; it never pushes the buttons off screen
	goods.custom_minimum_size.x = 0.0
	h.add_child(goods)
	for group in [Data.ITEM_ORDER.slice(0, FIRST_ROW), Data.ITEM_ORDER.slice(FIRST_ROW)]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.custom_minimum_size = Vector2(0, ROW_H)
		for id in group:
			row.add_child(_chip(id, CHIP_W))
		if group[0] == Data.ITEM_ORDER[FIRST_ROW]:
			tools_label = Ui.label("", Ui.MIN_TEXT)
			tools_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_fix_width(tools_label, [tools_label], 120)
			row.add_child(tools_label)
		goods.add_child(row)
	h.add_child(VSeparator.new())

	# Speed buttons, with the Messages button below them.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	h.add_child(right)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	right.add_child(speeds)
	for part in [["Pause", 0], ["1x", 1], ["2x", 2], ["3x", 3]]:
		var b := Ui.button(part[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(60 if part[1] == 0 else 36, 28)
		b.tooltip_text = "Pause or resume (Space)" if part[1] == 0 else "Speed x%d (key %d)" % [part[1], part[1]]
		var v: int = part[1]
		b.pressed.connect(func(): speed_picked.emit(v))
		speeds.add_child(b)
		speed_buttons[v] = b
	log_button = Ui.button(Data.LOG_BUTTON + "  (L)")
	log_button.custom_minimum_size = Vector2(0, 28)
	log_button.tooltip_text = Data.LOG_TIP
	log_button.pressed.connect(func(): log_pressed.emit())
	right.add_child(log_button)

	flow_panel = PanelContainer.new()
	flow_panel.top_level = true
	flow_panel.visible = false
	flow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow_panel.custom_minimum_size = Vector2(280, 0)
	flow_panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 10))
	add_child(flow_panel)
	flow_box = VBoxContainer.new()
	flow_box.add_theme_constant_override("separation", 3)
	flow_panel.add_child(flow_box)


## A fixed-width chip: the item's sprite, the count and the net rate under it. The name is in its tooltip.
func _chip(id: String, width: float) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_stylebox_override("panel", _outline(Color(0, 0, 0, 0)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	box.add_child(h)
	var icon := Ui.item_icon(id, ICON)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	var count := Ui.label("", COUNT_SIZE)
	var rate := Ui.label("", Ui.MIN_TEXT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(count)
	v.add_child(rate)
	h.add_child(v)
	Ui.ignore_mouse(h)
	box.tooltip_text = item_tip(id)
	box.mouse_entered.connect(_show_flow.bind(id))
	box.mouse_exited.connect(_hide_flow.bind(id))
	_fix_width(box, [count, rate], width)
	chips[id] = {"box": box, "count": count, "rate": rate, "icon": icon}
	return box


## A panel style that keeps the same margins whether or not its outline shows, so a ring never moves anything.
static func _outline(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(2)
	return s


## Keep `c` at a fixed width whatever its labels say (they clip with an ellipsis), so the bar's goods
## wrap the same way all game and the bar's height, and so the map's scale, never changes on its own.
static func _fix_width(c: Control, labels: Array, width: float) -> void:
	c.custom_minimum_size.x = width
	for l in labels:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if l != c:
			l.custom_minimum_size.x = 0


## A good's name, and where it comes from when that isn't plain ("Fiber: cut from wild flax").
static func item_tip(id: String) -> String:
	var item: Dictionary = Data.ITEMS[id]
	return item["name"] + ("\n" + item["desc"] if item.has("desc") else "")


## A chip's tooltip: the name, the count and the rate, then where the good comes from when that isn't plain.
static func chip_tip(id: String, count: int, per_sec: float) -> String:
	var item: Dictionary = Data.ITEMS[id]
	return (
		"%s: %d, %s per second" % [item["name"], count, rate_text(per_sec)]
		+ ("\n" + item["desc"] if item.has("desc") else "")
	)


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
		total += state.economy.flows.rate(id) * state.economy.food_value(id)
	return total


func refresh(paused: bool, speed: int) -> void:
	var idle := Ui.idle_kith(state)
	var workers := state.people.kith.size() - idle
	var jobs := 0
	for b in state.town.buildings:
		jobs += 1 if Buildings.needs_worker(b) and not b["paused"] else 0
	kith_label.text = Data.KITH_LABEL % [Data.PEOPLE["many"], state.people.kith.size(), state.town.housing()]
	var note := Ui.growth_note(state)
	kith_label.get_parent().tooltip_text = (
		Data.JOBS_TIP % [state.people.job_counts(), Data.PEOPLE["many"]]
		+ ("\n\n" + GrowthNote.rule() if GrowthNote.food_is_the_blocker(state) else "")
	)
	kith_label.add_theme_color_override("font_color", Ui.TEXT if note != "" else Ui.GOOD)
	var rest: String = Data.HAUL_WORD if state.tech_tree.researched.has("haulers") else Data.IDLE_WORD
	jobs_label.text = Data.JOBS_LABEL % [workers, jobs, idle, rest]
	note_label.text = note
	note_label.visible = note != ""
	note_label.add_theme_color_override("font_color", Ui.SHORT if state.economy.starving else Ui.TEXT_DIM)
	_refresh_food()
	var have_tools: bool = state.economy.seen.has("flint_tools")
	tools_label.visible = have_tools
	var held := Hands.tools_held(state)
	tools_label.text = Data.TOOLS_LABEL % [held, state.people.kith.size(), Data.PEOPLE["many"]]
	tools_label.tooltip_text = (
		Data.TOOLS_TIP % [Data.PEOPLE["many"], Data.TOOL_JOBS, state.economy.inv.get("flint_tools", 0)]
	)
	tools_label.mouse_filter = Control.MOUSE_FILTER_STOP
	tools_label.add_theme_color_override("font_color", Ui.GOOD if held >= state.people.kith.size() else Ui.TEXT)
	for id in chips:
		var c: Dictionary = chips[id]
		var n: int = state.economy.inv.get(id, 0)
		var r := state.economy.flows.rate(id)
		# A good shows once the stockpile has held it. The rows never wrap, so the bar keeps its height.
		c["box"].visible = state.economy.seen.has(id)
		c["count"].text = str(n)
		c["count"].modulate = Color(1, 1, 1, 0.5 if n == 0 and absf(r) < 0.005 else 1.0)
		c["rate"].text = rate_text(r) + "/s"
		c["rate"].add_theme_color_override("font_color", rate_color(r))
		c["box"].tooltip_text = "" if flow_item == id else chip_tip(id, n, r)
		c["box"].add_theme_stylebox_override("panel", _outline(Ui.HIGHLIGHT if flow_item == id else Color(0, 0, 0, 0)))
	for v in speed_buttons:
		speed_buttons[v].button_pressed = paused if v == 0 else (not paused and v == speed)
	if flow_item != "":
		_fill_flow(flow_item)


## The Food readout: the count, then what is happening to it. While it is about to run out (Data.FOOD_WARN_SECONDS)
## or already has, the block rings red and flashes (see _process) and says what to do about it.
func _refresh_food() -> void:
	var eco := state.economy
	var food := eco.food_total()
	var fr := food_rate()
	food_label.text = "Food %d" % int(food)
	var sub := "%s/s" % rate_text(fr)
	if fr < -0.005:
		sub += "  ·  " + _duration(food / -fr, true) + " left"
	if eco.starving:
		sub = Data.STARVING_TEXT % Data.PEOPLE["many"]
	elif eco.low:
		sub = Data.FOOD_LOW_TEXT % _duration(minf(eco.seconds_of_food(), 3600.0), true)
	food_sub.text = sub
	var alarm := eco.low or eco.starving
	food_label.add_theme_color_override("font_color", ALARM_TEXT if alarm else Ui.TEXT)
	food_sub.add_theme_color_override("font_color", ALARM_TEXT if alarm else rate_color(fr))
	food_box.add_theme_stylebox_override("panel", _outline(flash_ring(pulse) if alarm else Color(0, 0, 0, 0)))
	food_box.modulate.a = 1.0
	food_bar.max_value = maxf(state.people.kith.size() * 2.0 + Data.BIRTH_FOOD, 1.0)
	food_bar.value = minf(food, food_bar.max_value)
	food_bar.modulate = Ui.BAD if alarm or fr < -0.005 else Ui.HIGHLIGHT


## The flash: while the food is low or gone the ring around the Food block pulses. Only the ring does: the block's
## words and the bar behind them stay as they are, so they can always be read.
func _process(delta: float) -> void:
	if state == null or not (state.economy.low or state.economy.starving):
		return
	pulse += delta
	food_box.add_theme_stylebox_override("panel", _outline(flash_ring(pulse)))


## The ring's colour at `phase` (seconds into the flash).
static func flash_ring(phase: float) -> Color:
	return FLASH_FROM.lerp(FLASH_TO, 0.5 + 0.5 * sin(phase * FLASH_SPEED))


func _show_flow(id: String) -> void:
	flow_item = id
	_fill_flow(id)
	var chip: Control = chips[id]["box"]
	flow_panel.visible = true
	flow_panel.position = chip.global_position + Vector2(0, chip.size.y + 8)
	var vp := get_viewport_rect().size
	flow_panel.position.x = minf(flow_panel.position.x, vp.x - 290.0)


func _hide_flow(id: String) -> void:
	if flow_item == id:
		flow_item = ""
		flow_panel.visible = false


## The hover panel: what makes this good, what uses it, and what happens if it runs out.
func _fill_flow(id: String) -> void:
	for c in flow_box.get_children():
		flow_box.remove_child(c)
		c.queue_free()
	var net := state.economy.flows.rate(id)
	var head := Ui.label(
		"%s  %d   %s/s" % [Data.ITEMS[id]["name"], state.economy.inv.get(id, 0), rate_text(net)], Ui.LABEL_TEXT
	)
	head.add_theme_color_override("font_color", rate_color(net) if absf(net) >= 0.005 else Ui.TEXT)
	flow_box.add_child(head)
	var parts := state.economy.flows.parts(id)
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
		_flow_note(Data.FOOD_NOTE % [str(state.economy.food_value(id)), Data.PEOPLE["many"]], Ui.TEXT_DIM)
	if net < -0.005 and not outs.is_empty():
		var have: int = state.economy.inv.get(id, 0)
		var left := have / -net
		var then := (
			Data.HUNGRY_THEN % Data.PEOPLE["many"] if outs[0] == "kith" else "the %s stops" % _type_name(outs[0])
		)
		_flow_note("Runs out in %s. Then %s." % [_duration(left), then], LOSS)
		var fix := "Fix: " + _how_to_make(id)
		if outs[0] != "kith" and outs[0] != "craft":
			fix += ", or pause the " + _type_name(outs[0])
		_flow_note(fix + ".", Ui.TEXT_DIM)


func _flow_caption(text: String) -> void:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.add_theme_color_override("font_color", Ui.TEXT_DIM)
	flow_box.add_child(l)


func _flow_row(text: String, per_sec: float) -> void:
	var h := HBoxContainer.new()
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(180, 0)
	h.add_child(l)
	if per_sec != 0.0:
		var r := Ui.label(rate_text(per_sec), Ui.MIN_TEXT)
		r.add_theme_color_override("font_color", rate_color(per_sec))
		h.add_child(r)
	flow_box.add_child(h)


func _flow_note(text: String, col: Color) -> void:
	var l := Ui.label(text, Ui.MIN_TEXT)
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
		Data.FLOW_FORAGE_SOURCE:
			return Data.FORAGE_MAKER % Data.PEOPLE["many"]
	var n := 0
	for b in state.town.buildings:
		if b["type"] == source and (id == b["focus"] or Data.BUILDINGS[source].get("out", {}).has(id)):
			n += 1
	var title := _type_name(source)
	return "%d %ss" % [n, title] if n > 1 else title


## "Twine Post: 3 Fiber into 1 Rope", "Eaten by the Kith".
func _user_name(source: String, id: String) -> String:
	match source:
		"kith":
			return Data.EATEN_BY % Data.PEOPLE["many"]
		"craft":
			return "Crafting by hand"
	var def: Dictionary = Data.BUILDINGS.get(source, {})
	if def.has("in") and def["in"].has(id):
		return "%s: %d %s into %s" % [def["name"], def["in"][id], Data.ITEMS[id]["name"], Ui.cost_text(def["out"])]
	return _type_name(source)


## Where more of a good comes from, for the fix line.
static func _how_to_make(id: String) -> String:
	for tile in Data.TILES:
		if Data.TILES[tile]["yields"] == id:
			if Data.TILES[tile].get("mine_only", false):
				return "a Mine on %s" % Data.TILES[tile]["name"]
			return "another Gatherer's Hut near %s" % Data.TILES[tile]["name"]
	for type in Data.BUILD_ORDER:
		if Data.BUILDINGS[type].get("out", {}).has(id):
			return "another " + Data.BUILDINGS[type]["name"]
	return "make more"


static func _duration(seconds: float, short := false) -> String:
	if short:  # "2 min", "45 s"
		return ("%d min" % int(seconds / 60.0)) if seconds >= 60.0 else ("%d s" % int(seconds))
	var s := int(seconds)
	if s < 60:
		return "%d s" % s
	var mins := floori(s / 60.0)
	return "%d min %d s" % [mins, s % 60] if s % 60 != 0 else "%d min" % mins
