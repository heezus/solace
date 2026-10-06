extends PanelContainer
## The bottom bar: the tech tree button, build tabs (Homes, Gathering, Workshops, Logistics, Lore),
## fixed-size build buttons, the Demolish tool and a small Craft group.
## Buttons never change size: costs live in their tooltips and in the placement preview.

signal build_picked(type: String)
signal craft_picked(recipe: String)
signal tech_pressed
signal demolish_pressed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Hands = preload("res://scripts/hands.gd")
const CardText = preload("res://scripts/card_text.gd")
const FieldText = preload("res://scripts/field_text.gd")

const BUTTON := Vector2(172, 64)
const TEXT_X := 42.0  # the title and state line start here, beside the 30 px icon
const TEXT_W := 124.0
const LOWER_Y := 41.0  # the price pips run along the bottom
const WHY_Y := 22.0  # a locked card has no state line or price: its reason (two lines at most) starts here
const LOCKED_BG: Color = Ui.CARD_LOCKED
const LOCKED_TEXT: Color = Ui.TEXT_DIM
const DEMOLISH_SIZE := 40.0
const DEMOLISH_W := 112.0  # the hammer and its one-word label
const PULSE_SECONDS := 4.0  # how long a card and its tab glow after research unlocks it

var state: Sim
var tab := "Gathering"
var tab_buttons := {}
var build_buttons := {}  # type -> {"button", "name", "sub"}
var craft_buttons := {}
var pulses := {}  # building type or tab name -> seconds of glow left
var tech_button: Button
var demolish_button: Button
var row: HBoxContainer


func setup(game: Sim) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.bar_style(Ui.BAR, false))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)

	tech_button = _tech_button()
	tech_button.pressed.connect(func(): tech_pressed.emit())
	h.add_child(tech_button)
	h.add_child(VSeparator.new())

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for tab_name in Data.BUILD_TABS:
		var b := Ui.button(tab_name)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(100, 26)
		b.pressed.connect(_show_tab.bind(tab_name))
		tabs.add_child(b)
		tab_buttons[tab_name] = b
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for tab_name in Data.BUILD_TABS:
		for type in Data.BUILD_TABS[tab_name]:
			var parts := _build_button(type)
			parts["button"].pressed.connect(func(): build_picked.emit(type))
			row.add_child(parts["button"])
			build_buttons[type] = parts

	h.add_child(VSeparator.new())

	var craft := VBoxContainer.new()
	craft.add_theme_constant_override("separation", 4)
	craft.add_child(Ui.heading("Craft by hand"))
	for r in Data.RECIPES:
		var b := Ui.button(Data.RECIPES[r]["name"])
		b.custom_minimum_size = Vector2(120, 26)
		var sprite := Ui.item_sprite(r) if Data.ITEMS.has(r) else null
		b.icon = sprite if sprite != null else Ui.swatch_texture(Ui.tech_color(Data.RECIPES[r]["tech"]))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.pressed.connect(func(): craft_picked.emit(r))
		craft.add_child(b)
		craft_buttons[r] = b
	h.add_child(craft)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	demolish_button = _demolish_button()  # the far right: small, ghost style, red only while it is the tool in use
	demolish_button.pressed.connect(func(): demolish_pressed.emit())
	h.add_child(demolish_button)
	_show_tab(tab)


func _show_tab(tab_name: String) -> void:
	tab = tab_name
	_apply_visibility()


## Show the current tab's cards, hide the cards of story buildings nothing has revealed yet, and hide a tab
## with no card to show.
func _apply_visibility() -> void:
	for t in tab_buttons:
		tab_buttons[t].button_pressed = t == tab
		tab_buttons[t].visible = tab_shown(t)
	for type in build_buttons:
		build_buttons[type]["button"].visible = type in Data.BUILD_TABS[tab] and CardText.shown(state, type)


## Whether a tab has any card to show.
func tab_shown(tab_name: String) -> bool:
	return Data.BUILD_TABS[tab_name].any(func(type): return CardText.shown(state, type))


## Research unlocked these buildings: their cards and tabs glow for a few seconds (see _process).
func pulse_unlock(types: Array) -> void:
	for type in types:
		pulses[type] = PULSE_SECONDS
		pulses[tab_of(type)] = PULSE_SECONDS


## Whether the card of building `type`, or the tab named `type`, is glowing.
func pulsing(type: String) -> bool:
	return pulses.get(type, 0.0) > 0.0


func _process(delta: float) -> void:
	if pulses.is_empty():
		return
	for key in pulses.keys():
		pulses[key] -= delta
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0) if pulses[key] > 0.0 else 0.0
		var node: Control = build_buttons[key]["button"] if build_buttons.has(key) else tab_buttons[key]
		node.modulate = Color.WHITE.lerp(Ui.HIGHLIGHT, 0.55 * glow)
		if pulses[key] <= 0.0:
			pulses.erase(key)


func show_tab_of(type: String) -> void:
	var t := tab_of(type)
	if t != "":
		_show_tab(t)


## The tab a building type sits in.
static func tab_of(type: String) -> String:
	for tab_name in Data.BUILD_TABS:
		if type in Data.BUILD_TABS[tab_name]:
			return tab_name
	return ""


## A fixed-size card: the sprite, the name in bold, one short line saying what's missing, and along the
## bottom the price as pips (or, on a locked card, the tech to discover). Nothing on it is ever cut off.
func _build_button(type: String) -> Dictionary:
	var def: Dictionary = Data.BUILDINGS[type]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = BUTTON
	b.clip_contents = true
	var icon := TextureRect.new()
	icon.position = Vector2(6, 5)
	icon.size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = Art.building_sprite(type)
	if icon.texture == null:
		icon.texture = Ui.swatch_texture(def["color"])
	b.add_child(icon)
	var title := _text(def["name"], Ui.MIN_TEXT, Vector2(TEXT_X, 3), Vector2(TEXT_W, 19))
	b.add_child(title)
	var sub := _text("", CardText.FONT_SIZE, Vector2(TEXT_X, 21), Vector2(TEXT_W, 19))
	b.add_child(sub)
	var pips := Ui.cost_pips(def["cost"], 20, Ui.MIN_TEXT)
	pips.position = Vector2(6, LOWER_Y)
	b.add_child(pips)
	var why := _text("", CardText.FONT_SIZE, Vector2(TEXT_X, WHY_Y), Vector2(TEXT_W, 34))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.clip_text = false
	why.add_theme_constant_override("line_spacing", -4)
	b.add_child(why)
	for c in [icon, title, sub, pips, why]:
		Ui.ignore_mouse(c)
	return {"button": b, "title": title, "sub": sub, "icon": icon, "pips": pips, "why": why}


## A label at a fixed place and size on a card.
static func _text(text: String, font_size: int, at: Vector2, extent: Vector2) -> Label:
	var l := Ui.label(text, font_size)
	l.position = at
	l.size = extent
	l.custom_minimum_size = extent
	l.clip_text = true
	return l


## Research is the primary brass action; other controls stay quiet.
func _tech_button() -> Button:
	var b := Ui.button("Tech tree\nT")
	b.custom_minimum_size = Vector2(112, BUTTON.y)
	b.add_theme_font_size_override("font_size", Ui.LABEL_TEXT)
	Ui.action_button(b)
	return b


## The Demolish tool: a small button, a hammer with a small X and its name, in the ghost card style.
func _demolish_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(DEMOLISH_W, DEMOLISH_SIZE)
	b.text = Data.DEMOLISH_LABEL
	b.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.icon = Art.sprite("demolish_tool")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 28)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = Data.DEMOLISH_TIP
	return b


## `placing` is the building type being placed, "demolish" for the Demolish tool, or "".
func refresh(placing: String, ready_count: int) -> void:
	tech_button.text = "Tech tree\n%d ready · T" % ready_count
	_apply_visibility()
	for type in build_buttons:
		var parts: Dictionary = build_buttons[type]
		var b: Button = parts["button"]
		var unlocked := state.town.unlocked(type)
		var style := Ui.panel_style(Ui.CARD if unlocked else LOCKED_BG, 4)
		if placing == type:
			style.border_color = Ui.HIGHLIGHT  # the card being placed is ringed in gold
			style.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.06)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", style)
		var text_col: Color = Ui.TEXT if unlocked else LOCKED_TEXT
		parts["title"].add_theme_color_override("font_color", text_col)
		b.disabled = not unlocked
		var sub: Label = parts["sub"]
		sub.text = CardText.state_line(state, type, placing, sub.size.x) if unlocked else ""  # the reason says it
		var price: Dictionary = state.town.price(type)
		var short := not CardText.shortfall(state.economy.inv, price).is_empty()
		sub.add_theme_color_override("font_color", Ui.SHORT if short and placing != type else Ui.TEXT_DIM)
		var why: Label = parts["why"]
		why.text = CardText.locked_reason(type, why.size.x) if not unlocked else ""
		why.add_theme_color_override("font_color", LOCKED_TEXT)
		parts["pips"].visible = unlocked
		Ui.update_pips(parts["pips"], price, state.economy.inv)
		parts["icon"].modulate = Color(1, 1, 1, 1.0 if unlocked else 0.4)
		b.tooltip_text = _tooltip(type)
	var demo := Ui.panel_style(Ui.BAD if placing == "demolish" else Ui.CARD_LOCKED, 4)
	demolish_button.add_theme_stylebox_override("normal", demo)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		demolish_button.add_theme_color_override(key, Ui.LINE if placing == "demolish" else Ui.TEXT_DIM)
	var demo_hover := demo.duplicate()
	demo_hover.border_color = Ui.HIGHLIGHT
	demolish_button.add_theme_stylebox_override("hover", demo_hover)
	for r in craft_buttons:
		var b: Button = craft_buttons[r]
		var rec: Dictionary = Data.RECIPES[r]
		b.disabled = not Hands.recipe_unlocked(state, r) or not state.economy.can_afford(rec["in"])
		b.tooltip_text = "%s: %s into %s" % [rec["name"], Ui.cost_text(rec["in"]), Ui.cost_text(rec["out"])]
		if not Hands.recipe_unlocked(state, r):
			b.tooltip_text += "\n%s first." % (Data.CARD_DISCOVER % Data.TECHS[rec["tech"]]["name"])


func _tooltip(type: String) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	var s: String = def["name"] + "\n" + def["desc"]
	var price: Dictionary = state.town.price(type)
	if not price.is_empty():
		s += "\nPrice (have/need): " + Ui.progress_text(state.economy.inv, price, 99)
	var copies: int = state.town.copies(type)
	if Rules.is_production(type) and copies > 0:
		s += "\n" + Data.COPY_COST_NOTE % [copies, roundi((Rules.copy_multiplier(type, copies) - 1.0) * 100.0)]
	if def["kind"] == "field":
		s += "\n" + FieldText.card_text(state, def)
	if def["tech"] == "":
		s += "\nAlways available."
	elif not state.town.unlocked(type):
		s += "\n%s to unlock it." % (Data.CARD_DISCOVER % Data.TECHS[def["tech"]]["name"])
	return s
