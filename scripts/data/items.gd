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
	"flint_tools": {"name": "Flint Tools", "short": "Tools", "color": Color("6c757d")},
	"fish": {"name": "Fish", "color": Color("5fa8d3")},
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
}
