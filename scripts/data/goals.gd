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
	"wanderer_named": "The new light in the sky was named the Wanderer",
	"star_falling": "The Wanderer was seen to fall",
	"cairn_raised": "The Shard Cairn was raised",
	"star_landed": "Something came down in the east",
	"lumen_arrived": "Strangers came out of the fog",
	"name_read": "The first set of marks was read",
	"market_open": "The strangers would trade",
	"shrine_raised": "A shrine was raised for both peoples",
	"guard_raised": "The Kith set a watch on the strangers",
	"wreck_found": "The crash site was reached",
	"light_read": "The marks of Light were read",
	"body_read": "The marks of the Body were read",
	"growth_read": "The marks of Growth were read",
	"craft_read": "The marks of Craft were read",
	"hunger_shared": "The Kith shared their food with the strangers",
	"hunger_held": "The Kith kept their food from the strangers",
	"shards_given": "The Kith gave the strangers the shards",
	"shards_traded": "The Kith traded the strangers a shard",
	"shards_refused": "The Kith refused the strangers the shards",
	"dark_kept": "The Kith went dark when the strangers asked",
	"dark_refused": "The Kith kept their fires lit against the warning",
	"warning_read": "The Warning was read",
	"bloom_seen": "A strange growth was seen at the edge of the fog",
	"lean_allies": "The Lumen and the Kith ended as allies",
	"lean_neighbours": "The Lumen and the Kith ended as neighbours",
	"lean_enemies": "The Lumen and the Kith ended as enemies",
	"ironfall_begun": "The Starfall was over, and the Kith turned to iron",
	"teardown_lesson": "The Kith opened a part and kept what it taught",
	"livewire_lit": "The wires hummed, and the age of iron was done",
	"livewire_begun": "The wires were strung, and the Kith began to write their orders",
}

## Techs that are story moments: tech id -> the STORY_EVENTS id the Story block records when it is researched.
const STORY_TECHS := {
	"haulers": "haulers",
	"bronze_dawn": "bronze_dawn",
	"sky_watch": "wanderer_named",
	"falling_star": "star_falling",
	"livewire": "livewire_lit",
}

## The opening checklist. A goal with `tech` or `building` is met once that is researched or built;
## Story.goal_met() checks the others by id.

## The Goals panel's header: goals done, goals in all. The done ones list under it on hover.
const GOALS_HEADER := "Goals %d/%d"
const GOALS_ALL_DONE := "All goals done."
## Under it once the Falling Star has fallen: hopeful, then not (the card says the same, scripts/era_card.gd).
const GOALS_STAR_CLOSING := "The star is coming down. Keep building while you wait."
## The same header once Bronze Dawn is discovered, over the era's own list (GOALS_ERA2).
const GOALS_HEADER_ERA2 := "Dawn goals %d/%d"

const GOALS := [
	{
		"id": "learn_wood",
		"text": "Hold the mouse on trees to gather Wood, until a Kith learns it (6 harvests, 10 for later lessons)"
	},
	{
		"id": "learn_berries",
		"text": "Hold the mouse on the red Berry Bushes near the Hearth. The Kith eat berries: keep a good stock"
	},
	{"id": "learn_stone", "text": "Gather Stone and Flint by hand until they're learned too"},
	{
		"id": "flax",
		"text": "Find Wild Flax (tall stalks with tiny blue-violet flowers) and gather it: all Fiber comes from flax"
	},
	{"id": "knapping", "text": "Press T and discover Knapping", "tech": "knapping"},
	{"id": "tools", "text": "Craft Flint Tools: each harvest takes 0.6s instead of 0.8s"},
	{"id": "hut_tech", "text": "Discover Gatherer's Hut", "tech": "gatherers_hut"},
	{
		"id": "hut",
		"text": "Place a Gatherer's Hut next to trees or rocks. A hut works one resource, and only when you click it",
		"building": "gatherers_hut"
	},
	{
		"id": "trip",
		"text": "Click your hut to send a trip: its Kith brings back a bundle (3 harvests' worth). No click, no trip"
	},
	{
		"id": "berries",
		"text":
		(
			"Place a hut right beside Berry Bushes (or click a hut to switch it to Berries), then click it to send"
			+ " a trip for berries. A hut only works when you click it"
		)
	},
	{
		"id": "dwelling",
		"text": "Build a Dwelling. Kith grow when there's room and steady food (a hut on a road feeds the Hearth)",
		"building": "dwelling"
	},
	{"id": "twine", "text": "Discover Cordage, then build a Twine Post", "building": "twine_post"},
	{"id": "haulers", "text": "Discover Paths & Haulers: it unlocks Roads and lets idle Kith haul", "tech": "haulers"},
	{"id": "road", "text": "Lay a Road from a hut to the Hearth: road-linked buildings run on their own"},
	{"id": "rush", "text": "Click a working building to rush it: it finishes its cycle at once"},
	{"id": "charcoal", "text": "Discover Fire, then build a Charcoal Pit", "building": "charcoal_pit"},
	{"id": "kiln", "text": "Discover Pottery, then build a Kiln", "building": "kiln"},
	{
		"id": "wheel",
		"text": "Discover Water Wheel (Stone Axe, Masonry) and build one on the river",
		"building": "water_wheel"
	},
	{"id": "grind", "text": "Build a Grindstone within 3 tiles of the wheel"},
	{"id": "storehouse", "text": "Discover Storehouse and build one by far workshops", "building": "storehouse"},
	{"id": "calendar", "text": "Discover Calendar: Farming, plus Storytelling or Megaliths", "tech": "calendar"},
	{"id": "bronze", "text": "Discover Bronze Dawn", "tech": "bronze_dawn"},
]

## The second era's checklist: it takes over from GOALS once Bronze Dawn is discovered, and its goals count in any order.
## A goal with `tech` is met once that is researched, one with `building` once one stands; Story.goal_met() checks the
## rest by id (the ore is found when its tile is out of the fog).
const GOALS_ERA2 := [
	{"id": "prospecting", "text": "Discover Prospecting: it names the ore in the new land", "tech": "prospecting"},
	{"id": "find_copper", "text": "Find copper in the east: lay roads east, and press Look east to see the way"},
	{"id": "copper_road", "text": "Lay a road to the copper hills"},
	{
		"id": "mine",
		"text": "Discover Mining, then build a Mine on the copper hills (it takes two Kith)",
		"building": "mine"
	},
	{"id": "smelting", "text": "Discover Smelting", "tech": "smelting"},
	{"id": "smelter", "text": "Build a Smelter: Copper Ore and Charcoal make Copper", "building": "smelter"},
	{"id": "find_tin", "text": "Find tin: it lies far off, to the north-east"},
	{
		"id": "crucible",
		"text": "Discover Alloying, then build a Crucible: Copper and Tin make Bronze",
		"building": "crucible"
	},
	{"id": "first_bronze", "text": "Make the first Bronze"},
]
