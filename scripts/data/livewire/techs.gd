extends RefCounted
## The tech tree of era 5, Livewire (design-system/23-livewire.md): fourteen techs, one constant each, so scripts/data/techs.gd can
## list them in TECHS (a constant cannot merge two dictionaries). It sits in a folder of its own, like the Ironfall tree, because
## every constant in scripts/data/*.gd must be re-exported by the Data facade, and these are only read through TECHS.
## Costs are first guesses in the goods of the tier before (Steel, Iron, Wire), to tune with the pacing bot. Every tech carries a
## `stage` (page 23, Staging): stage 1 builds Power Poles, Order Board and Generator, and the rest are on the board, locked
## (Data.ERA_BUILT_STAGE says how far the era is built: see Rules.tech_enabled). `after` is a story id (Data.STORY_EVENTS): the
## roots stay out of view until it has happened. The board has tiers 0 to 3 and the gate in column 4.

const POWER_POLES := {
	"abbr": "Pp",
	"color": Color("c9a26b"),
	"name": "Power Poles",
	"era": 5,
	"stage": 1,
	"lane": "fiber",
	"tier": 0,
	"slot": 0,
	"unlock": "Power Pole, the net, Wire, Wire Mill",
	"icon": "watchtower",
	"after": "livewire_begun",
	"requires": [],
	"cost": {"iron": 40, "steel": 10, "rope": 40},
	"desc":
	(
		"Carry power on a wire. Power Poles within 3 tiles of one another join into a net, and machines and engines within 2 tiles"
		+ " of a pole share it. A Wire Mill draws Copper into Wire."
	),
}
const ORDER_BOARD := {
	"abbr": "Ob",
	"color": Color("d9c27a"),
	"name": "Order Board",
	"era": 5,
	"stage": 1,
	"lane": "lore",
	"tier": 0,
	"slot": 0,
	"unlock": "Order Board, 3 orders: Pause and Bring first",
	"icon": "glyph_wall",
	"after": "livewire_begun",
	"requires": [],
	"cost": {"iron": 30, "steel": 10, "brick": 60},
	"desc":
	(
		"Write down how the town should run. The Board holds three one-line orders: when a good in the stores is below or above a"
		+ " number, Pause a kind of workshop or Bring a good first. The Kith carry them out without being asked."
	),
}
const TIDE_WATCH := {
	"abbr": "Tw",
	"color": Color("8fd694"),
	"name": "Tide Watch",
	"era": 5,
	"stage": 2,
	"lane": "lore",
	"tier": 0,
	"slot": 1,
	"unlock": "The Bloom's front on the map",
	"icon": "wanderer",
	"after": "livewire_begun",
	"requires": ["bloom_sampling"],
	"cost": {"iron": 30, "steel": 10, "brick": 40},
	"desc":
	"Draw the green tide's front on the map, with a note on the building it is heading for and when it will arrive.",
}
const GENERATOR := {
	"abbr": "Ge",
	"color": Color("e9a23b"),
	"name": "Generator",
	"era": 5,
	"stage": 1,
	"lane": "hearth",
	"tier": 1,
	"slot": 0,
	"unlock": "Generator",
	"icon": "kiln",
	"requires": ["power_poles", "boiler"],
	"cost": {"iron": 60, "steel": 25, "brick": 80},
	"desc":
	(
		"A great flywheel on a coal fire. A Generator gives a whole net 8 units and burns coal only while the net asks for more than"
		+ " the others give."
	),
}
const ARC_LAMPS := {
	"abbr": "Al",
	"color": Color("a6e3ff"),
	"name": "Arc Lamps",
	"era": 5,
	"stage": 2,
	"lane": "lore",
	"tier": 1,
	"slot": 0,
	"unlock": "Arc Lamp",
	"icon": "watchtower",
	"requires": ["power_poles", "shard_lamps"],
	"cost": {"steel": 20, "wire": 20, "brick": 40},
	"desc": "A lamp that needs power and lights 5 tiles. The tide does not enter its light.",
}
const FOREMEN := {
	"abbr": "Fm",
	"color": Color("b8a1e0"),
	"name": "Foremen",
	"era": 5,
	"stage": 2,
	"lane": "lore",
	"tier": 1,
	"slot": 1,
	"unlock": "3 more standing orders",
	"icon": "kith",
	"side": true,
	"requires": ["order_board", "taught_hands_ii"],
	"cost": {"steel": 20, "iron": 40, "rope": 60},
	"desc": "Kith who run a floor for the rest. The Order Board holds three more orders.",
}
const POWERED_MINES := {
	"abbr": "Pm",
	"color": Color("8a8f98"),
	"name": "Powered Mines",
	"era": 5,
	"stage": 2,
	"lane": "stone",
	"tier": 1,
	"slot": 0,
	"unlock": "Mines on a net dig twice as fast",
	"icon": "mine",
	"side": true,
	"requires": ["power_poles", "iron_tools"],
	"cost": {"steel": 25, "wire": 25, "iron": 40},
	"desc": "A Mine on a net digs twice as fast. Coal is finite, so this is a loan from the future.",
}
const FACTORY_FLOOR := {
	"abbr": "Ff",
	"color": Color("c0c6cc"),
	"name": "Factory Floor",
	"era": 5,
	"stage": 3,
	"lane": "stone",
	"tier": 2,
	"slot": 0,
	"unlock": "Factory Floor",
	"icon": "crucible",
	"requires": ["generator", "steel"],
	"cost": {"steel": 50, "wire": 40, "iron": 80},
	"desc":
	"A floor that runs one chosen recipe at three times a workshop's speed, and eats its inputs three times as fast.",
}
const SCORCHER := {
	"abbr": "Sc",
	"color": Color("ff7b39"),
	"name": "Scorcher",
	"era": 5,
	"stage": 2,
	"lane": "hearth",
	"tier": 2,
	"slot": 0,
	"unlock": "Scorcher",
	"icon": "smelter",
	"requires": ["generator", "arc_lamps"],
	"cost": {"steel": 40, "wire": 30, "brick": 80},
	"desc": "A burner that needs power and coal, and clears Bloom ground within 4 tiles, one tile in 30 seconds.",
}
const FIREBREAKS := {
	"abbr": "Fb",
	"color": Color("90be6d"),
	"name": "Firebreaks",
	"era": 5,
	"stage": 2,
	"lane": "land",
	"tier": 2,
	"slot": 0,
	"unlock": "Firebreak strips",
	"icon": "field",
	"side": true,
	"requires": ["tide_watch", "iron_plough"],
	"cost": {"iron": 50, "steel": 20, "wood": 150},
	"desc": "Cleared strips of ground that burn and never grow. The tide goes round them or waits.",
}
const SHARD_DYNAMO := {
	"abbr": "Sd",
	"color": Color("9fe0f0"),
	"name": "Shard Dynamo",
	"era": 5,
	"stage": 3,
	"lane": "fiber",
	"tier": 3,
	"slot": 0,
	"unlock": "Shard Dynamo",
	"icon": "kiln",
	"requires": ["generator", "shard_boiler"],
	"cost": {"steel": 60, "wire": 50, "iron": 80},
	"desc": "A Generator on Shards: 1 Shard for 160 seconds and no coal, once the Heat plate is learned.",
}
const CHAIN_ORDERS := {
	"abbr": "Co",
	"color": Color("d7b8f2"),
	"name": "Chain Orders",
	"era": 5,
	"stage": 3,
	"lane": "lore",
	"tier": 3,
	"slot": 0,
	"unlock": "3 more orders, orders that run orders, Send",
	"icon": "kith",
	"side": true,
	"requires": ["foremen", "tide_watch"],
	"cost": {"steel": 60, "wire": 40, "iron": 60},
	"desc": "Three more orders, an order that names another to run next, and the Send verb for expeditions.",
}
const LIVING_GROUND := {
	"abbr": "Lg",
	"color": Color("7bd389"),
	"name": "Living Ground",
	"era": 5,
	"stage": 2,
	"lane": "land",
	"tier": 3,
	"slot": 0,
	"unlock": "Ash Ground, Fields +50% on it",
	"icon": "field",
	"side": true,
	"requires": ["scorcher"],
	"lessons": ["spore", "root", "sap"],
	"cost": {"steel": 40, "wire": 40, "brick": 120},
	"desc": "Burnt Bloom ground becomes Ash Ground, and Fields on it yield 50% more. It needs the three Bloom Lessons.",
}
const SKYWARD := {
	"abbr": "Sk",
	"color": Color("7fe0d0"),
	"name": "Skyward",
	"era": 5,
	"stage": 3,
	"lane": "gate",
	"tier": 4,
	"slot": 0,
	"unlock": "The era ends",
	"icon": "wanderer",
	"requires": ["factory_floor", "scorcher", "chain_orders", "shard_dynamo"],
	"cost": {"steel": 120, "iron": 100, "wire": 120, "brick": 100},
	"desc": "A mast over the town with a lamp that never goes out. The hum carries up the wire, and something answers.",
}
