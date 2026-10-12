extends RefCounted
## Era 4, Ironfall, stage 2: Teardown (design-system/19-ironfall.md). The parts, the eight Lessons they hold and every
## number and word of the Bench. Read through the `Data` facade (scripts/data.gd). Every number is a placeholder to tune with
## the pacing bot.

## A part is a whole one-off object, never a pile: it lives in the pack or on the Bench, not in the stockpile counters.
## Each part holds exactly one Lesson, and the part and its Lesson share an id. `from` says where it comes from in words.
## `color` is the swatch that stands in for its icon until Codex paints one.
const PARTS := {
	"lamp_core":
	{"name": "Lamp Core", "color": Color("9fe0f0"), "from": "the Wreck, or the Lumen Camp when the Lumen are friendly"},
	"heat_plate": {"name": "Heat Plate", "color": Color("e9a45a"), "from": "the Wreck, shared by the Lumen as allies"},
	"hull_gear": {"name": "Hull Gear", "color": Color("b9bec6"), "from": "the Wreck"},
	"seed_pod": {"name": "Seed Pod", "color": Color("a7c957"), "from": "the Lumen Camp, when the Lumen trust the Kith"},
	"water_glass":
	{"name": "Water Glass", "color": Color("7ec8e3"), "from": "the Lumen Camp, when the Lumen are allies"},
	"spore": {"name": "Spore Sample", "color": Color("c04a9d"), "from": "the Bloom patch in the south"},
	"root": {"name": "Root Sample", "color": Color("6fa84a"), "from": "the Bloom patch in the south"},
	"sap": {"name": "Sap Sample", "color": Color("d98ad0"), "from": "the Bloom patch in the south"},
}

## The finite list of Lessons, in the order the Lessons list shows them. `teaches` is the short name of what it gives, `note`
## says it in a sentence once learned. A Lesson with `live` false is learned and kept, and does nothing yet: the thing it
## names is not built. All eight are live since stage 3 (the Shard Lamp, the Shard Boiler, Lantern Parties).
const LESSON_ORDER := ["lamp_core", "heat_plate", "hull_gear", "seed_pod", "water_glass", "spore", "root", "sap"]
const LESSONS := {
	"lamp_core":
	{
		"name": "Lamp core",
		"teaches": "Shard Lamp",
		"live": true,
		"note": "A lamp post that burns one shard a long while and lights 3 tiles.",
	},
	"heat_plate":
	{
		"name": "Heat plate",
		"teaches": "Shard Boiler",
		"live": true,
		"note": "A boiler that burns shards, so far less coal.",
	},
	"hull_gear":
	{
		"name": "Hull gear",
		"teaches": "Iron Gears",
		"live": true,
		"note": "Iron Gears, made by hand from Iron. A workshop fed one works 25% faster.",
	},
	"seed_pod":
	{
		"name": "Seed pod",
		"teaches": "Starfruit in smoke",
		"live": true,
		"note": "Starfruit ripens in coal smoke too: berries near a Coal Mine or a Bloomery yield 50% more.",
	},
	"water_glass":
	{
		"name": "Water glass",
		"teaches": "Rain Barrel",
		"live": true,
		"note": "A Rain Barrel: Fields near one never wilt in a dry spell (+20% Field yield).",
	},
	"spore":
	{
		"name": "Spore",
		"teaches": "what the Bloom eats",
		"live": true,
		"note": "Bloom patches show their reach on the map.",
	},
	"root":
	{
		"name": "Root",
		"teaches": "how the Bloom spreads",
		"live": true,
		"note": "The ground the Bloom crosses slowest is lit on the map.",
	},
	"sap":
	{
		"name": "Sap",
		"teaches": "Lantern Parties",
		"live": true,
		"note": "Expeditions that may stay out past dusk.",
	},
}

# --- The Bench ---
const BENCH_SECONDS := 40.0  # one part
const BENCH_SLOTS := 3  # the short queue: parts on the Bench or on their way to it, at most
const SCRAP_SECONDS := 8.0  # a part whose Lesson is known is only stripped for scrap
const SCRAP_IRON := 6  # ...and that gives this much Iron
const BENCH_NEEDS_ROAD := "Needs road: haulers carry parts to the Bench, or carry them by hand."

# --- Where parts come from ---
## The Wreck always holds these three, so no run is locked out of the Boiler or the Lamp. A trip brings home the pack's share
## (a late party half of it), the parts the town does not hold yet first.
const WRECK_PARTS := ["heat_plate", "lamp_core", "hull_gear"]
const WRECK_TRIP_PARTS := {"light": 1, "standard": 1, "heavy": 2}
## What the Lumen Camp hands over by the lean the Starfall ended on (page 19: enemies none, neighbours two, allies all).
const CAMP_PARTS := {
	"enemies": [],
	"neighbours": ["lamp_core", "seed_pod"],
	"allies": ["lamp_core", "seed_pod", "water_glass", "heat_plate"],
}
const CAMP_GIVE_SECONDS := 45.0  # between one handover and the next, while a Lumen Camp stands
## The three Bloom patches, in the order the sample types are named. Each lies in the far south, a small spread of green and
## magenta ground (BLOOM_GROUND) with one sample tile (BLOOM_TILES) at its middle; once taken, the sample tile is ground.
const BLOOM_KINDS := ["spore", "root", "sap"]
const BLOOM_TILES := {"spore": "bloom_spore", "root": "bloom_root", "sap": "bloom_sap"}
const BLOOM_GROUND := "bloom_ground"
## Taking a sample needs the Bloom Sampling tech (built in stage 3). In stage 2 this flag stood in for it: with it set the Kith
## could sample without the tech. It is false now, and the tech decides.
const BLOOM_SAMPLING_PLACEHOLDER := false

# --- What the Lessons do ---
const GEARS_ITEM := "iron_gears"  # made by hand (Data.RECIPES), fitted by haulers, one to a workshop (Data.BONUSES)
const RAIN_BARREL_RADIUS := 3.0  # tiles
const RAIN_BARREL_FIELD := 0.2  # extra Field yield, as a share of the bundle
const SPORE_REACH := 4  # tiles round a Bloom sign that Spore lights
const ROOT_LIT := ["road", "rock"]  # the ground the Bloom crosses slowest, lit by Root (page 18: roads, hard ground)

# --- Words ---
const LESSONS_HEADING := "Lessons"
const LESSON_LOCKED := "Locked: %s"  # where the part comes from
const LESSON_FOUND := "Found: the %s is on its way to the Bench"  # the part's name
const LESSON_LEARNED := "Learned: %s"  # what it gave
const LESSON_WAITS := "Learned. It will be used once %s can be built."  # the thing it names
const LESSON_HINT := "Each part holds one Lesson. A second copy of a part gives only scrap."
const PART_CARD := "%s · holds the %s Lesson: %s"  # part, Lesson, what it teaches
const PART_CARD_KNOWN := "%s · its Lesson is learned: scrap"
const PACK_HEADING := "In the pack"
const PACK_EMPTY := "No parts in the pack. Parts come from the Wreck, the Lumen Camp and the Bloom patches."
const PACK_HINT := "Click a part to carry it to the Bench next."
const BENCH_HEADING := "On the Bench"
const BENCH_IDLE := "The Bench is empty."
const BENCH_WAITING := "Waiting for a part."
const BENCH_WORKING := "Taking apart the %s · %d s left"
const BENCH_STRIPPING := "Stripping the %s for scrap · %d s left"
const BENCH_ROOM := "Room for %d more."
const BENCH_FULL := "The Bench is full."
const CARRY_BUTTON := "Carry %s by hand"
const PART_OPENED_LINE := "The Kith open the %s and learn from it: %s."
const SCRAP_LINE := "The %s teaches nothing new. The Kith strip it for %d Iron."
const WRECK_PART_LINE := "The party comes home with %s from the Wreck."  # "a Heat Plate", "a Lamp Core and a Hull Gear"
const CAMP_GIVES_LINE := 'The Lumen set a %s in the Kith\'s hands. "Open it," says %s.'  # part, the lead stranger
const SAMPLE_LINE := "The party comes home with a %s from the Bloom patch. It is cold, and it moves a little."
const BLOOM_NO_LAND := "The land south of the map is closed: discover Coal Seams or Ironstone."
const BLOOM_NO_TECH := "The Kith cannot take a sample yet: discover Bloom Sampling."
const BLOOM_NONE_LEFT := "Every patch has been sampled."
const BLOOM_NO_TEARDOWN := "The Kith will not touch it without Teardown."
