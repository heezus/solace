extends RefCounted
## Every building, the build bar's tabs and order. Read through the `Data` facade (scripts/data.gd).

## kind: "camp" | "house" | "road" | "bridge" | "field" | "depot" | "gatherer" | "processor" | "power" | "aura" | "cairn"
##   | "shed" (a Cart Shed) | "tower" (a Watchtower)
## A `stone` bridge bears carts and walks at the Causeway pace; the Wooden Bridge bears the Kith only.
## A processor with `trade` has no fixed recipe: it swaps Data.TRADE_GIVE of the good it is set to give for
## Data.TRADE_GET of the one it is set to get (the building's `give` and `get`). `sight` is how far a building sees.
## `story` buildings stay off the build bar until their tech is on the board and reachable (nothing to spoil early).
## Processors turn `in` into `out` every `time` seconds (a processor with no `in` just makes `out`).
## A processor with `dig` is a mine: it stands on one of its `on_tiles` and digs `dig` of whatever that tile yields
## each cycle, with no input and without walking. `crew` is how many people it needs (default 1); it works only
## while all of them are at it.
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
		"desc": "Room for 3 more Kith. Must be within 6 tiles of the Hearth. They grow while food keeps coming in.",
	},
	"road":
	{
		"name": "Road",
		"kind": "road",
		"tech": "haulers",
		"cost": {"wood": 2},
		"color": Color("c8a36a"),
		"desc":
		(
			"A timber trackway. Kith walk twice as fast on roads, and haulers serve only road-linked buildings."
			+ " Through Forest, a Road fells the trees; on Rocks, it cuts a pass for 3 Stone."
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
	"stone_bridge":
	{
		"name": "Stone Bridge",
		"kind": "bridge",
		"stone": true,
		"tech": "causeways",
		"cost": {"stone": 6, "brick": 4},
		"color": Color("b3aca2"),
		"desc":
		"Goes on a river tile. The Kith cross at Causeway pace, and carts can cross too. Drag to span the river.",
	},
	"field":
	{
		"name": "Field",
		"kind": "field",
		"job": "Reaper",
		"tech": "farming",
		"cost": {"fiber": 3, "grain": 1},
		"color": Color("d4b44a"),
		"desc": "Plant wild grain on open grassland, for huts to gather. Drag to sow.",
	},
	"storehouse":
	{
		"name": "Storehouse",
		"kind": "depot",
		"tech": "storehouse",
		"cost": {"wood": 20, "stone": 10},
		"color": Color("8d6e63"),
		"desc": "A second stockpile. Haulers drop off and pick up at the nearest one.",
	},
	"charcoal_pit":
	{
		"name": "Charcoal Pit",
		"kind": "processor",
		"job": "Collier",
		"tech": "fire",
		"cost": {"wood": 5, "stone": 5},
		"in": {"wood": 2},
		"out": {"charcoal": 2},
		"time": 4.0,
		"color": Color("3d405b"),
		"desc": "Smoulders wood into charcoal.",
	},
	"twine_post":
	{
		"name": "Twine Post",
		"kind": "processor",
		"job": "Roper",
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
		"desc":
		"Works one resource within 2 tiles, the one it stands next to. Until a road links it, it works only when you click it.",
	},
	"kiln":
	{
		"name": "Kiln",
		"kind": "processor",
		"job": "Potter",
		"tech": "pottery",
		"cost": {"stone": 10, "clay": 10},
		"in": {"clay": 1, "charcoal": 1},
		"out": {"brick": 2},
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
		"job": "Miller",
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
		"job": "Fisher",
		"tech": "nets",
		"cost": {"wood": 15, "rope": 5},
		"in": {},
		"out": {"fish": 1},
		"time": 6.0,
		"needs_river": true,
		"color": Color("0077b6"),
		"desc": "Must touch the river. Its worker traps Fish, worth 2 food.",
	},
	"mine":
	{
		"name": "Mine",
		"kind": "processor",
		"job": "Miner",
		"tech": "mining",
		"story": true,
		"cost": {"wood": 80, "stone": 30},
		"in": {},
		"out": {},
		"dig": 2,
		"on_tiles": ["copper_hills", "tin_stream"],
		"crew": 2,
		"time": 5.0,
		"color": Color("8f9b5a"),
		"desc": "Stands on Copper Hills or a Tin Stream. Two Kith dig ore without walking.",
	},
	"smelter":
	{
		"name": "Smelter",
		"kind": "processor",
		"job": "Smith",
		"tech": "smelting",
		"story": true,
		"cost": {"stone": 30, "brick": 40},
		"in": {"copper_ore": 2, "charcoal": 1},
		"out": {"copper": 1},
		"time": 5.0,
		"color": Color("b87333"),
		"desc": "Melts Copper Ore with Charcoal into Copper.",
	},
	"crucible":
	{
		"name": "Crucible",
		"kind": "processor",
		"job": "Founder",
		"tech": "alloying",
		"story": true,
		"cost": {"brick": 50, "stone": 30},
		"in": {"copper": 3, "tin": 1},
		"out": {"bronze": 1},
		"time": 6.0,
		"color": Color("cd7f32"),
		"desc": "Pours 3 Copper and 1 Tin into Bronze.",
	},
	"cart_shed":
	{
		"name": "Cart Shed",
		"kind": "shed",
		"tech": "the_wheel",
		"story": true,
		"cost": {"wood": 60, "rope": 20, "copper": 6},
		"color": Color("c9a45c"),
		"desc": "Turns two haulers into carts. A cart carries twice a hauler's load, but only on roads.",
		"status": "Two haulers push carts for it.",
	},
	"trading_post":
	{
		"name": "Trading Post",
		"kind": "processor",
		"job": "Trader",
		"tech": "markets",
		"story": true,
		"cost": {"wood": 60, "stone": 20, "brick": 20},
		"in": {},
		"out": {},
		"trade": true,
		"time": 10.0,
		"color": Color("f2a65a"),
		"desc": "Swaps 3 of one good for 1 of another, slowly. Choose what it gives and what it gets.",
	},
	"watchtower":
	{
		"name": "Watchtower",
		"kind": "tower",
		"tech": "sky_watch",
		"story": true,
		"cost": {"stone": 40, "brick": 30, "copper": 6},
		"sight": 9,
		"color": Color("8d8a99"),
		"desc": "Sees far over the fog, and from its top the Kith watch the sky for the Wanderer.",
		"status": "Watching the sky.",
	},
	"standing_stone":
	{
		"name": "Standing Stone",
		"kind": "aura",
		"tech": "megaliths",
		"story": true,
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
		"story": true,
		"cost": {"stone": 12},
		"needs_shard": true,
		"color": Color("caf0f8"),
		"research_discount": 0.05,
		"desc":
		(
			"A ring of stones beside the Strange Stone. Must go next to it."
			+ " Its hum steadies the Kith's thinking: every tech costs 5% less (one is enough)."
			+ " Something far off may hear it."
		),
		"status": "It hums. The Kith think clearer. Something far off may hear.",
	},
}

## The build bar's tabs, in order. Craft by hand has its own small group beside them.
const BUILD_TABS := {
	"Homes": ["dwelling"],
	"Gathering": ["gatherers_hut", "field", "fishing_weir"],
	"Workshops": ["charcoal_pit", "twine_post", "kiln", "water_wheel", "grindstone"],
	"Metal": ["mine", "smelter", "crucible"],
	"Logistics": ["road", "bridge", "stone_bridge", "storehouse", "cart_shed", "trading_post"],
	"Lore": ["standing_stone", "shard_cairn", "watchtower"],
}

const BUILD_ORDER := [
	"dwelling",
	"road",
	"bridge",
	"stone_bridge",
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
	"mine",
	"smelter",
	"crucible",
	"cart_shed",
	"trading_post",
	"watchtower",
]

## Output a building holds before it stops, when nobody hauls it away.
const BUFFER_CAP := 10
