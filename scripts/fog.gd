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
