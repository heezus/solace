extends RefCounted
## Static UI helpers shared by the HUD, the building panel and the tech tree.
## Everything is built in code, so these keep the look in one place.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Rules = preload("res://scripts/rules.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")

const OUTLINE: Color = Art.OUTLINE
const BAD := Color("ef476f")
const SHORT := Color("ff6f61")  # a count the stockpile falls short of
const GOOD := Color("9fe39f")  # the `positive` token
const HIGHLIGHT := Color("ffd166")
const PANEL := Color("1d3557")
const BAR := Color("264653")
const CARD := Color("32607f")


static func label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


## A small caption, used for "Build:" and similar headings.
static func heading(text: String) -> Label:
	var l := label(text, 13)
	l.add_theme_color_override("font_color", Color("a8dadc"))
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


## WCAG contrast ratio between two opaque colours, 1 (none) to 21.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


static func panel_style(color: Color, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = OUTLINE
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


## A small outlined color square, used as a button icon.
static func swatch_texture(color: Color) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(2, 2, 8, 8), color)
	return ImageTexture.create_from_image(img)


## A colored square for an item: the stand-in when its sprite is missing.
static func item_swatch(id: String, size: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Data.ITEMS[id]["color"]
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
		l.add_theme_color_override("font_color", Color.WHITE if inv.get(id, 0) >= cost[id] else SHORT)
		i += 1


static func tech_color(tech: String) -> Color:
	return Data.TECHS[tech]["color"] if Data.TECHS.has(tech) else Color("e76f51")


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
		return Color(1, 1, 1, 0.5)
	return GOOD if per_min > 0.0 else BAD


## A tech's colored square with its two-letter code.
static func badge(tech: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel_style(tech_color(tech), 2)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(26, 22)
	var l := label(Data.TECHS[tech]["abbr"], 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
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


## What the buildings a tech unlocks cost to put up: "Then builds for: 10 Wood, 5 Stone", or with several
## "Then builds Road for 2 Wood, Wooden Bridge for 10 Wood, 2 Rope". "" for a tech that unlocks no building.
static func then_builds_text(tech: String) -> String:
	var types := Rules.buildings_of(tech)
	if types.size() == 1:
		return "Then builds for: " + cost_text(Data.BUILDINGS[types[0]]["cost"])
	var parts: Array = types.map(
		func(t): return "%s for %s" % [Data.BUILDINGS[t]["name"], cost_text(Data.BUILDINGS[t]["cost"])]
	)
	return "" if parts.is_empty() else "Then builds " + ", ".join(parts)


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


## Kith not staffing a building: they haul once Paths & Haulers is known, or wait at the Hearth.
static func idle_kith(s) -> int:
	var n := 0
	for k in s.people.kith:
		if k["job"] != "work":
			n += 1
	return n


## Why the population isn't growing, or "" when it is (see scripts/growth_note.gd).
static func growth_note(s) -> String:
	return GrowthNote.note(s)


static func ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)
