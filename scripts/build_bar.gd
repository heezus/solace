extends PanelContainer
## The bottom bar: the tech tree button, build tabs (Homes, Gathering, Workshops, Logistics, Lore),
## fixed-size build buttons, the Demolish tool and a small Craft group.
## Buttons never change size: costs live in their tooltips and in the placement preview.

signal build_picked(type: String)
signal craft_picked(recipe: String)
signal tech_pressed
signal demolish_pressed

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")

const BUTTON := Vector2(142, 50)
const LOCKED_BG := Color("1f3a47")
const LOCKED_TEXT := Color("9fb4bf")

var state: GameState
var tab := "Gathering"
var tab_buttons := {}
var build_buttons := {}  # type -> {"button", "name", "sub"}
var craft_buttons := {}
var tech_button: Button
var demolish_button: Button
var row: HBoxContainer


func setup(game: GameState) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.BAR, 6))
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)

	tech_button = _big_button("Tech tree", "T", Ui.tech_color("storytelling"))
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
		b.custom_minimum_size = Vector2(96, 22)
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
	demolish_button = _big_button("Demolish", "Half back · X", Ui.BAD)
	demolish_button.custom_minimum_size = Vector2(118, BUTTON.y)
	demolish_button.pressed.connect(func(): demolish_pressed.emit())
	h.add_child(demolish_button)
	h.add_child(VSeparator.new())

	var craft := VBoxContainer.new()
	craft.add_theme_constant_override("separation", 4)
	craft.add_child(Ui.heading("Craft by hand"))
	for r in Data.RECIPES:
		var b := Ui.button(Data.RECIPES[r]["name"])
		b.custom_minimum_size = Vector2(110, 22)
		b.icon = Ui.swatch_texture(
			Data.ITEMS[r]["color"] if Data.ITEMS.has(r) else Ui.tech_color(Data.RECIPES[r]["tech"])
		)
		b.pressed.connect(func(): craft_picked.emit(r))
		craft.add_child(b)
		craft_buttons[r] = b
	h.add_child(craft)
	_show_tab(tab)


func _show_tab(tab_name: String) -> void:
	tab = tab_name
	for t in tab_buttons:
		tab_buttons[t].button_pressed = t == tab_name
	for type in build_buttons:
		build_buttons[type]["button"].visible = type in Data.BUILD_TABS[tab_name]


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


## A fixed-size button: the sprite, the name in bold and a short second line.
func _build_button(type: String) -> Dictionary:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = BUTTON
	b.clip_contents = true
	var h := HBoxContainer.new()
	h.position = Vector2(6, 6)
	h.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = Art.building_sprite(type)
	if icon.texture == null:
		icon.texture = Ui.swatch_texture(Data.BUILDINGS[type]["color"])
	h.add_child(icon)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	var title := Ui.label(Data.BUILDINGS[type]["name"], 12)
	title.custom_minimum_size = Vector2(BUTTON.x - 50, 0)
	title.clip_text = true
	tv.add_child(title)
	var sub := Ui.label("", 10)
	sub.custom_minimum_size = Vector2(BUTTON.x - 50, 0)
	sub.clip_text = true
	tv.add_child(sub)
	h.add_child(tv)
	b.add_child(h)
	Ui.ignore_mouse(h)
	return {"button": b, "title": title, "sub": sub, "icon": icon}


func _big_button(title: String, sub: String, col: Color) -> Button:
	var b := Ui.button(title + "\n" + sub)
	b.custom_minimum_size = Vector2(104, BUTTON.y)
	var style := Ui.panel_style(col.darkened(0.35), 6)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = col.darkened(0.2)
	b.add_theme_stylebox_override("hover", hover)
	return b


## `placing` is the building type being placed, "demolish" for the Demolish tool, or "".
func refresh(placing: String, ready_count: int) -> void:
	tech_button.text = "Tech tree\n%d ready · T" % ready_count
	for type in build_buttons:
		var parts: Dictionary = build_buttons[type]
		var b: Button = parts["button"]
		var def: Dictionary = Data.BUILDINGS[type]
		var sub: Label = parts["sub"]
		var title: Label = parts["title"]
		var unlocked := state.building_unlocked(type)
		var afford := state.can_afford(def["cost"])
		var style := Ui.panel_style(Ui.CARD if unlocked else LOCKED_BG, 4)
		if placing == type:
			style.bg_color = Ui.HIGHLIGHT
		b.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", style)
		var text_col := Art.OUTLINE if placing == type else (Color.WHITE if unlocked else LOCKED_TEXT)
		title.add_theme_color_override("font_color", text_col)
		b.disabled = not unlocked
		if not unlocked:
			sub.text = "Needs " + Data.TECHS[def["tech"]]["name"]
			sub.add_theme_color_override("font_color", LOCKED_TEXT)
		elif placing == type:
			sub.text = "Placing · right-click stops"
			sub.add_theme_color_override("font_color", Art.OUTLINE)
		else:
			sub.text = _sub_text(type) if afford else "Need more"
			sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.75) if afford else Color("ff9aa9"))
		parts["icon"].modulate = Color(1, 1, 1, 1.0 if unlocked else 0.4)
		b.tooltip_text = _tooltip(type)
	var demo := Ui.panel_style(Ui.BAD if placing == "demolish" else Ui.BAD.darkened(0.55), 6)
	demolish_button.add_theme_stylebox_override("normal", demo)
	for r in craft_buttons:
		var b: Button = craft_buttons[r]
		var rec: Dictionary = Data.RECIPES[r]
		b.disabled = not state.recipe_unlocked(r) or not state.can_afford(rec["in"])
		b.tooltip_text = "%s: %s into %s" % [rec["name"], Ui.cost_text(rec["in"]), Ui.cost_text(rec["out"])]
		if not state.recipe_unlocked(r):
			b.tooltip_text += "\nResearch %s first." % Data.TECHS[rec["tech"]]["name"]


func _sub_text(type: String) -> String:
	match Data.BUILDINGS[type]["kind"]:
		"road", "field", "bridge":
			return "Ready · drag to lay"
	return "Ready"


func _tooltip(type: String) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	var s: String = def["name"] + "\n" + def["desc"]
	if not def["cost"].is_empty():
		s += "\nCost: " + Ui.progress_text(state.inv, def["cost"], 99)
	if not state.building_unlocked(type):
		s += "\nResearch %s to unlock it." % Data.TECHS[def["tech"]]["name"]
	return s
