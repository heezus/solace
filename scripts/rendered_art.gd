extends RefCounted
## Rendered miniature atlas presentation. Pure visual hashing never consumes the simulation RNG.

const REGIONS := {
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
	"coal_seam": [[22, 51, 688, 621], [734, 93, 700, 554], [1452, 165, 705, 500]],
	"iron_hills": [[46, 70, 676, 590], [745, 151, 703, 486], [1448, 264, 681, 378]],
	"spent_seam": [[19, 45, 693, 627], [728, 89, 706, 560], [1448, 158, 707, 507]],
	"coal_mine": [[61, 45, 1221, 1066]],
	"bloomery": [[80, 49, 1167, 1073]],
	"ironfall-items":
	[[30, 85, 482, 369], [551, 79, 452, 376], [1045, 116, 463, 337], [32, 585, 480, 394], [512, 536, 512, 421]],
	"tool-bench": [[0, 19, 1242, 1193]],
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
	],
	# Ironfall stage 3, Livewire and research art: one subject per image, index 0 the map region (docs/art/livewire/buildings,
	# docs/art/ironfall/stage3, docs/art/ironfall/livewire-items, docs/art/livewire/bloom-tide, docs/art/research-ironfall-livewire).
	# A second region is the research card's tighter crop of the same picture.
	"power_pole": [[346, 44, 549, 1152], [330, 38, 580, 400]],
	"generator": [[95, 59, 1088, 1150]],
	"wire_mill": [[92, 106, 1070, 1042]],
	"order_board": [[150, 91, 971, 1082]],
	"arc_lamp": [[382, 47, 485, 1131], [360, 24, 540, 470]],
	"scorcher": [[173, 192, 950, 878]],
	"factory_floor": [[87, 187, 1154, 889]],
	"shard_dynamo": [[82, 100, 1091, 1051]],
	"firebreak": [[0, 0, 1254, 1254]],
	"firebreak_corner": [[202, 192, 856, 856]],
	"firebreak_end": [[0, 0, 1254, 1254]],
	"boiler": [[288, 112, 814, 1016]],
	"shard_boiler": [[213, 152, 903, 937]],
	"forge": [[230, 48, 826, 1070]],
	"steam_shed": [[97, 93, 1116, 985]],
	"shard_lamp": [[461, 35, 333, 1178]],
	"shard_lamp_lit": [[461, 35, 333, 1178], [450, 28, 360, 525]],
	"beast_pen": [[105, 240, 1084, 829]],
	"rail": [[444, 0, 886, 886], [720, 274, 340, 340]],
	"rail_corner": [[200, 80, 900, 900]],
	"rail_t": [[385, 348, 485, 485]],
	"rail_cross": [[301, 301, 650, 650]],
	"rail_end": [[0, 182, 886, 886]],
	"steam_cart": [[191, 98, 1192, 885]],
	"beast_cart": [[186, 219, 1185, 734]],
	"wire": [[175, 81, 1000, 983]],
	"steel_tools": [[89, 86, 1168, 1032]],
	"shard": [[344, 91, 549, 1114]],
	"bloom_tide": [[0, 0, 1312, 1199]],
	"bloom_tide_field": [[0, 0, 1254, 1254]],
	"bloom_tide_wood": [[0, 0, 1312, 1199]],
	"research/teardown": [[67, 9, 1241, 1138]],
	"research/taught_hands_ii": [[243, 5, 909, 1154]],
	"research/iron_plough": [[41, 88, 1227, 1043]],
	"research/bloom_sampling": [[348, 94, 818, 919]],
	"research/livewire": [[211, 83, 914, 1039]],
	"research/tide_watch": [[130, 149, 1069, 1002]],
	"research/foremen": [[76, 188, 1127, 859]],
	"research/powered_mines": [[128, 87, 1010, 977]],
	"research/firebreaks": [[54, 215, 1183, 860]],
	"research/chain_orders": [[35, 322, 1185, 636]],
	"research/living_ground": [[230, 57, 834, 1144]],
	"research/skyward": [[358, 107, 537, 1037]],
	# Starfall: one subject per image (docs/art/starfall-buildings, -travellers, -icons).
	"starfall-glyph-wall": [[112, 318, 1061, 707]],
	"starfall-lumen-camp": [[162, 272, 977, 713]],
	"starfall-expedition-post": [[146, 122, 1059, 1026]],
	"starfall-wreck": [[80, 110, 1647, 667]],
	# The tellings (docs/art/tellings/map-relics): one subject per image, 1x1 on the map, relic icons at 20 px.
	"ruins": [[34, 186, 1199, 970]],
	"ruins_2": [[27, 113, 1201, 1016]],
	"ruins_cleared": [[21, 377, 1210, 740]],
	"bloom_dormant": [[57, 71, 1168, 1123]],
	"relic_dig": [[26, 95, 1214, 1065]],
	"first_wreck": [[72, 198, 1138, 881]],
	"first_wreck_2": [[43, 382, 1181, 597]],
	"relic_everburning_forge": [[166, 44, 957, 1142]],
	"relic_old_lantern": [[309, 23, 680, 1172]],
	"relic_founders_cart": [[49, 242, 1156, 732]],
	"starfall-lumen-strangers": [[307, 51, 319, 620], [891, 53, 368, 618], [1537, 57, 306, 614]],
	"starfall-party-pack": [[279, 270, 733, 725]],
	"starfall-icons":
	[
		[29, 64, 267, 244],
		[332, 44, 294, 271],
		[648, 29, 285, 289],
		[1014, 62, 182, 248],
		[26, 349, 275, 262],
		[329, 344, 301, 280],
		[665, 346, 284, 265],
		[998, 332, 219, 292],
		[25, 647, 271, 269],
		[335, 646, 268, 270],
		[649, 646, 271, 270],
		[964, 646, 267, 270],
		[31, 943, 268, 269],
		[337, 943, 276, 269]
	]
}

const BloomLook = preload("res://scripts/bloom_look.gd")
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
	# Ironfall: Codex's painted tiles (docs/art/ironfall/tiles). Each has three variants.
	"coal_seam": ["coal_seam", 0, 3],
	"iron_hills": ["iron_hills", 0, 3],
	"spent_seam": ["spent_seam", 0, 3],
}
## A tile that picks its variant with another tile's hash: a worked-out seam keeps the ridge shape its coal seam had.
const VARIANT_SALT := {"spent_seam": "coal_seam"}
## The tellings' tiles that have two paintings (the second is the sheet named `<id>_2`).
const TELLING_PAIRS := {"ruins": ["ruins", "ruins_2"], "first_wreck": ["first_wreck", "first_wreck_2"]}
const RELIC_ICONS := {
	"forge": "relic_everburning_forge",
	"lantern": "relic_old_lantern",
	"cart": "relic_founders_cart",
}
const BUILDINGS := {"dwelling": 0, "gatherers_hut": 3, "camp": 6}
const SINGLE_BUILDINGS := {
	"tool_bench": ["tool-bench", 0],  # Codex's painted Tool Bench (docs/art/tool-bench)
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
	"glyph_wall": ["starfall-glyph-wall", 0],
	"lumen_camp": ["starfall-lumen-camp", 0],
	"expedition_post": ["starfall-expedition-post", 0],
	# Stage 4 stand-ins: the Market borrows the Trading Post, the Guard Post the Watchtower, the shrine the Standing Stone.
	"lumen_market": ["industry", 4],
	"guard_post": ["industry", 5],
	"shared_shrine": ["workshops", 7],
	# Ironfall: Codex's painted Coal Mine and Bloomery (docs/art/ironfall/buildings).
	"coal_mine": ["coal_mine", 0],
	"bloomery": ["bloomery", 0],
	# Ironfall stage 2: the Teardown Bench borrows the Trading Post, the Rain Barrel the Twine Post (tinted, see TINTS).
	"teardown_bench": ["industry", 4],
	"rain_barrel": ["workshops", 2],
	# Ironfall stage 3: Codex's painted buildings (docs/art/ironfall/stage3). The Shard Lamp has a lit picture of its own.
	"boiler": ["boiler", 0],
	"shard_boiler": ["shard_boiler", 0],
	"forge": ["forge", 0],
	"steam_shed": ["steam_shed", 0],
	"beast_pen": ["beast_pen", 0],
	"shard_lamp": ["shard_lamp", 0],
	"shard_lamp_lit": ["shard_lamp_lit", 0],
	# Livewire: Codex's painted buildings (docs/art/livewire/buildings).
	"generator": ["generator", 0],
	"wire_mill": ["wire_mill", 0],
	"power_pole": ["power_pole", 0],
	"order_board": ["order_board", 0],
	"arc_lamp": ["arc_lamp", 0],
	"scorcher": ["scorcher", 0],
	"factory_floor": ["factory_floor", 0],
	"shard_dynamo": ["shard_dynamo", 0],
	# Starfall's Lumen buildings borrow a picture until Codex paints them (docs/art/requests.md): the Lantern the Shard Lamp, the
	# Healing House the Lumen Camp, the Grove the Twine Post and the Shardwright the Kiln (the last two tinted, see TINTS).
	"shard_lantern": ["shard_lamp", 0],
	"healing_house": ["starfall-lumen-camp", 0],
	"starfruit_grove": ["workshops", 2],
	"shardwright": ["workshops", 3],
}
## The tint of a placeholder that borrows another one's sprite, by feature or building id.
const TINTS := {
	"teardown_bench": Color(0.78, 0.7, 1.0),
	"rain_barrel": Color(0.55, 0.8, 1.0),
	"starfruit_grove": Color(1.0, 0.9, 0.45),
	"shardwright": Color(0.6, 0.85, 1.0),
}
## The fourteen Starfall icons, in the order of the "starfall-icons" regions: the three packs (Starfall.PACKS keys), the Shard,
## the four gifts (LUMEN_GIFTS keys) and the six glyph-set headings (GLYPH_SETS ids).
const STARFALL_ICONS := [
	"pack_light",
	"pack_standard",
	"pack_heavy",
	"shard",
	"gift_light",
	"gift_body",
	"gift_growth",
	"gift_craft",
	"set_name",
	"set_light",
	"set_body",
	"set_growth",
	"set_craft",
	"set_warning"
]
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

## Iron Gears, Starfruit and Shardwork have no icon of their own yet: they borrow another's, recolored (docs/art/requests.md has the slot).
const BORROWED_ITEMS := {
	"iron_gears": ["copper", Color(0.72, 0.76, 0.84)],
	"starfruit": ["berries", Color(1.0, 0.85, 0.35)],
	"shardwork": ["bronze", Color(0.62, 0.9, 1.0)],
}
## Wire, Steel Tools and the Shard, each a picture of its own (docs/art/ironfall/livewire-items). The Shard's Starfall icon
## (STARFALL_ICONS) stays for the Starfall panels; this one is the item.
const PAINTED_ITEMS := ["wire", "steel_tools", "shard"]
## Connected ground modules (Rail, Firebreak): the sheet of each shape. Every sheet is a square cell drawn with its connections
## LEFT (straight: left and right; corner: left and down; T: left, right and down; end: left), turned a quarter turn at a time.
const MODULES := {
	"rail": {"straight": "rail", "corner": "rail_corner", "end": "rail_end", "t": "rail_t", "cross": "rail_cross"},
	"firebreak": {"straight": "firebreak", "corner": "firebreak_corner", "end": "firebreak_end"},
}
## Where the empty bed of each painted cart lies, as a share of the fitted picture: x, y, width, height (cargo rides there).
const CART_BEDS := {
	"steam_cart": Rect2(0.67, 0.18, 0.22, 0.26),
	"beast_cart": Rect2(0.68, 0.10, 0.22, 0.24),
}
## The five Ironfall icons, in the order of the "ironfall-items" regions (docs/art/ironfall/items).
const IRONFALL_ITEM_IDS := ["coal", "iron_ore", "iron", "steel", "iron_tools"]
## The research cards' pictures by tech id, as [sheet, region index] (docs/art/research-ironfall-livewire/spec.json): the painted
## buildings and items reuse their own sheets, the rest have a sheet each under art/rendered/research/.
const RESEARCH := {
	"coal_seams": ["coal_seam", 0],
	"ironstone": ["iron_hills", 0],
	"teardown": ["research/teardown", 0],
	"bloomery": ["bloomery", 0],
	"boiler": ["boiler", 0],
	"beast_pen": ["beast_pen", 0],
	"iron_tools": ["ironfall-items", 4],
	"rails": ["rail", 1],
	"shard_lamps": ["shard_lamp_lit", 1],
	"taught_hands_ii": ["research/taught_hands_ii", 0],
	"blast_furnace": ["forge", 0],
	"iron_plough": ["research/iron_plough", 0],
	"shard_boiler": ["shard_boiler", 0],
	"steel": ["ironfall-items", 3],
	"bloom_sampling": ["research/bloom_sampling", 0],
	"livewire": ["research/livewire", 0],
	"power_poles": ["power_pole", 1],
	"order_board": ["order_board", 0],
	"tide_watch": ["research/tide_watch", 0],
	"generator": ["generator", 0],
	"arc_lamps": ["arc_lamp", 1],
	"foremen": ["research/foremen", 0],
	"powered_mines": ["research/powered_mines", 0],
	"factory_floor": ["factory_floor", 0],
	"scorcher": ["scorcher", 0],
	"firebreaks": ["research/firebreaks", 0],
	"shard_dynamo": ["shard_dynamo", 0],
	"chain_orders": ["research/chain_orders", 0],
	"living_ground": ["research/living_ground", 0],
	"skyward": ["research/skyward", 0],
}
const BORROWED_PX := 64  # the recolored copy's size: items are shown at 20 to 48 px

const LEAD_SPRITE_PATH := "res://art/sprites/lumen_lead.png"
const LEAD_SPRITE_REGION := Rect2(277, 92, 524, 1333)
const LUMEN_HEIGHT := 35.0  # an ordinary Lumen on the map, level with a Kith
const LEAD_HEIGHT := 38.0  # Sela, marginally taller

static var map_seed := 0
static var _textures := {}
static var _sheets := {}


static func variant(p: Vector2i, count: int, family: int = 0, seed_value: int = 0) -> int:
	var value := (p.x * 374761393) ^ (p.y * 668265263) ^ (family * 1274126177) ^ seed_value
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return (value ^ (value >> 16)) % count


static func sheet(name: String) -> Texture2D:
	if not _sheets.has(name):
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
	if BloomLook.draw(ci, type, at, p, time):  # the Bloom patches: placeholder tiles (docs/art/requests.md)
		return true
	if type == "ruins":  # what a Cataclysm leaves of the town: two paintings, told apart by the tile
		telling(ci, "ruins", at, p, 31.0)
		return true
	if not FEATURES.has(type):
		return false
	var spec: Array = FEATURES[type]
	var index := int(spec[1]) + variant(p, spec[2], String(VARIANT_SALT.get(type, type)).hash(), map_seed)
	var offset := Vector2((variant(p, 5, 17) - 2) * 0.22, 0)
	if type in ["tree", "berry", "flax", "flax_field", "grain"]:
		offset.x += sin(time * 1.1 + variant(p, 31)) * 0.18
	fit(ci, sprite(spec[0], index), Rect2(at - Vector2(15, 15) + offset, Vector2(30, 30)), TINTS.get(type, Color.WHITE))
	if type == "flax_field":
		for i in 3:
			ci.draw_line(at + Vector2(-12, 10 + i * 2), at + Vector2(12, 10 + i * 2), Color("63594570"), 0.7)
	return true


static func building(ci: CanvasItem, type: String, box: Rect2) -> bool:
	if SINGLE_BUILDINGS.has(type):
		var spec: Array = SINGLE_BUILDINGS[type]
		fit(ci, sprite(spec[0], spec[1]), box.grow(-1.0), TINTS.get(type, Color.WHITE))
		return true
	if not BUILDINGS.has(type):
		return false
	if type == "camp":
		ci.draw_circle(box.position + box.size * Vector2(0.55, 0.86), box.size.x * 0.18, Color(1.0, 0.57, 0.14, 0.06))
	var p := Vector2i((box.position / 48.0).round())
	fit(ci, sprite("buildings", BUILDINGS[type] + variant(p, 3, type.hash(), map_seed)), box.grow(-1.0))
	return true


## One of the fourteen Starfall icons (STARFALL_ICONS), or null for an id it does not know.
static func icon(id: String) -> Texture2D:
	var index := STARFALL_ICONS.find(id)
	return sprite("starfall-icons", index) if index >= 0 else null


## A Lumen stranger standing at `at` (the middle of its feet), one of three figures. The Lumen stand as tall as the Kith
## (35 px, the shared character standard, docs/design-system/mockups/character-standard.md); Sela, a hero, is a little taller.
static func stranger(ci: CanvasItem, at: Vector2, index: int) -> void:
	var lead := index % 3 == 0
	var tex: Texture2D = lead_sprite() if lead else sprite("starfall-lumen-strangers", index % 3)
	var h := LEAD_HEIGHT if lead else LUMEN_HEIGHT
	fit(ci, tex, Rect2(at + Vector2(-h * 0.5, -h), Vector2(h, h)))


## Sela, the lead stranger (stranger 0): her own one-pose sprite, cut from art/sprites/lumen_lead.png.
static func lead_sprite() -> AtlasTexture:
	if not _textures.has("lead"):
		var tex := AtlasTexture.new()
		tex.atlas = load(LEAD_SPRITE_PATH) as Texture2D
		tex.region = LEAD_SPRITE_REGION
		tex.filter_clip = true
		_textures["lead"] = tex
	return _textures["lead"]


## The expedition pack behind a Kith standing at `at`, on the side the Kith faces away from.
static func party_pack(ci: CanvasItem, at: Vector2, flip: bool) -> void:
	var side := -1.0 if flip else 1.0
	var box := Rect2(at + Vector2(3 * side - (12.0 if flip else 0.0), -21), Vector2(12, 14))
	fit(ci, sprite("starfall-party-pack", 0), box)


## A telling's 1x1 sprite `id` (TELLING_PAIRS has two paintings for some) fitted in a `box` square about `center`. Which painting a tile
## wears comes from the tile and the map, never the simulation's random numbers.
static func telling(ci: CanvasItem, id: String, center: Vector2, p: Vector2i, box: float) -> void:
	var name: String = id
	if TELLING_PAIRS.has(id):
		name = TELLING_PAIRS[id][variant(p, 2, id.hash(), map_seed)]
	fit(ci, sprite(name, 0), Rect2(center - Vector2(box, box) * 0.5, Vector2(box, box)))


## The 20 px icon of relic `id` ("forge", "lantern" or "cart", Data.ENDINGS["relics"]), or null for another id.
static func relic_icon(id: String) -> Texture2D:
	return sprite(RELIC_ICONS[id], 0) if RELIC_ICONS.has(id) else null


## The crash hull, in a centered 96x48 box at the 48 px tile.
static func wreck(ci: CanvasItem, center: Vector2) -> void:
	fit(ci, sprite("starfall-wreck", 0), Rect2(center - Vector2(48, 24), Vector2(96, 48)))


## The pieces of a `family` module (MODULES) for a tile joined on `links` (x LEFT, y RIGHT, z UP, w DOWN; above zero is joined):
## each as [sheet, quarter turns clockwise]. A lone piece runs across. A Firebreak has no T or cross, so it is a straight with
## an end laid toward the third arm, or two straights.
static func module_pieces(family: String, links: Vector4) -> Array:
	var shapes: Dictionary = MODULES[family]
	var l := links.x > 0.0
	var r := links.y > 0.0
	var u := links.z > 0.0
	var d := links.w > 0.0
	match int(l) + int(r) + int(u) + int(d):
		1:
			return [[shapes["end"], 0 if l else (1 if u else (2 if r else 3))]]
		2:
			if l and r:
				return [[shapes["straight"], 0]]
			if u and d:
				return [[shapes["straight"], 1]]
			return [[shapes["corner"], 0 if (l and d) else (1 if (l and u) else (2 if (r and u) else 3))]]
		3:
			if shapes.has("t"):
				return [[shapes["t"], 0 if not u else (1 if not r else (2 if not d else 3))]]
			var across := 0 if (l and r) else 1
			var third := (3 if d else 1) if across == 0 else (2 if r else 0)
			return [[shapes["straight"], across], [shapes["end"], third]]
		4:
			if shapes.has("cross"):
				return [[shapes["cross"], 0]]
			return [[shapes["straight"], 0], [shapes["straight"], 1]]
	return [[shapes["straight"], 0]]


## A `family` module drawn over `cell`, the whole square sample stretched to it and turned for the sides it joins.
static func module(ci: CanvasItem, family: String, links: Vector4, cell: Rect2) -> void:
	for piece in module_pieces(family, links):
		ci.draw_set_transform(cell.get_center(), float(piece[1]) * PI / 2.0, Vector2.ONE)
		ci.draw_texture_rect(sprite(piece[0], 0), Rect2(-cell.size * 0.5, cell.size), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A painted cart (a CART_BEDS key) fitted into `box`, with `cargo` in its bed when it has any.
static func cart(ci: CanvasItem, stem: String, box: Rect2, cargo: Texture2D = null) -> void:
	var tex := sprite(stem, 0)
	fit(ci, tex, box)
	if cargo != null:
		var factor := minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())
		var size := tex.get_size() * factor
		var at := box.position + Vector2((box.size.x - size.x) * 0.5, box.size.y - size.y)
		var bed: Rect2 = CART_BEDS[stem]
		fit(ci, cargo, Rect2(at + size * bed.position, size * bed.size))


## The Bloom tide's young growth on one ground tile `cell`: the sheet of what the tile was (a Field, a wood, or grass).
static func tide_ground(ci: CanvasItem, cell: Rect2, former: String, p: Vector2i) -> void:
	var stem := "bloom_tide" if former == "" else "bloom_tide_" + former
	var tex := sprite(stem, 0)
	if variant(p, 2, 43, map_seed) == 1:
		ci.draw_texture_rect(tex, Rect2(cell.end.x, cell.position.y, -cell.size.x, cell.size.y), false)
	else:
		ci.draw_texture_rect(tex, cell, false)


## The research card picture of tech `id` (RESEARCH), or null for a tech with none.
static func research(id: String) -> Texture2D:
	if not RESEARCH.has(id):
		return null
	var spec: Array = RESEARCH[id]
	return sprite(spec[0], spec[1])


## The borrowed icon of `id` (BORROWED_ITEMS), recolored once and kept; null for a good that is not borrowed.
static func borrowed_item(id: String) -> Texture2D:
	if not BORROWED_ITEMS.has(id):
		return null
	var key := "borrowed_" + id
	if not _textures.has(key):
		var spec: Array = BORROWED_ITEMS[id]
		var from: AtlasTexture = (
			sprite("items", ITEM_IDS.find(spec[0]))
			if spec[0] in ITEM_IDS
			else sprite("ironfall-items", IRONFALL_ITEM_IDS.find(spec[0]))
		)
		var img: Image = from.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var scale := float(BORROWED_PX) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(roundi(img.get_width() * scale), 1), maxi(roundi(img.get_height() * scale), 1))
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * spec[1].r, c.g * spec[1].g, c.b * spec[1].b, c.a))
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


static func named(name: String) -> Texture2D:
	if name.begins_with("tile_") and FEATURES.has(name.trim_prefix("tile_")):
		var spec: Array = FEATURES[name.trim_prefix("tile_")]
		return sprite(spec[0], spec[1])
	if name.begins_with("item_"):
		var index := ITEM_IDS.find(name.trim_prefix("item_"))
		if index >= 0:
			return sprite("items", index)
		var ironfall := IRONFALL_ITEM_IDS.find(name.trim_prefix("item_"))
		if ironfall >= 0:
			return sprite("ironfall-items", ironfall)
		if name.trim_prefix("item_") in PAINTED_ITEMS:
			return sprite(name.trim_prefix("item_"), 0)
		if BORROWED_ITEMS.has(name.trim_prefix("item_")):
			return borrowed_item(name.trim_prefix("item_"))
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
