extends RefCounted
## Map tiles and how hard they are to cross. Read through the `Data` facade (scripts/data.gd).

const TILES := {
	"grass":
	{
		"name": "Grassland",
		"yields": "",
		"color": Color("9bb85c"),
		"buildable": true,
		"hint": "Open ground: you can build here. Pick a card below, or press T to discover more to build."
	},
	# `clearable`: the Demolish tool turns the tile into open grass (see scripts/clearing.gd). A tile without it stays,
	# and `stays` is the pill's reason.
	"flax": {"name": "Wild Flax", "yields": "fiber", "color": Color("9bb85c"), "buildable": false, "clearable": true},
	"tree": {"name": "Forest", "yields": "wood", "color": Color("3f7d3a"), "buildable": false, "clearable": true},
	"rock": {"name": "Rocks", "yields": "stone", "color": Color("8d8d8d"), "buildable": false, "clearable": true},
	"gravel":
	{
		"name": "Riverbed Gravel",
		"yields": "flint",
		"color": Color("b0a18a"),
		"buildable": false,
		"clearable": true,
	},
	"clay": {"name": "Clay Bank", "yields": "clay", "color": Color("c47a5a"), "buildable": false, "clearable": true},
	"berry":
	{"name": "Berry Bushes", "yields": "berries", "color": Color("558b2f"), "buildable": false, "clearable": true},
	"grain": {"name": "Wild Grain", "yields": "grain", "color": Color("d4b44a"), "buildable": false, "clearable": true},
	"river":
	{
		"name": "River",
		"yields": "",
		"color": Color("3a86c8"),
		"buildable": false,
		"stays": "The river stays · water can't be cleared",
	},
	"shard":
	{
		"name": "Strange Stone",
		"yields": "",
		"color": Color("9bb85c"),
		"buildable": false,
		"stays": "The Strange Stone stays · it was here before the Kith",
	},
	# Era 2 ore (the land that grows east at Bronze Dawn). Nobody gathers ore with a hut: it is dug by hand once
	# `tech` is known, or by a Mine standing on it (`mine_only`). `plain_name` is what the tile is called before then.
	"copper_hills":
	{
		"name": "Copper Hills",
		"plain_name": "Hills",
		"yields": "copper_ore",
		"color": Color("8f9b5a"),
		"buildable": false,
		"mine_only": true,
		"tech": "prospecting",
		"stays": "The land stays · ore lies where the earth put it",
	},
	"tin_stream":
	{
		"name": "Tin Stream",
		"plain_name": "Stony Stream",
		"yields": "tin",
		"color": Color("b0a18a"),
		"buildable": false,
		"mine_only": true,
		"tech": "prospecting",
		"stays": "The land stays · ore lies where the earth put it",
	},
	# Era 4 (Ironfall), in the land that grows south (scripts/map_south.gd). Coal is finite: the tiles of a seam share a pile
	# (World.seam_left, Data.COAL_PER_SEAM) and become a Spent Seam when it is gone. Iron is plentiful.
	"coal_seam":
	{
		"name": "Coal Seam",
		"plain_name": "Dark Ridge",
		"yields": "coal",
		"color": Color("3b3b46"),
		"buildable": false,
		"mine_only": true,
		"tech": "coal_seams",
		"gated": true,
		"stays": "The land stays · coal lies where the earth put it",
	},
	"iron_hills":
	{
		"name": "Iron Hills",
		"plain_name": "Rust-red Hills",
		"yields": "iron_ore",
		"color": Color("8a4f3a"),
		"buildable": false,
		"mine_only": true,
		"tech": "ironstone",
		"gated": true,
		"stays": "The land stays · ore lies where the earth put it",
	},
	# Era 4, stage 2: the three Bloom patches at the far edge of the south (scripts/map_south.gd): a small spread of green and
	# magenta ground with a sample at its middle (Data.BLOOM_TILES). The ground does nothing; a party can take the sample
	# home (scripts/teardown_finds.gd), and then the sample tile is plain Bloom ground.
	"bloom_ground":
	{
		"name": "Bloom Ground",
		"yields": "",
		"color": Color("8a4f9a"),
		"buildable": false,
		"hint": "A spread of Bloom: green and magenta ground. It does nothing. Yet.",
		"stays": "The Bloom stays · nobody knows how to clear it",
	},
	"bloom_spore":
	{
		"name": "Bloom Sample (Spore)",
		"yields": "",
		"color": Color("c04a9d"),
		"buildable": false,
		"hint": "A Bloom sample lies here. A party can bring it home.",
		"stays": "The Bloom stays · nobody knows how to clear it",
	},
	"bloom_root":
	{
		"name": "Bloom Sample (Root)",
		"yields": "",
		"color": Color("6fa84a"),
		"buildable": false,
		"hint": "A Bloom sample lies here. A party can bring it home.",
		"stays": "The Bloom stays · nobody knows how to clear it",
	},
	"bloom_sap":
	{
		"name": "Bloom Sample (Sap)",
		"yields": "",
		"color": Color("d98ad0"),
		"buildable": false,
		"hint": "A Bloom sample lies here. A party can bring it home.",
		"stays": "The Bloom stays · nobody knows how to clear it",
	},
	"spent_seam":
	{
		"name": "Spent Seam",
		"yields": "",
		"color": Color("55555e"),
		"buildable": false,
		"hint": "The coal here is gone. A Mine standing on it has nothing left to dig.",
		"stays": "The seam is spent · nothing is left to dig",
	},
}

## The Demolish tool on a resource tile (scripts/clearing.gd): the pill's words, %s being the tile's name. Clearing is
## free and gives nothing back. A tile is cleared only while at least CLEAR_KEEP other tiles of its kind are left on the whole map.
const CLEAR_TEXT := "Clear %s · gone for good"
const CLEAR_LAST := "That's the last %s · it stays"
const CLEAR_FOG := "Unexplored · can't clear what you can't see"
const CLEAR_KEEP := 1
const CLEAR_EVENT := "Cleared the %s for good"

## What the Info panel adds under an empty tile, when something to gather lies within NEAR_RADIUS tiles of it.
const NEAR_TEXT := "Close by you can gather: %s."
const NEAR_RADIUS := 3

## The second grass shade, for the checker (4% from `grass`), and the flat color of unexplored land.
const GRASS_ALT := Color("93b055")
const FOG := Color("5b5046")

const SHARD_TEXT := (
	"A smooth stone, faintly warm, humming with a pale light no fire gave it. "
	+ "The elders say it fell from the sky before memory. It does nothing. Yet."
)

## Path cost of each tile kind. Rivers are impassable without a Wooden Bridge, or slow once Rafts are known.
const WALK_COST := {"tree": 2.0, "rock": 2.0, "road": 0.5, "river": 4.0}

## A Road laid on Rocks cuts a mountain pass: it costs this instead, and the rock is cleared.
const PASS_COST := {"stone": 3}
