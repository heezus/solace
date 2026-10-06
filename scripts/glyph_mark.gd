extends Control
## One glyph, drawn from its strokes (Data.GLYPHS: lines in a unit square) so it needs no art. Used in the Glyph Wall's
## panel (scripts/glyph_picker.gd).

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

var glyph := ""
var read := false  # the set is read: the mark is drawn in the good color


func setup(id: String) -> void:
	glyph = id
	custom_minimum_size = Vector2(30, 30)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not Data.GLYPHS.has(glyph):
		return
	var box := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	draw_rect(Rect2(Vector2.ZERO, size), Ui.PANEL)
	var color := Ui.GOOD if read else Ui.TEXT
	for stroke in Data.GLYPHS[glyph]["strokes"]:
		var points := PackedVector2Array()
		for p in stroke:
			points.append(box.position + Vector2(p[0], p[1]) * box.size)
		draw_polyline(points, color, 2.0)
