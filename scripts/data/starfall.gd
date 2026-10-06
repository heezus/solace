extends RefCounted
## Era 3, Starfall (design-system/16-starfall.md), stage 1: the landing, the survivors, the Glyph Wall and the first set of
## glyphs. Numbers and every word the era says live here, so another faction can see something else. Read through the
## `Data` facade (scripts/data.gd).

const CARD_WAIT := "Not yet"  # a locked card of this era: there is no tech to discover, only the story to wait for

# --- The landing (scripts/starfall.gd) ---
const LANDING_DELAY := 20.0  # seconds of silence after the Falling Star card before it comes down
const ARRIVAL_DELAY := 40.0  # seconds after it lands before the survivors walk out of the fog
const SURVIVORS := 3
const LANDED_LINE := "Something big came down to the east. The ground shook, then it was quiet again."
const ARRIVED_GUESTS := "Three strangers walk out of the fog toward the Hearth. They stop at the edge of the light and wait to be asked in."
const ARRIVED_WARY := "Three strangers come out of the fog and stop far from the Hearth. They watch the Kith and do not come closer."
const STRANGERS_NAME := "the Starfallen"  # what the Kith call them until the name is read
const LUMEN_NAME := "the Lumen"  # what they are called once the first set is read

# --- Trust: a hidden number 0 to 100, never shown (the Lumen's behavior shows it) ---
const TRUST_MAX := 100.0
const TRUST_START_GUESTS := 20.0  # a Cairn built before the star fell: they arrive as guests
const TRUST_START_WARY := 0.0
const TRUST_CAMP := 8.0  # the Lumen Camp goes up
const TRUST_CAMP_PER_MINUTE := 1.0  # and while it stands
const TRUST_SET := 6.0  # a set of glyphs is read
const CONTEXT_TRUST := 40.0  # from here the survivors say a little more about each mark

# --- The Glyph Wall and the guesses ---
const COPY_SECONDS := 45.0  # a standing Wall copies one more mark onto itself
const CHECK_SECONDS := 20.0  # the Kith talk the guesses over this often
const GLYPH_WORDS := ["Fire", "Water", "Hurt", "Home", "Star", "Come", "Go", "Hunger", "Danger", "Kin", "Light", "Heal"]
const NO_GUESS := "?"
const WALL_NEED_SURVIVORS := "The Wall waits for someone who can show it the marks."
const WALL_COPYING := "Marks copied: %d of %d"
const WALL_SET_LINE := "%s: %d of %d marks copied"  # set name, copied, in the set
const WALL_SET_LOCKED := "%s: read"
const WALL_HINT := "Click a mark to try the next word. The Kith say nothing until all three are right."
const WALL_FOUND := "Found %s"  # filled with the context line
const COPIED_LINE := "A scribe finishes copying another mark onto the Wall."
const READ_LINE := "The three marks fit together. They mean: Star, Kin, Come. The strangers are %s."

## Glyph sets, in order. Each holds three glyph ids; a set locks when all three guesses are right at a check.
const GLYPH_SETS := {1: {"id": "name", "name": "The Name", "glyphs": ["g_star", "g_come", "g_kin"]}}

## One glyph: its true word, its strokes (lines in a unit square, so a Control can draw it), and where it was found.
## The first line is always shown, the second to guests, the third once trust is up.
const GLYPHS := {
	"g_star":
	{
		"word": "Star",
		"strokes": [[[0.5, 0.1], [0.5, 0.9]], [[0.15, 0.4], [0.85, 0.4]], [[0.25, 0.8], [0.5, 0.5], [0.75, 0.8]]],
		"found":
		[
			"on a hull panel above the door",
			"and the survivors point up when they touch it",
			"and they hold it over their hearts first, then up",
		],
	},
	"g_come":
	{
		"word": "Come",
		"strokes": [[[0.2, 0.2], [0.2, 0.8]], [[0.2, 0.5], [0.8, 0.5]], [[0.6, 0.3], [0.8, 0.5], [0.6, 0.7]]],
		"found":
		[
			"scratched on a shard crate beside an open hand",
			"and a stranger makes it, then waves toward the Hearth",
			"and they make it when the Kith stand back from the light",
		],
	},
	"g_kin":
	{
		"word": "Kin",
		"strokes": [[[0.3, 0.15], [0.3, 0.85]], [[0.7, 0.15], [0.7, 0.85]], [[0.3, 0.5], [0.7, 0.5]]],
		"found":
		[
			"on a cloth tied at the neck, on all of them",
			"and two of them make it, then touch hands",
			"and they make it for each other, never for the Kith, at first",
		],
	},
}

# --- The Lumen Camp (a place for the survivors) ---
const CAMP_BUILT_LINE := "The strangers look at the Camp for a long time, then one of them sits down inside it."
const SURVIVOR_STAND := 6.0  # tiles from the Hearth when trust is 0 ...
const SURVIVOR_CLOSE := 2.5  # ... and when it is full
const SURVIVOR_AT_CAMP := 1.6  # tiles from a Lumen Camp, once one stands
