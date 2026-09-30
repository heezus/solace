extends RefCounted
## The people the player leads: what they are called, their names, their job titles, and the messages
## that mention them. Faction words ("Kith") live here and nowhere in engine code, so a later faction
## (13-three-perspectives.md) only swaps this file. Read through the `Data` facade (scripts/data.gd).

## Display names for the people the player leads. Engine code formats its messages with these.
const PEOPLE := {"one": "Kith", "many": "Kith"}

## The event a birth sends to the UI, formatted with PEOPLE["one"].
const BORN_EVENT := "A %s was born"
## The event when one leaves in search of food, formatted with PEOPLE["one"].
const LEFT_EVENT := "A %s left in search of food"
## The early warning, sent once when food is about to run out (formatted with PEOPLE["many"]).
const FOOD_LOW_EVENT := "Food is running low. Hold the mouse on Berry Bushes to gather more, and the %s stay fed"
## Short earthy names, given in turn to each Kith as they're born (a second round adds " II").
const PEOPLE_NAMES := ["Aro", "Tam", "Esk", "Bru", "Olla", "Fen", "Rook", "Moss", "Sef", "Tarn", "Wren", "Hask"]

## Job titles (07-glossary.md, "Kith jobs"). They are labels only: a Kith's title comes from the building
## it works at (BUILDINGS `job`), a hut's from what it gathers most (HUT_JOBS), or from hauling or idling.
## `craft` names the skill in the toast when a Kith learns it by watching you.
const HUT_JOBS := {
	"wood": {"title": "Woodcutter", "craft": "to chop wood"},
	"stone": {"title": "Quarrier", "craft": "to quarry stone"},
	"flint": {"title": "Knapper", "craft": "to gather flint"},
	"berries": {"title": "Forager", "craft": "to pick berries"},
	"fiber": {"title": "Thatcher", "craft": "to cut flax"},
	"grain": {"title": "Reaper", "craft": "to reap grain"},
	"clay": {"title": "Digger", "craft": "to dig clay"},
}
const JOB_ANY := {"title": "Gatherer", "craft": "to gather"}  # for an item with no entry above
const JOB_HAULER := "Hauler"
const JOB_IDLE := "Idle"

## Messages and labels that name the people. Each is formatted with PEOPLE["one"] or PEOPLE["many"]
## (the noun they use is noted beside it).
const CAMP_TOAST := "The %s gather at the Hearth, hopeful. Hold the mouse on a tree to begin: the goals are on the right."  # many
const LEARNED_LINE := "%s learned %s and is now the %s."  # name, "to chop wood", job title
const BORN_POPUP := "+1 %s"  # one
const BORN_TOAST := "New %s arrive at the Hearth while food lasts"  # many
const NAMELESS := "A %s"  # one: who learns a job when no one is named
const BRIDGE_HINT := "Wooden Bridge. %s and haulers cross the river here."  # many
const ROAD_HINT := "Road on %s. %s walk twice as fast here."  # tile name, many
const FOOD_TIP := "Every %s eats food: Berries, then Fish, then any Flour that isn't in use."  # one
## The Food readout while the warning is up, formatted with the time left ("45 s").
const FOOD_LOW_TEXT := "Low: %s left. Gather berries!"
const STARVING_TEXT := "Food: none! The %s have stopped working"  # many
const TOOLS_LABEL := "Tools %d/%d %s"  # held, people, many
const TOOLS_TIP := "%s holding a Flint Tool work 50%% faster. Each tool lasts %d jobs; spares in the stockpile: %d."  # many
const FOOD_NOTE := "Food worth %s each. The %s eat it."  # many
const HUNGRY_THEN := "the %s go hungry"  # many
const EATEN_BY := "Eaten by the %s"  # many
