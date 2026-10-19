extends RefCounted
## Seasons of Strain (design-system/24-balance.md, pick 1): a pressure that arrives every few minutes and asks a question with no
## right answer. Read through the `Data` facade (scripts/data.gd).

## The first season comes this long into a run; the next ones SEASON_EVERY seconds after the one before (give or take SEASON_JITTER).
const SEASON_FIRST := 360.0
const SEASON_EVERY := 270.0
const SEASON_JITTER := 30
## A season lasts this long once it is answered, and a card nobody answers answers itself (option 0) after SEASON_AUTO seconds of
## game time, so a bot or an idle window is never stuck.
const SEASON_LENGTH := 90.0
const SEASON_AUTO := 20.0
## Lean: food buildings work at this share of their pace. Ration: everyone eats this share. Forage: a trip brings this many times as much.
const LEAN_PACE := 0.6
const RATION_EAT := 0.75
const FORAGE_MULT := 2
## Cold snap: every COLD_BURN_SECONDS the town burns one fuel (Charcoal, else Coal), or one Wood on the other answer. Huddling slows every
## workshop to HUDDLE_PACE and burns nothing.
const COLD_BURN_SECONDS := 6.0
const HUDDLE_PACE := 0.8
## Bloom surge: the tide moves at SURGE_PACE for the season, but nothing is lost to overgrowth in it. Holding it back costs SURGE_COAL Coal.
const SURGE_PACE := 1.5
const SURGE_COAL := 20

## kind -> title, what happens (formatted with the season's length in seconds and the people's name), and two answers.
const SEASONS := {
	"lean":
	{
		"title": "A lean season",
		"text":
		(
			"The bushes and fields are giving less. For %d seconds food buildings work at three fifths of their pace."
			+ " How will the %s get through it?"
		),
		"options":
		[
			{"label": "Ration", "note": "Everyone eats a quarter less, and no one is born until it passes."},
			{"label": "Forage", "note": "Idle hands forage from the start, and bring back twice as much a trip."},
		],
		"told": "A lean season: food buildings work slower.",
		"over": "The lean season is over.",
	},
	"cold":
	{
		"title": "A cold snap",
		"text": "The nights bite. For %d seconds the %s need fire to keep warm. What do they burn?",
		"options":
		[
			{"label": "Burn fuel", "note": "One Charcoal (or Coal) every six seconds from the stores. Work goes on."},
			{"label": "Huddle", "note": "Nothing burns, but every workshop works at four fifths of its pace."},
		],
		"told": "A cold snap: the town needs fire.",
		"over": "The cold snap has passed.",
	},
	"surge":
	{
		"title": "A Bloom surge",
		"text": "The green ground is moving. For %d seconds the tide could run half as fast again. What do the %s do?",
		"options":
		[
			{
				"label": "Let it come",
				"note": "The tide runs half again as fast, but no building is lost to it in the season."
			},
			{"label": "Hold it back", "note": "Spend 20 Coal now and the tide keeps its pace."},
		],
		"told": "A Bloom surge: the tide is running.",
		"over": "The surge has passed.",
	},
}
