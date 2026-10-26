extends RefCounted
## Step 7, the first reset, the Exodus (design-system/12-knowledge-is-progress.md): the words of "Set out" and of what the Kith
## carry into the next land, and the number the carry changes. Read through the `Data` facade (scripts/data.gd) as `Data.EXODUS`,
## one dictionary so the facade stays small. The words are placeholders until the story framing of a second run is chosen.

const EXODUS := {
	# What the carry does. A tech learned in an earlier run costs this share of its study (each item rounded up).
	"known_share": 0.3,
	"known_line": "Known from before: 30% of the study",
	# The card that opens a run that begins with a carry.
	"land_title": "A NEW LAND",
	"land_text": "The town stays behind. The Kith walk into a land they have not seen, carrying what they know.",
	"land_techs": "%d things they learned before, each at 30%% of the study",
	"land_marks": "%d marks of the strangers' writing, already read",
	"land_echoes": "The echo of %s: %s",  # the set, the building it opens
	"land_button": "Begin",
	# The Skyward card's second button, the game menu's entry and the confirm.
	"set_out": "Set out",
	"set_out_tip": "Leave this land for a new one, carrying what the Kith know. Opens once Skyward is raised.",
	"confirm": "Leave this land? The town stays behind. The Kith carry what they know.",
	"confirm_yes": "Set out",
	"confirm_no": "Stay",
	"unsaved": "The Kith's story could not be kept, so they stay.",
	# Forget past runs: the profile cleared, so the next game is a first game.
	"forget": "Forget past runs",
	"forget_tip": "Clear what earlier runs left behind: the next new game is a first game.",
	"forget_confirm": "Forget every past run? The next new game starts as a first game, with nothing carried.",
	"forget_yes": "Forget",
	"forget_no": "Keep",
	"forget_done": "Past runs forgotten.",
	"forget_failed": "The past runs could not be cleared.",
}
