extends RefCounted
## Step 7, the endings (design-system/18-roadmap.md, "Endings as built"): the three ways the first telling can end, which of them
## the Lumen lean opens, the words of each end card and of the next run's first card, and the numbers of the ruins a Cataclysm
## leaves. Read through the `Data` facade (scripts/data.gd) as `Data.ENDINGS`. The words are placeholders in the design doc's
## voice until the story is written out. Nothing here names a faction beyond the words of the page: the Kith, the Lumen, Sela.

const ENDINGS := {
	# The order the rows show in.
	"order": ["exodus", "cataclysm", "loop"],
	# The ending card (the Skyward card's "Choose an ending", the game menu's entry).
	"choose": "Choose an ending",
	"choose_tip": "End this telling and begin the next. Opens once Skyward is raised.",
	"title_first": "The first telling ends here",
	"title_later": "Telling %d ends here",
	"text": "Skyward stands, and the Bloom is coming. How the Kith treated the Lumen decides which endings are open.",
	"keep": "Keep building",
	"gives": "Gives: %s",
	"confirm_yes": "Begin the next telling",
	"confirm_no": "Stay",
	"unsaved": "The Kith's story could not be kept, so they stay.",
	"needs_enemies": "Needs the Lumen as enemies",
	"needs_allies": "Needs the Lumen as allies",
	# Each ending: its story id (the Chronicle), the lean it needs ("" for none), the row's words and its end card.
	"exodus":
	{
		"id": "ending_exodus",
		"lean": "",
		"name": "Exodus",
		"line": "Pack up and walk to a new land, carrying what you know.",
		"gives": "Blueprints, and everything the Kith know",
		"end": "The town stays behind. The Kith walk into a land they have not seen, carrying what they know.",
		"next_title": "A NEW LAND",
		"next_text": "The town stays behind. The Kith walk into a land they have not seen, carrying what they know.",
	},
	"cataclysm":
	{
		"id": "ending_cataclysm",
		"lean": "enemies",
		"name": "Cataclysm",
		"line": "Magic overreach breaks the world. You wake in your own ruins.",
		"gives": "Relics from the ruins",
		"end":
		"The light broke the sky. When the Kith woke, the town was ruin, and something green was already growing in it.",
		"next_title": "THE RUINS",
		"next_text":
		"The same hills, the same river. Where the town stood there is rubble, and the Bloom has taken root beside it. The Lumen come wary.",
	},
	"loop":
	{
		"id": "ending_loop",
		"lean": "allies",
		"name": "Time loop",
		"line": "The planet rewinds. Only you remember.",
		"gives": "Memory: Sela and the Lumen remember you",
		"end":
		"The planet turned back on itself. The town was gone, and the Kith were the only ones who remembered it.",
		"next_title": "ANOTHER VALLEY",
		"next_text": "A different valley, and the same people. The Lumen remember the Kith, and Sela knows their name.",
	},
	# The first words of the next run for the Lumen's side, and the line that notes the lean you had.
	"greet": "Sela said the Kith's name before they said hers.",
	"remembered": "The Lumen remember: last time, you were %s.",
	"wary": "The Lumen came wary. They remembered the ruins.",
	"lean_words": {"allies": "allies", "neighbours": "neighbours", "enemies": "enemies"},
	# The small choices of the Starfall era a telling records (the story ids, scripts/data/goals.gd), in the order they are asked.
	"choices":
	[
		"cairn_raised",
		"hunger_shared",
		"hunger_held",
		"shards_given",
		"shards_traded",
		"shards_refused",
		"dark_kept",
		"dark_refused",
	],
	# The ruins a Cataclysm leaves on the map: the buildings of the old town as rubble (one tile each), the largest kept.
	"ruins_max": 60,  # how many ruins are kept, the dearest buildings first
	"ruins_clear": 3,  # tiles round the Hearth where nothing is left
	"patches_min": 2,  # the dormant Bloom patches, one beside each of the largest ruins
	"patches_max": 4,
	"stone_min": 3,  # clearing a ruin gives its weight (what its building cost) / stone_per, between these
	"stone_max": 20,
	"stone_per": 25,
	# Relics, the Cataclysm's gift (scripts/relics.gd): the largest ruins each hold one, dug out by a crew, used up with the run.
	"relics":
	[
		{
			"id": "forge",
			"name": "Everburning Forge",
			"building": "forge",
			"event": "relic_forge",
			"line": "A forge that was never let go out.",
		},
		{
			"id": "lantern",
			"name": "Old Lantern",
			"building": "shard_lantern",
			"event": "relic_lantern",
			"line": "A lantern from the first ship, still lit.",
		},
		{
			"id": "cart",
			"name": "Founders' Cart",
			"building": "storehouse",
			"event": "relic_cart",
			"line": "The cart the first ones pulled, mended with care.",
		},
	],
	"dig_seconds": 60.0,  # a crew works this long at a relic
	"lantern_reach": 2.0,  # the Old Lantern lights this many times the Shard Lantern's radius
	"cart_reach": 8.0,  # haulers within this many tiles of the Founders' Cart...
	"cart_load": 1.5,  # ...carry this many times as much
	"job_dig": "Digger",
	"relic_ruin_kept": "A relic lies under this ruin: dig it out first.",
	"relic_here": "A relic lies under this ruin: click it to dig it out.",
	"relic_tip": "%s: click to send a crew to dig (about a minute, and it needs a road beside it).",
	"dig_sent": "%s went to dig out the %s.",  # the Kith, the relic
	"dig_done": "The crew dug out the %s. %s",  # the relic, its line
	"dig_no_road": "A crew can only reach it by a road: lay a road beside the ruin.",
	"dig_busy": "A crew is digging there already.",
	"dig_nobody": "Nobody is free to dig.",
	"dig_progress": "Digging the %s",
}
