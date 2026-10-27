extends RefCounted
## The tellings' map pieces that lie over the ground (docs/art/tellings/map-relics): the first ship's hull where a Kith party found it
## (Starfall.old_ship), the swept ground where a Cataclysm's ruin was cleared, and the dormant Bloom of a patch until the tide wakes.
## A standing ruin is a tile (Rendered.feature) and the dig under a crew is drawn with the relic marks (Overlays.relic_marks).
## Static: `ci` is the map (map px, Overlays.TILE a tile), `s` the Sim. Fog hides each piece as it hides the ground.

const Overlays = preload("res://scripts/overlays.gd")
const Rendered = preload("res://scripts/rendered_art.gd")
const Ruins = preload("res://scripts/ruins.gd")

const BOX := 46.0  # a 1x1 piece in the 48 px tile


static func draw(ci: CanvasItem, s) -> void:
	_swept(ci, s)
	_dormant(ci, s)
	_old_ship(ci, s)


## Ground a ruin was cleared from: bare swept stone where nothing was built since.
static func _swept(ci: CanvasItem, s) -> void:
	for r in s.carry.ruins:
		var p := Ruins.tile_of(r)
		if (
			s.world.tile_at(p) == "grass"
			and s.fog.is_revealed(p)
			and s.town.built_type(p) == ""
			and not s.world.roads.has(p)
		):
			Rendered.telling(ci, "ruins_cleared", Overlays.center(p), p, BOX)


## The Bloom patches a Cataclysm left, asleep: closed buds, until the tide begins and they spread like any Bloom.
static func _dormant(ci: CanvasItem, s) -> void:
	if s.tide.begun:
		return
	for a in s.carry.patches:
		for p in [Ruins.tile_of(a), Ruins.tile_of(a) + Vector2i(1, 0)]:
			if s.world.tile_at(p) == "bloom_ground" and s.fog.is_revealed(p):
				Rendered.telling(ci, "bloom_dormant", Overlays.center(p), p, BOX)


## The first ship's site, once a party has lifted the fog there: the hull under the moss.
static func _old_ship(ci: CanvasItem, s) -> void:
	var w: Vector2i = s.starfall.old_ship
	if w.x >= 0 and s.starfall.old_ship_found and s.fog.is_revealed(w):
		Rendered.telling(ci, "first_wreck", Overlays.center(w), w, BOX)
