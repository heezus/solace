extends RefCounted
## Items, what the people eat, and the hand-crafting recipes. Read through the `Data` facade (scripts/data.gd).

const ITEMS := {
	"wood": {"name": "Wood", "color": Color("8b5a2b")},
	"stone": {"name": "Stone", "color": Color("9aa0a6")},
	"flint": {"name": "Flint", "color": Color("4a4e69")},
	"fiber": {"name": "Fiber", "color": Color("a7c957"), "desc": "Cut from wild flax"},
	"clay": {"name": "Clay", "color": Color("c8553d")},
	"berries": {"name": "Berries", "color": Color("d62246")},
	"grain": {"name": "Grain", "color": Color("e9c46a")},
	"rope": {"name": "Rope", "color": Color("bc8a5f")},
	"charcoal": {"name": "Charcoal", "color": Color("2b2d42")},
	"brick": {"name": "Brick", "color": Color("b5543a")},
	"flour": {"name": "Flour", "color": Color("f1e3c8")},
	"flint_tools": {"name": "Flint Tools", "one": "Flint Tool", "short": "Tools", "color": Color("6c757d")},
	"fish": {"name": "Fish", "color": Color("5fa8d3")},
	# Era 2 (Bronze Dawn). `era` marks an item the stone age never holds.
	"copper_ore": {"name": "Copper Ore", "short": "Ore", "color": Color("a5683a"), "era": 2},
	"tin": {"name": "Tin", "color": Color("c0c7cf"), "era": 2},
	"copper": {"name": "Copper", "color": Color("b87333"), "era": 2},
	"bronze": {"name": "Bronze", "color": Color("cd7f32"), "era": 2},
	"bronze_tools":
	{"name": "Bronze Tools", "one": "Bronze Tool", "short": "Tools", "color": Color("a0522d"), "era": 2},
	# Era 4 (Ironfall). Coal is finite: a seam holds a pile and runs out (Data.COAL_PER_SEAM). Steel is made from stage 3.
	"coal": {"name": "Coal", "color": Color("2f2f38"), "era": 4, "desc": "Fuel for the Bloomery. Each seam runs out"},
	"iron_ore": {"name": "Iron Ore", "short": "Ore", "color": Color("8a4f3a"), "era": 4},
	"iron": {"name": "Iron", "color": Color("7d8791"), "era": 4},
	"steel": {"name": "Steel", "color": Color("a9bfd1"), "era": 4},
	"iron_tools": {"name": "Iron Tools", "one": "Iron Tool", "short": "Tools", "color": Color("56606b"), "era": 4},
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
	"copper_ore",
	"tin",
	"copper",
	"bronze",
	"bronze_tools",
	"coal",
	"iron_ore",
	"iron",
	"steel",
	"iron_tools",
]

## Food value of each edible item. The Kith eat from the stockpile.
const FOOD_VALUE := {"berries": 1.0, "fish": 2.0, "flour": 3.0}
## The order the Kith eat in. Flour comes last, and only what research doesn't need.
const EAT_ORDER := ["berries", "fish", "flour"]

## What Smoking and Baking make food worth (researched in the tech tree).
const SMOKED_BERRY_FOOD := 2.0
const BAKED_FLOUR_FOOD := 5.0

## Made by hand at the Hearth, or in a workshop.
const RECIPES := {
	"rope": {"name": "Rope", "tech": "cordage", "in": {"fiber": 2}, "out": {"rope": 1}},
	"flint_tools":
	{"name": "Flint Tools", "tech": "knapping", "in": {"flint": 2, "wood": 2}, "out": {"flint_tools": 1}},
	"bronze_tools":
	{"name": "Bronze Tools", "tech": "bronze_tools", "in": {"bronze": 1, "wood": 2}, "out": {"bronze_tools": 1}},
	"iron_tools": {"name": "Iron Tools", "tech": "iron_tools", "in": {"iron": 1, "wood": 2}, "out": {"iron_tools": 1}},
}
