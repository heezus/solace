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
	# Forget past runs: the profile cleared, so the next game is a first game.
	"forget": "Forget past runs",
	"forget_tip": "Clear what earlier runs left behind: the next new game is a first game.",
	"forget_confirm": "Forget every past run? The next new game starts as a first game, with nothing carried.",
	"forget_yes": "Forget",
	"forget_no": "Keep",
	"forget_done": "Past runs forgotten.",
	"forget_failed": "The past runs could not be cleared.",
	# Blueprints, the Exodus's gift (scripts/blueprints.gd): a boxed part of the town saved under a name, laid down again as plans.
	"bp_max": 6,  # blueprints held at once
	"bp_share": 0.7,  # a part laid from a banked blueprint (carried from an earlier run) costs this share of its price, rounded up
	"bp_label": "Blueprints",
	"bp_tip": "Save a part of the town as a blueprint, and lay it down again anywhere.",
	"bp_title": "BLUEPRINTS",
	"bp_save": "Save a blueprint: drag a box",
	"bp_save_hint": "Drag a box over what to keep. Right click to stop.",
	"bp_lay": "Lay down",
	"bp_drop": "Delete",
	"bp_empty": "Nothing saved yet. Drag a box over a road grid or a yard and keep it.",
	"bp_full": "Six blueprints are kept. Delete one to save another.",
	"bp_nothing": "Nothing in that box to keep.",
	"bp_saved": "Saved %s: %d parts",  # the name, the parts
	"bp_laid": "Plans laid for %d parts of %s",  # the parts, the name
	"bp_done": "The laid plans are all built",
	"bp_dropped": "%d plans could not be laid and were dropped",
	"bp_name": "Blueprint %d",
	"bp_carried": "%d blueprints carried from before",  # the new-land card line
}
