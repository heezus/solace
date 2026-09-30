extends RefCounted
## Makes a new map: a river down the east side, scattered resources, the Hearth and the Strange Stone.
## Static, and works on the World passed in: it sets the tiles, camp_pos and shard_pos, nothing more (the
## Hearth building, the fog, the walk grid and the first Kith are set up by whoever owns the World).

const Data = preload("res://scripts/data.gd")

## The flax patch every map gets near the Hearth (offsets from it), within a hut's reach of it.
const FLAX_PATCH := [Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(-2, -4)]


## `s` is the World; the map is as big as it is.
static func generate(s, seed_value: int) -> void:
	var w: int = s.width
	var h: int = s.height
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	s.reset("grass")

	# A meandering river down the right third of the map, with gravel and clay banks.
	var rx := int(w * 0.7)
	for y in h:
		rx = clampi(rx + rng.randi_range(-1, 1), int(w * 0.6), w - 4)
		s.set_tile(Vector2i(rx, y), "river")
		s.set_tile(Vector2i(rx + 1, y), "river")
		for side in [Vector2i(rx - 1, y), Vector2i(rx + 2, y)]:
			var roll := rng.randf()
			if roll < 0.25:
				s.set_tile(side, "gravel")
			elif roll < 0.5:
				s.set_tile(side, "clay")

	_scatter(s, w, h, rng, "tree", 7, 3, 0.75)
	_scatter(s, w, h, rng, "rock", 5, 2, 0.7)
	_scatter(s, w, h, rng, "berry", 4, 1, 0.8)
	_scatter(s, w, h, rng, "grain", 4, 2, 0.7)
	_scatter(s, w, h, rng, "flax", 5, 1, 0.75)  # wild flax in patches on open grassland, anywhere

	# Clear the Hearth and the ground around it.
	var camp := Vector2i(int(w / 3.0), int(h / 2.0))
	s.camp_pos = camp
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := camp + Vector2i(dx, dy)
			if s.in_bounds(p) and s.tile_at(p) != "river":
				s.set_tile(p, "grass")
	# Guarantee every resource near the Hearth so the opening never stalls.
	s.set_tile(camp + Vector2i(-3, -1), "tree")
	s.set_tile(camp + Vector2i(-3, 0), "tree")
	for off in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3)]:  # a small outcrop: every tier costs Stone
		s.set_tile(camp + off, "rock")
	for off in [Vector2i(-2, 3), Vector2i(-1, 3), Vector2i(-2, 4)]:  # a berry patch: food for the first Kith
		s.set_tile(camp + off, "berry")
	s.set_tile(camp + Vector2i(2, -3), "grain")
	# A patch of wild flax: Fiber comes only from flax, and Cordage needs it early.
	for off in FLAX_PATCH:
		s.set_tile(camp + off, "flax")
	# Flint mostly lies on the river banks, out in the fog, so a little crops out near the Hearth too:
	# Knapping needs it before anything can be built out there.
	s.set_tile(camp + Vector2i(4, 0), "gravel")
	s.set_tile(camp + Vector2i(4, 1), "gravel")

	# One ancient star shard, far from home.
	for attempt in 200:
		var p := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if s.tile_at(p) == "grass" and p.distance_to(camp) > 10:
			s.set_tile(p, "shard")
			s.shard_pos = p
			break


static func _scatter(
	s, w: int, h: int, rng: RandomNumberGenerator, tile: String, count: int, radius: int, density: float
) -> void:
	for i in count:
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var p := c + Vector2i(dx, dy)
				if s.in_bounds(p) and s.tile_at(p) == "grass" and rng.randf() < density:
					s.set_tile(p, tile)
