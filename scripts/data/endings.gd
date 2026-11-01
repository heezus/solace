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
	# Step 8B, the true endings: they appear on the card once the marks of The Way Out (set 9) are read while the Lumen are allies. Seal
	# Solace is open then; Heal the Bloom needs a Cataclysm in an earlier telling and Leave together a Time loop in an earlier one.
	# `needs` is the earlier ending ("" for none). A true ending ends the telling for good: its cutscene (scripts/data/cutscenes.gd),
	# then the Chronicle with a gold star, then the player chooses Another telling (the cycles, Step 8C) or the title screen.
	"true_order": ["seal", "heal", "leave"],
	"true_title": "The telling can be made whole",
	"true_text":
	"The marks of the Way Out are read, and the Lumen stand with the Kith. Each of these ends the telling for good.",
	"true_gives": "The telling is told whole",
	"needs_way": "Needs the marks of The Way Out read while the Lumen are allies",
	"needs_cataclysm": "Needs a Cataclysm in an earlier telling",
	"needs_loop": "Needs a Time loop in an earlier telling",
	"true_confirm_yes": "Make it whole",
	"seal":
	{
		"id": "ending_seal",
		"true": true,
		"needs": "",
		"gives": "The telling told whole",
		"next_title": "ANOTHER TELLING",
		"next_text": "A new land, and the Kin who remember a telling made whole. Whatever comes now comes harder.",
		"name": "Seal Solace",
		"line": "Shut the door, and keep the world as it is.",
		"end":
		"The door is shut with everyone it carried standing at it. Solace stays as it is, and the Bloom stays outside.",
	},
	"heal":
	{
		"id": "ending_heal",
		"true": true,
		"needs": "cataclysm",
		"gives": "The telling told whole",
		"next_title": "ANOTHER TELLING",
		"next_text": "A new land, and the Kin who remember a telling made whole. Whatever comes now comes harder.",
		"name": "Heal the Bloom",
		"line": "Mend what the first hands broke.",
		"end":
		"The Kith and the Lumen walk out to the green growth together. The Bloom answers, and the river it was remembers its name.",
	},
	"leave":
	{
		"id": "ending_leave",
		"true": true,
		"needs": "loop",
		"gives": "The telling told whole",
		"next_title": "ANOTHER TELLING",
		"next_text": "A new land, and the Kin who remember a telling made whole. Whatever comes now comes harder.",
		"name": "Leave together",
		"line": "Go through the door, with everyone it has carried.",
		"end":
		"The door opens for everyone it has ever carried. The Kith and the Lumen go through it, and Solace is left to heal.",
	},
	"next_choice": "The telling is whole. Begin another telling, or return to the title screen?",
	"another": "Another telling",
	"to_title": "Title screen",
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
	"ruins_clear": 8,  # tiles round the Hearth where nothing is left: the old square survives, the build area is open ground
	"patches_min": 2,  # the dormant Bloom patches, one beside each of the largest ruins
	"patches_max": 4,
	"patch_clear": 20,  # no dormant patch lies closer than this to the Hearth (tiles, either way)
	"patch_edge": 0.9,  # ...and each lies beyond the old town's edge: the distance (to the Hearth) that this share of its buildings are within
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
			"building": "",
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
	# What the feed says when a road clears what lay in its way (Sim.place): Rocks, Forest, or the rubble of the old town.
	"road_clears":
	{
		"rock": "Cut a pass through the rocks",
		"tree": "Felled the trees for a road",
		"ruins": "Cleared the rubble for a road",
	},
	"rubble_in_the_way": "Rubble is in the way. Lay a road over it to clear it (gives Stone).",
	"relic_here": "A relic lies under this ruin: click it to dig it out.",
	"relic_tip": "%s: click to send a crew to dig (about a minute, and it needs a road beside it).",
	"dig_sent": "%s went to dig out the %s.",  # the Kith, the relic
	"dig_done": "The crew dug out the %s. %s",  # the relic, its line
	"dig_no_road": "A crew can only reach it by a road: lay a road beside the ruin.",
	"dig_busy": "A crew is digging there already.",
	"dig_nobody": "Nobody is free to dig.",
	"dig_progress": "Digging the %s",
	# The old marks (Step 7F, scripts/starfall.gd `sets`): three sets beyond the six, found at the first ship's site (scripts/old_ship.gd).
	# `run` is the run they appear from (a first run is run 1), `cataclysm_run` an earlier run for a Cataclysm's, `lean` the lean the
	# strangers must stand in for the set to be read. Reading one gives the usual trust and its lore (a cutscene, scripts/data/cutscenes.gd).
	"old":
	{
		"sets":
		{
			7:
			{
				"id": "ship",
				"name": "The First Ship",
				"glyphs": ["g_ship", "g_kin_old", "g_home_old"],
				"run": 2,
			},
			8:
			{
				"id": "broke",
				"name": "What Broke",
				"glyphs": ["g_shape_old", "g_broke", "g_hurt_old"],
				"run": 3,
				"cataclysm_run": 2,
			},
			9:
			{
				"id": "way",
				"name": "The Way Out",
				"glyphs": ["g_door", "g_heal_old", "g_go_old"],
				"run": 4,
				"lean": "allies",
			},
		},
		"words": ["Ship", "Broke", "Door"],  # the words these marks add to the list of words to try
		"warm": 6.0,  # once The First Ship is read, every later run's strangers begin this much warmer
		"site_near": 12,  # the first ship's site lies this many tiles from the Hearth at the least, and "site_far" at the most
		"site_far": 22,
		"site_apart": 10,  # and this far from the crash site
		"found_line":
		"The party reaches a hull older than the ships: a ribbed shape under the roots, green with the Bloom's first growth.",
		"marks_line": "The party comes home with %d new marks copied from the first ship.",
		"nothing_line": "The party comes home. The first ship has nothing more to show them.",
		"ruin_marks_line": "The party comes home with %d new marks copied from the sprouting ruins.",
		"ruin_nothing_line": "The party comes home. The ruins have nothing more to show them.",
		"ruin_hint": "Older marks wait in the sprouting ruins. An Expedition Post can send a party for them.",
		"set_line": "An older set: %d of %d marks copied",
		"wall_hint": "Older marks wait at the first ship's site. An Expedition Post can send a party for them.",
		"needs_lean": "The marks fit together, but the strangers will not say them yet: the Kith are not their allies.",
		"no_site": "There is no first ship's site on this land.",
	},
}
