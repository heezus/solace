extends RefCounted
## Makes a new map: a river down the east side, scattered resources, the Hearth and the Strange Stone.
## Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")

## The flax patch every map gets near the Hearth (offsets from it), within a hut's reach of it.
const FLAX_PATCH := [Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(-2, -4)]


## `s` is the GameState; w and h are its map size.
static func generate(s, seed_value: int, w: int, h: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	s.tiles.clear()
	s.tiles.resize(w * h)
	s.tiles.fill("grass")
	s.fog.setup(w, h)

	# A meandering river down the right third of the map, with gravel and clay banks.
	var rx := int(w * 0.7)
	for y in h:
		rx = clampi(rx + rng.randi_range(-1, 1), int(w * 0.6), w - 4)
		s._set_tile(Vector2i(rx, y), "river")
		s._set_tile(Vector2i(rx + 1, y), "river")
		for side in [Vector2i(rx - 1, y), Vector2i(rx + 2, y)]:
			var roll := rng.randf()
			if roll < 0.25:
				s._set_tile(side, "gravel")
			elif roll < 0.5:
				s._set_tile(side, "clay")

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
				s._set_tile(p, "grass")
	# Guarantee every resource near the Hearth so the opening never stalls.
	s._set_tile(camp + Vector2i(-3, -1), "tree")
	s._set_tile(camp + Vector2i(-3, 0), "tree")
	s._set_tile(camp + Vector2i(3, 2), "rock")
	s._set_tile(camp + Vector2i(-2, 3), "berry")
	s._set_tile(camp + Vector2i(2, -3), "grain")
	# A patch of wild flax: Fiber comes only from flax, and Cordage needs it early.
	for off in FLAX_PATCH:
		s._set_tile(camp + off, "flax")
	# Flint mostly lies on the river banks, out in the fog, so a little crops out near the Hearth too:
	# Knapping needs it before anything can be built out there.
	s._set_tile(camp + Vector2i(4, 0), "gravel")
	s._set_tile(camp + Vector2i(4, 1), "gravel")
	s._place_building("camp", camp)
	s._build_walk_grid()
	s.fog.reveal(camp, Data.SIGHT_START)
	s.kith.clear()
	for i in Data.KITH_START:
		s._add_kith()

	# One ancient star shard, far from home.
	for attempt in 200:
		var p := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if s.tile_at(p) == "grass" and p.distance_to(camp) > 10 and not s.building_at.has(p):
			s._set_tile(p, "shard")
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
					s._set_tile(p, tile)
