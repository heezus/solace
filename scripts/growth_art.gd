extends RefCounted
## Pure visual slots for Claude's needs/logistics hooks. Never reads or mutates game state.

const Rendered = preload("res://scripts/rendered_art.gd")
const HOUSES = preload("res://art/rendered/growth-houses.png")
const SCAFFOLD = preload("res://art/rendered/growth-scaffold.png")
const HAND_CART = preload("res://art/rendered/growth-hand-cart.png")
const ROADS = preload("res://art/rendered/growth-roads.png")
const ROAD_SHADER = preload("res://art/rendered/growth-road.gdshader")
const REGIONS := {
	"homestead": Rect2(61, 148, 754, 618),
	"longhouse": Rect2(815, 128, 937, 657),
	"upgrade_scaffold": Rect2(135, 49, 1208, 953),
	"hand_cart": Rect2(195, 194, 1150, 775),
	"path": Rect2(0, 0, 724, 724),
	"gravel": Rect2(724, 0, 724, 724),
	"paved": Rect2(1448, 0, 724, 724),
}
const HOUSE_NAMES := ["dwelling", "homestead", "longhouse"]
const ROAD_NAMES := ["path", "gravel", "paved"]
static var _sprites: Dictionary = {}


static func named(slot: String) -> Texture2D:
	if slot == "dwelling":
		return Rendered.named("dwelling")
	if not REGIONS.has(slot):
		return null
	if not _sprites.has(slot):
		var tex := AtlasTexture.new()
		match slot:
			"homestead", "longhouse":
				tex.atlas = HOUSES
			"upgrade_scaffold":
				tex.atlas = SCAFFOLD
			"hand_cart":
				tex.atlas = HAND_CART
			_:
				tex.atlas = ROADS
		tex.region = REGIONS[slot]
		tex.filter_clip = true
		_sprites[slot] = tex
	return _sprites[slot]


## House tiers are 1-based; caller chooses the researched/built tier. All fit the original cell.
static func house(tier: int) -> Texture2D:
	return named(HOUSE_NAMES[clampi(tier, 1, 3) - 1])


## Road tiers are 0-based, matching path/gravel/paved. These are materials, not rectangular map stamps.
static func road_material(tier: int) -> Texture2D:
	return named(ROAD_NAMES[clampi(tier, 0, 2)])


static func draw_house(ci: CanvasItem, tier: int, box: Rect2) -> void:
	if tier <= 1:
		Rendered.building(ci, "dwelling", box)  # preserve the existing tier's coordinate variants and scale
	else:
		Rendered.fit(ci, house(tier), box)


## Call after drawing the building; the transparent center preserves the house underneath.
static func draw_scaffold(ci: CanvasItem, box: Rect2) -> void:
	Rendered.fit(ci, named("upgrade_scaffold"), box)


## Single worker plus empty cart. Goods stay a caller-supplied illustration; no carry rules live here.
static func draw_hand_cart(ci: CanvasItem, box: Rect2, cargo: Texture2D = null) -> void:
	var tex := named("hand_cart")
	Rendered.fit(ci, tex, box)
	if cargo != null:
		var factor := minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())
		var size := tex.get_size() * factor
		var at := box.position + Vector2((box.size.x - size.x) * 0.5, box.size.y - size.y)
		Rendered.fit(ci, cargo, Rect2(at + size * Vector2(0.62, 0.19), size * Vector2(0.22, 0.25)))


## Apply to a tile-sized draw_texture_rect; its UV is 0..1. Caller supplies revealed connectivity.
## Reuse the material on a persistent visual node; do not allocate it on every redraw.
static func road_shader_material(tier: int, connections: Vector4, origin: Vector2, tile_size := 48.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ROAD_SHADER
	material.set_shader_parameter("road_atlas", ROADS)
	material.set_shader_parameter("tier", float(clampi(tier, 0, 2)))
	material.set_shader_parameter("connections", connections)
	material.set_shader_parameter("tile_origin", origin)
	material.set_shader_parameter("tile_size", tile_size)
	return material
