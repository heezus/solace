extends RefCounted
## Every building, the build bar's tabs and order. Read through the `Data` facade (scripts/data.gd).

## kind: "camp" | "house" | "road" | "bridge" | "field" | "depot" | "gatherer" | "processor" | "power" | "aura" | "cairn"
##   | "shed" (a Cart Shed) | "tower" (a Watchtower) | "wall" (the Glyph Wall)
##   | "refuge" (the Lumen Camp, the shared shrine, the Guard Post) | "bench" (the Teardown Bench) | "barrel" (the Rain Barrel)
## A building with an `event` (and no tech) opens when that story event has happened (Data.STORY_EVENTS): the era of the
## Lumen has no research to gate it, and the card stays off the build bar until then.
## A "field" with `crop` "flax" sows flax instead of grain (World.flax_fields); it yields fiber as wild flax does.
## A `stone` bridge bears carts and walks at the top road tier; the Wooden Bridge bears the Kith only. A road has a
## `tier` (0 path, 1 gravel, 2 paved, 3 rail; Data.ROAD_SPEEDS): dragging a higher tier over a lower one upgrades it in place for
## the difference in cost, and the Stone Bridge does the same over a Wooden Bridge.
## A processor with `trade` has no fixed recipe: it swaps Data.TRADE_GIVE of the good it is set to give for
## Data.TRADE_GET of the one it is set to get (the building's `give` and `get`); a `trade_give` of its own replaces
## Data.TRADE_GIVE (the Lumen Market gives 2). A trading building trades every good the people have held except its `trade_not`
## list (the Trading Post: Kith goods, never a shard), or only the goods in its `trade_only` list (the Lumen Market: the Lumen's own
## far-travelled goods). `sight` is how far a building sees.
## `lesson` (a Data.LESSONS id) opens a building once that Lesson is learned (scripts/teardown.gd): the card stays off the bar
## until then. `unique` allows one only. A `bench` has no worker: haulers carry parts to it (scripts/teardown.gd).
## `story` buildings stay off the build bar until their tech is on the board and reachable (nothing to spoil early).
## Processors turn `in` into `out` every `time` seconds (a processor with no `in` just makes `out`).
## A processor with `makes` is a tool bench: a list of tool recipes (Data.RECIPES ids, worst first), and it makes
## the best one the people have the tech and the stock for (the building's `make`), only while the stockpile holds
## fewer tools than they need (Work.enough). Its own `in` and `out` stay empty.
## A processor with `dig` is a mine: it stands on one of its `on_tiles` and digs `dig` of whatever that tile yields
## each cycle, with no input and without walking. `crew` is how many people it needs (default 1); it works only
## while all of them are at it.
## A building with `fed` has no worker: haulers bring it its `in` (Data.RECIPES-style, up to `stock` of it) and it burns that on its
## own (scripts/steam.gd): a "power" with a `fuel` burns `burn` seconds of it for each item and powers machines within `radius`
## only while lit; a "lamp" lights `light` tiles; a "pen" eats Grain while it tames its beast. A "shed" with a `cart` ("hand" by
## default, "steam") turns a hauler into that kind of cart (Data.CART_KINDS); a tamed Beast Pen gives a beast cart.
## Buildings without a worker show `status`, or `desc` if they have none.
## Livewire (page 23): a "pole" (the Power Pole) joins a net with the poles within Data.POLE_LINK tiles; a machine (`needs_power`) or
## an engine (a "power" with `gives`, the units it adds to a net: Water Wheel 2, Boiler 3 while lit, Generator 8) within
## Data.POLE_REACH tiles of a pole is on that net (scripts/power.gd). A "board" (the Order Board) holds the standing orders
## (scripts/livewire.gd). A "power" with a `radius` of 0 reaches nothing of its own: it feeds a net or nothing.
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
		"tier": 0,
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
	"gravel_road":
	{
		"name": "Gravel Road",
		"kind": "road",
		"tier": 1,
		"tech": "haulers",
		"cost": {"wood": 2, "flint": 2},
		"color": Color("a9a395"),
		"desc":
		(
			"A road bedded in riverbed gravel: Kith and haulers move 25% faster than on a Road."
			+ " Drag over a Road to upgrade it in place: you pay only the difference for each tile."
		),
	},
	"paved_road":
	{
		"name": "Paved Road",
		"kind": "road",
		"tier": 2,
		"tech": "paved_roads",
		"cost": {"wood": 2, "stone": 2, "brick": 1},
		"color": Color("8e9aa6"),
		"desc":
		(
			"A road laid in dressed stone: Kith and haulers move 50% faster than on a Road."
			+ " Drag over a Road or a Gravel Road to upgrade it in place: you pay only the difference for each tile."
		),
	},
	"rail":
	{
		"name": "Rail",
		"kind": "road",
		"tier": 3,
		"tech": "rails",
		"story": true,
		"cost": {"wood": 2, "iron": 1},
		"color": Color("6b7280"),
		"desc":
		(
			"Iron strips on sleepers: Kith and haulers move 8 times as fast as over open ground. Steam Carts run only on Rail."
			+ " Drag over a road to upgrade it in place: you pay only the difference for each tile. Rail stops at the river."
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
		(
			"Goes on a river tile. The Kith cross at paved pace, and carts can cross too. Drag to span the river,"
			+ " or drag over a Wooden Bridge to rebuild it in stone."
		),
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
	"flax_field":
	{
		"name": "Flax Field",
		"kind": "field",
		"crop": "flax",
		"tech": "cordage",
		"cost": {"fiber": 2},
		"color": Color("8fbf9f"),
		"desc": "Sow flax seed on open grassland, for huts and hands to cut as fiber. It never runs out. Drag to sow.",
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
	"tool_bench":
	{
		"name": "Tool Bench",
		"kind": "processor",
		"job": "Toolmaker",
		"tech": "knapping",
		"cost": {"wood": 10, "stone": 5},
		"in": {},
		"out": {},
		"makes": ["flint_tools", "bronze_tools", "iron_tools", "steel_tools"],
		"time": 6.0,
		"color": Color("8a8d91"),
		"desc": "Makes tools so you do not have to. Keeps a spare or two ready, then waits until more are needed.",
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
		"gives": 2,
		"needs_river": true,
		"color": Color("2a9d8f"),
		"desc": "Must touch the river. Powers machines within 3 tiles.",
	},
	"boiler":
	{
		"name": "Boiler",
		"kind": "power",
		"tech": "boiler",
		"story": true,
		"cost": {"stone": 30, "brick": 50, "iron": 10},
		"radius": 5,
		"gives": 3,
		"fed": true,
		"fuel": true,
		"in": {"coal": 1},
		"stock": 6,
		"burn": 20.0,
		"color": Color("b5543a"),
		"desc":
		(
			"A closed vessel over a coal fire. Powers machines within 5 tiles, with no river needed, while it burns."
			+ " It burns 1 Coal for every 20 seconds a machine wants power (1 Charcoal lasts half as long), and haulers bring it."
		),
	},
	"shard_boiler":
	{
		"name": "Shard Boiler",
		"kind": "power",
		"tech": "shard_boiler",
		"lesson": "heat_plate",
		"story": true,
		"cost": {"stone": 30, "brick": 50, "iron": 20, "bronze": 10},
		"radius": 5,
		"gives": 3,
		"fed": true,
		"in": {"shard": 1},
		"stock": 4,
		"burn": 80.0,
		"color": Color("e9c46a"),
		"desc":
		(
			"A Boiler built round the Lumen heat plate. Burns 1 Shard for 80 seconds of power and no coal at all."
			+ " Powers machines within 5 tiles."
		),
	},
	"generator":
	{
		"name": "Generator",
		"kind": "power",
		"tech": "generator",
		"story": true,
		"cost": {"stone": 40, "brick": 60, "iron": 18},
		"radius": 0,
		"gives": 8,
		"fed": true,
		"fuel": true,
		"in": {"coal": 1},
		"stock": 6,
		"burn": 25.0,
		"color": Color("e9a23b"),
		"desc":
		(
			"A great flywheel on a coal fire. It gives a whole net 8 units, and burns 1 Coal for every 25 seconds the net asks"
			+ " for more than the others give (1 Charcoal lasts half as long). Stand it within 2 tiles of a Power Pole; haulers bring it."
		),
	},
	"shard_dynamo":
	{
		"name": "Shard Dynamo",
		"kind": "power",
		"tech": "shard_dynamo",
		"lesson": "heat_plate",
		"story": true,
		"cost": {"brick": 60, "iron": 18, "steel": 6, "wire": 20},
		"radius": 0,
		"gives": 8,
		"fed": true,
		"in": {"shard": 1},
		"stock": 4,
		"burn": 160.0,
		"color": Color("9fe0f0"),
		"desc":
		(
			"A Generator that burns the Lumen heat plate's way: 1 Shard for every 160 seconds the net asks for more than the"
			+ " others give, and no coal. It gives a whole net 8 units. Stand it within 2 tiles of a Power Pole; haulers bring"
			+ " the Shards."
		),
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
		"cost": {"wood": 60, "stone": 30, "rope": 20},
		"in": {},
		"out": {},
		"dig": 2,
		"on_tiles": ["copper_hills", "tin_stream", "iron_hills"],
		"crew": 2,
		"time": 5.0,
		"color": Color("8f9b5a"),
		"desc":
		"Stands on Copper Hills, a Tin Stream or (with Ironstone) Iron Hills. Two Kith dig ore without walking.",
	},
	"coal_mine":
	{
		"name": "Coal Mine",
		"kind": "processor",
		"job": "Miner",
		"tech": "coal_seams",
		"story": true,
		"cost": {"wood": 60, "stone": 40, "brick": 40, "charcoal": 30},
		"in": {},
		"out": {},
		"dig": 2,
		"on_tiles": ["coal_seam"],
		"crew": 2,
		"time": 5.0,
		"color": Color("3b3b46"),
		"desc":
		"Stands on a Coal Seam. Two Kith dig coal without walking. A seam holds about 500, and then it is spent.",
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
	"bloomery":
	{
		"name": "Bloomery",
		"kind": "processor",
		"job": "Smith",
		"tech": "bloomery",
		"story": true,
		"cost": {"stone": 40, "brick": 60, "clay": 30},
		"in": {"iron_ore": 2, "coal": 1},
		"fuel": true,
		"out": {"iron": 1},
		"time": 9.0,
		"color": Color("a65f45"),
		"desc":
		"A clay stack fired with coal. Melts 2 Iron Ore and 1 Coal into Iron, slowly. Burns Charcoal at half speed when Coal runs short.",
	},
	"forge":
	{
		"name": "Forge",
		"kind": "processor",
		"job": "Smith",
		"tech": "blast_furnace",
		"story": true,
		"cost": {"stone": 40, "brick": 60, "iron": 20},
		"in": {"iron": 2, "coal": 1},
		"fuel": true,
		"out": {"steel": 1},
		"time": 8.0,
		"needs_power": true,
		"color": Color("a9bfd1"),
		"desc":
		(
			"Needs power. A steady blast turns 2 Iron and 1 Coal into Steel (Charcoal at half speed when Coal runs short)."
			+ " Stand it within 5 tiles of a Boiler."
		),
	},
	"wire_mill":
	{
		"name": "Wire Mill",
		"kind": "processor",
		"job": "Wiredrawer",
		"tech": "power_poles",
		"story": true,
		"cost": {"stone": 30, "brick": 40, "iron": 12},
		"in": {"copper": 1},
		"out": {"wire": 1},
		"time": 6.0,
		"needs_power": true,
		"color": Color("d98a4a"),
		"desc": "Needs power. Draws Copper into Wire, the good of the age of the wire.",
	},
	"factory_floor":
	{
		"name": "Factory Floor",
		"kind": "processor",
		"job": "Floor hand",
		"tech": "factory_floor",
		"story": true,
		"cost": {"brick": 60, "iron": 24, "wire": 20},
		"crew": 2,
		"floor": ["twine_post", "kiln", "bloomery", "forge", "wire_mill"],
		"time": 4.0,  # a stand-in: a Floor works at its recipe's workshop time over FLOOR_SPEED (Work.time), but this lets cards show a pace
		"needs_power": true,
		"color": Color("c0c6cc"),
		"desc":
		(
			"Needs power and two Kith. Runs one chosen recipe (Rope, Bricks, Iron, Steel or Wire) at three times a workshop's"
			+ " speed, and eats its inputs three times as fast. Pick the recipe on its card."
		),
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
		"desc": "Turns a hauler into a hand cart: one Kith, three times a hauler's load, but only on roads.",
		"status": "A hauler pulls a hand cart for it.",
	},
	"steam_shed":
	{
		"name": "Steam Shed",
		"kind": "shed",
		"cart": "steam",
		"tech": "rails",
		"story": true,
		"cost": {"wood": 60, "iron": 40, "brick": 30},
		"color": Color("6f7d8c"),
		"desc":
		(
			"Turns a hauler into a Steam Cart: 4 times a hauler's load (40), but only on Rail, and it burns 1 Coal for every"
			+ " 3 trips. With no coal it hauls like a plain hauler."
		),
		"status": "A hauler drives a Steam Cart for it.",
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
		"trade_not": ["shard"],
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
	"glyph_wall":
	{
		"name": "Glyph Wall",
		"kind": "wall",
		"tech": "",
		"event": "lumen_arrived",
		"cost": {"stone": 40, "brick": 20},
		"color": Color("7aa6c2"),
		"desc":
		"A smooth wall where the Kith copy every mark the strangers show them. Click it to guess what each one means.",
		"status": "Copying marks.",
	},
	"expedition_post":
	{
		"name": "Expedition Post",
		"kind": "post",
		"tech": "",
		"event": "name_read",
		"cost": {"wood": 60, "stone": 40, "rope": 50},
		"color": Color("d9a066"),
		"desc": "Where parties leave for the fog and the crash site. Choose a target and a pack, then send two Kith.",
		"status": "Waiting for a party.",
	},
	"lumen_camp":
	{
		"name": "Lumen Camp",
		"kind": "refuge",
		"tech": "",
		"event": "name_read",
		"cost": {"wood": 60, "stone": 30, "rope": 20},
		"color": Color("9fd8e8"),
		"desc":
		"A place for the strangers to sit by their own fire. They trust the Kith a little more while it stands.",
		"status": "The strangers rest here.",
	},
	"lumen_market":
	{
		"name": "Lumen Market",
		"kind": "processor",
		"job": "Trader",
		"tech": "",
		"event": "market_open",
		"cost": {"wood": 60, "stone": 30, "rope": 20},
		"in": {},
		"out": {},
		"trade": true,
		"trade_give": 2,
		"trade_only": ["shard", "coal", "wire", "steel"],
		"time": 8.0,
		"color": Color("9fd8e8"),
		"desc":
		(
			"Swaps 2 of one good for 1 of another, but only the strangers' own goods: Shards, Coal, Wire and Steel. "
			+ "Choose what it gives and what it gets."
		),
	},
	"shared_shrine":
	{
		"name": "Shared Shrine",
		"kind": "refuge",
		"tech": "",
		"event": "name_read",
		"cost": {"stone": 30, "wood": 20, "rope": 10},
		"color": Color("c9b8e8"),
		"desc": "A small shrine where both peoples leave something. They trust the Kith more while it stands.",
		"status": "Both peoples leave something here.",
	},
	"teardown_bench":
	{
		"name": "Teardown Bench",
		"kind": "bench",
		"tech": "teardown",
		"cost": {"iron": 20, "brick": 40},
		"near_hearth": true,
		"unique": true,
		"color": Color("b8a8f0"),
		"desc":
		(
			"Where the Kith open a part to see how it works. Haulers carry parts here, one takes about 40 seconds, and"
			+ " each teaches one Lesson for good. A second copy of a part gives only scrap."
		),
		"status": "Waiting for a part.",
	},
	"rain_barrel":
	{
		"name": "Rain Barrel",
		"kind": "barrel",
		"tech": "",
		"lesson": "water_glass",
		"cost": {"wood": 20, "brick": 10},
		"color": Color("7ec8e3"),
		"desc": "A glass-lined barrel from the Water glass Lesson. Fields within 3 tiles never wilt: +20% Field yield.",
		"status": "Holding the rain.",
	},
	"beast_pen":
	{
		"name": "Beast Pen",
		"kind": "pen",
		"tech": "beast_pen",
		"story": true,
		"cost": {"wood": 60, "grain": 30, "rope": 20},
		"fed": true,
		"in": {"grain": 1},
		"stock": 4,
		"color": Color("86b6c9"),
		"desc":
		(
			"The starstuff touched the beasts. Feed a shard-touched beast Grain for a minute and it is tame:"
			+ " it pulls a beast cart, 30 a trip on roads, with no coal. Never on Rail."
		),
	},
	"shard_lamp":
	{
		"name": "Shard Lamp",
		"kind": "lamp",
		"tech": "shard_lamps",
		"lesson": "lamp_core",
		"story": true,
		"cost": {"iron": 6, "brick": 8, "stone": 6},
		"fed": true,
		"in": {"shard": 1},
		"stock": 2,
		"burn": 300.0,
		"light": 3,
		"color": Color("9fe0f0"),
		"desc":
		(
			"A lamp post built round the Lumen lamp core. One Shard burns for five minutes and it lights 3 tiles."
			+ " With the Sap Lesson, a Lantern Party may stay out past dusk while one burns."
		),
	},
	"power_pole":
	{
		"name": "Power Pole",
		"kind": "pole",
		"tech": "power_poles",
		"story": true,
		"cost": {"wood": 2, "iron": 1},
		"color": Color("a9825a"),
		"desc":
		(
			"Poles within 3 tiles of one another join into a net. A machine or an engine within 2 tiles of a pole is on its net,"
			+ " and draws from it or feeds it. A short net runs every machine on it slower."
		),
	},
	"order_board":
	{
		"name": "Order Board",
		"kind": "board",
		"tech": "order_board",
		"story": true,
		"cost": {"wood": 40, "brick": 40, "iron": 6},
		"near_hearth": true,
		"unique": true,
		"color": Color("d9c27a"),
		"desc":
		(
			"Where the town's standing orders are written: when a good in the stores is below or above a number, pause a workshop"
			+ " or bring a good first. Three orders. Must be within 6 tiles of the Hearth."
		),
		"status": "The orders are read every few seconds.",
	},
	# Era 5, stage 2: holding the tide (scripts/tide.gd). `draws` is a machine with no worker that asks the net for power.
	"arc_lamp":
	{
		"name": "Arc Lamp",
		"kind": "arc_lamp",
		"tech": "arc_lamps",
		"story": true,
		"cost": {"steel": 2, "wire": 6, "brick": 10},
		"needs_power": true,
		"draws": true,
		"light": 5,
		"color": Color("f3e6a1"),
		"desc":
		(
			"A white arc on a pole. The Bloom does not enter its light, 5 tiles round, while it has power, and a building"
			+ " standing in it is not lost. Stand it within 2 tiles of a Power Pole."
		),
		"status": "It lights its tiles while the net gives power.",
	},
	"scorcher":
	{
		"name": "Scorcher",
		"kind": "scorcher",
		"tech": "scorcher",
		"story": true,
		"cost": {"steel": 6, "wire": 8, "brick": 20},
		"needs_power": true,
		"draws": true,
		"fed": true,
		"fuel": true,
		"in": {"coal": 1},
		"stock": 6,
		"burn": 120.0,
		"reach": 4,
		"color": Color("e0642b"),
		"desc":
		(
			"A jet of flame on a pump. It burns the Bloom ground nearest it clear, a tile every 30 seconds within 4 tiles,"
			+ " and 1 Coal does 4 tiles (1 Charcoal does 2). Burnt ground is never taken again. Stand it within 2 tiles"
			+ " of a Power Pole; haulers bring the fuel."
		),
	},
	"firebreak":
	{
		"name": "Firebreak",
		"kind": "firebreak",
		"tech": "tide_watch",
		"story": true,
		"cost": {"wood": 4, "stone": 1},
		"color": Color("6e5a45"),
		"desc":
		(
			"A strip of bare, trodden ground. The Bloom takes 10 times as long to cross it, so a line of them buys a few minutes."
			+ " Drag a line of them."
		),
		"status": "Bare ground.",
	},
	"guard_post":
	{
		"name": "Guard Post",
		"kind": "refuge",
		"tech": "",
		"event": "lumen_arrived",
		"cost": {"wood": 40, "stone": 40},
		"color": Color("8d6e63"),
		"desc":
		"A watch on the strangers. The Kith near it work a little faster, and the strangers trust the Kith less while it stands.",
		"status": "The Kith keep watch.",
	},
}

## The build bar's tabs, in order. Craft by hand has its own small group beside them.
const BUILD_TABS := {
	"Homes": ["dwelling"],
	"Gathering": ["gatherers_hut", "field", "flax_field", "fishing_weir", "rain_barrel", "beast_pen"],
	"Workshops":
	[
		"tool_bench",
		"charcoal_pit",
		"twine_post",
		"kiln",
		"water_wheel",
		"boiler",
		"shard_boiler",
		"generator",
		"shard_dynamo",
		"scorcher",
		"grindstone"
	],
	"Metal": ["mine", "coal_mine", "smelter", "crucible", "bloomery", "forge", "wire_mill", "factory_floor"],
	"Logistics":
	[
		"road",
		"gravel_road",
		"paved_road",
		"rail",
		"bridge",
		"stone_bridge",
		"storehouse",
		"cart_shed",
		"steam_shed",
		"trading_post",
		"power_pole",
		"firebreak"
	],
	"Lore":
	[
		"standing_stone",
		"shard_cairn",
		"watchtower",
		"glyph_wall",
		"lumen_camp",
		"expedition_post",
		"lumen_market",
		"shared_shrine",
		"guard_post",
		"teardown_bench",
		"shard_lamp",
		"order_board",
		"arc_lamp"
	],
}

const BUILD_ORDER := [
	"dwelling",
	"road",
	"gravel_road",
	"paved_road",
	"rail",
	"bridge",
	"stone_bridge",
	"field",
	"flax_field",
	"storehouse",
	"charcoal_pit",
	"twine_post",
	"tool_bench",
	"gatherers_hut",
	"kiln",
	"water_wheel",
	"boiler",
	"shard_boiler",
	"grindstone",
	"fishing_weir",
	"standing_stone",
	"shard_cairn",
	"mine",
	"coal_mine",
	"smelter",
	"crucible",
	"bloomery",
	"forge",
	"cart_shed",
	"steam_shed",
	"trading_post",
	"watchtower",
	"glyph_wall",
	"lumen_camp",
	"expedition_post",
	"lumen_market",
	"shared_shrine",
	"guard_post",
	"teardown_bench",
	"rain_barrel",
	"beast_pen",
	"shard_lamp",
	"generator",
	"shard_dynamo",
	"factory_floor",
	"wire_mill",
	"power_pole",
	"order_board",
	"arc_lamp",
	"scorcher",
	"firebreak",
]

## Output a building holds before it stops, when nobody hauls it away.
const BUFFER_CAP := 10
