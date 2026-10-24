extends RefCounted
## Static UI helpers shared by the HUD, the building panel and the tech tree.
## Everything is built in code, so these keep the look in one place.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Rules = preload("res://scripts/rules.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Scouting = preload("res://scripts/scouting.gd")
const Expedition = preload("res://scripts/expedition.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")

const OUTLINE: Color = Art.OUTLINE  # the sprite outline, also the map's

## The miniature world's field-journal UI: charcoal green, ivory, brass and restrained status colors.
const BAR := Color("17272a")
const PANEL := Color("213337")
const CARD := Color("30464a")
const CARD_DONE := Color("29433b")
const CARD_LOCKED := Color("1c2b2e")
const TEXT := Color("eee7d6")
const TEXT_DIM := Color("bac7bd")
const LINE := Color("0b1618")
const EDGE := Color("536968")
const HOVER := Color("3c5155")
const SELECTED := Color("3a5354")
const ACTION := Color("dcc08a")
const KITH := Color("e76f51")  # faction identity; interface actions use brass
const HIGHLIGHT := ACTION
const GOOD := Color("a4c199")
const BAD := Color("c96062")
const SHORT := Color("ec9a8c")
const SCRIM := Color("0b1618b8")
const LANE_COLORS := {
	"hearth": Color("e4af83"),
	"stone": Color("bac7bd"),
	"fiber": Color("dcc08a"),
	"land": Color("a4c199"),
	"lore": Color("bbc4de"),
}
# Glass surfaces: 94% protects the existing text contrast even over pure white ground.
const GLASS_PANEL := Color("0f1c1ff0")
const GLASS_LABEL := Color("081013fa")  # small BAD text exceeds its former outline contrast over white
const GLASS_CARD := Color(1, 1, 1, 0.06)
const GLASS_BUTTON := Color(1, 1, 1, 0.07)
const GLASS_HOVER := Color(1, 1, 1, 0.15)
const GLASS_ON := Color(ACTION, 0.20)
const GLASS_SHADOW := Color(0, 0, 0, 0.22)
const GLASS_TOP := Color("0f1c1fe0")
const GLASS_KEY := Color(TEXT, 0.70)
const GLASS_FLOW := 0.28
const GLASS_DOT := 0.85
const GLASS_CARD_RADIUS := 12
const GLASS_PILL_RADIUS := 1000
const RADIUS := 16
const MIN_TEXT := 14  # nothing on screen is smaller
const LABEL_TEXT := 16  # UI labels; numbers are 18


## Shared Glass theme. Every state keeps the same margins and minimum size.
static func apply_theme() -> void:
	var t := ThemeDB.get_default_theme()
	t.set_default_font_size(MIN_TEXT)
	for type in ["Label", "Button", "CheckBox", "LinkButton"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, TEXT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color(TEXT_DIM, 0.6))
	t.set_font_size("font_size", "Label", MIN_TEXT)
	t.set_font_size("font_size", "Button", MIN_TEXT)
	var normal := button_style(GLASS_BUTTON, 6)
	t.set_stylebox("normal", "Button", normal)
	var hover := button_style(GLASS_HOVER, 6)
	hover.border_color = HIGHLIGHT
	t.set_stylebox("hover", "Button", hover)
	var selected := button_style(GLASS_ON, 6)
	selected.border_color = HIGHLIGHT
	t.set_color("font_pressed_color", "Button", ACTION)
	t.set_color("font_hover_pressed_color", "Button", ACTION)
	t.set_stylebox("pressed", "Button", selected)
	t.set_stylebox("hover_pressed", "Button", selected)
	t.set_stylebox("disabled", "Button", button_style(GLASS_BUTTON, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for type in ["HScrollBar", "VScrollBar"]:
		var track_style := StyleBoxFlat.new()
		track_style.bg_color = BAR
		track_style.set_content_margin_all(6)
		track_style.set_corner_radius_all(RADIUS)
		t.set_stylebox("scroll", type, track_style)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grabber := panel_style(ACTION if state == "grabber_pressed" else EDGE, 4)
			grabber.shadow_size = 0
			grabber.border_color = ACTION if state == "grabber_highlight" else EDGE
			t.set_stylebox(state, type, grabber)
	var tip := panel_style(PANEL, 8)
	tip.set_border_width_all(0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", MIN_TEXT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE  # tinted by each bar's modulate
	fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = LINE
	track.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", track)
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = Color(EDGE, 0.55)
		line.thickness = 1
		line.vertical = type == "VSeparator"
		t.set_stylebox("separator", type, line)


static func label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(size, MIN_TEXT))
	return l


## A small caption, used for "Build:" and similar headings.
static func heading(text: String) -> Label:
	var l := label(text, MIN_TEXT)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", MIN_TEXT)
	return b


## Keep Button.text (and its measured width) intact, painting only its key suffix lighter.
static func key_hint(b: Button, suffix: String, solid_action: bool = false) -> void:
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_disabled_color",
		"font_focus_color"
	]:
		b.add_theme_color_override(state, Color.TRANSPARENT)
	b.draw.connect(func(): _draw_key_hint(b, suffix, solid_action))


static func _draw_key_hint(b: Button, suffix: String, solid_action: bool) -> void:
	var font := b.get_theme_font("font")
	var px := b.get_theme_font_size("font_size")
	var width := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := Vector2((b.size.x - width) / 2.0, (b.size.y - font.get_height(px)) / 2.0 + font.get_ascent(px))
	var prefix := b.text.trim_suffix(suffix)
	var col := LINE if solid_action else ACTION if b.button_pressed else TEXT
	if b.disabled:
		col = Color(TEXT_DIM, 0.6)
	b.draw_string(font, at, prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	at.x += font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	b.draw_string(font, at, suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, GLASS_KEY.a))


## The same brass action treatment in research, the build bar and milestone cards.
static func action_button(b: Button, active: bool = true) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var bg := ACTION if active else GLASS_BUTTON
		var style := button_style(bg.lightened(0.06) if state == "hover" else bg, 6)
		style.border_color = ACTION if active else EDGE
		b.add_theme_stylebox_override(state, style)
	for state in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"
	]:
		b.add_theme_color_override(state, LINE if active else TEXT)


## WCAG contrast ratio between two opaque colours, 1 (none) to 21.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


## Glass skin with explicit unchanged content margins; drawing never changes layout.
static func panel_style(color: Color, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var card := color in [CARD, CARD_DONE, CARD_LOCKED, HOVER, SELECTED]
	s.bg_color = GLASS_CARD if card else GLASS_PANEL if color in [BAR, PANEL] else color
	if color == SELECTED:
		s.bg_color = GLASS_ON
	elif color == ACTION:
		s.bg_color = ACTION
	elif color == BAD:
		s.bg_color = Color(BAD, 0.20)
	s.shadow_color = GLASS_SHADOW
	s.shadow_size = 8 if not card else 0
	s.shadow_offset = Vector2(0, 3)
	s.set_corner_radius_all(GLASS_CARD_RADIUS if card else RADIUS)
	s.set_content_margin_all(margin)
	return s


static func button_style(color: Color = GLASS_BUTTON, margin: int = 6) -> StyleBoxFlat:
	var s := panel_style(PANEL, margin)
	s.bg_color = color
	s.shadow_size = 0
	s.set_corner_radius_all(GLASS_PILL_RADIUS)
	return s


## Edge bars keep their exact padding; the top has a painted vertical fade.
static func bar_style(color: Color, _rule_on_bottom: bool) -> StyleBoxFlat:
	var s := panel_style(color, 6)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func top_style() -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([GLASS_TOP, Color(GLASS_TOP, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 2
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var s := StyleBoxTexture.new()
	s.texture = texture
	s.set_content_margin_all(6)
	return s


## A round swatch with no rim, used as a button icon.
static func swatch_texture(color: Color) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in 12:
		for x in 12:
			img.set_pixel(x, y, Color(color, color.a * clampf(6.0 - Vector2(x - 5.5, y - 5.5).length(), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## A colored square for an item: the stand-in when its sprite is missing.
static func item_swatch(id: String, size: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Data.ITEMS[id]["color"]
	r.tooltip_text = Data.ITEMS[id]["name"]
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


## An item's sprite (art/sprites/item_<id>.svg), or null when there isn't one.
static func item_sprite(id: String) -> Texture2D:
	return Art.sprite("item_" + id)


## An item's icon `size` px square: its sprite with nothing behind it, or the old colored square if the sprite is missing.
static func item_icon(id: String, size: float) -> Control:
	var tex := item_sprite(id)
	if tex == null:
		return item_swatch(id, size * 0.6)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.set_meta("item", id)
	r.tooltip_text = Data.ITEMS[id]["name"]
	return r


## A row of price pips, one per item in `cost`: its 20 px sprite and the amount (see update_pips).
static func cost_pips(cost: Dictionary, icon_size: float, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for id in cost:
		var pip := HBoxContainer.new()
		pip.add_theme_constant_override("separation", 1)
		pip.add_child(item_icon(id, icon_size))
		var l := label("", font_size)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_child(l)
		row.add_child(pip)
	return row


## Set each pip's amount: the price, red where the stockpile `inv` is short of it.
static func update_pips(row: HBoxContainer, cost: Dictionary, inv: Dictionary) -> void:
	var i := 0
	for id in cost:
		var l: Label = row.get_child(i).get_child(1)
		l.text = str(cost[id])
		l.add_theme_color_override("font_color", TEXT if inv.get(id, 0) >= cost[id] else SHORT)
		i += 1


static func tech_color(tech: String) -> Color:
	return LANE_COLORS.get(Data.TECHS[tech]["lane"], ACTION) if Data.TECHS.has(tech) else ACTION


## "10 Wood, 5 Stone".
static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%d %s" % [cost[id], Data.ITEMS[id]["name"]])
	return ", ".join(parts)


## "Wood 5/20, Stone 10/10": what you have toward each cost. Shows at most `limit` entries.
static func progress_text(inv: Dictionary, cost: Dictionary, limit: int) -> String:
	var parts: Array = []
	for id in cost:
		var have: int = inv.get(id, 0)
		var need: int = cost[id]
		parts.append("%s %d/%d" % [Data.ITEMS[id]["name"], mini(have, need), need])
	if parts.size() > limit:
		return ", ".join(parts.slice(0, limit)) + ", ..."
	return ", ".join(parts)


## "+12/min" or "-3/min", rounded; "0/min" when flat.
static func rate_text(per_min: float) -> String:
	var n := roundi(per_min)
	if n == 0:
		return "0/min"
	return ("+%d/min" if n > 0 else "%d/min") % n


static func rate_color(per_min: float) -> Color:
	if roundi(per_min) == 0:
		return Color(TEXT_DIM, 0.8)
	return GOOD if per_min > 0.0 else SHORT


## A tech's colored square with its two-letter code.
static func badge(tech: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel_style(BAR, 2)
	s.border_color = tech_color(tech)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(30, 24)
	var l := label(Data.TECHS[tech]["abbr"], MIN_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", TEXT)
	p.add_child(l)
	return p


## "need 10 Clay, 3 Rope" for whatever the stockpile is short of, or "" if affordable.
static func shortfall_text(inv: Dictionary, cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		var short: int = cost[id] - inv.get(id, 0)
		if short > 0:
			parts.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return "" if parts.is_empty() else "need " + ", ".join(parts)


## What the buildings a tech unlocks cost to put up, apart from the research: "then each Hut costs 10 Wood, 5 Stone", or with
## several "then Road costs 2 Wood, Wooden Bridge costs 10 Wood, 2 Rope". "" for a tech that unlocks no building.
static func then_builds_text(tech: String) -> String:
	var types := Rules.buildings_of(tech)
	if types.size() == 1:
		return "then each %s costs %s" % [Data.BUILDINGS[types[0]]["name"], cost_text(Data.BUILDINGS[types[0]]["cost"])]
	var parts: Array = types.map(
		func(t): return "%s costs %s" % [Data.BUILDINGS[t]["name"], cost_text(Data.BUILDINGS[t]["cost"])]
	)
	return "" if parts.is_empty() else "then " + ", ".join(parts)


## A heads-up when paying for `tech` from the stockpile `inv` would leave too little for its first building
## (researching and building both charge for materials), or "" when there's enough or no building. `cost` is what
## the tech costs now (Tally Sticks changes it), the tech's own cost when left out.
static func build_warning(inv: Dictionary, tech: String, cost: Dictionary = {}) -> String:
	var types := Rules.buildings_of(tech)
	if types.is_empty():
		return ""
	var paid: Dictionary = cost if not cost.is_empty() else Data.TECHS[tech]["cost"]
	var short := shortfall_text(Rules.left_after(inv, paid), Data.BUILDINGS[types[0]]["cost"])
	if short == "":
		return ""
	return (
		"Heads up: after paying for this you couldn't build the %s yet (%s more)."
		% [Data.BUILDINGS[types[0]]["name"], short.trim_prefix("need ")]
	)


## Kith not staffing a building or out scouting: they haul once Paths & Haulers is known, or wait at the Hearth.
static func idle_kith(s) -> int:
	return s.people.kith.size() - jobs_filled(s) - Scouting.count(s) - Expedition.count(s)


## The places to work: one for each person a building needs (a Mine needs two), not counting a paused building.
static func job_slots(s) -> int:
	var n := 0
	for b in s.town.buildings:
		if Buildings.needs_worker(b) and not b["paused"]:
			n += Buildings.crew_size(b)
	return n


## The places at work that a Kith holds, never more than job_slots: a Kith with any other job (hauling, scouting,
## waiting) holds none, and a place nobody holds is not counted.
static func jobs_filled(s) -> int:
	var n := 0
	for b in s.town.buildings:
		if not Buildings.needs_worker(b) or b["paused"]:
			continue
		for slot in Buildings.crew_slots(b):
			var i: int = b[slot]
			if i >= 0 and i < s.people.kith.size() and s.people.kith[i]["job"] == "work":
				n += 1
	return mini(n, job_slots(s))


## Why the population isn't growing, or "" when it is (see scripts/growth_note.gd).
static func growth_note(s) -> String:
	return GrowthNote.note(s)


static func ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)
