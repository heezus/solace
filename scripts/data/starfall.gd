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
const ARRIVED_GUESTS := (
	"Three strangers walk out of the fog toward the Hearth. The tall one, with long pale hair, waves first. "
	+ "They stop at the edge of the light and wait to be asked in."
)
const ARRIVED_WARY := (
	"Three strangers come out of the fog and stop far from the Hearth. The tall one, with long pale hair, "
	+ "smiles at the Kith anyway. They do not come closer."
)
const STRANGERS_NAME := "the Starfallen"  # what the Kith call them until the name is read
const LUMEN_NAME := "the Lumen"  # what they are called once the first set is read
## The lead stranger: the tall Lumen with long pale hair, the first to trust the Kith and the voice of
## the trust choices. Warm, playful, quick to tease, perceptive; glamorous at first sight, goofy and loyal once she trusts you.
const LEAD_NAME := "Sela"
# Her name twice.
const LEAD_NAMED_LINE := 'The tall stranger taps her chest. "%s," she says, and waits. Then, delighted: "%s! Say it back!"'

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
	"Spread",
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
	6: {"id": "warning", "name": "The Warning", "source": "wreck", "glyphs": ["g_hunger", "g_spread", "g_danger"]},
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
	"g_hunger":
	{
		"word": "Hunger",
		"strokes": [[[0.2, 0.2], [0.2, 0.8]], [[0.8, 0.2], [0.8, 0.8]], [[0.2, 0.8], [0.5, 0.55], [0.8, 0.8]]],
		"found":
		[
			"scratched deep into the hull, over and over, in a column",
			"and a survivor holds an empty bowl and makes it",
			"and they make it softly, and then look at the sky as if something might hear",
		],
	},
	"g_spread":
	{
		"word": "Spread",
		"strokes":
		[[[0.5, 0.85], [0.5, 0.5]], [[0.5, 0.5], [0.2, 0.2]], [[0.5, 0.5], [0.8, 0.2]], [[0.5, 0.5], [0.5, 0.15]]],
		"found":
		[
			"at the end of a long row of marks, drawn larger than the rest",
			"and they draw it in the dust, then rub it out fast",
			"and they will not say it aloud, only point east and shake their heads",
		],
	},
	"g_danger":
	{
		"word": "Danger",
		"strokes": [[[0.5, 0.1], [0.9, 0.85], [0.1, 0.85], [0.5, 0.1]], [[0.5, 0.4], [0.5, 0.6]]],
		"found":
		[
			"last on the hull, circled three times",
			"and every stranger turns to look when it is read out",
			"and they put out their fire before they will say what it means",
		],
	},
}

# --- The Lumen Camp (a place for the survivors) ---
const CAMP_BUILT_LINE := "The strangers look at the Camp for a long time, then one of them sits down inside it."
# --- Trade, the Guard Post and the shared shrine (stage 4): more buildings that move trust ---
const MARKET_OPEN_TRUST := 8.0  # the Lumen will trade once this much trust stands (guests at once, the wary after a Camp)
const MARKET_TRUST_PER_MINUTE := 0.6  # trade alone makes neighbours: it stops lifting trust here
const MARKET_TRUST_CAP := 60.0
const TRUST_SHRINE := 10.0  # the shared shrine goes up
const TRUST_SHRINE_PER_MINUTE := 1.0
const TRUST_GUARD := -6.0  # a Guard Post goes up
const TRUST_GUARD_PER_MINUTE := -1.0
const GUARD_RADIUS := 4.0  # tiles round a Guard Post where the Kith work a little faster
const MARKET_OPEN_LINE := "One of the strangers holds out a hand with a small bright thing in it. They would trade."
const MARKET_BUILT_LINE := "The strangers lay out what they have, and the Kith lay out what they have."
const SHRINE_BUILT_LINE := "Both peoples leave something at the shrine. Nobody says whose it is."
const GUARD_BUILT_LINE := "The strangers see the Guard Post and move their things a little farther from the Kith."

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
## `bloom` (Ironfall, scripts/teardown_finds.gd) goes to the nearest Bloom patch in the far south for its sample; the picker
## offers it only while a patch is left to sample.
const TARGETS := {"wreck": "The crash site (east)", "fog": "The nearest fog", "bloom": "A Bloom patch (far south)"}
const TARGET_ORDER := ["wreck", "fog", "bloom"]
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

# --- Stage 3: the three moments, the Warning and the end of the era (scripts/starfall.gd) ---
## A moment is asked once, `wait` seconds after the set it follows is read, and waits for the player's answer (the game is
## paused behind its card, scripts/moment_card.gd). Each option moves trust, may cost something and is recorded as the
## story id in `story`. `cost` is food worth, `dim` seconds the Cairn's shardlight is lent away, `dark` seconds the
## workshops go quiet. Order matters: one moment at a time.
const ENDING_SET := "warning"  # the id of the set whose reading ends the era
const MOMENT_ORDER := ["hunger", "shards", "warning"]
const MOMENTS := {
	"hunger":
	{
		"title": "The Hunger",
		"after": "name",
		"wait": 150.0,
		"text":
		"The strangers have eaten almost nothing for days. The smallest one cannot stand. They will not ask. They only look at the stores.",
		"says":
		(
			'"We\'re fine," says '
			+ LEAD_NAME
			+ ", which is a lie, and she knows you know. \"Okay, a little hungry. We'd never ask. "
			+ "I'm just standing very near your food. Casually.\""
		),
		"options":
		[
			{
				"label": "Share the food",
				"note": "Costs a good share of the stockpile's food. They will remember it.",
				"story": "hunger_shared",
				"trust": 14.0,
				"food": 40.0,
				"line":
				(
					"The Kith set bowls down in front of the strangers. The smallest one eats first. "
					+ LEAD_NAME
					+ ' laughs, wipes her eyes and hugs the nearest Kith so hard they squeak. "You are officially my favourites."'
				),
			},
			{
				"label": "Hold it back",
				"note": "Keeps the food. They will remember this too.",
				"story": "hunger_held",
				"trust": -12.0,
				"line":
				(
					"The Kith keep the stores. "
					+ LEAD_NAME
					+ ' keeps smiling, but it stops reaching her eyes. "No, I understand. Everyone is careful with strangers."'
				),
			},
		],
	},
	"shards":
	{
		"title": "The Shards",
		"after": "light",
		"wait": 120.0,
		"text":
		"The strangers kneel at the Cairn and touch the shards. Then they hold out their hands to the Kith. They are asking.",
		"says":
		(
			LEAD_NAME
			+ ' touches the Cairn as if it were alive. "Oh, you have been looking after it." She looks up. '
			+ '"Could I borrow some? I promise I am better at sharing than I look."'
		),
		"options":
		[
			{
				"label": "Give them",
				"note": "Shardlight is lent away for a while. Most trust.",
				"story": "shards_given",
				"trust": 14.0,
				"dim": 150.0,
				"line":
				(
					"The Kith step back from the Cairn. The strangers carry shards away in their cloaks, and the glow dims. "
					+ LEAD_NAME
					+ ' squeezes a Kith hand. "I owe you one. I always pay back, and I make it fun."'
				),
			},
			{
				"label": "Trade",
				"note": "Shardlight dims only a little. A little trust.",
				"story": "shards_traded",
				"trust": 5.0,
				"dim": 60.0,
				"line":
				(
					"The Kith lay out food and rope beside the Cairn. The strangers take one shard and leave the rest. "
					+ LEAD_NAME
					+ ' grins. "A bargain! I like you. You know what things are worth."'
				),
			},
			{
				"label": "Refuse",
				"note": "The Cairn keeps its light. Trust drops.",
				"story": "shards_refused",
				"trust": -10.0,
				"line":
				(
					"The Kith stand in front of the Cairn. The strangers lower their hands. "
					+ LEAD_NAME
					+ " lets her smile thin. \"Fair. You really don't have to look at me like that. I wasn't going to run off with it.\""
				),
			},
		],
	},
	"warning":
	{
		"title": "The Warning",
		"after": "craft",
		"wait": 90.0,
		"text":
		"They point at the smoke over the kilns, then at the east, then they put a finger to their lips. They want the Kith to go dark.",
		"says":
		(
			LEAD_NAME
			+ "'s smile is gone, and it is strange to see it gone. She says the Kith word for quiet, badly. "
			+ '"Quiet. Please. Quiet."'
		),
		"options":
		[
			{
				"label": "Go dark",
				"note": "Workshops run at half speed for a while. Most trust.",
				"story": "dark_kept",
				"trust": 14.0,
				"dark": 90.0,
				"line":
				(
					"The Kith bank the kilns and keep the Hearth low. The strangers sit very still and listen. "
					+ LEAD_NAME
					+ ' lets out a long breath and laughs, shakily. "You didn\'t even ask why. I could cry."'
				),
			},
			{
				"label": "Keep working",
				"note": "The fires stay lit. Trust drops.",
				"story": "dark_refused",
				"trust": -12.0,
				"line":
				(
					"The Kith keep their fires. The strangers watch the east, and flinch at every spark. "
					+ LEAD_NAME
					+ " sits down hard in the grass and stops teasing, which is worse than any words."
				),
			},
		],
	},
}
const DARK_NAME := "Lights out"  # the workshop slowdown while the Kith go dark (Data.BONUSES "lights_out")
const DARK_SLOWER := -0.5
const DIM_NOTE := "The Cairn's light is lent away for %d more seconds."
const DARK_NOTE := "The Kith are keeping dark for %d more seconds."
const MOMENT_ASKED_LINE := "The strangers have something to ask. (%s)"  # the moment's title

## The Warning set is read: the era ends. Trust at that moment sets the lean (stored as a story id, never shown as a number).
const LEAN_ALLIES := 70.0
const LEAN_NEIGHBOURS := 35.0
const LEANS := {"allies": "lean_allies", "neighbours": "lean_neighbours", "enemies": "lean_enemies"}
const WARNING_LINE := (
	"The three marks fit. They mean: Hunger, Spread, Danger. "
	+ "The strangers did not come to live here. They came to hide."
)
const WARNING_NEEDS := "The Kith cannot read the Warning until they have answered what the strangers asked."
const BLOOM_LINE := "Far to the east, at the edge of the fog, something is growing that no one planted."
const BLOOM_SIGHT := 3  # how much fog the Bloom sign lifts around it
const BLOOM_DISTANCE := 7  # tiles from the Wreck (north of it, or south if there is no room)
const ENDING_TITLE := "They Came to Hide"
const ENDING_TEXT := (
	"The strangers say the word at last, and the Kith understand why they ran. "
	+ "Something is following them. It is slow, and it does not stop."
)
const ENDING_SAYS := (
	LEAD_NAME
	+ ' says it softly. "We did not come here to live. We came to hide. I am sorry. I should have told you sooner, '
	+ 'but you were so kind, and I did not want it to be true yet."'
)
const ENDING_NOTE := "The Bloom has been seen. The game goes on."
const ENDING_BUTTON := "Keep building"
