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
const GLYPH_WORDS := [
	"Fire",
	"Water",
	"Hurt",
	"Home",
	"Star",
	"Come",
	"Go",
	"Hunger",
	"Danger",
	"Kin",
	"Light",
	"Heal",
	"Bright",
	"Rest",
	"Seed",
	"Rain",
	"Soil",
	"Shape",
	"Bind",
	"Weave",
]
const NO_GUESS := "?"
const WALL_NEED_SURVIVORS := "The Wall waits for someone who can show it the marks."
const WALL_COPYING := "Marks copied: %d of %d"
const WALL_SET_LINE := "%s: %d of %d marks copied"  # set name, copied, in the set
const WALL_SET_LOCKED := "%s: read"
const WALL_HINT := "Click a mark to try the next word. The Kith say nothing until all three are right."
const WALL_FOUND := "Found %s"  # filled with the context line
const WALL_WRECK_HINT := "More marks wait at the crash site. An Expedition Post can send a party for them."
const COPIED_LINE := "A scribe finishes copying another mark onto the Wall."
const READ_LINE := "The three marks fit together. They mean: Star, Kin, Come. The strangers are %s."

## Glyph sets, in order. Each holds three glyph ids; a set locks when all three guesses are right at a check.
## `source` says where a set's marks come from: "survivors" (the strangers show them to the Wall) or "wreck" (an
## expedition brings them back from the crash site, Expedition.finish). `gift` is what reading the set gives (LUMEN_GIFTS).
const GLYPH_SETS := {
	1: {"id": "name", "name": "The Name", "source": "survivors", "glyphs": ["g_star", "g_come", "g_kin"]},
	2: {"id": "light", "name": "Light", "source": "wreck", "glyphs": ["g_light", "g_fire", "g_bright"]},
	3: {"id": "body", "name": "Body", "source": "wreck", "glyphs": ["g_hurt", "g_heal", "g_rest"]},
	4: {"id": "growth", "name": "Growth", "source": "wreck", "glyphs": ["g_seed", "g_rain", "g_soil"]},
	5: {"id": "craft", "name": "Craft", "source": "wreck", "glyphs": ["g_shape", "g_bind", "g_weave"]},
}

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
	"g_light":
	{
		"word": "Light",
		"strokes": [[[0.5, 0.1], [0.5, 0.45]], [[0.15, 0.65], [0.85, 0.65]], [[0.3, 0.9], [0.7, 0.9]]],
		"found":
		[
			"on a lamp cage in the hold, with a shard still glowing in it",
			"and a survivor lifts the lamp and the mark together",
			"and they say it softly, the way the Kith say a name",
		],
	},
	"g_fire":
	{
		"word": "Fire",
		"strokes": [[[0.2, 0.9], [0.5, 0.2], [0.8, 0.9]], [[0.35, 0.75], [0.65, 0.75]]],
		"found":
		[
			"burned black into a bulkhead, the same mark at every door",
			"and the strangers keep well back from it",
			"and they touch it, then the Kith's own hearth, and nod",
		],
	},
	"g_bright":
	{
		"word": "Bright",
		"strokes":
		[
			[[0.15, 0.5], [0.85, 0.5]],
			[[0.5, 0.1], [0.5, 0.9]],
			[[0.25, 0.25], [0.75, 0.75]],
			[[0.75, 0.25], [0.25, 0.75]]
		],
		"found":
		[
			"under the lamp mark on every lamp cage, never alone",
			"and a survivor shades their eyes when they make it",
			"and they make it for a good day, as the Kith say fair",
		],
	},
	"g_hurt":
	{
		"word": "Hurt",
		"strokes": [[[0.5, 0.1], [0.5, 0.6]], [[0.4, 0.8], [0.6, 0.8]], [[0.2, 0.3], [0.8, 0.3]]],
		"found":
		[
			"painted in red on a splinted panel in the hold",
			"and a stranger holds an arm and makes it",
			"and they make it when a Kith is hurt, before they are asked",
		],
	},
	"g_heal":
	{
		"word": "Heal",
		"strokes": [[[0.5, 0.15], [0.5, 0.85]], [[0.15, 0.5], [0.85, 0.5]]],
		"found":
		[
			"on a cloth wrapped round a bundle of leaves, the same cloth at every bunk",
			"and a survivor presses a leaf into a hand",
			"and they teach a Kith the leaf, then the mark",
		],
	},
	"g_rest":
	{
		"word": "Rest",
		"strokes": [[[0.15, 0.7], [0.85, 0.7]], [[0.3, 0.5], [0.7, 0.5]], [[0.45, 0.3], [0.55, 0.3]]],
		"found":
		[
			"cut over the bunks, low and long",
			"and they lie down when they point to it",
			"and they make it for the Kith's sleepers, and smile",
		],
	},
	"g_seed":
	{
		"word": "Seed",
		"strokes": [[[0.5, 0.3], [0.5, 0.9]], [[0.3, 0.3], [0.7, 0.3]], [[0.4, 0.1], [0.6, 0.1]]],
		"found":
		[
			"stamped on small pouches, hundreds of them, most spoiled",
			"and a survivor opens one and cups the seeds in both hands",
			"and they plant one beside the Wreck, then wait to see if the Kith do the same",
		],
	},
	"g_rain":
	{
		"word": "Rain",
		"strokes": [[[0.2, 0.2], [0.2, 0.6]], [[0.5, 0.3], [0.5, 0.8]], [[0.8, 0.2], [0.8, 0.6]]],
		"found":
		[
			"three lines on a cistern, the tallest at its mouth",
			"and they hold their palms up and look at the sky",
			"and they make it when the wind turns wet, a day before it falls",
		],
	},
	"g_soil":
	{
		"word": "Soil",
		"strokes": [[[0.15, 0.7], [0.85, 0.7]], [[0.15, 0.85], [0.85, 0.85]], [[0.5, 0.2], [0.5, 0.7]]],
		"found":
		[
			"on a tray of black earth carried out of the ship",
			"and a stranger crumbles it through their fingers and sighs",
			"and they make it for the Kith's own fields, when they think no one watches",
		],
	},
	"g_shape":
	{
		"word": "Shape",
		"strokes": [[[0.2, 0.8], [0.5, 0.2], [0.8, 0.8], [0.2, 0.8]]],
		"found":
		[
			"scratched beside a half-made tool in a hold workshop",
			"and a survivor turns it over and over in their hands",
			"and they show the Kith a smaller one, to start",
		],
	},
	"g_bind":
	{
		"word": "Bind",
		"strokes": [[[0.2, 0.3], [0.8, 0.7]], [[0.8, 0.3], [0.2, 0.7]], [[0.5, 0.1], [0.5, 0.9]]],
		"found":
		[
			"knotted into cords on every crate, in a pattern",
			"and they pull it tight between two fingers",
			"and they tie a cord round a Kith's wrist, and mean it kindly",
		],
	},
	"g_weave":
	{
		"word": "Weave",
		"strokes":
		[
			[[0.2, 0.2], [0.8, 0.2]],
			[[0.2, 0.5], [0.8, 0.5]],
			[[0.2, 0.8], [0.8, 0.8]],
			[[0.35, 0.1], [0.35, 0.9]],
			[[0.65, 0.1], [0.65, 0.9]]
		],
		"found":
		[
			"woven into a blanket in the hold, over and under",
			"and they run a thread through it with a bone needle",
			"and they teach the Kith the first stitch before the mark",
		],
	},
}

# --- The Lumen Camp (a place for the survivors) ---
const CAMP_BUILT_LINE := "The strangers look at the Camp for a long time, then one of them sits down inside it."
const SURVIVOR_STAND := 6.0  # tiles from the Hearth when trust is 0 ...
const SURVIVOR_CLOSE := 2.5  # ... and when it is full
const SURVIVOR_AT_CAMP := 1.6  # tiles from a Lumen Camp, once one stands

# --- The gifts: what reading a set gives (scripts/starfall.gd `gift`; the effects are in Data.BONUSES and Kith) ---
## `line` is said when the set is read. Shardlight, Starfruit and Shardwork are Data.BONUSES entries that work within
## SHARDLIGHT_RADIUS tiles of a Shard Cairn; the Healer's gift is a slower tool wear and a quicker birth (Kith).
const LUMEN_GIFTS := {
	"light":
	{
		"name": "Shardlight",
		"line": "The Cairn begins to hum and glow. Gatherers working in its light go faster. (Shardlight)",
		"note": "Gatherers near a Shard Cairn work 25% faster.",
	},
	"body":
	{
		"name": "Lumen Healer",
		"line":
		"The Lumen teach the Kith their leaves and cloths. Tools last longer, children come sooner. (Lumen Healer)",
		"note": "Tools last 40% longer and births come 20% sooner.",
	},
	"growth":
	{
		"name": "Starfruit",
		"line": "The Lumen's seeds take in shardlight. Berries near the Cairn grow fat and sweet. (Starfruit)",
		"note": "Berries picked near a Shard Cairn yield 50% more.",
	},
	"craft":
	{
		"name": "Shardwork",
		"line":
		"The Lumen show the Kith how to bind and shape with shard. Workshops in its light go faster. (Shardwork)",
		"note": "Workshops near a Shard Cairn work 25% faster.",
	},
}
const SHARDLIGHT_RADIUS := 4.0  # tiles from a Shard Cairn
const HEALER_WEAR := 0.7  # a job wears a tool this much: 1 / 0.7 = 40% longer
const HEALER_GROW := 0.8  # a birth takes this share of the usual time
const GIFT_LINE := "Lumen lore: %s. %s"  # gift name, what it does (the Glyph Wall's panel)

# --- The Expedition Post and the Wreck (scripts/expedition.gd) ---
## A party is two Kith who walk to a target, look around, and walk home before dusk. They carry a pack, taken from the
## stockpile when they leave, so a standing order needs no clicking. A pack's `finds` is how many marks it brings back from
## the Wreck; the far fog gives a wide look instead.
const PARTY_SIZE := 2
const DAYLIGHT_SECONDS := 80.0  # the whole trip must fit: a party home later than this lost half its pack (and its finds)
const EXPEDITION_SIGHT := 8  # how far a party sees at the target (a scout sees SCOUT_SIGHT)
const WRECK_SIGHT := 5
const PACKS := {
	"light": {"name": "Light pack", "cost": {"berries": 8}, "finds": 1},
	"standard": {"name": "Standard pack", "cost": {"berries": 16, "rope": 4}, "finds": 2},
	"heavy": {"name": "Heavy pack", "cost": {"berries": 24, "rope": 8, "flint": 6}, "finds": 3},
}
const PACK_ORDER := ["light", "standard", "heavy"]
const TARGETS := {"wreck": "The crash site (east)", "fog": "The nearest fog"}
const TARGET_ORDER := ["wreck", "fog"]
const POST_TARGET := "Going to: %s"
const POST_PACK := "Pack: %s (%s), %d marks"  # name, cost, finds
const POST_HINT := "Click a line to change it. A party leaves when you press Send, or again and again while Keep sending is on."
const POST_SEND := "Send a party"
const POST_KEEP := "Keep sending: %s"
const POST_ON := "on"
const POST_OFF := "off"
const POST_TRIP := "About %d s there and back, before dusk at %d s."
const POST_LATE := "Too far for one day: a party home after dusk loses half its pack."
const POST_OUT := "A party is out."
const POST_NOBODY := "Two Kith are needed, and none are free."
const POST_NEED := "The pack needs %s."
const POST_NO_WAY := "No way through to there. Water or rock is in the way: a bridge or a raft may help."
const POST_NO_FOG := "There is no fog left to look at."
const POST_NO_TARGET := "Nothing more to find there."
const POST_SENT := "%s and %s set out toward %s with a %s."  # two names, target, pack
const WRECK_FOUND_LINE := "The party reaches the crash site: a long hull broken in the grass, still warm. The strangers go quiet."
const WRECK_MARKS_LINE := "The party comes home with %d new marks copied from the Wreck."
const WRECK_NOTHING_LINE := "The party comes home. The Wreck has nothing more to show them."
const FOG_BACK_LINE := "The party comes home and tells of what lies %s."
const LATE_LINE := "Dusk caught the party on the road. They lost half their pack."
const WRECK_NAME := "The Wreck"
