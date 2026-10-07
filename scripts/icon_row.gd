extends RefCounted
## A Starfall icon beside a panel line (Rendered.icon): the picture at a fixed square, and its name on hover.

const Rendered = preload("res://scripts/rendered_art.gd")

const SIZE := 24.0


## `body` with the icon `id` to its left, or `body` alone when the icon is unknown. `hover` names what the picture shows.
static func wrap(id: String, body: Control, hover: String) -> Control:
	var tex := Rendered.icon(id)
	if tex == null:
		return body
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(SIZE, SIZE)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.tooltip_text = hover
	pic.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(pic)
	row.add_child(body)
	return row
