extends RefCounted
## Fog of war: which tiles the Kith have seen. Buildings, roads and walking Kith lift it.

var width := 0
var height := 0
var cells := PackedByteArray()  # 1 where the fog has lifted, index = y * width + x


func setup(w: int, h: int) -> void:
	width = w
	height = h
	cells.resize(w * h)
	cells.fill(0)


func is_revealed(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height and cells[p.y * width + p.x] == 1


## Lift the fog within `radius` tiles of p (a rounded circle).
func reveal(p: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var q := p + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < width and q.y < height and dx * dx + dy * dy <= radius * radius + radius:
				cells[q.y * width + q.x] = 1


func reveal_all() -> void:
	cells.fill(1)


func count() -> int:
	var n := 0
	for v in cells:
		n += v
	return n


# --- Save --------------------------------------------------------------------


## The size and one character a tile, "1" where the fog has lifted and "0" where it hasn't, row by row.
func to_dict() -> Dictionary:
	var text := ""
	for v in cells:
		text += "1" if v == 1 else "0"
	return {"width": width, "height": height, "cells": text}


## Restore what to_dict wrote. A save whose cells don't fit its size comes back fully fogged.
func from_dict(d: Dictionary) -> void:
	setup(int(d.get("width", 0)), int(d.get("height", 0)))
	var text := String(d.get("cells", ""))
	if text.length() != cells.size():
		return
	for i in cells.size():
		if text[i] == "1":
			cells[i] = 1
