extends RefCounted
## Dwelling tiers and what each asks of the settlement (design-system/17-needs-and-upgrades.md). Read through the `Data`
## facade (scripts/data.gd). The tier names are in words.gd (HOME_NAMES, same order).

## Dwelling, Homestead, Longhouse. Each tier has:
##   housing: Kith it houses (Shelter adds to each Dwelling on top).
##   foods: how many kinds of food the stockpile must hold at once (a kind counts at HOME_FOOD_STOCK or more).
##   goods: what the household uses up, item -> amount every HOME_GOOD_SECONDS; haulers carry it in from the stockpile.
##   up: what the next tier costs, item -> amount; haulers carry it to the home (the last tier has none).
## A home's needs are those of the tier it stands at. Met for HOME_UPGRADE_AFTER seconds, it asks for `up`.
const HOME_TIERS := [
	{"housing": 3, "foods": 1, "goods": {}, "up": {"wood": 10, "clay": 6}},
	{"housing": 5, "foods": 2, "goods": {"rope": 1}, "up": {"wood": 14, "brick": 8}},
	{"housing": 8, "foods": 3, "goods": {"brick": 1, "charcoal": 1}, "up": {}},
]

## How often a home looks at its needs (seconds): slowly, so a late delivery is a warning and not a famine.
const HOME_CHECK_SECONDS := 20.0
## A food kind counts as in stock at this many.
const HOME_FOOD_STOCK := 8
## A household uses its goods once this often (seconds), and haulers keep two rounds of them in the home.
const HOME_GOOD_SECONDS := 60.0
const HOME_GOOD_ROUNDS := 2
## Needs met this long (seconds, counted up on a met check and down on a missed one, never below 0) make a home ask to
## upgrade.
const HOME_UPGRADE_AFTER := 100.0
## Seconds a scaffold stands once the materials are in, before the home takes its new tier.
const HOME_BUILD_SECONDS := 30.0
## The most homes the player allows at a tier or above, until they say otherwise.
const HOME_CAP_OPEN := 99
