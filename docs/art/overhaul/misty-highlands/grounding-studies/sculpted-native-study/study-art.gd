extends RefCounted
## Rendered miniature atlas presentation. Pure visual hashing never consumes the simulation RNG.

const REGIONS := {
	"riverbank-details":
	[
		[24, 198, 475, 186],
		[532, 220, 480, 179],
		[1043, 220, 469, 169],
		[22, 561, 478, 244],
		[524, 606, 492, 217],
		[1051, 590, 468, 228]
	],
	"research-landmarks": [[38, 55, 595, 594], [638, 14, 610, 641], [32, 668, 635, 548], [665, 646, 588, 601]],
	"research-symbols": [[0, 0, 627, 627], [627, 0, 627, 627], [0, 627, 627, 627], [627, 627, 627, 627]],
	"crossings-v2":
	[
		[91, 8, 419, 224],
		[569, 36, 400, 173],
		[1032, 9, 414, 223],
		[91, 244, 419, 210],
		[570, 268, 397, 163],
		[1031, 245, 414, 209],
		[235, 450, 219, 244],
		[682, 458, 175, 236],
		[1091, 458, 216, 235],
		[235, 706, 219, 294],
		[676, 707, 188, 293],
		[1084, 708, 226, 292]
	],
	"trees": [[183, 59, 525, 476], [838, 32, 414, 504], [150, 558, 574, 479], [724, 628, 572, 409]],
	"rocks":
	[
		[47, 86, 464, 404],
		[540, 83, 470, 395],
		[1047, 171, 454, 307],
		[45, 526, 467, 416],
		[547, 551, 465, 386],
		[1054, 642, 445, 296]
	],
	"plants":
	[
		[31, 85, 329, 298],
		[388, 81, 320, 301],
		[730, 94, 337, 288],
		[22, 428, 340, 305],
		[362, 423, 356, 309],
		[736, 419, 336, 313],
		[25, 773, 337, 302],
		[362, 764, 362, 313],
		[745, 766, 326, 314],
		[24, 1116, 334, 256],
		[390, 1127, 320, 247],
		[742, 1126, 329, 247]
	],
	"buildings":
	[
		[69, 49, 347, 307],
		[523, 46, 385, 308],
		[1027, 40, 364, 322],
		[66, 364, 362, 326],
		[543, 369, 378, 321],
		[1021, 379, 392, 308],
		[35, 690, 423, 361],
		[510, 690, 433, 343],
		[1013, 700, 410, 341]
	],
	"bridges": [[91, 202, 607, 341], [769, 202, 602, 341], [1474, 202, 600, 340]],
	"walk":
	[
		[0, 0, 362, 362],
		[362, 0, 362, 362],
		[724, 0, 362, 362],
		[1086, 0, 362, 362],
		[0, 362, 362, 362],
		[362, 362, 362, 362],
		[724, 362, 362, 362],
		[1086, 362, 362, 362],
		[0, 724, 362, 362],
		[362, 724, 362, 362],
		[724, 724, 362, 362],
		[1086, 724, 362, 362]
	],
	"workshops":
	[
		[46, 8, 429, 372],
		[552, 107, 411, 273],
		[1036, 24, 364, 344],
		[34, 380, 437, 343],
		[506, 380, 452, 350],
		[1017, 389, 404, 341],
		[45, 738, 437, 324],
		[482, 730, 444, 326],
		[1005, 753, 400, 302]
	],
	"industry":
	[
		[12, 48, 498, 432],
		[536, 24, 485, 451],
		[1056, 50, 472, 462],
		[21, 558, 491, 408],
		[512, 545, 512, 418],
		[1024, 512, 475, 482]
	],
	"items":
	[
		[42, 42, 295, 214],
		[380, 54, 298, 202],
		[755, 43, 211, 213],
		[26, 256, 315, 256],
		[341, 256, 332, 244],
		[718, 256, 276, 241],
		[35, 512, 306, 249],
		[341, 522, 330, 246],
		[714, 517, 280, 251],
		[41, 769, 300, 255],
		[341, 768, 314, 256],
		[704, 768, 298, 256],
		[37, 1024, 304, 256],
		[386, 1024, 282, 256],
		[718, 1024, 273, 256],
		[33, 1280, 303, 218],
		[385, 1280, 291, 217],
		[703, 1280, 290, 213]
	],
	"extras":
	[
		[60, 103, 452, 357],
		[512, 168, 512, 282],
		[1024, 54, 440, 422],
		[21, 533, 491, 408],
		[512, 559, 512, 357],
		[1024, 599, 497, 320]
	]
}

const DIR := "res://art/rendered/"
const FEATURES := {
	"tree": ["trees", 0, 4],
	"rock": ["rocks", 0, 3],
	"plain_ore": ["rocks", 0, 3],
	"copper_hills": ["rocks", 3, 3],
	"berry": ["plants", 0, 3],
	"flax": ["plants", 3, 3],
	"flax_field": ["plants", 3, 3],
	"grain": ["plants", 6, 3],
	"clay": ["plants", 9, 3],
	"tin_stream": ["extras", 0, 1],
	"gravel": ["extras", 1, 1],
	"shard": ["extras", 2, 1],
}
const BUILDINGS := {"dwelling": 0, "gatherers_hut": 3, "camp": 6}
const SINGLE_BUILDINGS := {
	"storehouse": ["workshops", 0],
	"charcoal_pit": ["workshops", 1],
	"twine_post": ["workshops", 2],
	"kiln": ["workshops", 3],
	"water_wheel": ["workshops", 4],
	"grindstone": ["workshops", 5],
	"fishing_weir": ["workshops", 6],
	"standing_stone": ["workshops", 7],
	"shard_cairn": ["workshops", 8],
	"mine": ["industry", 0],
	"smelter": ["industry", 1],
	"crucible": ["industry", 2],
	"cart_shed": ["industry", 3],
	"trading_post": ["industry", 4],
	"watchtower": ["industry", 5],
	"stone_bridge": ["crossings-v2", 4],
}
const ITEM_IDS := [
	"wood",
	"stone",
	"flint",
	"fiber",
	"clay",
	"berries",
	"grain",
	"rope",
	"charcoal",
	"brick",
	"flour",
	"fish",
	"copper_ore",
	"tin",
	"copper",
	"bronze",
	"flint_tools",
	"bronze_tools"
]

static var map_seed := 0
static var _textures := {}
static var _sheets := {}


static func variant(p: Vector2i, count: int, family: int = 0, seed_value: int = 0) -> int:
	var value := (p.x * 374761393) ^ (p.y * 668265263) ^ (family * 1274126177) ^ seed_value
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return (value ^ (value >> 16)) % count


static func sheet(name: String) -> Texture2D:
	if not _sheets.has(name):
		if name in ["sculpted-ground", "riverbank-details"]:
			_sheets[name] = ImageTexture.create_from_image(
				Image.load_from_file(
					"res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/" + name + ".png"
				)
			)
		else:
			_sheets[name] = load(DIR + name + ".png") as Texture2D
	return _sheets[name]


static func sprite(name: String, index: int) -> AtlasTexture:
	var key := "%s:%d" % [name, index]
	if not _textures.has(key):
		var region: Array = REGIONS[name][index]
		var tex := AtlasTexture.new()
		tex.atlas = sheet(name)
		tex.region = Rect2(region[0], region[1], region[2], region[3])
		tex.filter_clip = true
		_textures[key] = tex
	return _textures[key]


static func fit(ci: CanvasItem, tex: Texture2D, box: Rect2, tint := Color.WHITE) -> void:
	var factor := minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())
	var size := tex.get_size() * factor
	var at := box.position + Vector2((box.size.x - size.x) * 0.5, box.size.y - size.y)
	ci.draw_texture_rect(tex, Rect2(at, size), false, tint)


static func feature(ci: CanvasItem, type: String, at: Vector2, p: Vector2i, time: float) -> bool:
	if not FEATURES.has(type):
		return false
	var spec: Array = FEATURES[type]
	var index := int(spec[1]) + variant(p, spec[2], type.hash(), map_seed)
	var offset := Vector2((variant(p, 5, 17) - 2) * 0.22, 0)
	if type in ["tree", "berry", "flax", "flax_field", "grain"]:
		offset.x += sin(time * 1.1 + variant(p, 31)) * 0.18
	fit(ci, sprite(spec[0], index), Rect2(at - Vector2(15, 15) + offset, Vector2(30, 30)))
	if type == "flax_field":
		for i in 3:
			ci.draw_line(at + Vector2(-12, 10 + i * 2), at + Vector2(12, 10 + i * 2), Color("63594570"), 0.7)
	return true


static func building(ci: CanvasItem, type: String, box: Rect2) -> bool:
	if SINGLE_BUILDINGS.has(type):
		var spec: Array = SINGLE_BUILDINGS[type]
		fit(ci, sprite(spec[0], spec[1]), box.grow(-1.0))
		return true
	if not BUILDINGS.has(type):
		return false
	if type == "camp":
		ci.draw_circle(box.position + box.size * Vector2(0.55, 0.86), box.size.x * 0.18, Color(1.0, 0.57, 0.14, 0.06))
	var p := Vector2i((box.position / 48.0).round())
	fit(ci, sprite("buildings", BUILDINGS[type] + variant(p, 3, type.hash(), map_seed)), box.grow(-1.0))
	return true


static func named(name: String) -> Texture2D:
	if name.begins_with("tile_") and FEATURES.has(name.trim_prefix("tile_")):
		var spec: Array = FEATURES[name.trim_prefix("tile_")]
		return sprite(spec[0], spec[1])
	if name.begins_with("item_"):
		var index := ITEM_IDS.find(name.trim_prefix("item_"))
		if index >= 0:
			return sprite("items", index)
	if SINGLE_BUILDINGS.has(name):
		var spec: Array = SINGLE_BUILDINGS[name]
		return sprite(spec[0], spec[1])
	match name:
		"tile_bridge_wood":
			return sprite("crossings-v2", 1)
		"hearth":
			return sprite("buildings", 6)
		"dwelling":
			return sprite("buildings", 0)
		"gatherers_hut":
			return sprite("buildings", 3)
		"field":
			return sprite("plants", 6)
		"flax", "flax_field":
			return sprite("plants", 3)
		"raft":
			return sprite("extras", 5)
	return null


static func kith(ci: CanvasItem, at: Vector2, identity: String, moving: bool, time: float, flip: bool) -> void:
	var row := variant(Vector2i(identity.hash(), 0), 3, 71)
	var frame := int(time * 7.0 + row) % 4 if moving else 1
	var tex := sprite("walk", row * 4 + frame)
	var size := Vector2(tex.get_width(), tex.get_height()) * (35.0 / tex.get_height())
	var box := Rect2(at - Vector2(size.x * 0.5, size.y - 3.0), size)
	if flip:
		box.position.x += box.size.x
		box.size.x = -box.size.x
	ci.draw_texture_rect(tex, box, false)
