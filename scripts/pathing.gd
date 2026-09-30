extends RefCounted
## The Pathing block: the walking grid, A* over it, and what each tile costs to cross. It reads the World
## (tiles and roads) and never writes it. The two facts it needs from research, paved roads and rafts, come
## in as a read-only callable: has_tech.call(tech_id) -> bool. GameState owns one and passes the old
## walking methods through to it. Moving Kith along a path is the Kith block's job, not this one's.

const Data = preload("res://scripts/data.gd")
const World = preload("res://scripts/world.gd")

var astar := AStarGrid2D.new()  # river tiles are solid unless a road (a bridge) or Rafts lets you cross
var _world: World
var _has_tech: Callable  # (String) -> bool: is that tech researched?


func _init(world: World, has_tech: Callable) -> void:
	_world = world
	_has_tech = has_tech


## Size the grid to the World and fill it. Call once the map exists.
func build() -> void:
	astar.region = Rect2i(0, 0, _world.width, _world.height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	refresh()


## Re-read every cell (a tech such as Rafts changed what is walkable everywhere).
func refresh() -> void:
	for y in _world.height:
		for x in _world.width:
			update_cell(Vector2i(x, y))


## Re-read one cell after its tile or road changed.
func update_cell(p: Vector2i) -> void:
	var t := _world.tile_at(p)
	astar.set_point_solid(p, t == "river" and not _world.roads.has(p) and not _has_tech.call("rafts"))
	astar.set_point_weight_scale(p, walk_cost(p))


## Relative time to cross a tile: roads are fast, forest and rocks are slow, rafting a river slower.
func walk_cost(p: Vector2i) -> float:
	if _world.roads.has(p):
		return Data.WALK_COST["road"] / (2.0 if _has_tech.call("paved_roads") else 1.0)
	return Data.WALK_COST.get(_world.tile_at(p), 1.0)


## The tiles to walk from `from` to `to`, both ends included, or [] when there is no way. The start
## counts as open even if it is blocked (someone standing on a tile that was just blocked may step off).
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var was := astar.is_point_solid(from)
	astar.set_point_solid(from, false)
	var found := astar.get_id_path(from, to)
	astar.set_point_solid(from, was)
	return found
