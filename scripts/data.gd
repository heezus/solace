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

# --- The people ----------------------------------------------------------------
## Display names for the people the player leads. Engine code formats its messages with these, so a
## later faction (13-three-perspectives.md) only swaps data.
const PEOPLE := {"one": "Kith", "many": "Kith"}
## Short earthy names, given in turn to each Kith who learns a job by watching you.
## The event a birth sends to the UI, formatted with PEOPLE["one"].
const BORN_EVENT := "A %s was born"
const PEOPLE_NAMES := ["Aro", "Tam", "Esk", "Bru", "Olla", "Fen", "Rook", "Moss", "Sef", "Tarn", "Wren", "Hask"]

## Major story moments, by stable id, recorded in GameState.story_events so a future profile save can
## keep them across runs.
const STORY_EVENTS := {
	"first_lesson": "A Kith learned a job by watching",
	"first_trip": "A hut sent its first Kith out for a bundle",
	"shard_found": "The Strange Stone was found",
	"haulers": "The Kith began to carry for each other",
	"bronze_dawn": "The stone age ended",
}

# --- From Hands to Haulers (14-hands-to-haulers.md) --------------------------------
## Gather a resource by hand this many times and a watching Kith learns it: huts may then gather it.
const LEARN_CLICKS := 10
## A hut trip brings back a bundle: this many times your click yield for that resource.
const BUNDLE := 3
## Trips a hut can have queued before Paths & Haulers (the one under way counts).
const TRIP_QUEUE := 3
## Clicking a working building finishes its cycle now, then it can't be rushed for this long.
const RUSH_COOLDOWN := 5.0
## Click yield is base x tool x rank. Tools multiply it; the best one that applies counts.
## `crafted` needs a Flint Tool made once, `tech` a researched tech (Bronze Tools is era 2's slot),
## `item` limits it to one resource.
const CLICK_TOOLS := {
	"flint_tools": {"name": "Flint Tools", "mult": 2, "crafted": true},
	"stone_axe": {"name": "Stone Axe", "mult": 3, "tech": "stone_axe", "item": "wood"},
	"bronze_tools": {"name": "Bronze Tools", "mult": 4, "tech": "bronze_tools"},
}
## Ranks I to III: rank I is the tech, ranks II and III are optional buys on its card.
const MAX_RANK := 3
## Each rank costs this many times the one before it (rank I is the tech's own cost).
const RANK_COST_STEP := 2.5
const RANK_NAMES := ["", "I", "II", "III"]

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
## Path cost of each tile kind. Rivers are impassable without a Wooden Bridge, or slow once Rafts are known.
const WALK_COST := {"tree": 2.0, "rock": 2.0, "road": 0.5, "river": 4.0}

## A Road laid on Rocks cuts a mountain pass: it costs this instead, and the rock is cleared.
const PASS_COST := {"stone": 3}

## Dwellings must stand within this many tiles of the Hearth (the Camp), where the Kith are born.
const HEARTH_RADIUS := 6.0

# --- Fog of war ----------------------------------------------------------------
## How far each thing lets the Kith see, in tiles. Scouting adds SCOUTING_SIGHT to buildings and Kith.
const SIGHT_START := 6
const SIGHT_BUILDING := 3
const SIGHT_KITH := 2
const SCOUTING_SIGHT := 2

## Rates in the top bar are averaged over this many seconds.
const RATE_WINDOW := 30

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
## On the research board, `tier` is the column, `lane` the band (LANES) and `slot` the row within the band.
## `unlock` is the card's one-line summary, `icon` a sprite in art/sprites ("@name" for a drawn one),
## and `side` marks an optional branch that Bronze Dawn doesn't need.
## `requires` must all be researched; `requires_any` (optional) needs just one of its techs.
## `effect` marks a tech whose bonus GameState applies while it is researched.
## `hidden` techs stay out of the tree until the player has clicked the Strange Stone.
## `rank` gives a tech optional ranks II and III, bought on its card (never needed for Bronze Dawn):
## {"item": id} adds 1 to that item's click base per rank, {"building": type} is +25% Speed there
## (BONUSES "rank_<type>").
## The board is laid out from these keys alone (scripts/tech_layout.gd): `lane` ("gate" for the full-height
## Bronze Dawn column), `tier` and `slot` place the card, and lines are routed automatically. An optional
## `via` dictionary steers a line that skips tiers: {parent: lane id} runs it along the channel just below
## that lane ("top" for the channel above the first lane), e.g. "via": {"masonry": "fiber"}.

## The research board's bands, top to bottom. Bronze Dawn sits alone in the "gate" column.
const LANES := {
	"hearth": {"name": "Hearth", "color": Color("ff7b39")},
	"stone": {"name": "Stone", "color": Color("c0c6cc")},
	"fiber": {"name": "Fiber", "color": Color("e9c46a")},
	"land": {"name": "Land", "color": Color("90be6d")},
	"lore": {"name": "Lore", "color": Color("b8b8ff")},
}
const LANE_ORDER := ["fiber", "stone", "land", "hearth", "lore"]
## Column captions on the research board, one per tier; the last is the gate's column.
const TIER_NAMES := ["TIER I  ·  ROOTS", "TIER II", "TIER III", "TIER IV", "TIER V", "THE GATE"]

## How many techs the research queue lines up at once.
const QUEUE_SLOTS := 5

## Tech bonuses GameState applies.
const STORYTELLING_GROW := 0.75  # grow time multiplier

## Work multipliers (scripts/bonuses.gd). "speed" shortens work cycles, "yield" multiplies each harvest.
## They add within a group and multiply across groups. Optional keys: `tech` (needs it researched),
## `kinds` (building kinds it applies to), `types` (building types), `item` (only harvests of that item),
## `rank_of` (a tech's ranks: `add` per rank bought beyond I).
## The Stone Axe is a click tool (CLICK_TOOLS): huts get it through their bundle, which is based on a click.
## "tools" applies while the worker holds a Flint Tool, "standing_stone" next to a Standing Stone.
const BONUSES := {
	"tools": {"name": "Flint Tools", "group": "speed", "add": 0.5, "kinds": ["gatherer", "processor"]},
	"standing_stone": {"name": "Standing Stone", "group": "speed", "add": 1.0, "kinds": ["gatherer", "processor"]},
	"foraging": {"name": "Foraging", "group": "yield", "add": 1.0, "tech": "foraging", "item": "berries"},
	"ochre": {"name": "Ochre", "group": "yield", "add": 1.0, "tech": "ochre", "item": "clay", "kinds": ["gatherer"]},
	# Ranks II and III on workshop techs: +25% Speed each, at that workshop only (`rank_of`, `types`).
	"rank_twine_post":
	{"name": "Cordage", "group": "speed", "add": 0.25, "rank_of": "cordage", "types": ["twine_post"]},
	"rank_charcoal_pit": {"name": "Fire", "group": "speed", "add": 0.25, "rank_of": "fire", "types": ["charcoal_pit"]},
	"rank_kiln": {"name": "Pottery", "group": "speed", "add": 0.25, "rank_of": "pottery", "types": ["kiln"]},
}
## A Flint Tool lasts this many jobs (harvests or work cycles) in a worker's hands.
const TOOL_JOBS := 40
const CALENDAR_FIELD_BONUS := 0.25  # extra yield from Fields
const SMOKED_BERRY_FOOD := 2.0
const BAKED_FLOUR_FOOD := 5.0

const TECHS := {
	"foraging":
	{
		"abbr": "Fo",
		"color": Color("d62246"),
		"name": "Foraging",
		"lane": "land",
		"tier": 0,
		"slot": 0,
		"unlock": "Berries x2",
		"icon": "gatherers_hut",
		"requires": [],
		"cost": {"berries": 5, "fiber": 10},
		"rank": {"item": "berries"},
		"desc": "Know the good bushes. Berries gather twice as fast, by hand and by hut.",
	},
	"knapping":
	{
		"abbr": "Kn",
		"color": Color("6c757d"),
		"name": "Knapping",
		"lane": "stone",
		"tier": 0,
		"slot": 0,
		"unlock": "Flint Tools",
		"icon": "@flint",
		"requires": [],
		"cost": {"flint": 5, "stone": 10},
		"rank": {"item": "flint"},
		"desc":
		"Shape flint. Craft Flint Tools: you gather twice as much by hand, and each worker holding one works 50% faster.",
	},
	"cordage":
	{
		"abbr": "Co",
		"color": Color("bc8a5f"),
		"name": "Cordage",
		"lane": "fiber",
		"tier": 0,
		"slot": 0,
		"unlock": "Rope, Twine Post",
		"icon": "twine_post",
		"requires": [],
		"cost": {"fiber": 15},
		"rank": {"building": "twine_post"},
		"desc": "Twist fiber into rope, by hand or at a Twine Post.",
	},
	"fire":
	{
		"abbr": "Fi",
		"color": Color("e85d04"),
		"name": "Fire",
		"lane": "hearth",
		"tier": 0,
		"slot": 0,
		"unlock": "Charcoal Pit",
		"icon": "hearth",
		"requires": [],
		"cost": {"wood": 10, "stone": 5},
		"rank": {"building": "charcoal_pit"},
		"desc": "Tame flame. Smoulder wood into charcoal in a Charcoal Pit.",
	},
	"storytelling":
	{
		"abbr": "St",
		"color": Color("7b2cbf"),
		"name": "Storytelling",
		"lane": "lore",
		"tier": 0,
		"slot": 0,
		"unlock": "Kith born faster",
		"icon": "kith",
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
		"lane": "land",
		"tier": 1,
		"slot": 0,
		"unlock": "Gatherer's Hut",
		"icon": "gatherers_hut",
		"requires": ["knapping", "foraging"],
		"cost": {"wood": 20, "stone": 10},
		"desc": "Your first self-running building. Its worker walks out to nearby resources.",
	},
	"water_wheel":
	{
		"abbr": "WW",
		"color": Color("2a9d8f"),
		"name": "Water Wheel",
		"lane": "stone",
		"tier": 2,
		"slot": 0,
		"unlock": "Water Wheel",
		"icon": "water_wheel",
		"requires": ["stone_axe", "masonry"],
		"cost": {"rope": 10, "wood": 40, "stone": 10},
		"desc": "Harness the river. Powers machines within 3 tiles.",
	},
	"masonry":
	{
		"abbr": "Ma",
		"color": Color("9aa0a6"),
		"name": "Masonry",
		"lane": "stone",
		"tier": 1,
		"slot": 1,
		"unlock": "Dressed stone",
		"icon": "quarry",
		"requires": ["knapping", "fire"],
		"cost": {"stone": 25, "charcoal": 5},
		"rank": {"item": "stone"},
		"desc": "Dress and fit stone. Needed for millstones, paved roads and megaliths.",
	},
	"shelter":
	{
		"abbr": "Sh",
		"color": Color("a3b18a"),
		"name": "Thatched Roofs",
		"lane": "land",
		"tier": 1,
		"slot": 1,
		"unlock": "Dwellings house 5",
		"icon": "dwelling",
		"side": true,
		"requires": ["cordage", "foraging"],
		"cost": {"fiber": 30, "rope": 5, "wood": 20},
		"effect": "shelter",
		"desc": "Warm, dry homes. Each Dwelling houses 5 Kith instead of 3.",
	},
	"pottery":
	{
		"abbr": "Po",
		"color": Color("c8553d"),
		"name": "Pottery",
		"lane": "hearth",
		"tier": 1,
		"slot": 0,
		"unlock": "Kiln",
		"icon": "kiln",
		"requires": ["fire"],
		"cost": {"clay": 20, "charcoal": 10},
		"rank": {"building": "kiln"},
		"desc": "Fire clay. Unlocks the Kiln (clay + charcoal into brick).",
	},
	"ochre":
	{
		"abbr": "Oc",
		"color": Color("cc7722"),
		"name": "Ochre",
		"lane": "lore",
		"tier": 1,
		"slot": 0,
		"unlock": "Clay x2",
		"icon": "@clay",
		"side": true,
		"requires": ["storytelling", "foraging"],
		"cost": {"clay": 10, "berries": 10},
		"rank": {"item": "clay"},
		"effect": "ochre",
		"desc": "Know the red earth. Gatherer's Huts bring back twice the Clay per trip.",
	},
	"star_lore":
	{
		"abbr": "SL",
		"color": Color("caf0f8"),
		"name": "Star Lore",
		"lane": "lore",
		"tier": 1,
		"slot": 1,
		"unlock": "Shard Cairn",
		"icon": "shard_cairn",
		"side": true,
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
		"lane": "land",
		"tier": 2,
		"slot": 1,
		"unlock": "Wider reach",
		"icon": "watchtower",
		"side": true,
		"requires": ["gatherers_hut", "storytelling"],
		"cost": {"berries": 20, "wood": 20},
		"effect": "scouting",
		"desc": "Know the land. Gatherer's Huts reach 3 tiles instead of 2.",
	},
	"farming":
	{
		"abbr": "Fa",
		"color": Color("e9d8a6"),
		"name": "Farming",
		"lane": "land",
		"tier": 2,
		"slot": 0,
		"unlock": "Field",
		"icon": "field",
		"requires": ["gatherers_hut", "stone_axe"],
		"cost": {"grain": 20, "wood": 20},
		"rank": {"item": "grain"},
		"desc": "Sow wild grain. Plant Fields of grain on open grassland.",
	},
	"haulers":
	{
		"abbr": "PH",
		"color": Color("b388eb"),
		"name": "Paths & Haulers",
		"lane": "fiber",
		"tier": 2,
		"slot": 1,
		"unlock": "Haulers, Road, Bridge",
		"icon": "hauler",
		"requires": ["cordage", "gatherers_hut"],
		"cost": {"rope": 10, "wood": 30},
		"desc":
		"Idle Kith carry goods between buildings and the stockpile. Unlocks Roads, Wooden Bridges and Storehouses.",
	},
	"nets":
	{
		"abbr": "Ne",
		"color": Color("0077b6"),
		"name": "Nets",
		"lane": "fiber",
		"tier": 1,
		"slot": 0,
		"unlock": "Fishing Weir",
		"icon": "fishing_weir",
		"side": true,
		"requires": ["cordage", "foraging"],
		"cost": {"rope": 10, "fiber": 20},
		"desc": "Knot rope into nets. Build a Fishing Weir on the river bank: Fish are worth 2 food.",
	},
	"grindstone":
	{
		"abbr": "Gr",
		"color": Color("adb5bd"),
		"name": "Grindstone",
		"lane": "stone",
		"tier": 3,
		"slot": 1,
		"unlock": "Grindstone",
		"icon": "grindstone",
		"requires": ["water_wheel", "farming"],
		"cost": {"stone": 20, "brick": 10},
		"desc": "A powered millstone. Grinds grain into flour, the best food.",
	},
	"smoking":
	{
		"abbr": "Sm",
		"color": Color("7f5539"),
		"name": "Smoking",
		"lane": "hearth",
		"tier": 1,
		"slot": 1,
		"unlock": "Berries worth 2",
		"icon": "smokehouse",
		"side": true,
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
		"lane": "lore",
		"tier": 2,
		"slot": 0,
		"unlock": "Standing Stone",
		"icon": "standing_stone",
		"side": true,
		"requires": ["masonry"],
		"requires_any": ["storytelling", "star_lore"],
		"cost": {"stone": 50, "rope": 10},
		"desc": "Raise great stones. Buildings right next to a Standing Stone work twice as fast.",
	},
	"stone_axe":
	{
		"abbr": "SA",
		"color": Color("606c38"),
		"name": "Stone Axe",
		"lane": "stone",
		"tier": 1,
		"slot": 0,
		"unlock": "Wood x2",
		"icon": "@axe",
		"requires": ["knapping", "cordage"],
		"cost": {"flint": 10, "wood": 15},
		"rank": {"item": "wood"},
		"effect": "stone_axe",
		"desc": "Haft a flint head with cord. Wood x2 per harvest, by hand and from huts. Clears land for Farming.",
	},
	"irrigation":
	{
		"abbr": "Ir",
		"color": Color("00b4d8"),
		"name": "Irrigation",
		"lane": "land",
		"tier": 3,
		"slot": 0,
		"unlock": "River Fields x2",
		"icon": "@irrigation",
		"side": true,
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
		"lane": "land",
		"tier": 3,
		"slot": 1,
		"unlock": "Kith eat less",
		"icon": "granary",
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
		"lane": "fiber",
		"tier": 3,
		"slot": 0,
		"unlock": "Carry 10",
		"icon": "hauler_pack",
		"side": true,
		"requires": ["haulers", "stone_axe"],
		"cost": {"rope": 15, "wood": 20},
		"effect": "carrying_poles",
		"desc": "Haulers carry 10 at a time instead of 5.",
	},
	"paved_roads":
	{
		"abbr": "PR",
		"color": Color("8d99ae"),
		"name": "Paved Roads",
		"lane": "stone",
		"tier": 3,
		"slot": 0,
		"unlock": "Roads 4x",
		"icon": "tile_road",
		"requires": ["haulers", "masonry"],
		"cost": {"stone": 40, "rope": 10},
		"effect": "paved_roads",
		"desc": "Roads are 4x faster than open ground, up from 2x.",
	},
	"baking":
	{
		"abbr": "Ba",
		"color": Color("f1e3c8"),
		"name": "Baking",
		"lane": "hearth",
		"tier": 4,
		"slot": 0,
		"unlock": "Flour worth 5",
		"icon": "@bread",
		"requires": ["grindstone", "pottery"],
		"cost": {"flour": 10, "charcoal": 20},
		"effect": "baking",
		"desc": "Bake flour into bread in a clay oven. Flour is worth 5 food, up from 3.",
	},
	"rafts":
	{
		"abbr": "Ra",
		"color": Color("57cc99"),
		"name": "Rafts",
		"lane": "fiber",
		"tier": 2,
		"slot": 0,
		"unlock": "Cross rivers",
		"icon": "raft",
		"side": true,
		"requires": ["nets", "stone_axe"],
		"cost": {"wood": 40, "rope": 15},
		"effect": "rafts",
		"desc": "Lash logs together. Kith can cross the river without a bridge, slowly.",
	},
	"calendar":
	{
		"abbr": "Ca",
		"color": Color("f15bb5"),
		"name": "Calendar",
		"lane": "lore",
		"tier": 3,
		"slot": 0,
		"unlock": "Fields +25%",
		"icon": "@calendar",
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
		"lane": "gate",
		"tier": 5,
		"slot": 0,
		"unlock": "The next era",
		"icon": "item_bronze",
		"requires": ["preservation", "paved_roads", "baking", "calendar"],
		"cost": {"brick": 30, "flour": 20, "rope": 30, "stone": 60},
		"desc": "The stone age ends. The next era begins.",
	},
}

## Order for lists and tests (roots first, then by column).
const TECH_ORDER := [
	"cordage",
	"knapping",
	"foraging",
	"fire",
	"storytelling",
	"nets",
	"stone_axe",
	"masonry",
	"gatherers_hut",
	"shelter",
	"pottery",
	"smoking",
	"ochre",
	"star_lore",
	"rafts",
	"haulers",
	"water_wheel",
	"farming",
	"scouting",
	"megaliths",
	"carrying_poles",
	"paved_roads",
	"grindstone",
	"irrigation",
	"preservation",
	"calendar",
	"baking",
	"bronze_dawn",
]

# --- Hand crafting -----------------------------------------------------------

const RECIPES := {
	"rope": {"name": "Rope", "tech": "cordage", "in": {"fiber": 2}, "out": {"rope": 1}},
	"flint_tools":
	{"name": "Flint Tools", "tech": "knapping", "in": {"flint": 2, "wood": 2}, "out": {"flint_tools": 1}},
}

# --- Buildings ---------------------------------------------------------------
## kind: "camp" | "house" | "road" | "bridge" | "field" | "depot" | "gatherer" | "processor" | "power" | "aura" | "cairn"
## Processors turn `in` into `out` every `time` seconds (a processor with no `in` just makes `out`).
## Buildings without a worker show `status`, or `desc` if they have none.

const BUILDINGS := {
	"camp":
	{
		"name": "Hearth",
		"kind": "camp",
		"tech": "",
		"cost": {},
		"housing": 4,
		"color": Color("e76f51"),
		"desc": "The Kith's home fire and stockpile. Kith are born here. Houses 4.",
	},
	"dwelling":
	{
		"name": "Dwelling",
		"kind": "house",
		"tech": "",
		"cost": {"wood": 12, "fiber": 6},
		"housing": 3,
		"near_hearth": true,
		"color": Color("e9c46a"),
		"desc": "Room for 3 more Kith. Must be within 6 tiles of the Hearth. They grow when there is spare food.",
	},
	"road":
	{
		"name": "Road",
		"kind": "road",
		"tech": "haulers",
		"cost": {"stone": 1},
		"color": Color("c8a36a"),
		"desc":
		(
			"Kith walk twice as fast on roads. On Rocks, a Road cuts a pass for 3 Stone."
			+ " Roads can't cross the river: build a Wooden Bridge. Drag to lay."
		),
	},
	"bridge":
	{
		"name": "Wooden Bridge",
		"kind": "bridge",
		"tech": "haulers",
		"cost": {"wood": 10, "rope": 2},
		"color": Color("f4a261"),
		"desc": "Goes on a river tile. The Kith cross it at road speed. Drag to span the river.",
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
		"in": {"fiber": 2},
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
		"in": {"clay": 1, "charcoal": 1},
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
		"radius": 1.5,
		"color": Color("6c5b7b"),
		"desc": "Buildings right next to it (diagonals too) work twice as fast.",
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

## The build bar's tabs, in order. Craft by hand has its own small group beside them.
const BUILD_TABS := {
	"Homes": ["dwelling"],
	"Gathering": ["gatherers_hut", "field", "fishing_weir"],
	"Workshops": ["charcoal_pit", "twine_post", "kiln", "water_wheel", "grindstone"],
	"Logistics": ["road", "bridge", "storehouse"],
	"Lore": ["standing_stone", "shard_cairn"],
}

const BUILD_ORDER := [
	"dwelling",
	"road",
	"bridge",
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
	{
		"id": "wheel",
		"text": "Research Water Wheel (Stone Axe, Masonry) and build one on the river",
		"building": "water_wheel"
	},
	{"id": "grind", "text": "Build a Grindstone within 3 tiles of the wheel"},
	{"id": "calendar", "text": "Research Calendar: Farming, plus Storytelling or Megaliths", "tech": "calendar"},
	{"id": "bronze", "text": "Research Bronze Dawn", "tech": "bronze_dawn"},
]
