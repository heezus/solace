extends RefCounted
## Era 6, Skyreach (design-system/32-skyreach.md): survey the sky, meet the landfalls, raise the Skyreach. Read through the `Data`
## facade as `Data.SKYREACH` (one dictionary, as data.gd has no lines to spare). Every number is a first guess to tune with the bots.
## Run 1 never reaches it: Skyward still ends the first telling. From run 2 on, Skyward opens the sky and Skyreach is the last era.

const SKYREACH := {
	"begun": "skyreach_begun",  # the story moment Skyward's card opens it with, from run 2 on
	"done": "skyreach_done",  # the third stage stands: the endings card opens
	# --- The sky: 6 sectors round the Hearth, each named by where its middle lies ---
	"sectors": 6,
	"names": ["east", "south-east", "south-west", "west", "north-west", "north-east"],
	"warn": 90.0,  # seconds a landfall shows on a surveyed sector before it falls
	# --- Landfalls: waves of seed-falls, the same on a map every time ---
	"first_wave": 180.0,  # seconds after the Skyreach begins
	"wave_every": 120.0,
	"wave_min": 2,
	"wave_max": 4,
	"wave_more_every": 3,  # a wave later in the era carries one more fall for every this many waves
	"patch_radius": 2,  # tiles: the Bloom a fall starts, which then spreads as the tide does
	"far_min": 10,  # a fall lands this many tiles (and more) from the Hearth
	"far_max": 36,
	"apart": 6,  # falls of one wave keep this far from each other
	# --- The Skyreach: three stages, each one delivery, then a building time ---
	"site_min": 8,  # the site lies this far from the Hearth, in the sector of the first Signal Tower
	"site_max": 13,
	"site_sight": 6,
	"stage_cost":
	[
		{"steel": 40, "stone": 160},
		{"wire": 60, "shard": 3},
		{"steel": 30, "wire": 30, "brick": 120, "rope": 80, "copper": 80, "shard": 2},
	],
	"stage_seconds": 150.0,
	"help_speed": 0.7,  # a stage takes this share of its time with the Lumen helping (trust at neighbours or better)
	"help_leans": ["allies", "neighbours"],
	# --- The era card at Skyward (run 2 on) ---
	"card_title": "The sky is open",
	"card_text":
	(
		"The mast hums, and the Kith turn their eyes up. What hunted the Lumen across the stars has followed, "
		+ "and it will not come to fight. It will come to stay."
	),
	"card_note": "Survey the sky, then raise the Skyreach.",
	"card_button": "Begin the Skyreach",
	# --- The era card when the Skyreach stands: the end of the telling, from the second on ---
	"done_title": "The Skyreach stands",
	"done_text":
	(
		"The tower is lit from its foot to its crown, and the sky answers it. Whatever comes down now will find "
		+ "the Kith awake, and the telling has reached the place where it can turn."
	),
	"done_note": "The age of the sky is done. The game goes on.",
	"done_button": "Keep building",
	# --- Words ---
	"surveyed": "The %s is surveyed: landfalls there show %d seconds ahead",
	"site_found": "The Signal Tower has found a place for the Skyreach, %s of the Hearth",
	"warned": "A landfall is coming in the %s in %d seconds",
	"fell": "A seed fell in the %s",
	"fell_dark": "Something fell in the dark, far off",
	"stage_started": "The Skyreach's stage %d is begun",
	"stage_done": "The Skyreach's stage %d stands",
	"needs": "Stage %d needs %s",
	"building": "Stage %d: %d s to go",
	"ready": "The Skyreach stands",
	"site_tip": "Build it on the site the Signal Tower found",
	"goals":
	[
		{
			"id": "signal_tower",
			"text": "Build a Signal Tower: it surveys the sky sector it stands in",
			"building": "signal_tower"
		},
		{"id": "survey_three", "text": "Survey three sectors of the sky: a Signal Tower in each"},
		{
			"id": "sky_site",
			"text": "Build the Skyreach on the site the Signal Tower found",
			"building": "skyreach_tower"
		},
		{"id": "stage_1", "text": "Skyreach stage 1: deliver Steel and Stone"},
		{"id": "stage_2", "text": "Skyreach stage 2: deliver Wire and Shards"},
		{"id": "stage_3", "text": "Skyreach stage 3: deliver a mix of everything"},
	],
}
