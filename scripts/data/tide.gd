extends RefCounted
## Era 5, Livewire, stage 2: the tide (design-system/23-livewire.md). The numbers and words of the Bloom's creep out of the south
## patches, the buildings it eats, and what holds it back (Arc Lamps, Firebreaks, the Scorcher). Read through the `Data` facade
## (scripts/data.gd). Every number is a first guess to tune with the pacing bot.

# --- The creep ---
## Seconds a front takes to cross one open tile. A road, rock or river tile takes TIDE_SLOW_ROAD times as long, a paved road or
## rail TIDE_SLOW_RAIL times, a Firebreak TIDE_SLOW_FIREBREAK times, and ground in a burning Shard Lamp's light TIDE_SLOW_LAMP times.
const TIDE_STEP_SECONDS := 35.0
const TIDE_SLOW_ROAD := 3.0
const TIDE_SLOW_RAIL := 6.0
const TIDE_SLOW_FIREBREAK := 10.0
const TIDE_SLOW_LAMP := 2.0
## The tide never comes within this many tiles of the Hearth.
const TIDE_HEARTH_RING := 6.0
## A tile the tide may not enter yet (an Arc Lamp's light) is looked at again after this long.
const TIDE_RETRY_SECONDS := 10.0
## The ground the tide leaves as it is under it: ore and water and the Strange Stone, which only wear the Bloom's colour.
const TIDE_KEEPS := [
	"river",
	"shard",
	"copper_hills",
	"tin_stream",
	"coal_seam",
	"iron_hills",
	"spent_seam",
	"bloom_ground",
	"bloom_spore",
	"bloom_root",
	"bloom_sap",
	"bloom_tide"
]
## A building on Bloom ground is overgrown at once: it stops, and is lost after this long unless it is held (an Arc Lamp's light
## or a burning Scorcher's reach stops the count).
const OVERGROWN_LOST_SECONDS := 180.0
## While any building stands overgrown, the Bloom eats the stores (design-system/24-balance.md, pick 3): once in BLOOM_EAT_SECONDS it
## takes BLOOM_EAT_SHARE of one good that has at least BLOOM_EAT_MIN in the stores, picked by the clock and the map's seed.
const BLOOM_EAT_SECONDS := 60.0
const BLOOM_EAT_SHARE := 0.05
const BLOOM_EAT_MIN := 40
const BLOOM_EAT_LINE := "The Bloom has eaten %d %s from the stores."  # how many, the good
## With Tide Watch the Kith say so once, when the front is about this far from a building.
const TIDE_WARN_SECONDS := 180.0
## Arrival times are worked out this often (game seconds), and not past this horizon.
const TIDE_ETA_SECONDS := 3.0
const TIDE_ETA_HORIZON := 1200.0

# --- Holding it ---
const SCORCH_REACH := 4.0  # tiles round a Scorcher it clears Bloom ground in
const SCORCH_SECONDS := 30.0  # one tile of Bloom ground burnt clear in this long
const ASH_FIELD_BONUS := 0.5  # a Field on burnt ground yields this much more once Living Ground is learned
const POWERED_MINE_SPEED := 2.0  # a Mine on a net that gives power digs this many times as fast (Powered Mines)

# --- Words ---
const TILE_BLOOM_TIDE := "bloom_tide"
const TIDE_BEGAN_LINE := "The Bloom is on the move: green ground is creeping up from the three patches in the south."
const TIDE_BUILD_ERROR := "The Bloom is here: burn it clear first"
const TIDE_STAYS := "The Bloom stays · a Scorcher can burn it clear"
const OVERGROWN_STATUS := "Overgrown by the Bloom: it will be lost in %s unless the ground is burnt clear or held"  # a duration
const OVERGROWN_HELD := "Overgrown by the Bloom, but held: it stays dead until the ground is burnt clear"
const OVERGROWN_ALERT := "Overgrown"
const OVERGROWN_LOST_LINE := "The Bloom took the %s"  # a building's name
const TIDE_REACHES_LINE := "The Bloom reaches the %s in about %s"  # a building's name, a duration
const TIDE_REACHES_NOTE := "Tide Watch: the Bloom reaches this in about %s"  # a duration
const TIDE_FRONT_NOTE := "Tide Watch: the Bloom's front lies %d tiles from the Hearth"  # tiles
const SCORCHER_NO_POWER := "No power: stand it within 2 tiles of a Power Pole whose net gives power"
const SCORCHER_NOTHING := "Nothing to burn: no Bloom ground within 4 tiles"
const SCORCHER_BURNING := "Burning Bloom ground clear: %d tiles done, %d Coal in store"  # tiles done, coal stored
const SCORCHER_COLD := "Out of Coal: haulers bring it more"
const SCORCHER_ROW := "Burns 1 Coal for every 4 tiles of Bloom ground it clears within %d tiles, one every %d seconds"  # reach, seconds
const ARC_LIT := "Lit: the Bloom does not enter its light, %d tiles round"  # tiles
const ARC_DARK := "Dark: it needs power from a net, so the Bloom may pass"
const ARC_ROW := "Lights %d tiles round it while it has power"  # tiles
const FIREBREAK_NOTE := "Bare ground: the Bloom takes %d times as long to cross it"  # a multiple
const TIDE_HERE_BLOOM := "Bloom ground. A Scorcher within 4 tiles can burn it clear."
const TIDE_HERE_ASH := "Burnt ground: the Bloom cannot grow here. Fields on it yield more once Living Ground is learned."

# --- Goals (appended to GOALS_ERA5) ---
const GOALS_TIDE := [
	{"id": "tide_watch", "text": "Discover Tide Watch: it draws the Bloom's front on the map", "tech": "tide_watch"},
	{
		"id": "arc_lamp",
		"text": "Build an Arc Lamp (Lore tab) on a net: the Bloom does not enter its light",
		"building": "arc_lamp"
	},
	{"id": "scorcher", "text": "Build a Scorcher (Workshops tab) on a net and feed it Coal", "building": "scorcher"},
	{"id": "burnt_clear", "text": "Burn the first Bloom ground clear with a Scorcher"},
]
