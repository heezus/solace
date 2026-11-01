extends RefCounted
## The cutscenes (design-system/20-cutscenes.md): short skippable sequences of painted stills that tell one story across the
## eras, in the Kith's own voice, never more than three short lines on a still. Played by scripts/cutscene_player.gd.
## A sequence is a row of CUTSCENES, in the order they play when several wait at once:
##   triggers the story ids (Data.STORY_EVENTS) any of which starts it, or "start" for a fresh run
##   after    optional: a story id that must have happened first, else it waits (the Bloom sign waits for Ironfall)
##   by       optional: what picks a still's variant (see ARRIVAL_KEY and LEAN_KEY in scripts/cutscene_player.gd)
##   stills   the painted stills in order: `art` is the file name under CUTSCENE_ART_DIR (no extension), `line` the
##            caption, and `variants` (optional) maps a variant key to the `art` and/or `line` it swaps in; `portrait`
##            (optional) is a painted bust (art/rendered/portraits/) that sits by the caption
## A still whose picture is not painted yet shows its line over a dark panel, so the story ships first.
## Nothing here names a faction: the Kith, the Lumen and Sela are the words of the page, kept in data.

const CUTSCENE_ART_DIR := "res://art/rendered/cutscenes/"
const CUTSCENE_STILL_SECONDS := 6.0  # how long a still stays, fades included
const CUTSCENE_FADE_SECONDS := 0.9  # a still fades in and out of black over this long
const CUTSCENE_PUSH_IN := 0.07  # the slow push-in over a still: 7% larger by the end
const CUTSCENE_CAPTION_SHARE := 0.34  # the bottom share of the window kept for the lines (a dark gradient sits behind them)
const CUTSCENE_MEMORY_OPACITY := 0.12  # a memory overlay's strength, lower when several are drawn together
const CUTSCENE_SKIP_GRACE := 0.35  # seconds a click is ignored at the start, so the click that began the moment does not skip it
const CUTSCENE_SKIP_HINT := "Esc, Space or a click to skip"
const CUTSCENE_PANEL := Color("14141a")  # the dark panel behind lines with no picture yet
const CUTSCENES_LABEL := "Cutscenes"
const CUTSCENES_HELP := "The short painted stories between the eras. Off skips them all. Esc, Space or a click skips one."

const CUTSCENES := {
	"opening":
	{
		"triggers": ["start"],
		"stills":
		[
			{"art": "opening_1", "line": "Solace was quiet when the Kith came."},
			{"art": "opening_2", "line": "They raised a fire and called the place home."},
			{"art": "opening_3", "line": "Nothing yet told them they were not alone."},
		],
	},
	# A run that begins after an ending opens in the land that ending led to. No trigger: the player queues it after the opening,
	# from the ending that began the run.
	"next_telling":
	{
		"triggers": [],
		"by": "ending",
		"stills":
		[
			{
				"art": "next_land_1",
				"line": "Past the last hill there was a country nobody had named.",
				"variants":
				{
					"cataclysm":
					{
						"art": "next_ruins_1",
						"line": "The same hills, the same river. Grass had come into the town, and small green buds."
					},
					"loop":
					{"art": "next_valley_1", "line": "A different valley. A Kith woke in it, remembering everything."},
				},
			},
		],
	},
	"bronze_dawn":
	{
		"triggers": ["bronze_dawn"],
		"stills":
		[
			{"art": "bronze_dawn_1", "line": "Copper and tin, and a new color in the fire."},
			{"art": "bronze_dawn_2", "line": "The roads reached farther than anyone had walked."},
			{"art": "bronze_dawn_3", "line": "East, under the fog, something waited."},
		],
	},
	"falling_star":
	{
		"triggers": ["star_falling"],
		"stills":
		[
			{"art": "falling_star_1", "line": "A star came down."},
			{"art": "falling_star_2", "line": "The Kith watched it fall. Nobody spoke."},
			{"art": "falling_star_3", "line": "It landed beyond the hills."},
			{"art": "falling_star_4", "line": "In the morning, the silence began."},
		],
	},
	"first_contact":
	{
		"triggers": ["lumen_arrived"],
		"by": "arrival",
		"stills":
		[
			{
				"art": "first_contact_1",
				"line": "Three strangers came out of the fog, and stopped.",
				"variants":
				{"guests": {"art": "first_contact_1_guests", "line": "Three strangers came to the Cairn, as guests."}},
			},
			{"art": "first_contact_2", "line": "The tall one smiled anyway."},
			{
				"art": "first_contact_3",
				"line": "She tapped her chest and said a word, and waited.",
				"variants": {"loop": {"line": "She said the Kith's name first, and smiled."}},
			},
		],
	},
	"starfall_end":
	{
		"triggers": ["lean_allies", "lean_neighbours", "lean_enemies"],
		"by": "lean",
		"stills":
		[
			{"art": "starfall_end_1", "line": "The ship would not fly again."},
			{"art": "starfall_end_2", "line": "What the Lumen carried, the Kith began to read."},
			{
				"art": "starfall_end_3_neighbours",
				"line": "They would be neighbours.",
				"variants":
				{
					"allies": {"art": "starfall_end_3_allies", "line": "They stopped counting whose fire it was."},
					"enemies": {"art": "starfall_end_3_enemies", "line": "They kept their distance."},
				},
			},
		],
	},
	"ironfall":
	{
		"triggers": ["ironfall_begun"],
		"stills":
		[
			{"art": "ironfall_1", "line": "Iron, and a way to open things."},
			{"art": "ironfall_2", "line": "The Lumen showed what their ship was made of."},
			{"art": "ironfall_3", "line": "At the edge of the fog, something was growing."},
		],
	},
	"bloom_sign":
	{
		"triggers": ["bloom_seen"],
		"after": "ironfall_begun",
		"stills":
		[
			{"art": "bloom_sign_1", "line": "It was not there yesterday."},
			{"art": "bloom_sign_2", "line": "Sela stopped smiling. She knew what it was."},
		],
	},
	# The end of a telling (Data.SKYWARD_EVENT): the cliffhanger the first run ends on, before the ending card.
	"skyward_end":
	{
		"triggers": ["skyward_raised"],
		"stills":
		[
			{"art": "skyward_end_1", "line": "The mast stood lit over the town."},
			{"art": "skyward_end_2", "line": "On the horizon, the Bloom was waking."},
			{"art": "skyward_end_3", "line": 'Sela said, "Not this time. But you\'ll remember."'},
		],
	},
	# The old marks (Step 7F): what each of the three sets said when it was read. Placeholder words until Codex paints the stills.
	"kin_reveal":
	{
		"triggers": ["ship_read"],
		"stills":
		[
			{"art": "kin_reveal_1", "line": "The ship that fell before ours was full of children."},
			{"art": "kin_reveal_2", "line": 'Sela said, "We did not find you. We came home."'},
			{
				"art": "fireside_1",
				"portrait": "portrait_kin_elder",
				"line": 'The Hearthkeeper said, "We were never only Kith. We are Kin."'  # kept as written (KinName.KEPT)
			},
		],
	},
	"broken_world":
	{
		"triggers": ["broke_read"],
		"stills":
		[
			{"art": "broken_world_1", "line": "This world was shaped too hard, by hands that loved it."},
			{"art": "broken_world_2", "line": 'In the growth, a voice: "I was a river once."'},
		],
	},
	"way_out":
	{
		"triggers": ["way_read"],
		"stills":
		[
			{"art": "way_out_1", "line": "There is a door the first ship could not use."},
			{
				"art": "way_out_2",
				"line": "It needs everyone it has ever carried.\nShut it, heal what is outside it, or go."
			},
		],
	},
	# After any ending, before the next run: the ending itself, then the Hearthkeeper tells the children the telling that just ended
	# (placeholder words; the Chronicle of the tellings, Step 7G, opens after it).
	"fireside":
	{
		"triggers": ["ending_exodus", "ending_cataclysm", "ending_loop"],
		"by": "chosen",
		"stills":
		[
			{
				"art": "ending_exodus_1",
				"line": "The town was left with its lamps lit.\nThe Kith walked out past it, carrying what they knew.",
				"variants":
				{
					"cataclysm":
					{
						"art": "ending_cataclysm_1",
						"line": "The light broke the sky.\nThe town woke as ruin, with something green in it."
					},
					"loop":
					{
						"art": "ending_loop_1",
						"line": "The planet turned back on itself.\nThe town was gone. Only the Kith remembered."
					},
				},
			},
			{
				"art": "fireside_1",
				"portrait": "portrait_kin_elder",
				"line":
				(
					"By the fire, the Hearthkeeper told it to the children:\nthe mast, the strangers, the choice.\n"
					+ '"And then?" they asked. "Then we began again."'
				)
			},
		],
	},
	# After a true ending (Step 8B, placeholder words and no painted stills yet): three stills, the last the Hearthkeeper's fireside.
	"seal_end":
	{
		"triggers": ["ending_seal"],
		"stills":
		[
			{
				"art": "seal_end_1",
				"line": "The Kin and the Lumen stand at the door together.\nNo one is left outside it."
			},
			{
				"art": "seal_end_2",
				"line": "It closes without a sound.\nThe Bloom stays on the far side, and does not knock."
			},
			{
				"art": "seal_end_3",
				"portrait": "portrait_kin_elder",
				"line":
				'By the fire, the Hearthkeeper told it to the children.\n"And that is how the telling became whole."'
			},
		],
	},
	"heal_end":
	{
		"triggers": ["ending_heal"],
		"stills":
		[
			{
				"art": "heal_end_1",
				"line": "The Kin and the Lumen walk out together\nto the green growth at the edge of the fog."
			},
			{"art": "heal_end_2", "line": 'A voice in it: "I was a river once."\nThe river runs again.'},
			{
				"art": "heal_end_3",
				"portrait": "portrait_kin_elder",
				"line":
				'By the fire, the Hearthkeeper told it to the children.\n"And that is how the telling became whole."'
			},
		],
	},
	"leave_end":
	{
		"triggers": ["ending_leave"],
		"stills":
		[
			{"art": "leave_end_1", "line": "The door opens for everyone it has ever carried."},
			{"art": "leave_end_2", "line": "The Kin and the Lumen go through it together.\nSolace is left to heal."},
			{
				"art": "leave_end_3",
				"portrait": "portrait_kin_elder",
				"line":
				'By the fire, the Hearthkeeper told it to the children.\n"And that is how the telling became whole."'
			},
		],
	},
}

## Repeat runs remember: a sequence may swap ONE line when the profile holds a matching story id from an earlier run
## (Profile.chronicle). `still` counts from 0. The first matching row of a sequence wins. A hint, never a spoiler.
## The rows that need a "reset_*" id wait for the resets (design-system/18-roadmap.md): no run records those ids yet,
## so they never match today. They are the hook the reset PR fills, not dead text to delete.
const CUTSCENE_VARIANT_LINES := [
	{
		"seq": "first_contact",
		"still": 2,
		"needs": "name_read",
		"line": "She said a word. This time a few of the Kith knew it."
	},
	{
		"seq": "bloom_sign",
		"still": 0,
		"needs": "bloom_seen",
		"line": "It was not there yesterday. Some of the Kith had seen it before."
	},
	{"seq": "opening", "still": 1, "needs": "reset_exodus", "line": "They raised a fire, the way they remembered."},
	{"seq": "opening", "still": 2, "needs": "reset_loop", "line": "Something felt like déjà vu."},
]

## Memory overlays: transparent full-frame layers (art/rendered/cutscenes/<overlay>.png) drawn over any still at low
## opacity when the profile holds the id. The three resets pick from the first three (the most recent one, once resets exist),
## and each echo kind adds its own. Same hook rule as above for the "reset_*" ids.
const CUTSCENE_MEMORY := [
	{"overlay": "memory_exodus", "needs": "reset_exodus"},
	{"overlay": "memory_cataclysm", "needs": "reset_cataclysm"},
	{"overlay": "memory_loop", "needs": "reset_loop"},
	{"overlay": "memory_glyph", "needs": "name_read"},
	{"overlay": "memory_bloom", "needs": "bloom_seen"},
]
