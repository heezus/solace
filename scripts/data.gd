extends RefCounted
## Static game data for the stone-age first playable.
## Canon lives in the design system (design-system/08-first-playable.md); keep names in sync with its glossary.

# --- Items -----------------------------------------------------------------

const ITEMS := {
	"wood": {"name": "Wood", "color": Color("8b5a2b")},
	"stone": {"name": "Stone", "color": Color("9aa0a6")},
	"flint": {"name": "Flint", "color": Color("4a4e69")},
	"fiber": {"name": "Fiber", "color": Color("a7c957")},
	"clay": {"name": "Clay", "color": Color("c8553d")},
	"berries": {"name": "Berries", "color": Color("d62246")},
	"grain": {"name": "Grain", "color": Color("e9c46a")},
	"rope": {"name": "Rope", "color": Color("bc8a5f")},
	"charcoal": {"name": "Charcoal", "color": Color("2b2d42")},
	"brick": {"name": "Brick", "color": Color("b5543a")},
	"flour": {"name": "Flour", "color": Color("f1e3c8")},
	"flint_tools": {"name": "Flint Tools", "color": Color("6c757d")},
	"fish": {"name": "Fish", "color": Color("5fa8d3")},
}

## Order items appear in the top bar.
const ITEM_ORDER := [
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
	"flint_tools",
	"fish",
]

## Food value of each edible item. The Kith eat from the stockpile.
const FOOD_VALUE := {"berries": 1.0, "fish": 2.0, "flour": 3.0}
## The order the Kith eat in. Flour comes last, and only what research doesn't need.
const EAT_ORDER := ["berries", "fish", "flour"]

# --- The Kith (population) ---------------------------------------------------

## Food each Kith eats per second.
const FOOD_PER_KITH_PER_SEC := 0.02
const KITH_START := 3
## A new Kith is born every GROW_TIME seconds while there is room and food to spare. Birth costs BIRTH_FOOD.
const GROW_TIME := 12.0
const BIRTH_FOOD := 5.0
## After this long with no food, one Kith leaves.
const STARVE_TIME := 20.0
## Tiles per second on open ground. Roads double it; forest and rocks halve it.
const KITH_SPEED := 2.0
## Items a hauler carries per trip.
const CARRY := 5
## Path cost of each tile kind. Rivers are impassable without a road (bridge), or slow once Rafts are known.
const WALK_COST := {"tree": 2.0, "rock": 2.0, "road": 0.5, "river": 4.0}

# --- Map tiles ---------------------------------------------------------------

const TILES := {
	"grass": {"name": "Grassland", "yields": "fiber", "color": Color("7cb342"), "buildable": true},
	"tree": {"name": "Forest", "yields": "wood", "color": Color("2e7d32"), "buildable": false},
	"rock": {"name": "Rocks", "yields": "stone", "color": Color("8d8d8d"), "buildable": false},
	"gravel": {"name": "Riverbed Gravel", "yields": "flint", "color": Color("b0a18a"), "buildable": false},
	"clay": {"name": "Clay Bank", "yields": "clay", "color": Color("c47a5a"), "buildable": false},
	"berry": {"name": "Berry Bushes", "yields": "berries", "color": Color("558b2f"), "buildable": false},
	"grain": {"name": "Wild Grain", "yields": "grain", "color": Color("d4b44a"), "buildable": false},
	"river": {"name": "River", "yields": "", "color": Color("3a86c8"), "buildable": false},
	"shard": {"name": "Strange Stone", "yields": "", "color": Color("7cb342"), "buildable": false},
}

const SHARD_TEXT := (
	"A smooth stone, faintly warm, humming with a pale light no fire gave it. "
	+ "The elders say it fell from the sky before memory. It does nothing. Yet."
)

# --- Tech tree ---------------------------------------------------------------
## A web, not a line: every node past the roots needs another node.
## `pos` is the node's place in the tech tree view: x = column (tier), y = row. Row 7 is the Lore lane.
## `requires` must all be researched; `requires_any` (optional) needs just one of its techs.
## `effect` marks a tech whose bonus GameState applies while it is researched.
## `hidden` techs stay out of the tree until the player has clicked the Strange Stone.

## Tech bonuses GameState applies.
const STORYTELLING_GROW := 0.75  # grow time multiplier
const OCHRE_SPEED := 1.1  # Gatherer's Hut workers
const STANDING_STONE_SPEED := 1.15  # buildings in a Standing Stone's radius
const CALENDAR_FIELD_BONUS := 0.25  # extra yield from Fields
const SMOKED_BERRY_FOOD := 2.0
const BAKED_FLOUR_FOOD := 5.0

const TECHS := {
	"foraging":
	{
		"abbr": "Fo",
		"color": Color("d62246"),
		"name": "Foraging",
		"pos": Vector2(0, 0),
		"requires": [],
		"cost": {"berries": 5, "fiber": 10},
		"desc": "Know the good bushes. Berries gather twice as fast, by hand and by hut.",
	},
	"knapping":
	{
		"abbr": "Kn",
		"color": Color("6c757d"),
		"name": "Knapping",
		"pos": Vector2(0, 1.5),
		"requires": [],
		"cost": {"flint": 5, "stone": 10},
		"desc": "Shape flint. Craft Flint Tools to gather twice as much by hand.",
	},
	"cordage":
	{
		"abbr": "Co",
		"color": Color("bc8a5f"),
		"name": "Cordage",
		"pos": Vector2(0, 3),
		"requires": [],
		"cost": {"fiber": 15},
		"desc": "Twist fiber into rope, by hand or at a Twine Post.",
	},
	"fire":
	{
		"abbr": "Fi",
		"color": Color("e85d04"),
		"name": "Fire",
		"pos": Vector2(0, 4.5),
		"requires": [],
		"cost": {"wood": 10, "stone": 5},
		"desc": "Tame flame. Smoulder wood into charcoal in a Charcoal Pit.",
	},
	"storytelling":
	{
		"abbr": "St",
		"color": Color("7b2cbf"),
		"name": "Storytelling",
		"pos": Vector2(0, 7),
		"requires": [],
		"cost": {"berries": 10, "fiber": 10},
		"effect": "storytelling",
		"desc": "Tales around the fire hold the camp together. New Kith are born 25% faster.",
	},
	"gatherers_hut":
	{
		"abbr": "GH",
		"color": Color("f4a261"),
		"name": "Gatherer's Hut",
		"pos": Vector2(1, 0),
		"requires": ["knapping"],
		"cost": {"wood": 20, "stone": 10},
		"desc": "Your first self-running building. Its worker walks out to nearby resources.",
	},
	"water_wheel":
	{
		"abbr": "WW",
		"color": Color("2a9d8f"),
		"name": "Water Wheel",
		"pos": Vector2(1, 1),
		"requires": ["cordage", "knapping"],
		"cost": {"rope": 10, "wood": 40, "stone": 20},
		"desc": "Harness the river. Powers machines within 3 tiles.",
	},
	"masonry":
	{
		"abbr": "Ma",
		"color": Color("9aa0a6"),
		"name": "Masonry",
		"pos": Vector2(1, 2),
		"requires": ["knapping", "fire"],
		"cost": {"stone": 40, "charcoal": 5},
		"desc": "Dress and fit stone. Needed for millstones, paved roads and megaliths.",
	},
	"shelter":
	{
		"abbr": "Sh",
		"color": Color("a3b18a"),
		"name": "Thatched Roofs",
		"pos": Vector2(1, 3),
		"requires": ["cordage", "fire"],
		"cost": {"fiber": 30, "rope": 5, "wood": 20},
		"effect": "shelter",
		"desc": "Warm, dry homes. Each Dwelling houses 5 Kith instead of 3.",
	},
	"pottery":
	{
		"abbr": "Po",
		"color": Color("c8553d"),
		"name": "Pottery",
		"pos": Vector2(1, 4),
		"requires": ["fire"],
		"cost": {"clay": 20, "charcoal": 10},
		"desc": "Fire clay. Unlocks the Kiln (clay + charcoal into brick).",
	},
	"ochre":
	{
		"abbr": "Oc",
		"color": Color("cc7722"),
		"name": "Ochre",
		"pos": Vector2(1, 5),
		"requires": ["storytelling", "foraging"],
		"cost": {"clay": 10, "berries": 10},
		"effect": "ochre",
		"desc": "Red earth for painting the huts. Gatherer's Hut workers harvest 10% faster.",
	},
	"star_lore":
	{
		"abbr": "SL",
		"color": Color("caf0f8"),
		"name": "Star Lore",
		"pos": Vector2(1, 6),
		"requires": ["storytelling"],
		"cost": {"stone": 20, "flint": 10},
		"effect": "star_lore",
		"hidden": true,
		"desc": "The Strange Stone fell from the sky. Raise a Shard Cairn around it.",
	},
	"scouting":
	{
		"abbr": "Sc",
		"color": Color("90be6d"),
		"name": "Scouting",
		"pos": Vector2(2, 0),
		"requires": ["gatherers_hut", "foraging"],
		"cost": {"berries": 20, "wood": 20},
		"effect": "scouting",
		"desc": "Know the land. Gatherer's Huts reach 3 tiles instead of 2.",
	},
	"farming":
	{
		"abbr": "Fa",
		"color": Color("e9d8a6"),
		"name": "Farming",
		"pos": Vector2(2, 1),
		"requires": ["foraging", "gatherers_hut"],
		"cost": {"grain": 20, "wood": 20},
		"desc": "Sow wild grain. Plant Fields of grain on open grassland.",
	},
	"haulers":
	{
		"abbr": "PH",
		"color": Color("b388eb"),
		"name": "Paths & Haulers",
		"pos": Vector2(2, 2),
		"requires": ["cordage", "gatherers_hut"],
		"cost": {"rope": 10, "wood": 30},
		"desc": "Idle Kith carry goods between buildings and the stockpile. Unlocks Roads and Storehouses.",
	},
	"nets":
	{
		"abbr": "Ne",
		"color": Color("0077b6"),
		"name": "Nets",
		"pos": Vector2(2, 3),
		"requires": ["cordage", "foraging"],
		"cost": {"rope": 10, "fiber": 20},
		"desc": "Knot rope into nets. Build a Fishing Weir on the river bank: Fish are worth 2 food.",
	},
	"grindstone":
	{
		"abbr": "Gr",
		"color": Color("adb5bd"),
		"name": "Grindstone",
		"pos": Vector2(2, 4),
		"requires": ["water_wheel", "masonry", "pottery"],
		"cost": {"stone": 30, "brick": 10},
		"desc": "A powered millstone. Grinds grain into flour, the best food.",
	},
	"smoking":
	{
		"abbr": "Sm",
		"color": Color("7f5539"),
		"name": "Smoking",
		"pos": Vector2(2, 5.25),
		"requires": ["fire", "foraging"],
		"cost": {"wood": 20, "berries": 15},
		"effect": "smoking",
		"desc": "Smoke berries over the fire. Berries are worth 2 food, up from 1.",
	},
	"megaliths":
	{
		"abbr": "Me",
		"color": Color("6c5b7b"),
		"name": "Megaliths",
		"pos": Vector2(2, 6.5),
		"requires": ["masonry"],
		"requires_any": ["storytelling", "star_lore"],
		"cost": {"stone": 50, "rope": 10},
		"desc": "Raise great stones. Buildings within 3 tiles of a Standing Stone work 15% faster.",
	},
	"stone_axe":
	{
		"abbr": "SA",
		"color": Color("606c38"),
		"name": "Stone Axe",
		"pos": Vector2(3, 0),
		"requires": ["knapping", "gatherers_hut"],
		"cost": {"flint": 15, "wood": 20},
		"effect": "stone_axe",
		"desc": "Haft a ground stone head. Gatherer's Huts gather Wood twice as fast.",
	},
	"irrigation":
	{
		"abbr": "Ir",
		"color": Color("00b4d8"),
		"name": "Irrigation",
		"pos": Vector2(3, 1),
		"requires": ["water_wheel", "farming"],
		"cost": {"clay": 20, "stone": 20},
		"effect": "irrigation",
		"desc": "Dig ditches from the river. Fields that touch the river grow twice as fast.",
	},
	"preservation":
	{
		"abbr": "Pr",
		"color": Color("f28482"),
		"name": "Preservation",
		"pos": Vector2(3, 2),
		"requires": ["farming", "pottery"],
		"cost": {"clay": 20, "berries": 20},
		"effect": "preservation",
		"desc": "Sealed pots keep food. The Kith eat 25% less.",
	},
	"carrying_poles":
	{
		"abbr": "CP",
		"color": Color("cdb4db"),
		"name": "Carrying Poles",
		"pos": Vector2(3, 3),
		"requires": ["haulers"],
		"cost": {"rope": 15, "wood": 20},
		"effect": "carrying_poles",
		"desc": "Haulers carry 10 at a time instead of 5.",
	},
	"paved_roads":
	{
		"abbr": "PR",
		"color": Color("8d99ae"),
		"name": "Paved Roads",
		"pos": Vector2(3, 4),
		"requires": ["haulers", "masonry"],
		"cost": {"stone": 60, "rope": 10},
		"effect": "paved_roads",
		"desc": "Roads are 4x faster than open ground, up from 2x.",
	},
	"baking":
	{
		"abbr": "Ba",
		"color": Color("f1e3c8"),
		"name": "Baking",
		"pos": Vector2(3, 5),
		"requires": ["grindstone", "fire"],
		"cost": {"flour": 10, "charcoal": 20},
		"effect": "baking",
		"desc": "Bake flour into bread. Flour is worth 5 food, up from 3.",
	},
	"rafts":
	{
		"abbr": "Ra",
		"color": Color("57cc99"),
		"name": "Rafts",
		"pos": Vector2(3, 6),
		"requires": ["nets", "haulers"],
		"cost": {"wood": 40, "rope": 15},
		"effect": "rafts",
		"desc": "Lash logs together. Kith can cross the river without a bridge, slowly.",
	},
	"calendar":
	{
		"abbr": "Ca",
		"color": Color("f15bb5"),
		"name": "Calendar",
		"pos": Vector2(3, 7),
		"requires": ["farming"],
		"requires_any": ["megaliths", "storytelling"],
		"cost": {"grain": 30, "stone": 20},
		"effect": "calendar",
		"desc": "Count the moons and sow on time. Fields yield 25% more.",
	},
	"bronze_dawn":
	{
		"abbr": "BD",
		"color": Color("cd7f32"),
		"name": "Bronze Dawn",
		"pos": Vector2(4, 4.5),
		"requires": ["preservation", "paved_roads", "baking", "calendar"],
		"cost": {"brick": 40, "flour": 30, "rope": 40, "stone": 100},
		"desc": "The stone age ends. The next era begins.",
	},
}

## Order for lists and tests (roots first, then by column).
const TECH_ORDER := [
	"foraging",
	"knapping",
	"cordage",
	"fire",
	"storytelling",
	"gatherers_hut",
	"water_wheel",
	"masonry",
	"shelter",
	"pottery",
	"ochre",
	"star_lore",
	"scouting",
	"farming",
	"haulers",
	"nets",
	"grindstone",
	"smoking",
	"megaliths",
	"stone_axe",
	"irrigation",
	"preservation",
	"carrying_poles",
	"paved_roads",
	"baking",
	"rafts",
	"calendar",
	"bronze_dawn",
]

# --- Hand crafting -----------------------------------------------------------

const RECIPES := {
	"rope": {"name": "Rope", "tech": "cordage", "in": {"fiber": 3}, "out": {"rope": 1}},
	"flint_tools":
	{"name": "Flint Tools", "tech": "knapping", "in": {"flint": 2, "wood": 2}, "out": {"flint_tools": 1}},
}

# --- Buildings ---------------------------------------------------------------
## kind: "camp" | "house" | "road" | "field" | "depot" | "gatherer" | "processor" | "power" | "aura" | "cairn"
## Processors turn `in` into `out` every `time` seconds (a processor with no `in` just makes `out`).
## Buildings without a worker show `status`, or `desc` if they have none.

const BUILDINGS := {
	"camp":
	{
		"name": "Camp",
		"kind": "camp",
		"tech": "",
		"cost": {},
		"housing": 4,
		"color": Color("e76f51"),
		"desc": "The Kith's home and stockpile. Houses 4.",
	},
	"dwelling":
	{
		"name": "Dwelling",
		"kind": "house",
		"tech": "",
		"cost": {"wood": 12, "fiber": 6},
		"housing": 3,
		"color": Color("e9c46a"),
		"desc": "Room for 3 more Kith. They grow when there is spare food.",
	},
	"road":
	{
		"name": "Road",
		"kind": "road",
		"tech": "haulers",
		"cost": {"stone": 1},
		"color": Color("c9a66b"),
		"desc": "Kith walk twice as fast on roads. Lay one across the river to bridge it. Drag to paint.",
	},
	"field":
	{
		"name": "Field",
		"kind": "field",
		"tech": "farming",
		"cost": {"fiber": 3, "grain": 1},
		"color": Color("d4b44a"),
		"desc": "Plant wild grain on open grassland, for huts to gather. Drag to sow.",
	},
	"storehouse":
	{
		"name": "Storehouse",
		"kind": "depot",
		"tech": "haulers",
		"cost": {"wood": 20, "stone": 10},
		"color": Color("8d6e63"),
		"desc": "A second stockpile. Haulers drop off and pick up at the nearest one.",
	},
	"charcoal_pit":
	{
		"name": "Charcoal Pit",
		"kind": "processor",
		"tech": "fire",
		"cost": {"wood": 5, "stone": 5},
		"in": {"wood": 2},
		"out": {"charcoal": 1},
		"time": 4.0,
		"color": Color("3d405b"),
		"desc": "Smoulders wood into charcoal.",
	},
	"twine_post":
	{
		"name": "Twine Post",
		"kind": "processor",
		"tech": "cordage",
		"cost": {"wood": 8},
		"in": {"fiber": 3},
		"out": {"rope": 1},
		"time": 4.0,
		"color": Color("bc8a5f"),
		"desc": "Twists fiber into rope.",
	},
	"gatherers_hut":
	{
		"name": "Gatherer's Hut",
		"kind": "gatherer",
		"tech": "gatherers_hut",
		"cost": {"wood": 10, "stone": 5},
		"radius": 2,
		"time": 3.0,
		"color": Color("f4a261"),
		"desc": "Gathers from resource tiles within 2 tiles.",
	},
	"kiln":
	{
		"name": "Kiln",
		"kind": "processor",
		"tech": "pottery",
		"cost": {"stone": 10, "clay": 10},
		"in": {"clay": 2, "charcoal": 1},
		"out": {"brick": 1},
		"time": 5.0,
		"color": Color("9c3d2e"),
		"desc": "Fires clay into brick.",
	},
	"water_wheel":
	{
		"name": "Water Wheel",
		"kind": "power",
		"tech": "water_wheel",
		"cost": {"wood": 30, "rope": 10},
		"radius": 3,
		"needs_river": true,
		"color": Color("2a9d8f"),
		"desc": "Must touch the river. Powers machines within 3 tiles.",
	},
	"grindstone":
	{
		"name": "Grindstone",
		"kind": "processor",
		"tech": "grindstone",
		"cost": {"stone": 20, "brick": 5},
		"in": {"grain": 2},
		"out": {"flour": 1},
		"time": 4.0,
		"needs_power": true,
		"color": Color("adb5bd"),
		"desc": "Needs power. Grinds grain into flour.",
	},
	"fishing_weir":
	{
		"name": "Fishing Weir",
		"kind": "processor",
		"tech": "nets",
		"cost": {"wood": 15, "rope": 5},
		"in": {},
		"out": {"fish": 1},
		"time": 6.0,
		"needs_river": true,
		"color": Color("0077b6"),
		"desc": "Must touch the river. Its worker traps Fish, worth 2 food.",
	},
	"standing_stone":
	{
		"name": "Standing Stone",
		"kind": "aura",
		"tech": "megaliths",
		"cost": {"stone": 30},
		"radius": 3,
		"color": Color("6c5b7b"),
		"desc": "Buildings within 3 tiles work 15% faster.",
	},
	"shard_cairn":
	{
		"name": "Shard Cairn",
		"kind": "cairn",
		"tech": "star_lore",
		"cost": {"stone": 12},
		"needs_shard": true,
		"color": Color("caf0f8"),
		"desc": "A ring of stones beside the Strange Stone. Must go next to it.",
		"status": "It hums. Nothing more. Yet.",
	},
}

const BUILD_ORDER := [
	"dwelling",
	"road",
	"field",
	"storehouse",
	"charcoal_pit",
	"twine_post",
	"gatherers_hut",
	"kiln",
	"water_wheel",
	"grindstone",
	"fishing_weir",
	"standing_stone",
	"shard_cairn",
]

## Output a building holds before it stops, when nobody hauls it away.
const BUFFER_CAP := 10

# --- Goals -------------------------------------------------------------------
## The opening checklist. A goal with `tech` or `building` is met once that is researched or built;
## GameState.goal_met() checks the others by id.

const GOALS := [
	{"id": "gather", "text": "Click trees, rocks and gravel: get 10 Wood, 10 Stone, 5 Flint"},
	{"id": "knapping", "text": "Press T and research Knapping", "tech": "knapping"},
	{"id": "tools", "text": "Craft Flint Tools (doubles hand gathering)"},
	{"id": "hut_tech", "text": "Research Gatherer's Hut", "tech": "gatherers_hut"},
	{"id": "hut", "text": "Place a Gatherer's Hut next to trees or rocks", "building": "gatherers_hut"},
	{"id": "berries", "text": "Place a hut near Berry Bushes. The Kith eat food"},
	{"id": "dwelling", "text": "Build a Dwelling. Kith grow when there's room and spare food", "building": "dwelling"},
	{"id": "charcoal", "text": "Research Fire, then build a Charcoal Pit", "building": "charcoal_pit"},
	{"id": "twine", "text": "Research Cordage, then build a Twine Post", "building": "twine_post"},
	{"id": "haulers", "text": "Research Paths & Haulers: idle Kith carry goods for you", "tech": "haulers"},
	{"id": "road", "text": "Lay Roads out to far buildings. Kith walk twice as fast"},
	{"id": "kiln", "text": "Research Pottery, then build a Kiln", "building": "kiln"},
	{"id": "wheel", "text": "Research Water Wheel and build one on the river", "building": "water_wheel"},
	{"id": "grind", "text": "Build a Grindstone within 3 tiles of the wheel"},
	{"id": "calendar", "text": "Research Calendar: Farming, plus Storytelling or Megaliths", "tech": "calendar"},
	{"id": "bronze", "text": "Research Bronze Dawn", "tech": "bronze_dawn"},
]
