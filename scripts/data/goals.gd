extends RefCounted
## The opening checklist and the story events. Read through the `Data` facade (scripts/data.gd).

## Major story moments, by stable id, recorded by the Story block (Story.events) so a future profile save can
## keep them across runs.
const STORY_EVENTS := {
	"first_lesson": "A Kith learned a job by watching",
	"first_trip": "A hut sent its first Kith out for a bundle",
	"shard_found": "The Strange Stone was found",
	"haulers": "The Kith began to carry for each other",
	"bronze_dawn": "The stone age ended",
}

## Techs that are story moments: tech id -> the STORY_EVENTS id the Story block records when it is researched.
const STORY_TECHS := {
	"haulers": "haulers",
	"bronze_dawn": "bronze_dawn",
}

## The opening checklist. A goal with `tech` or `building` is met once that is researched or built;
## Story.goal_met() checks the others by id.

const GOALS := [
	{"id": "learn_wood", "text": "Hold the mouse on trees to gather Wood, until a Kith learns it (10 harvests)"},
	{
		"id": "learn_berries",
		"text": "Hold the mouse on the red Berry Bushes near the Hearth. The Kith eat berries: keep a good stock"
	},
	{"id": "learn_stone", "text": "Gather Stone and Flint by hand until they're learned too"},
	{
		"id": "flax",
		"text": "Find Wild Flax (tall stalks with tiny blue-violet flowers) and gather it: all Fiber comes from flax"
	},
	{"id": "knapping", "text": "Press T and research Knapping", "tech": "knapping"},
	{"id": "tools", "text": "Craft Flint Tools: each harvest takes 0.7s instead of 1s"},
	{"id": "hut_tech", "text": "Research Gatherer's Hut", "tech": "gatherers_hut"},
	{
		"id": "hut",
		"text": "Place a Gatherer's Hut next to trees or rocks: it works the one resource it stands next to",
		"building": "gatherers_hut"
	},
	{"id": "trip", "text": "Click your hut to send a trip: its Kith brings back a bundle (3 harvests' worth)"},
	{
		"id": "berries",
		"text":
		"Place a hut right beside Berry Bushes, or click a hut to switch it to Berries: a hut works one resource"
	},
	{"id": "dwelling", "text": "Build a Dwelling. Kith grow when there's room and steady food", "building": "dwelling"},
	{"id": "charcoal", "text": "Research Fire, then build a Charcoal Pit", "building": "charcoal_pit"},
	{"id": "twine", "text": "Research Cordage, then build a Twine Post", "building": "twine_post"},
	{"id": "haulers", "text": "Research Paths & Haulers: it unlocks Roads and lets idle Kith haul", "tech": "haulers"},
	{"id": "road", "text": "Lay a Road from a hut to the Hearth: road-linked buildings run on their own"},
	{"id": "rush", "text": "Click a working building to rush it: it finishes its cycle at once"},
	{"id": "kiln", "text": "Research Pottery, then build a Kiln", "building": "kiln"},
	{
		"id": "wheel",
		"text": "Research Water Wheel (Stone Axe, Masonry) and build one on the river",
		"building": "water_wheel"
	},
	{"id": "grind", "text": "Build a Grindstone within 3 tiles of the wheel"},
	{"id": "storehouse", "text": "Research Storehouse and build one by far workshops", "building": "storehouse"},
	{"id": "calendar", "text": "Research Calendar: Farming, plus Storytelling or Megaliths", "tech": "calendar"},
	{"id": "bronze", "text": "Research Bronze Dawn", "tech": "bronze_dawn"},
]
