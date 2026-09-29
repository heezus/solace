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
]

## Food value of each edible item. Automated buildings eat from the stockpile.
const FOOD_VALUE := {"berries": 1.0, "flour": 3.0}

## Food each running building eats per second.
const FOOD_PER_BUILDING_PER_SEC := 0.05

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

const TECHS := {
	"fire":
	{
		"abbr": "Fi",
		"color": Color("e85d04"),
		"name": "Fire",
		"requires": [],
		"cost": {"wood": 10, "stone": 5},
		"desc": "Tame flame. Unlocks the Charcoal Pit.",
	},
	"knapping":
	{
		"abbr": "Kn",
		"color": Color("6c757d"),
		"name": "Knapping",
		"requires": [],
		"cost": {"flint": 5, "stone": 10},
		"desc": "Shape flint. Craft Flint Tools to gather twice as much by hand.",
	},
	"cordage":
	{
		"abbr": "Co",
		"color": Color("bc8a5f"),
		"name": "Cordage",
		"requires": [],
		"cost": {"fiber": 15},
		"desc": "Twist fiber into rope. Unlocks hand-made Rope and the Twine Post.",
	},
	"gatherers_hut":
	{
		"abbr": "GH",
		"color": Color("f4a261"),
		"name": "Gatherer's Hut",
		"requires": ["knapping"],
		"cost": {"wood": 20, "stone": 10},
		"desc": "Your first self-running building. A worker gathers from nearby tiles.",
	},
	"haulers":
	{
		"abbr": "PH",
		"color": Color("b388eb"),
		"name": "Paths & Haulers",
		"requires": ["cordage", "gatherers_hut"],
		"cost": {"rope": 10, "wood": 30},
		"desc": "Haulers move goods between buildings and the Camp. Chains run hands-free.",
	},
	"pottery":
	{
		"abbr": "Po",
		"color": Color("c8553d"),
		"name": "Pottery",
		"requires": ["fire"],
		"cost": {"clay": 20, "charcoal": 10},
		"desc": "Fire clay. Unlocks the Kiln (clay + charcoal into brick).",
	},
	"water_wheel":
	{
		"abbr": "WW",
		"color": Color("2a9d8f"),
		"name": "Water Wheel",
		"requires": ["cordage", "knapping"],
		"cost": {"rope": 10, "wood": 40, "stone": 20},
		"desc": "Harness the river. Powers machines within 3 tiles.",
	},
	"grindstone":
	{
		"abbr": "Gr",
		"color": Color("adb5bd"),
		"name": "Grindstone",
		"requires": ["water_wheel", "pottery"],
		"cost": {"stone": 30, "brick": 10},
		"desc": "A powered millstone. Grinds grain into flour, the best food.",
	},
	"bronze_dawn":
	{
		"abbr": "BD",
		"color": Color("cd7f32"),
		"name": "Bronze Dawn",
		"requires": ["pottery", "grindstone", "haulers"],
		"cost": {"brick": 40, "flour": 30, "rope": 40, "stone": 100},
		"desc": "The stone age ends. The next era begins.",
	},
}

## Display order and layout column for the tech panel.
const TECH_ORDER := [
	"fire",
	"knapping",
	"cordage",
	"gatherers_hut",
	"pottery",
	"water_wheel",
	"haulers",
	"grindstone",
	"bronze_dawn",
]

# --- Hand crafting -----------------------------------------------------------

const RECIPES := {
	"rope": {"name": "Rope", "tech": "cordage", "in": {"fiber": 3}, "out": {"rope": 1}},
	"flint_tools":
	{"name": "Flint Tools", "tech": "knapping", "in": {"flint": 2, "wood": 2}, "out": {"flint_tools": 1}},
}

# --- Buildings ---------------------------------------------------------------
## kind: "camp" | "gatherer" | "processor" | "power"
## Processors turn `in` into `out` every `time` seconds.

const BUILDINGS := {
	"camp":
	{
		"name": "Camp",
		"kind": "camp",
		"tech": "",
		"cost": {},
		"color": Color("e76f51"),
		"desc": "The Kith's home and stockpile.",
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
}

const BUILD_ORDER := ["charcoal_pit", "twine_post", "gatherers_hut", "kiln", "water_wheel", "grindstone"]

## Output a building holds before it stops, when nobody hauls it away.
const BUFFER_CAP := 10

# --- Goals -------------------------------------------------------------------
## The opening checklist. GameState.goal_met() knows how to check each id.

const GOALS := [
	{"id": "gather", "text": "Click trees, rocks and gravel: get 10 Wood, 10 Stone, 5 Flint"},
	{"id": "knapping", "text": "Press T and research Knapping"},
	{"id": "tools", "text": "Craft Flint Tools (doubles hand gathering)"},
	{"id": "hut_tech", "text": "Research Gatherer's Hut"},
	{"id": "hut", "text": "Place a Gatherer's Hut next to trees or rocks"},
	{"id": "berries", "text": "Place a hut near Berry Bushes. Running buildings eat food"},
	{"id": "charcoal", "text": "Research Fire, then build a Charcoal Pit"},
	{"id": "twine", "text": "Research Cordage, then build a Twine Post"},
	{"id": "haulers", "text": "Research Paths & Haulers so buildings run themselves"},
	{"id": "kiln", "text": "Research Pottery, then build a Kiln"},
	{"id": "wheel", "text": "Research Water Wheel and build one on the river"},
	{"id": "grind", "text": "Build a Grindstone within 3 tiles of the wheel"},
	{"id": "bronze", "text": "Research Bronze Dawn"},
]
