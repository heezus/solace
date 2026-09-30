extends RefCounted
## Map tiles and how hard they are to cross. Read through the `Data` facade (scripts/data.gd).

const TILES := {
	"grass": {"name": "Grassland", "yields": "", "color": Color("7cb342"), "buildable": true},
	"flax": {"name": "Wild Flax", "yields": "fiber", "color": Color("7cb342"), "buildable": false},
	"tree": {"name": "Forest", "yields": "wood", "color": Color("2e7d32"), "buildable": false},
	"rock": {"name": "Rocks", "yields": "stone", "color": Color("8d8d8d"), "buildable": false},
	"gravel": {"name": "Riverbed Gravel", "yields": "flint", "color": Color("b0a18a"), "buildable": false},
	"clay": {"name": "Clay Bank", "yields": "clay", "color": Color("c47a5a"), "buildable": false},
	"berry": {"name": "Berry Bushes", "yields": "berries", "color": Color("558b2f"), "buildable": false},
	"grain": {"name": "Wild Grain", "yields": "grain", "color": Color("d4b44a"), "buildable": false},
	"river": {"name": "River", "yields": "", "color": Color("3a86c8"), "buildable": false},
	"shard": {"name": "Strange Stone", "yields": "", "color": Color("7cb342"), "buildable": false},
}

const SHARD_TEXT := (
	"A smooth stone, faintly warm, humming with a pale light no fire gave it. "
	+ "The elders say it fell from the sky before memory. It does nothing. Yet."
)

## Path cost of each tile kind. Rivers are impassable without a Wooden Bridge, or slow once Rafts are known.
const WALK_COST := {"tree": 2.0, "rock": 2.0, "road": 0.5, "river": 4.0}

## A Road laid on Rocks cuts a mountain pass: it costs this instead, and the rock is cleared.
const PASS_COST := {"stone": 3}
