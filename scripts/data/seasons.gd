extends RefCounted
## Seasons of Strain (design-system/24-balance.md, pick 1; design-system/27-crises.md): a pressure that arrives every few minutes and
## asks a question with no right answer. Read through the `Data` facade (scripts/data.gd).

## The first season comes this long into a run; the next ones SEASON_EVERY seconds after the one before (give or take SEASON_JITTER).
const SEASON_FIRST := 360.0
const SEASON_EVERY := 270.0
const SEASON_JITTER := 30
## A season lasts this long once it is answered, and a card nobody answers answers itself (option 0) after SEASON_AUTO seconds of
## game time, so a bot or an idle window is never stuck.
const SEASON_LENGTH := 90.0
const SEASON_AUTO := 20.0
## Lean: food buildings work at this share of their pace. Ration: everyone eats this share. Forage: a trip brings this many times as much.
const LEAN_PACE := 0.45
const RATION_EAT := 0.75
const FORAGE_MULT := 2
## Fever: the sick eat this much more when tended, every building works at PUSH_PACE when the town pushes on.
const TEND_EAT := 1.25
const PUSH_PACE := 0.7
## Cold snap: every COLD_BURN_SECONDS the town burns one fuel (Charcoal, then Coal, then Wood). Huddling slows every workshop to
## HUDDLE_PACE and burns nothing.
const COLD_BURN_SECONDS := 2.0
const HUDDLE_PACE := 0.65
## Bloom surge: the tide moves at SURGE_PACE for the season, but nothing is lost to overgrowth in it, and the Bloom takes
## SURGE_TAKES of the raw goods in the stores when it comes. Holding it back costs SURGE_COAL Coal (or SURGE_WOOD Wood).
const SURGE_PACE := 1.5
const SURGE_TAKES := 0.2
const SURGE_COAL := 20
const SURGE_WOOD := 40
## Blight, Bad vein, Storm: the share of their pace the buildings it hits keep, with and without the answer that costs stores.
const BLIGHT_PACE := 0.4
const BLIGHT_TREATED_PACE := 0.75
const VEIN_PACE := 0.5
const STORM_PACE := 0.55

## The raw goods the Bloom takes a share of in a surge (the ones a town keeps in bulk).
const SURGE_GOODS := ["wood", "fiber", "stone", "clay", "berries", "grain"]
## The fuels a cold snap burns, first one with any stock first.
const FUELS := ["charcoal", "coal", "wood"]
## The buildings a "mines" pace hits.
const MINE_TYPES := ["mine", "coal_mine"]

## kind -> era it first comes in (1 the stone age, 2 Bronze Dawn, 3 the Falling Star, 4 Ironfall, 5 Livewire), what happens
## (formatted with the season's length in seconds and the people's name), and two answers. Both answers share the kind's "pace"
## (group -> share of pace; groups are food, workshops, fields, mines and all); an answer adds its own "pace", an "eat" share, "births"
## (none born), "forage" (idle hands forage), "tide" (the tide's pace), "keeps" (no building lost to the tide), "takes" (the share of
## SURGE_GOODS the Bloom takes), "drain" (fuels burnt every so often) and "cost" (alternatives: the first the stores can pay in full is
## paid, else the last is paid as far as the stores go).
const SEASONS := {
	"lean":
	{
		"era": 1,
		"title": "A lean season",
		"text":
		(
			"The bushes and fields are giving less. For %d seconds food buildings work at under half their pace."
			+ " How will the %s get through it?"
		),
		"pace": {"food": LEAN_PACE},
		"options":
		[
			{
				"label": "Ration",
				"note": "Everyone eats a quarter less, and no one is born until it passes.",
				"eat": RATION_EAT,
				"births": true,
			},
			{
				"label": "Forage",
				"note": "Idle hands forage from the start, and bring back twice as much a trip.",
				"forage": true,
			},
		],
		"told": "A lean season: food buildings work at under half their pace.",
		"over": "The lean season is over.",
	},
	"fever":
	{
		"era": 1,
		"title": "A fever",
		"text": "A sickness is going round. For %d seconds the %s are weak. How do they get through it?",
		"pace": {},
		"options":
		[
			{
				"label": "Tend the sick",
				"note": "Everyone eats a quarter more food for the season, and work goes on at its pace.",
				"eat": TEND_EAT,
			},
			{
				"label": "Push on",
				"note": "No one eats more, but every building works at seven tenths of its pace.",
				"pace": {"all": PUSH_PACE},
			},
		],
		"told": "A fever: the people are weak.",
		"over": "The fever has broken.",
	},
	"cold":
	{
		"era": 2,
		"title": "A cold snap",
		"text": "The nights bite. For %d seconds the %s need fire to keep warm. What do they burn?",
		"pace": {},
		"options":
		[
			{
				"label": "Burn fuel",
				"note":
				"One Charcoal (else Coal, else Wood) every two seconds from the stores, 45 in all. Work goes on.",
				"drain": FUELS,
			},
			{
				"label": "Huddle",
				"note": "Nothing burns, but every workshop works at two thirds of its pace.",
				"pace": {"workshops": HUDDLE_PACE},
			},
		],
		"told": "A cold snap: the town needs fire.",
		"over": "The cold snap has passed.",
	},
	"surge":
	{
		"era": 2,
		"needs": "tide",
		"title": "A Bloom surge",
		"text": "The green ground is moving. For %d seconds the tide could run half as fast again. What do the %s do?",
		"pace": {},
		"options":
		[
			{
				"label": "Let it come",
				"note":
				"The tide runs half again as fast and takes a fifth of the raw goods in the stores, but no building is lost to it.",
				"tide": SURGE_PACE,
				"keeps": true,
				"takes": SURGE_TAKES,
			},
			{
				"label": "Hold it back",
				"note": "Spend 20 Coal (or 40 Wood) now and the tide keeps its pace.",
				"cost": [{"coal": SURGE_COAL}, {"wood": SURGE_WOOD}],
			},
		],
		"told": "A Bloom surge: the tide is running.",
		"over": "The surge has passed.",
	},
	"blight":
	{
		"era": 3,
		"title": "A blight",
		"text": "The grain is going black in the rows. For %d seconds the fields fail. What do the %s do?",
		"pace": {},
		"options":
		[
			{
				"label": "Wait it out",
				"note": "Nothing is spent, but the fields work at two fifths of their pace.",
				"pace": {"fields": BLIGHT_PACE},
			},
			{
				"label": "Treat the rows",
				"note": "Spend 40 Wood and the fields keep three quarters of their pace.",
				"pace": {"fields": BLIGHT_TREATED_PACE},
				"cost": [{"wood": 40}],
			},
		],
		"told": "A blight: the fields are failing.",
		"over": "The blight has passed.",
	},
	"vein":
	{
		"era": 4,
		"title": "A bad vein",
		"text": "The rock is loose in the shafts. For %d seconds the mines are in danger. What do the %s do?",
		"pace": {},
		"options":
		[
			{
				"label": "Prop the shafts",
				"note": "Spend 40 Wood (or 10 Iron) and the mines work at four fifths of their pace.",
				"pace": {"mines": 0.8},
				"cost": [{"wood": 40}, {"iron": 10}],
			},
			{
				"label": "Dig round it",
				"note": "Nothing is spent, but the mines work at half their pace.",
				"pace": {"mines": VEIN_PACE},
			},
		],
		"told": "A bad vein: the mines are in danger.",
		"over": "The shafts are safe again.",
	},
	"storm":
	{
		"era": 5,
		"title": "A storm on the wires",
		"text": "Lightning walks the lines. For %d seconds the works are at risk. What do the %s do?",
		"pace": {},
		"options":
		[
			{
				"label": "Shelter",
				"note": "Nothing is spent, but every building works at just over half its pace.",
				"pace": {"all": STORM_PACE},
			},
			{
				"label": "Brave it",
				"note": "Spend 20 Iron (or 60 Wood) and every building works at nine tenths of its pace.",
				"pace": {"all": 0.9},
				"cost": [{"iron": 20}, {"wood": 60}],
			},
		],
		"told": "A storm on the wires: the works are at risk.",
		"over": "The storm has passed.",
	},
}
