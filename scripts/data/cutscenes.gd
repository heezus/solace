extends RefCounted
## The cutscenes (design-system/20-cutscenes.md): short skippable sequences of painted stills that tell one story across the
## eras, in the Kith's own voice, never more than three short lines on a still. Played by scripts/cutscene_player.gd.
## A sequence is a row of CUTSCENES, in the order they play when several wait at once:
##   triggers the story ids (Data.STORY_EVENTS) any of which starts it, or "start" for a fresh run
##   after    optional: a story id that must have happened first, else it waits (the Bloom sign waits for Ironfall)
##   by       optional: what picks a still's variant (see ARRIVAL_KEY and LEAN_KEY in scripts/cutscene_player.gd)
##   stills   the painted stills in order: `art` is the file name under CUTSCENE_ART_DIR (no extension), `line` the
##            caption, and `variants` (optional) maps a variant key to the `art` and/or `line` it swaps in
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
			{"art": "first_contact_3", "line": "She tapped her chest and said a word, and waited."},
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
