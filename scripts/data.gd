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

## Food value of each edible item. The Kith eat from the stockpile.
const FOOD_VALUE := {"berries": 1.0, "flour": 3.0}

## Food each running building eats per second.
# --- Population --------------------------------------------------------------
## The Kith eat food. Spare food grows the population; every working building
## needs one Kith, so food sets how many buildings can run.

const START_POPULATION := 3
const FOOD_PER_KITH_PER_SEC := 0.05
## A new Kith joins every GROWTH_SECONDS while stored food covers this much per Kith.
const GROWTH_SECONDS := 15.0
const GROWTH_FOOD_PER_KITH := 3.0
## With no food, one Kith is lost every STARVE_SECONDS (never the last one).
const STARVE_SECONDS := 10.0

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
		"name": "Fire",
		"color": Color("ff7b39"),
		"requires": [],
		"cost": {"wood": 10, "stone": 5},
		"desc": "Tame flame. Unlocks the Charcoal Pit.",
	},
	"knapping":
	{
		"name": "Knapping",
		"color": Color("d9d9d9"),
		"requires": [],
		"cost": {"flint": 5, "stone": 10},
		"desc": "Shape flint. Craft Flint Tools to gather twice as much by hand.",
	},
	"cordage":
	{
		"name": "Cordage",
		"color": Color("e9c46a"),
		"requires": [],
		"cost": {"fiber": 15},
		"desc": "Twist fiber into rope. Unlocks hand-made Rope and the Twine Post.",
	},
	"gatherers_hut":
	{
		"name": "Gatherer's Hut",
		"color": Color("90be6d"),
		"requires": ["knapping"],
		"cost": {"wood": 20, "stone": 10},
		"desc": "Your first self-running building. A worker gathers from nearby tiles.",
	},
	"haulers":
	{
		"name": "Paths & Haulers",
		"color": Color("f28482"),
		"requires": ["cordage", "gatherers_hut"],
		"cost": {"rope": 10, "wood": 30},
		"desc": "Haulers move goods between buildings and the Camp. Chains run hands-free.",
	},
	"pottery":
	{
		"name": "Pottery",
		"color": Color("ffb4a2"),
		"requires": ["fire"],
		"cost": {"clay": 20, "charcoal": 10},
		"desc": "Fire clay. Unlocks the Kiln (clay + charcoal into brick).",
	},
	"water_wheel":
	{
		"name": "Water Wheel",
		"color": Color("4cc9f0"),
		"requires": ["cordage", "knapping"],
		"cost": {"rope": 10, "wood": 40, "stone": 20},
		"desc": "Harness the river. Powers machines within 3 tiles.",
	},
	"grindstone":
	{
		"name": "Grindstone",
		"color": Color("b8b8ff"),
		"requires": ["water_wheel", "pottery"],
		"cost": {"stone": 30, "brick": 10},
		"desc": "A powered millstone. Grinds grain into flour, the best food.",
	},
	"bronze_dawn":
	{
		"name": "Bronze Dawn",
		"color": Color("e3a857"),
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

# --- Goals -------------------------------------------------------------------
## The on-screen goal list that walks a new player through the stone age.
## kind: "items" (have `need` in the stockpile), "tech", "build" (own one), "population".

const GOALS := [
	{
		"text": "Gather 10 Wood and 5 Stone",
		"hint": "Click the forests and rocks around the Camp.",
		"kind": "items",
		"need": {"wood": 10, "stone": 5},
	},
	{"text": "Research Fire", "hint": "Press T to open the tech tree.", "kind": "tech", "id": "fire"},
	{
		"text": "Research Knapping",
		"hint": "Flint comes from the riverbed gravel to the east. Click it.",
		"kind": "tech",
		"id": "knapping",
	},
	{
		"text": "Research Gatherer's Hut",
		"hint": "Your first building that works on its own.",
		"kind": "tech",
		"id": "gatherers_hut",
	},
	{
		"text": "Build a Gatherer's Hut",
		"hint": "Pick it in the Build bar. The highlight shows what it will gather. Near berries feeds the Kith.",
		"kind": "build",
		"id": "gatherers_hut",
	},
	{
		"text": "Grow to 5 Kith",
		"hint": "Every building needs a Kith. Keep 3 food per Kith stored and more join.",
		"kind": "population",
		"n": 5,
	},
	{
		"text": "Research Paths & Haulers",
		"hint": "Needs Cordage too. After this, buildings load and empty themselves.",
		"kind": "tech",
		"id": "haulers",
	},
	{
		"text": "Research Bronze Dawn",
		"hint": "Needs Pottery, Grindstone and Haulers. This ends the stone age.",
		"kind": "tech",
		"id": "bronze_dawn",
	},
]

## Output a building holds before it stops, when nobody hauls it away.
const BUFFER_CAP := 10
