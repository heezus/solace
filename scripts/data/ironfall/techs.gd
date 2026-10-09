extends RefCounted
## The tech tree of era 4, Ironfall (design-system/19-ironfall.md): sixteen techs, one constant each, so scripts/data/techs.gd can
## list them in TECHS (a constant cannot merge two dictionaries). It sits in a folder of its own because every constant
## in scripts/data/*.gd must be re-exported by the Data facade, and these are only read through TECHS.
## Costs are placeholders to tune with the pacing bot. The first stage builds Coal Seams, Ironstone, Bloomery and Iron
## Tools, the second Teardown and the third the rest (every tech carries a `stage`, and Data.BUILT_STAGE says how far the
## game is built: a tech past it is on the board, locked, see Rules.tech_enabled).
## `after` is a story id (Data.STORY_EVENTS): the tech stays out of view until it has happened (Research.tech_visible).
## `gift` names a Starfall gift (Data.LUMEN_GIFTS) the tech needs read before it can be bought (Rules.tech_gate_missing), and
## `lesson` a Lesson (Data.LESSONS) the building it unlocks waits for: the Shard Lamp on the Lamp core, the Shard Boiler on the
## Heat plate. `lessons` (the gate) are Lessons that must all be learned: one of each Bloom sample is "one of each Bloom
## sample" opened at the Bench. The era's board has tiers 0 to 3 and the gate in column 4.

const COAL_SEAMS := {
	"abbr": "Cs",
	"color": Color("4a4a58"),
	"name": "Coal Seams",
	"era": 4,
	"lane": "stone",
	"tier": 0,
	"slot": 0,
	"unlock": "Coal named, hand digging, Coal Mine",
	"icon": "mine",
	"after": "ironfall_begun",
	"requires": [],
	"cost": {"bronze": 10, "copper": 20, "rope": 60},
	"desc":
	(
		"Learn to read the dark ridges in the new land to the south. Coal Seams are named, a hold on one digs coal by hand,"
		+ " and a Coal Mine can stand on it. Each seam holds a pile of about 500, and then it is spent."
	),
}
const IRONSTONE := {
	"abbr": "Is",
	"color": Color("a65f45"),
	"name": "Ironstone",
	"era": 4,
	"lane": "stone",
	"tier": 0,
	"slot": 1,
	"unlock": "Iron named, hand digging",
	"icon": "item_copper_ore",
	"after": "ironfall_begun",
	"requires": [],
	"cost": {"bronze": 10, "copper": 20, "wood": 150},
	"desc":
	(
		"Heavy red stone that rings when struck. Iron Hills are named and a hold on one digs ore by hand. The land opens south of"
		+ " the old map, under fog, with coal and iron in it. A Mine can stand on the hills."
	),
}
const TEARDOWN := {
	"abbr": "Td",
	"color": Color("b8a8f0"),
	"name": "Teardown",
	"era": 4,
	"lane": "lore",
	"tier": 0,
	"slot": 0,
	"unlock": "Teardown Bench, Lessons list, Iron Gears",
	"icon": "wanderer",
	"after": "ironfall_begun",
	"requires": [],
	"cost": {"bronze": 15, "flour": 40, "brick": 40},
	"desc":
	(
		"Open a thing to see how it works. A Teardown Bench takes a part apart and the Kith keep one Lesson from it."
		+ " Parts come from the Wreck, the Lumen Camp and the Bloom patches."
	),
}
const BLOOMERY := {
	"abbr": "Bl",
	"color": Color("e0703a"),
	"name": "Bloomery",
	"era": 4,
	"lane": "hearth",
	"tier": 1,
	"slot": 0,
	"unlock": "Bloomery",
	"icon": "smelter",
	"requires": ["coal_seams", "ironstone"],
	"cost": {"brick": 120, "coal": 40, "bronze": 15},
	"desc": "A clay stack fired with coal. A Bloomery turns 2 Iron Ore and 1 Coal into Iron, slowly.",
}
const BOILER := {
	"abbr": "Bo",
	"color": Color("d4a373"),
	"name": "Boiler",
	"era": 4,
	"stage": 3,
	"lane": "hearth",
	"tier": 1,
	"slot": 1,
	"unlock": "Boiler",
	"icon": "kiln",
	"requires": ["coal_seams", "teardown"],
	"cost": {"brick": 100, "coal": 60, "bronze": 20},
	"desc": "A closed vessel over a coal fire. A Boiler powers machines within 5 tiles, and needs no river.",
}
const BEAST_PEN := {
	"abbr": "Bp",
	"color": Color("86b6c9"),
	"name": "Beast Pen",
	"era": 4,
	"stage": 3,
	"lane": "land",
	"tier": 1,
	"slot": 0,
	"unlock": "Beast Pen",
	"icon": "dwelling",
	"side": true,
	"requires": ["teardown", "plough"],
	"cost": {"wood": 200, "grain": 120, "rope": 60},
	"desc": "The starstuff touched the beasts. A Beast Pen tames one, and a beast cart pulls 30 on roads without coal.",
}
const IRON_TOOLS := {
	"abbr": "It",
	"color": Color("6f7d8c"),
	"name": "Iron Tools",
	"era": 4,
	"lane": "stone",
	"tier": 2,
	"slot": 0,
	"unlock": "Iron Tools, faster than bronze",
	"icon": "item_bronze_tools",
	"requires": ["bloomery", "ironstone"],
	"cost": {"iron": 25, "coal": 40, "wood": 100},
	"desc":
	(
		"Iron replaces bronze. A worker with an Iron Tool works 75 points faster than with bronze, and it lasts 300 jobs."
		+ " Tools wear out: keep the Bloomery going."
	),
}
const RAILS := {
	"abbr": "Ra",
	"color": Color("c7b299"),
	"name": "Rails",
	"era": 4,
	"stage": 3,
	"lane": "fiber",
	"tier": 2,
	"slot": 0,
	"unlock": "Rail, Steam Shed (the Steam Cart)",
	"icon": "tile_road",
	"requires": ["boiler", "bloomery"],
	"cost": {"iron": 60, "coal": 60, "wood": 200},
	"desc":
	"A road of iron strips. Rail carries 8 times open ground, and the Steam Cart runs only on rails and carries 40.",
}
const SHARD_LAMPS := {
	"abbr": "Sl",
	"color": Color("9fe0f0"),
	"name": "Shard Lamps",
	"era": 4,
	"stage": 3,
	"lane": "lore",
	"tier": 2,
	"slot": 0,
	"unlock": "Shard Lamp",
	"icon": "watchtower",
	"gift": "light",
	"lesson": "lamp_core",
	"requires": ["teardown"],
	"cost": {"iron": 30, "brick": 60, "bronze": 20},
	"desc": "A lamp post that burns one shard a long while and lights 3 tiles, once the Lamp core is learned.",
}
const TAUGHT_HANDS_II := {
	"abbr": "T2",
	"color": Color("c9b6f2"),
	"name": "Taught Hands II",
	"era": 4,
	"stage": 3,
	"lane": "lore",
	"tier": 2,
	"slot": 1,
	"unlock": "Teach-by-doing is faster",
	"icon": "kith",
	"side": true,
	"requires": ["teardown", "tally_sticks"],
	"cost": {"iron": 30, "rope": 80, "flour": 60},
	"desc": "Teach-by-doing is faster, and a job learned spreads to every hut of that kind.",
}
const BLAST_FURNACE := {
	"abbr": "Bf",
	"color": Color("ff7b39"),
	"name": "Blast Furnace",
	"era": 4,
	"stage": 3,
	"lane": "hearth",
	"tier": 3,
	"slot": 0,
	"unlock": "Forge, Iron x2 per firing",
	"icon": "crucible",
	"requires": ["bloomery", "boiler"],
	"cost": {"iron": 80, "brick": 140, "coal": 80},
	"desc":
	"A taller stack and a steady blast. A Forge turns Iron and Coal into Steel, and every firing gives twice the Iron.",
}
const IRON_PLOUGH := {
	"abbr": "Ip",
	"color": Color("8ab17d"),
	"name": "Iron Plough",
	"era": 4,
	"stage": 3,
	"lane": "land",
	"tier": 3,
	"slot": 0,
	"unlock": "Fields +50%",
	"icon": "field",
	"side": true,
	"requires": ["iron_tools", "plough"],
	"cost": {"iron": 40, "wood": 120, "coal": 30},
	"desc": "An iron share cuts the heavy ground. Fields yield another 50%.",
}
const SHARD_BOILER := {
	"abbr": "Sb",
	"color": Color("e9c46a"),
	"name": "Shard Boiler",
	"era": 4,
	"stage": 3,
	"lane": "fiber",
	"tier": 3,
	"slot": 0,
	"unlock": "Shard Boiler",
	"icon": "kiln",
	"gift": "craft",
	"lesson": "heat_plate",
	"requires": ["boiler", "shard_lamps"],
	"cost": {"iron": 45, "brick": 60, "bronze": 30},
	"desc": "A boiler that burns shards, so far less coal, once the Heat plate is learned.",
}
const STEEL := {
	"abbr": "Se",
	"color": Color("a9bfd1"),
	"name": "Steel",
	"era": 4,
	"stage": 3,
	"lane": "stone",
	"tier": 3,
	"slot": 0,
	"unlock": "Steel Tools: +50% more",
	"icon": "item_bronze_tools",
	"requires": ["iron_tools", "blast_furnace"],
	"cost": {"iron": 60, "coal": 60, "brick": 50},
	"desc": "Hard, springy metal. Steel Tools make a worker another 50% faster and wear slowly.",
}
const BLOOM_SAMPLING := {
	"abbr": "Bs",
	"color": Color("c77dd6"),
	"name": "Bloom Sampling",
	"era": 4,
	"stage": 3,
	"lane": "lore",
	"tier": 3,
	"slot": 0,
	"unlock": "Bloom samples",
	"icon": "wanderer",
	"requires": ["teardown", "shard_lamps"],
	"cost": {"iron": 40, "brick": 50, "rope": 60},
	"desc": "Expeditions can take a sample from each patch of the Bloom, and the Bloom Lessons open.",
}
const LIVEWIRE := {
	"abbr": "Lw",
	"color": Color("7fe0d0"),
	"name": "Livewire",
	"era": 4,
	"stage": 3,
	"lane": "gate",
	"tier": 4,
	"slot": 0,
	"unlock": "The era ends",
	"icon": "wanderer",
	"requires": ["steel", "rails", "shard_boiler", "bloom_sampling"],
	"lessons": ["spore", "root", "sap"],
	"cost": {"steel": 50, "iron": 70, "brick": 60, "rope": 40},
	"desc": "The lamps burn without a flame. Far to the north, something green moves in the fog.",
}
