extends RefCounted
## Era 4, Ironfall (design-system/19-ironfall.md), stage 1: the words and numbers that are not an item, a tile, a tech or a
## building. Read through the `Data` facade (scripts/data.gd). The tech tree is in scripts/data/ironfall/techs.gd. Every number
## is a placeholder to tune with the pacing bot.

## The story id recorded the first time the Starfall is over and its ending card is put away (Story.update): the era is entered.
## Techs with `after` (Data.TECHS) stay out of view until it has happened.
const IRONFALL_EVENT := "ironfall_begun"
const TECH_AFTER_EVENTS := ["ironfall_begun"]

## The land grows south when the first of these techs is learned, by SOUTH_ROWS rows (scripts/map_south.gd).
const SOUTH_TECHS := ["coal_seams", "ironstone"]
const SOUTH_ROWS := 22
const LAND_GREW_SOUTH_EVENT := "The land opens to the south. Dark ridges of coal and red hills of iron lie there, under the fog"
## What a coal seam holds: the tiles of a seam share the pile, and the seam is spent when it is gone. Three seams in all.
const COAL_PER_SEAM := 500

const SEAM_LEFT := "%d of %d left in this seam"  # what is in the ground, what the seam held
const SEAM_SPENT_STATUS := "The seam is spent. Tear this down and put its Kith to work elsewhere"
const SEAM_SPENT_ALERT := "Seam spent"
const SEAM_SPENT_EVENT := "A coal seam is spent. The coal that is left is in the stockpile"

const ERA_TAB_LOCKED_IRONFALL := "Opens when the Starfall is over"

## How many jobs an Iron Tool lasts in a worker's hands (flint 40, bronze 200).
const IRON_TOOL_JOBS := 300

## The Goals panel for the era (Story.goal_list), once the Starfall is over.
const GOALS_HEADER_ERA4 := "Ironfall goals %d/%d"
const GOALS_IRONFALL_CLOSING := "More is coming: Teardown, steam and Livewire."
const GOALS_ERA4 := [
	{
		"id": "coal_seams",
		"text": "Discover Coal Seams: it names the coal in the new land, south of the map",
		"tech": "coal_seams"
	},
	{"id": "find_coal", "text": "Find coal in the south: lay roads south, the seams lie on the near side"},
	{
		"id": "coal_mine",
		"text": "Build a Coal Mine on a Coal Seam (it takes two Kith). Each seam holds about 500 and runs out",
		"building": "coal_mine"
	},
	{"id": "ironstone", "text": "Discover Ironstone: it names the iron hills in the south", "tech": "ironstone"},
	{"id": "find_iron", "text": "Find the Iron Hills in the south"},
	{"id": "iron_mine", "text": "Build a Mine on the Iron Hills"},
	{
		"id": "bloomery",
		"text": "Discover Bloomery, then build one: Iron Ore and Coal make Iron",
		"building": "bloomery"
	},
	{"id": "first_iron", "text": "Make the first Iron"},
	{
		"id": "iron_tools",
		"text": "Discover Iron Tools: workers with an Iron Tool are 75% faster than with bronze",
		"tech": "iron_tools"
	},
]
