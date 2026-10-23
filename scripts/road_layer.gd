extends RefCounted
## Gravel and paved roads, drawn with Codex's connected-road material (GrowthArt.road_shader_material). A plain path is
## still the terrain's own worn strip (WorldGround); the upper tiers lie over it, one small node a tile so each can
## carry its own tier and connections. Rail (Ironfall) is the paved road with Codex's painted rail pieces (straight, corner, T,
## cross, end: Rendered.module) laid over it. The nodes sit with the terrain, beneath everything Main draws.

const Data = preload("res://scripts/data.gd")
const GrowthArt = preload("res://scripts/growth_art.gd")
const Rendered = preload("res://scripts/rendered_art.gd")
const TILE := 48.0
const SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _holder: Node2D
var _tiles := {}  # Vector2i -> Node2D, one for each revealed gravel or paved land tile
var _key := -1


## Bring the tile nodes in line with the town. Call after the terrain has drawn, so these nodes come after it.
func sync(ci: CanvasItem, s) -> void:
	if _holder == null:
		_holder = Node2D.new()
		_holder.name = "RoadTiers"
		_holder.z_index = -1
		ci.add_child(_holder)
	var key: int = hash([s.world.road_tiers, s.world.roads, s.town.road_rev, s.fog.cells])
	if key == _key:
		return
	_key = key
	for p in _tiles.keys():
		if not _wanted(s, p):
			_tiles[p].queue_free()
			_tiles.erase(p)
	for p in s.world.road_tiers:
		if _wanted(s, p):
			_set_tile(s, p)


func _wanted(s, p: Vector2i) -> bool:
	return s.world.road_tier(p) > 0 and s.world.roads.has(p) and s.world.tile_at(p) != "river" and s.fog.is_revealed(p)


func _set_tile(s, p: Vector2i) -> void:
	var tier: int = s.world.road_tier(p)
	var links := Vector4()
	for n in SIDES.size():
		var q: Vector2i = p + SIDES[n]
		if s.fog.is_revealed(q) and (s.world.roads.has(q) or s.town.building_at.has(q)):
			links[n] = 1.0
	var origin := Vector2(p) * TILE
	var node: Node2D = _tiles.get(p)
	if node == null:
		node = Node2D.new()
		node.position = origin
		node.draw.connect(func(): node.draw_rect(Rect2(Vector2.ZERO, Vector2(TILE, TILE)), Color.WHITE))
		node.material = GrowthArt.road_shader_material(mini(tier, Data.PAVED_TIER), links, origin, TILE)
		_holder.add_child(node)
		_tiles[p] = node
	else:
		var material := node.material as ShaderMaterial
		material.set_shader_parameter("tier", float(mini(tier, Data.PAVED_TIER)))
		material.set_shader_parameter("connections", links)
	_set_rails(_tiles[p], tier == Data.RAIL_TIER, _rail_links(s, p))


## Rail: a child node that draws the iron over the paved tile, added when the tile becomes rail and dropped if it stops being.
func _set_rails(node: Node2D, rail: bool, links: Vector4) -> void:
	var over: Node2D = node.get_node_or_null("Rails")
	if not rail:
		if over != null:
			over.queue_free()
			node.remove_child(over)
		return
	if over == null:
		over = Node2D.new()
		over.name = "Rails"
		over.draw.connect(func(): _draw_rails(over))
		node.add_child(over)
	over.set_meta("links", links)
	over.queue_redraw()


## Which sides of tile `p` a line of `type` joins (x LEFT, y RIGHT, z UP, w DOWN): the neighbours built as the same type.
static func joined(s, p: Vector2i, type: String) -> Vector4:
	var links := Vector4()
	for n in SIDES.size():
		if s.town.built_type(p + SIDES[n]) == type:
			links[n] = 1.0
	return links


## The sides a piece of rail joins: another piece of rail, or a Steam Shed (where the rail begins).
func _rail_links(s, p: Vector2i) -> Vector4:
	var links := Vector4()
	for n in SIDES.size():
		var q: Vector2i = p + SIDES[n]
		if not s.fog.is_revealed(q):
			continue
		var shed: bool = s.town.building_at.has(q) and Data.BUILDINGS[s.town.built_type(q)]["kind"] == "shed"
		if shed or (s.world.roads.has(q) and s.world.road_tier(q) == Data.RAIL_TIER):
			links[n] = 1.0
	return links


static func _draw_rails(over: Node2D) -> void:
	Rendered.module(over, "rail", over.get_meta("links"), Rect2(Vector2.ZERO, Vector2(TILE, TILE)))
